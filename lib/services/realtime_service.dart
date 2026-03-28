import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../core/app_constants.dart';
import '../models/chat_room_model.dart';
import '../models/invitation_model.dart';
import '../models/message_receive_model.dart';
import '../models/user_block_status_model.dart';
import '../models/user_with_avatar_model.dart';
import '../models/user_presence_model.dart';
import 'token_storage_service.dart';

class InvitationReplyEvent {
  const InvitationReplyEvent({
    required this.chatRoom,
  });

  final ChatRoomModel? chatRoom;

  factory InvitationReplyEvent.fromJson(Map<String, dynamic> json) {
    final roomJson = json['chatRoomDto'] ?? json['newChatRoom'];
    return InvitationReplyEvent(
      chatRoom: roomJson is Map<String, dynamic>
          ? ChatRoomModel.fromJson(roomJson)
          : null,
    );
  }
}

class FriendRemovedEvent {
  const FriendRemovedEvent({required this.roomId});

  final int? roomId;

  factory FriendRemovedEvent.fromJson(Map<String, dynamic> json) {
    final rawRoomId = json['roomId'];
    if (rawRoomId is int) {
      return FriendRemovedEvent(roomId: rawRoomId);
    }

    return FriendRemovedEvent(roomId: int.tryParse(rawRoomId?.toString() ?? ''));
  }
}

class ChatRoomCreatedEvent {
  const ChatRoomCreatedEvent({required this.chatRoom});

  final ChatRoomModel? chatRoom;

  factory ChatRoomCreatedEvent.fromJson(Map<String, dynamic> json) {
    final roomJson = json['chatRoom'] ?? json['room'] ?? json['chatRoomDto'];
    return ChatRoomCreatedEvent(
      chatRoom: roomJson is Map<String, dynamic>
          ? ChatRoomModel.fromJson(roomJson)
          : null,
    );
  }
}

class GroupMemberRemovedEvent {
  const GroupMemberRemovedEvent({
    required this.roomId,
    required this.removedUserId,
    required this.removedUsername,
    required this.action,
    required this.actionBy,
  });

  final int? roomId;
  final int? removedUserId;
  final String? removedUsername;
  final String? action;
  final String? actionBy;

  factory GroupMemberRemovedEvent.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value is int) {
        return value;
      }
      return int.tryParse(value?.toString() ?? '');
    }

    final username = json['removedUsername']?.toString().trim();
    final eventAction = json['action']?.toString().trim().toLowerCase();
    final rawActionBy = json['actionBy']?.toString().trim();

    return GroupMemberRemovedEvent(
      roomId: parseInt(json['roomId']),
      removedUserId: parseInt(json['removedUserId']),
      removedUsername: username == null || username.isEmpty ? null : username,
      action: eventAction == null || eventAction.isEmpty ? null : eventAction,
      actionBy: rawActionBy == null || rawActionBy.isEmpty ? null : rawActionBy,
    );
  }
}

class GroupMembersAddedEvent {
  const GroupMembersAddedEvent({
    required this.roomId,
    required this.newMembers,
    required this.addedBy,
  });

  final int? roomId;
  final List<String> newMembers;
  final String? addedBy;

  factory GroupMembersAddedEvent.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value is int) {
        return value;
      }
      return int.tryParse(value?.toString() ?? '');
    }

    final rawMembers = json['newMembers'] as List<dynamic>? ?? const [];
    final members = rawMembers
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final rawAddedBy = json['addedBy']?.toString().trim();

    return GroupMembersAddedEvent(
      roomId: parseInt(json['roomId']),
      newMembers: members,
      addedBy: rawAddedBy == null || rawAddedBy.isEmpty ? null : rawAddedBy,
    );
  }
}

class PresenceUpdateEvent {
  const PresenceUpdateEvent({required this.presence});

  final UserPresenceModel? presence;

  factory PresenceUpdateEvent.fromJson(Map<String, dynamic> json) {
    return PresenceUpdateEvent(
      presence: UserPresenceModel.fromJson(json),
    );
  }
}

