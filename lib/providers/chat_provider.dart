import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/message_receive_model.dart';
import '../services/message_service.dart';
import '../services/realtime_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required MessageService messageService,
    required RealtimeService realtimeService,
    required int roomId,
    required String? currentUsername,
  })  : _messageService = messageService,
        _realtimeService = realtimeService,
        _roomId = roomId,
        _currentUsername = currentUsername;

  final MessageService _messageService;
  final RealtimeService _realtimeService;
  final int _roomId;
  final String? _currentUsername;
  static const int _maxPersistedTranslations = 500;

  StreamSubscription<MessageReceiveModel>? _messageSub;

  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  List<MessageReceiveModel> _messages = const [];
  final Map<int, String> _translatedByMessageId = {};
  final Set<int> _translatingMessageIds = {};
  final Map<int, _PersistedTranslation> _persistedTranslations = {};
  bool _isPersistedTranslationsLoaded = false;

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  List<MessageReceiveModel> get messages => _messages;

  String? translatedTextForMessage(int? messageId) {
    if (messageId == null) {
      return null;
    }

    return _translatedByMessageId[messageId];
  }

  bool isTranslatingMessage(int? messageId) {
    if (messageId == null) {
      return false;
    }

    return _translatingMessageIds.contains(messageId);
  }

  Future<void> loadMessages() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final loaded = await _messageService.listMessages(roomId: _roomId);
      _messages = _sortBySentOn(loaded);
      await _loadPersistedTranslations();
      await _restoreTranslationsForCurrentMessages();
      _pruneTranslationState();
      await _emitReadStatus();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startRealtime() async {
    await _realtimeService.connect();
    _messageSub ??= _realtimeService.roomMessageStream(_roomId).listen((item) {
      _messages = _sortBySentOn([..._messages, item]);
      _pruneTranslationState();
      if (item.sender != _currentUsername) {
        unawaited(_emitReadStatus());
      }
      notifyListeners();
    });
  }

  void stopRealtime() {
    _messageSub?.cancel();
    _messageSub = null;
  }

  Future<bool> sendMessage({
    required String text,
    List<XFile> attachments = const [],
  }) async {
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      await _messageService.sendMessage(
        roomId: _roomId,
        text: text,
        attachments: attachments,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<bool> recallMessage({
    required int messageId,
  }) async {
    try {
      await _messageService.recallMessage(messageId);
      _translatedByMessageId.remove(messageId);
      _translatingMessageIds.remove(messageId);
      if (_persistedTranslations.remove(messageId) != null) {
        await _savePersistedTranslations();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> translateMessage({
    required int messageId,
    required String originalText,
    List<String> previousMessages = const [],
    bool forceRefresh = false,
  }) async {
    final normalizedText = originalText.trim();
    if (normalizedText.isEmpty) {
      _error = 'Translate message failed: empty text';
      notifyListeners();
      return false;
    }

    final cached = (_translatedByMessageId[messageId] ?? '').trim();
    if (!forceRefresh && cached.isNotEmpty) {
      return true;
    }

    _error = null;
    _translatingMessageIds.add(messageId);
    notifyListeners();

    try {
      final result = await _messageService.translateMessageToVietnamese(
        text: normalizedText,
        previousMessages: previousMessages,
      );
      final translatedText = result.translatedText.trim();
      if (translatedText.isEmpty) {
        _error = 'Translate message failed: empty translation';
        return false;
      }

      _translatedByMessageId[messageId] = translatedText;
      _persistedTranslations[messageId] = _PersistedTranslation(
        originalText: normalizedText,
        translatedText: translatedText,
      );
      await _savePersistedTranslations();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _translatingMessageIds.remove(messageId);
      notifyListeners();
    }
  }

  Future<void> setTypingStatus(bool typing) async {
    try {
      await _messageService.setTypingStatus(roomId: _roomId, typing: typing);
    } catch (_) {
      // Typing updates are best-effort and should not block chat flow.
    }
  }

  Future<void> refreshReadStatus() async {
    await _emitReadStatus();
  }

  Future<void> _emitReadStatus() async {
    try {
      await _messageService.setReadStatus(roomId: _roomId);
    } catch (_) {
      // Read receipts are best-effort and should not interrupt chat.
    }
  }

  String get _persistedTranslationsKey {
    final username = (_currentUsername ?? 'anonymous').trim();
    return 'chat.translation.cache.v1.$username.room.$_roomId';
  }

  Future<void> _loadPersistedTranslations() async {
    if (_isPersistedTranslationsLoaded) {
      return;
    }

    _isPersistedTranslationsLoaded = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_persistedTranslationsKey);
      if (raw == null || raw.isEmpty) {
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final loaded = <int, _PersistedTranslation>{};
      decoded.forEach((idKey, value) {
        final id = int.tryParse(idKey);
        if (id == null || value is! Map<String, dynamic>) {
          return;
        }

        final originalText = (value['originalText'] ?? '').toString().trim();
        final translatedText = (value['translatedText'] ?? '').toString().trim();
        if (originalText.isEmpty || translatedText.isEmpty) {
          return;
        }

        loaded[id] = _PersistedTranslation(
          originalText: originalText,
          translatedText: translatedText,
        );
      });

      _persistedTranslations
        ..clear()
        ..addAll(loaded);
    } catch (_) {
      // Ignore cache parsing failures and proceed without persisted translations.
    }
  }

  Future<void> _restoreTranslationsForCurrentMessages() async {
    _translatedByMessageId.clear();

    var changed = false;
    for (final message in _messages) {
      final id = message.id;
      if (id == null) {
        continue;
      }

      final persisted = _persistedTranslations[id];
      if (persisted == null) {
        continue;
      }

      final originalText = (message.message ?? '').trim();
      if (originalText.isEmpty || persisted.originalText != originalText) {
        _persistedTranslations.remove(id);
        changed = true;
        continue;
      }

      _translatedByMessageId[id] = persisted.translatedText;
    }

    if (changed) {
      await _savePersistedTranslations();
    }
  }

  Future<void> _savePersistedTranslations() async {
    try {
      if (_persistedTranslations.length > _maxPersistedTranslations) {
        final sortedIds = _persistedTranslations.keys.toList()
          ..sort((a, b) => a.compareTo(b));
        final overflow = _persistedTranslations.length - _maxPersistedTranslations;
        for (var i = 0; i < overflow; i++) {
          _persistedTranslations.remove(sortedIds[i]);
        }
      }

      final encoded = <String, Map<String, String>>{};
      _persistedTranslations.forEach((id, persisted) {
        encoded[id.toString()] = {
          'originalText': persisted.originalText,
          'translatedText': persisted.translatedText,
        };
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_persistedTranslationsKey, jsonEncode(encoded));
    } catch (_) {
      // Ignore persistence failures and keep in-memory behavior.
    }
  }

  void _pruneTranslationState() {
    final existingIds = _messages.map((item) => item.id).whereType<int>().toSet();
    _translatedByMessageId.removeWhere((id, _) => !existingIds.contains(id));
    _translatingMessageIds.removeWhere((id) => !existingIds.contains(id));
  }

  List<MessageReceiveModel> _sortBySentOn(List<MessageReceiveModel> items) {
    final uniqueById = <int, MessageReceiveModel>{};
    final noIdMessages = <MessageReceiveModel>[];

    for (final item in items) {
      final id = item.id;
      if (id == null) {
        noIdMessages.add(item);
      } else {
        uniqueById[id] = item;
      }
    }

    final values = [...uniqueById.values, ...noIdMessages]..sort((a, b) {
        final aTime = a.sentOn?.millisecondsSinceEpoch ?? 0;
        final bTime = b.sentOn?.millisecondsSinceEpoch ?? 0;
        return aTime.compareTo(bTime);
      });

    return values;
  }

  @override
  void dispose() {
    stopRealtime();
    super.dispose();
  }
}

class _PersistedTranslation {
  const _PersistedTranslation({
    required this.originalText,
    required this.translatedText,
  });

  final String originalText;
  final String translatedText;
}
