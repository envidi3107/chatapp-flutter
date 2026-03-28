import 'attachment_model.dart';
import 'message_receive_model.dart';

enum ChatRoomType { duo, group, unknown }

ChatRoomType parseChatRoomType(String? raw) {
  switch (raw) {
    case 'DUO':
      return ChatRoomType.duo;
    case 'GROUP':
      return ChatRoomType.group;
    default:
      return ChatRoomType.unknown;
  }
}

class ChatRoomModel {
  const ChatRoomModel({
    required this.id,
    required this.name,
    required this.avatar,
    required this.membersUsername,
    required this.type,
    required this.createdOn,
    required this.pinned,
    required this.latestMessage,
  });

  final int id;
  final String? name;
  final AttachmentModel? avatar;
  final List<String> membersUsername;
  final ChatRoomType type;
  final DateTime? createdOn;
  final bool pinned;
  final MessageReceiveModel? latestMessage;

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    final avatarJson = json['avatar'];
    final latestMessageJson = json['latestMessage'];
    return ChatRoomModel(
      id: (json['id'] ?? 0) as int,
      name: json['name'] as String?,
      avatar: avatarJson is Map<String, dynamic>
          ? AttachmentModel.fromJson(avatarJson)
          : null,
      membersUsername: (json['membersUsername'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      type: parseChatRoomType(json['type'] as String?),
      createdOn: DateTime.tryParse((json['createdOn'] ?? '').toString()),
      pinned: json['pinned'] == true,
      latestMessage: latestMessageJson is Map<String, dynamic>
          ? MessageReceiveModel.fromJson(latestMessageJson)
          : null,
    );
  }

  ChatRoomModel copyWith({
    int? id,
    String? name,
    AttachmentModel? avatar,
    List<String>? membersUsername,
    ChatRoomType? type,
    DateTime? createdOn,
    bool? pinned,
    MessageReceiveModel? latestMessage,
  }) {
    return ChatRoomModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      membersUsername: membersUsername ?? this.membersUsername,
      type: type ?? this.type,
      createdOn: createdOn ?? this.createdOn,
      pinned: pinned ?? this.pinned,
      latestMessage: latestMessage ?? this.latestMessage,
    );
  }

  int get latestTimestamp {
    return latestMessage?.sentOn?.millisecondsSinceEpoch ??
        createdOn?.millisecondsSinceEpoch ??
        0;
  }

  String displayNameFor(String? currentUsername) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    if (type == ChatRoomType.duo && currentUsername != null) {
      final other = membersUsername.firstWhere(
        (username) => username != currentUsername,
        orElse: () => '',
      );
      if (other.isNotEmpty) {
        return other;
      }
    }

    if (membersUsername.isNotEmpty) {
      return membersUsername.join(', ');
    }

    return 'Unknown room';
  }

  String? duoPeerFor(String? currentUsername) {
    if (type != ChatRoomType.duo || currentUsername == null) {
      return null;
    }

    final other = membersUsername.firstWhere(
      (username) => username != currentUsername,
      orElse: () => '',
    );

    if (other.isEmpty) {
      return null;
    }

    return other;
  }

  String latestPreviewFor(String? currentUsername) {
    final latest = latestMessage;
    if (latest == null) {
      return 'Start the conversation';
    }

    final content = (latest.message ?? '').trim();
    if (content.isNotEmpty) {
      final isMine =
          currentUsername != null && latest.sender == currentUsername;
      final senderName = (latest.sender ?? '').trim();
      if (senderName.isEmpty || isMine) {
        return content;
      }
      return '$senderName: $content';
    }

    if (latest.attachments.isNotEmpty) {
      return 'Sent an attachment';
    }

    return 'Message recalled';
  }
}