class TypingStatusEvent {
  const TypingStatusEvent({
    required this.roomId,
    required this.sender,
    required this.typing,
  });

  final int roomId;
  final String sender;
  final bool typing;

  factory TypingStatusEvent.fromJson(Map<String, dynamic> json) {
    return TypingStatusEvent(
      roomId: (json['roomId'] ?? 0) as int,
      sender: (json['sender'] ?? '').toString(),
      typing: json['typing'] == true,
    );
  }
}

class ReadStatusEvent {
  const ReadStatusEvent({
    required this.roomId,
    required this.reader,
    required this.readAt,
  });

  final int roomId;
  final UserWithAvatarModel? reader;
  final DateTime? readAt;

  factory ReadStatusEvent.fromJson(Map<String, dynamic> json) {
    final readerJson = json['reader'];
    return ReadStatusEvent(
      roomId: (json['roomId'] ?? 0) as int,
      reader: readerJson is Map<String, dynamic>
          ? UserWithAvatarModel.fromJson(readerJson)
          : null,
      readAt: DateTime.tryParse((json['readAt'] ?? '').toString()),
    );
  }
}

class RealtimeService {
  RealtimeService(this._tokenStorage);

  final TokenStorageService _tokenStorage;

  StompClient? _client;
  bool _isConnected = false;
  bool _isConnecting = false;

  final Set<int> _requestedRooms = {};
  final Set<int> _activeRoomSubscriptions = {};
  final Set<int> _activeTypingSubscriptions = {};
  final Set<int> _activeReadSubscriptions = {};

  final StreamController<InvitationModel> _invitationController =
      StreamController<InvitationModel>.broadcast();
  final StreamController<InvitationReplyEvent> _invitationReplyController =
      StreamController<InvitationReplyEvent>.broadcast();
  final StreamController<FriendRemovedEvent> _friendRemovedController =
      StreamController<FriendRemovedEvent>.broadcast();
  final StreamController<ChatRoomCreatedEvent> _chatRoomCreatedController =
      StreamController<ChatRoomCreatedEvent>.broadcast();
  final StreamController<GroupMemberRemovedEvent> _groupMemberRemovedController =
      StreamController<GroupMemberRemovedEvent>.broadcast();
  final StreamController<GroupMembersAddedEvent> _groupMembersAddedController =
      StreamController<GroupMembersAddedEvent>.broadcast();
  final StreamController<PresenceUpdateEvent> _presenceController =
      StreamController<PresenceUpdateEvent>.broadcast();
  final StreamController<UserWithAvatarModel> _profileController =
      StreamController<UserWithAvatarModel>.broadcast();
  final StreamController<UserBlockStatusModel> _blockStatusController =
      StreamController<UserBlockStatusModel>.broadcast();
  final Map<int, StreamController<MessageReceiveModel>> _roomControllers = {};
  final Map<int, StreamController<TypingStatusEvent>> _typingControllers = {};
  final Map<int, StreamController<ReadStatusEvent>> _readControllers = {};

  bool get isConnected => _isConnected;

  Stream<InvitationModel> get invitationStream => _invitationController.stream;

  Stream<InvitationReplyEvent> get invitationReplyStream =>
      _invitationReplyController.stream;

  Stream<FriendRemovedEvent> get friendRemovedStream =>
      _friendRemovedController.stream;
  Stream<ChatRoomCreatedEvent> get chatRoomCreatedStream =>
      _chatRoomCreatedController.stream;
  Stream<GroupMemberRemovedEvent> get groupMemberRemovedStream =>
      _groupMemberRemovedController.stream;
  Stream<GroupMembersAddedEvent> get groupMembersAddedStream =>
      _groupMembersAddedController.stream;

  Stream<PresenceUpdateEvent> get presenceStream => _presenceController.stream;
  Stream<UserWithAvatarModel> get profileStream => _profileController.stream;
  Stream<UserBlockStatusModel> get blockStatusStream => _blockStatusController.stream;

  Stream<MessageReceiveModel> roomMessageStream(int roomId) {
    _requestedRooms.add(roomId);

    final controller = _roomControllers.putIfAbsent(
      roomId,
      () => StreamController<MessageReceiveModel>.broadcast(),
    );

    if (_isConnected) {
      _subscribeRoom(roomId);
    }

    return controller.stream;
  }

