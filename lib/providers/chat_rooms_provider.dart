import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_room_model.dart';
import '../models/user_with_avatar_model.dart';
import '../models/message_receive_model.dart';
import '../services/chat_room_service.dart';
import '../services/message_service.dart';
import '../services/realtime_service.dart';
import '../services/unread_state_service.dart';
import '../services/user_service.dart';

class ChatRoomsProvider extends ChangeNotifier {
  ChatRoomsProvider(
    this._chatRoomService,
    this._realtimeService,
    this._messageService,
    this._unreadStateService,
    this._userService,
  );

  final ChatRoomService _chatRoomService;
  final RealtimeService _realtimeService;
  final MessageService _messageService;
  final UnreadStateService _unreadStateService;
  final UserService _userService;

  final Map<int, StreamSubscription<MessageReceiveModel>> _roomSubscriptions =
      {};
  StreamSubscription<InvitationReplyEvent>? _invitationReplySub;
  StreamSubscription<FriendRemovedEvent>? _friendRemovedSub;
  StreamSubscription<ChatRoomCreatedEvent>? _chatRoomCreatedSub;
  StreamSubscription<PresenceUpdateEvent>? _presenceSub;
  StreamSubscription<UserWithAvatarModel>? _profileSub;
  final Map<int, int> _unreadCounts = {};
  final Map<int, bool> _roomPeerOnline = {};

  String? _currentUsername;
  int? _activeRoomId;

