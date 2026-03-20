import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

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

  StreamSubscription<MessageReceiveModel>? _messageSub;

  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  List<MessageReceiveModel> _messages = const [];

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  List<MessageReceiveModel> get messages => _messages;

  Future<void> loadMessages() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final loaded = await _messageService.listMessages(roomId: _roomId);
      _messages = _sortBySentOn(loaded);
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
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
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

    final values = [...uniqueById.values, ...noIdMessages]
      ..sort((a, b) {
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