  Stream<TypingStatusEvent> roomTypingStream(int roomId) {
    _requestedRooms.add(roomId);

    final controller = _typingControllers.putIfAbsent(
      roomId,
      () => StreamController<TypingStatusEvent>.broadcast(),
    );

    if (_isConnected) {
      _subscribeTyping(roomId);
    }

    return controller.stream;
  }

  Stream<ReadStatusEvent> roomReadStream(int roomId) {
    _requestedRooms.add(roomId);

    final controller = _readControllers.putIfAbsent(
      roomId,
      () => StreamController<ReadStatusEvent>.broadcast(),
    );

    if (_isConnected) {
      _subscribeRead(roomId);
    }

    return controller.stream;
  }

  Future<void> connect() async {
    if (_isConnected || _isConnecting) {
      return;
    }

    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return;
    }

    _isConnecting = true;

    _client = StompClient(
      config: StompConfig.sockJS(
        url: '${AppConstants.baseUrl}/socket',
        reconnectDelay: const Duration(seconds: 4),
        stompConnectHeaders: {
          'Authorization': 'Bearer $accessToken',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $accessToken',
        },
        onConnect: (_) {
          _isConnected = true;
          _isConnecting = false;
          _activeRoomSubscriptions.clear();
          _activeTypingSubscriptions.clear();
          _activeReadSubscriptions.clear();
          _subscribeInvitations();
          _subscribeInvitationReplies();
          _subscribeFriendRemoved();
          _subscribeChatRoomCreated();
          _subscribeGroupMembersAdded();
          _subscribeGroupMemberRemoved();
          _subscribePresence();
          _subscribeProfileUpdates();
          _subscribeBlockStatusUpdates();
          for (final roomId in _requestedRooms) {
            _subscribeRoom(roomId);
            _subscribeTyping(roomId);
            _subscribeRead(roomId);
          }
        },
        onWebSocketError: (_) {
          _isConnected = false;
          _isConnecting = false;
          _activeRoomSubscriptions.clear();
          _activeTypingSubscriptions.clear();
          _activeReadSubscriptions.clear();
        },
        onStompError: (_) {
          _isConnected = false;
          _isConnecting = false;
          _activeRoomSubscriptions.clear();
          _activeTypingSubscriptions.clear();
          _activeReadSubscriptions.clear();
        },
        onDisconnect: (_) {
          _isConnected = false;
          _activeRoomSubscriptions.clear();
          _activeTypingSubscriptions.clear();
          _activeReadSubscriptions.clear();
        },
      ),
    );