  bool _isLoading = false;
  String? _error;
  List<ChatRoomModel> _rooms = const [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ChatRoomModel> get rooms => _rooms;

  int unreadCountFor(int roomId) => _unreadCounts[roomId] ?? 0;
  bool isPeerOnlineFor(int roomId) => _roomPeerOnline[roomId] ?? false;

  void upsertRoom(ChatRoomModel room) {
    final index = _rooms.indexWhere((item) => item.id == room.id);
    if (index < 0) {
      _rooms = _sortRooms([room, ..._rooms]);
    } else {
      final next = [..._rooms];
      next[index] = room;
      _rooms = _sortRooms(next);
    }

    _unreadCounts.putIfAbsent(room.id, () => 0);
    if (room.type != ChatRoomType.duo) {
      _roomPeerOnline[room.id] = false;
    }

    unawaited(_ensureRealtimeSubscriptions());
    notifyListeners();
  }

  void setCurrentUsername(String? username) {
    if (_currentUsername == username) {
      return;
    }
    _currentUsername = username;

    if (_rooms.isNotEmpty) {
      unawaited(_refreshOfflineUnreadCounts());
    }
  }

  void markRoomOpened(int roomId) {
    _activeRoomId = roomId;
    markRoomRead(roomId);
  }

  void markRoomClosed(int roomId) {
    if (_activeRoomId == roomId) {
      _activeRoomId = null;
    }
  }

  void markRoomRead(int roomId) {
    final room = _roomById(roomId);
    final lastSeenAt = room?.latestMessage?.sentOn ?? DateTime.now();
    unawaited(_unreadStateService.setLastReadAt(roomId, lastSeenAt));

    if ((_unreadCounts[roomId] ?? 0) == 0) {
      return;
    }

    _unreadCounts[roomId] = 0;
    notifyListeners();
  }

  Future<void> loadRooms() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _rooms = await _chatRoomService.listChatRooms();
      final roomIds = _rooms.map((room) => room.id).toSet();
      _unreadCounts.removeWhere((roomId, _) => !roomIds.contains(roomId));
      _roomPeerOnline.removeWhere((roomId, _) => !roomIds.contains(roomId));
      await _hydrateOfflineUnreadCounts();
      await _hydratePeerPresence();
      _rooms = _sortRooms(_rooms);
      await _ensureRealtimeSubscriptions();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startRealtime() async {
    await _realtimeService.connect();
    await _ensureRealtimeSubscriptions();

    _invitationReplySub ??=
        _realtimeService.invitationReplyStream.listen((event) async {
      final room = event.chatRoom;
      if (room == null) {
        return;
      }

      final index = _rooms.indexWhere((item) => item.id == room.id);
      if (index < 0) {
        _rooms = _sortRooms([room, ..._rooms]);
      } else {
        final next = [..._rooms];
        next[index] = room;
        _rooms = _sortRooms(next);
      }

      await _ensureRealtimeSubscriptions();
      notifyListeners();
    });

    _friendRemovedSub ??=
        _realtimeService.friendRemovedStream.listen((event) {
      final roomId = event.roomId;
      if (roomId == null) {
        return;
      }

      final nextRooms = _rooms.where((room) => room.id != roomId).toList();
      if (nextRooms.length == _rooms.length) {
        return;
      }

      _rooms = nextRooms;
      _unreadCounts.remove(roomId);
      _roomPeerOnline.remove(roomId);

      final roomSub = _roomSubscriptions.remove(roomId);
      roomSub?.cancel();

      if (_activeRoomId == roomId) {
        _activeRoomId = null;
      }

      notifyListeners();
    });

    _chatRoomCreatedSub ??=
        _realtimeService.chatRoomCreatedStream.listen((event) {
      final room = event.chatRoom;
      if (room == null) {
        return;
      }
      upsertRoom(room);
    });

    _presenceSub ??= _realtimeService.presenceStream.listen((event) {
      final presence = event.presence;
      final username = presence?.username ?? '';
      if (presence == null || username.isEmpty || _currentUsername == null) {
        return;
      }

      var changed = false;
      for (final room in _rooms) {
        final peer = room.duoPeerFor(_currentUsername);
        if (peer != username) {
          continue;
        }

        if (_roomPeerOnline[room.id] != presence.online) {
          _roomPeerOnline[room.id] = presence.online;
          changed = true;
        }
      }

      if (changed) {
        notifyListeners();
      }
    });

    _profileSub ??= _realtimeService.profileStream.listen((profile) {
      applyUserProfileUpdate(profile);
    });
  }

  void stopRealtime() {
    for (final sub in _roomSubscriptions.values) {
      sub.cancel();
    }
    _roomSubscriptions.clear();

    _invitationReplySub?.cancel();
    _invitationReplySub = null;

    _friendRemovedSub?.cancel();
    _friendRemovedSub = null;

    _chatRoomCreatedSub?.cancel();
    _chatRoomCreatedSub = null;

    _presenceSub?.cancel();
    _presenceSub = null;

    _profileSub?.cancel();
    _profileSub = null;
  }

  void applyUserProfileUpdate(UserWithAvatarModel profile) {
    final username = (profile.username ?? '').trim();
    if (username.isEmpty || _currentUsername == null) {
      return;
    }

    var changed = false;
    final next = <ChatRoomModel>[];

    for (final room in _rooms) {
      if (room.type != ChatRoomType.duo || room.duoPeerFor(_currentUsername) != username) {
        next.add(room);
        continue;
      }

      final updated = room.copyWith(
        name: profile.displayLabel,
        avatar: profile.avatar,
      );

      if (updated.name != room.name || updated.avatar?.source != room.avatar?.source) {
        changed = true;
      }

      next.add(updated);
    }

    if (!changed) {
      return;
    }

    _rooms = _sortRooms(next);
    notifyListeners();
  }

  Future<void> _hydratePeerPresence() async {
    final current = _currentUsername;
    if (current == null || current.isEmpty) {
      return;
    }

    final futures = _rooms.map((room) async {
      final peer = room.duoPeerFor(current);
      if (peer == null || peer.isEmpty) {
        _roomPeerOnline[room.id] = false;
        return;
      }

      try {
        final presence = await _userService.getPresence(peer);
        _roomPeerOnline[room.id] = presence.online;
      } catch (_) {
        _roomPeerOnline[room.id] = false;
      }
    });

    await Future.wait(futures);
  }

  Future<void> _ensureRealtimeSubscriptions() async {
    for (final room in _rooms) {
      if (_roomSubscriptions.containsKey(room.id)) {
        continue;
      }

      final sub = _realtimeService.roomMessageStream(room.id).listen((message) {
        _onIncomingRoomMessage(room.id, message);
      });
      _roomSubscriptions[room.id] = sub;
    }
  }

  void _onIncomingRoomMessage(int roomId, MessageReceiveModel message) {
    final index = _rooms.indexWhere((room) => room.id == roomId);
    if (index < 0) {
      return;
    }

    final isOwnMessage =
        _currentUsername != null && message.sender == _currentUsername;
    final isActiveRoom = _activeRoomId == roomId;

    if (!isOwnMessage && !isActiveRoom) {
      _unreadCounts[roomId] = (_unreadCounts[roomId] ?? 0) + 1;
    } else {
      final lastSeenAt = message.sentOn ?? DateTime.now();
      unawaited(_unreadStateService.setLastReadAt(roomId, lastSeenAt));
    }

    final updatedRoom = _rooms[index].copyWith(latestMessage: message);
    final nextRooms = [..._rooms];
    nextRooms[index] = updatedRoom;
    _rooms = _sortRooms(nextRooms);
    notifyListeners();
  }

  List<ChatRoomModel> _sortRooms(List<ChatRoomModel> input) {
    final sorted = [...input]
      ..sort((a, b) => b.latestTimestamp.compareTo(a.latestTimestamp));
    return sorted;
  }

  ChatRoomModel? _roomById(int roomId) {
    for (final room in _rooms) {
      if (room.id == roomId) {
        return room;
      }
    }
    return null;
  }

  Future<void> _refreshOfflineUnreadCounts() async {
    await _hydrateOfflineUnreadCounts();
    notifyListeners();
  }

  Future<void> _hydrateOfflineUnreadCounts() async {
    final username = _currentUsername;
    if (username == null || username.isEmpty) {
      return;
    }

    for (final room in _rooms) {
      final count = await _countUnreadFromHistory(room.id, username);
      _unreadCounts[room.id] = count;
    }
  }

  Future<int> _countUnreadFromHistory(int roomId, String currentUsername) async {
    var lastReadAt = await _unreadStateService.getLastReadAt(roomId);

    // Backward-compatible migration: if we don't have a read marker yet,
    // treat existing history as already read to avoid false unread badges.
    if (lastReadAt == null) {
      final room = _roomById(roomId);
      final inferredLastRead = room?.latestMessage?.sentOn;
      if (inferredLastRead != null) {
        await _unreadStateService.setLastReadAt(roomId, inferredLastRead);
        lastReadAt = inferredLastRead;
      }
    }

    var unread = 0;

    for (var page = 1; page <= 20; page++) {
      final messages = await _messageService.listMessages(roomId: roomId, page: page);
      if (messages.isEmpty) {
        break;
      }

      var reachedReadBoundary = false;
      for (final message in messages.reversed) {
        final sentOn = message.sentOn;
        if (sentOn == null) {
          continue;
        }

        if (lastReadAt != null && !sentOn.isAfter(lastReadAt)) {
          reachedReadBoundary = true;
          break;
        }

        if (message.sender != currentUsername) {
          unread++;
        }
      }

      if (reachedReadBoundary) {
        break;
      }

      if (lastReadAt == null) {
        break;
      }
    }

    return unread;
  }

  @override
  void dispose() {
    stopRealtime();
    super.dispose();
  }
}