    _client!.activate();
  }

  void disconnect() {
    _isConnected = false;
    _isConnecting = false;
    _activeRoomSubscriptions.clear();
    _activeTypingSubscriptions.clear();
    _activeReadSubscriptions.clear();
    _client?.deactivate();
    _client = null;
  }

  void dispose() {
    disconnect();
    _invitationController.close();
    _invitationReplyController.close();
    _friendRemovedController.close();
    _chatRoomCreatedController.close();
    _groupMemberRemovedController.close();
    _groupMembersAddedController.close();
    _presenceController.close();
    _profileController.close();
    _blockStatusController.close();
    for (final controller in _roomControllers.values) {
      controller.close();
    }
    for (final controller in _typingControllers.values) {
      controller.close();
    }
    for (final controller in _readControllers.values) {
      controller.close();
    }
    _roomControllers.clear();
    _typingControllers.clear();
    _readControllers.clear();
  }

  void _subscribeInvitations() {
    _client?.subscribe(
      destination: '/user/queue/invitations/',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) {
          return;
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          return;
        }

        _invitationController.add(InvitationModel.fromJson(decoded));
      },
    );
  }

  void _subscribeInvitationReplies() {
    _client?.subscribe(
      destination: '/user/queue/invitationReplies/',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) {
          _invitationReplyController.add(
            const InvitationReplyEvent(chatRoom: null),
          );
          return;
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          _invitationReplyController.add(
            const InvitationReplyEvent(chatRoom: null),
          );
          return;
        }

        _invitationReplyController.add(InvitationReplyEvent.fromJson(decoded));
      },
    );
  }

  void _subscribeRoom(int roomId) {
    if (_activeRoomSubscriptions.contains(roomId)) {
      return;
    }

    _client?.subscribe(
      destination: '/user/queue/chat/$roomId',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) {
          return;
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          return;
        }

        final message = MessageReceiveModel.fromJson(decoded);
        final controller = _roomControllers.putIfAbsent(
          roomId,
          () => StreamController<MessageReceiveModel>.broadcast(),
        );
        controller.add(message);
      },
    );

    _activeRoomSubscriptions.add(roomId);
  }

  void _subscribeFriendRemoved() {
    _client?.subscribe(
      destination: '/user/queue/friends/removed/',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) {
          _friendRemovedController.add(const FriendRemovedEvent(roomId: null));
          return;
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          _friendRemovedController.add(const FriendRemovedEvent(roomId: null));
          return;
        }

        _friendRemovedController.add(FriendRemovedEvent.fromJson(decoded));
      },
    );
  }

  void _subscribeChatRoomCreated() {
    _client?.subscribe(
      destination: '/user/queue/chatrooms/created/',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) {
          _chatRoomCreatedController.add(
            const ChatRoomCreatedEvent(chatRoom: null),
          );
          return;
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          _chatRoomCreatedController.add(
            const ChatRoomCreatedEvent(chatRoom: null),
          );
          return;
        }

        _chatRoomCreatedController.add(ChatRoomCreatedEvent.fromJson(decoded));
      },
    );
  }

  void _subscribeGroupMemberRemoved() {
    _client?.subscribe(
      destination: '/user/queue/groups/member_removed',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) {
          return;
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          return;
        }

        _groupMemberRemovedController.add(
          GroupMemberRemovedEvent.fromJson(decoded),
        );
      },
    );
  }

  void _subscribeGroupMembersAdded() {
    _client?.subscribe(
      destination: '/user/queue/groups/members_added',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) {
          return;
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          return;
        }

        _groupMembersAddedController.add(
          GroupMembersAddedEvent.fromJson(decoded),
        );
      },
    );
  }

  void _subscribeTyping(int roomId) {
    if (_activeTypingSubscriptions.contains(roomId)) {
      return;
    }

    _client?.subscribe(
      destination: '/user/queue/chat/$roomId/typing',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) {
          return;
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          return;
        }

        final event = TypingStatusEvent.fromJson(decoded);
        final controller = _typingControllers.putIfAbsent(
          roomId,
          () => StreamController<TypingStatusEvent>.broadcast(),
        );
        controller.add(event);
      },
    );

    _activeTypingSubscriptions.add(roomId);
  }

  void _subscribeRead(int roomId) {
    if (_activeReadSubscriptions.contains(roomId)) {
      return;
    }

    _client?.subscribe(
      destination: '/user/queue/chat/$roomId/read',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) {
          return;
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          return;
        }

        final event = ReadStatusEvent.fromJson(decoded);
        final controller = _readControllers.putIfAbsent(
          roomId,
          () => StreamController<ReadStatusEvent>.broadcast(),
        );
        controller.add(event);
      },
    );

    _activeReadSubscriptions.add(roomId);
  }

  void _subscribePresence() {
    _client?.subscribe(
      destination: '/queue/presence/',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) {
          return;
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          return;
        }

        _presenceController.add(PresenceUpdateEvent.fromJson(decoded));
      },
    );
  }

  void _subscribeProfileUpdates() {
    _client?.subscribe(
      destination: '/queue/users/profile/',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) {
          return;
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          return;
        }

        _profileController.add(UserWithAvatarModel.fromJson(decoded));
      },
    );
  }

  void _subscribeBlockStatusUpdates() {
    _client?.subscribe(
      destination: '/user/queue/users/block/',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) {
          return;
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          return;
        }

        _blockStatusController.add(UserBlockStatusModel.fromJson(decoded));
      },
    );
  }
}
