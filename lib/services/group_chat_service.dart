import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/attachment_model.dart';
import '../models/chat_room_model.dart';
import '../models/message_receive_model.dart';
import '../models/user_with_avatar_model.dart';
import 'api_client.dart';

class GroupChatService {
  const GroupChatService(this._apiClient);

  final ApiClient _apiClient;

  /// Create a new group chat
  ///
  /// [name] - Group name (required)
  /// [memberIds] - List of user IDs to add as members (minimum 2)
  /// [avatarId] - Optional avatar attachment ID
  Future<GroupChatDto> createGroup({
    required String name,
    required List<int> memberIds,
    int? avatarId,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'memberIds': memberIds,
    };

    if (avatarId != null) {
      body['avatarId'] = avatarId;
    }

    final response = await _apiClient.postJson(
      '/api/v1/chatrooms/groups/',
      body,
    );

    if (response.statusCode != 201) {
      throw Exception('Create group failed: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return GroupChatDto.fromJson(json);
  }

  /// Get group details by room ID
  Future<GroupChatDto> getGroupDetails(int roomId) async {
    final response = await _apiClient.get('/api/v1/chatrooms/$roomId/groups/');

    if (response.statusCode != 200) {
      throw Exception('Get group details failed: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return GroupChatDto.fromJson(json);
  }

  /// Update group information (admin only)
  ///
  /// [roomId] - Group room ID
  /// [name] - New group name (optional)
  /// [avatarId] - New avatar attachment ID (optional)
  Future<GroupChatDto> updateGroup({
    required int roomId,
    String? name,
    int? avatarId,
  }) async {
    final body = <String, dynamic>{};

    if (name != null) {
      body['name'] = name;
    }

    if (avatarId != null) {
      body['avatarId'] = avatarId;
    }

    final response = await _apiClient.patchJson(
      '/api/v1/chatrooms/$roomId/groups/',
      body,
    );

    if (response.statusCode != 200) {
      throw Exception('Update group failed: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return GroupChatDto.fromJson(json);
  }

  /// Update group profile using multipart form (name and/or avatar file).
  Future<GroupChatDto> updateGroupProfile({
    required int roomId,
    String? name,
    XFile? avatar,
  }) async {
    Future<List<http.MultipartFile>> buildFiles() async {
      if (avatar == null) {
        return <http.MultipartFile>[];
      }

      final bytes = await avatar.readAsBytes();
      return [
        http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename:
              avatar.name.isEmpty ? 'group_avatar_upload.bin' : avatar.name,
        ),
      ];
    }

    final fields = <String, String>{};
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      fields['name'] = trimmedName;
    }

    final streamed = await _apiClient.putMultipart(
      '/api/v1/chatrooms/$roomId/groups/',
      fields: fields,
      buildFiles: buildFiles,
    );

    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Update group profile failed: ${response.body}');
    }

    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return GroupChatDto.fromJson(json);
  }

  /// Add members to a group (any current member)
  ///
  /// [roomId] - Group room ID
  /// [memberIds] - List of user IDs to add
  Future<GroupChatDto> addMembers({
    required int roomId,
    required List<int> memberIds,
  }) async {
    final response = await _apiClient.postJson(
      '/api/v1/chatrooms/$roomId/groups/members/',
      {'memberIds': memberIds},
    );

    if (response.statusCode != 200) {
      throw Exception('Add members failed: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return GroupChatDto.fromJson(json);
  }

  /// Remove a member from a group (creator only)
  Future<void> removeMember({
    required int roomId,
    required int userId,
  }) async {
    final response = await _apiClient.delete(
      '/api/v1/chatrooms/$roomId/groups/members/$userId/',
    );

    if (response.statusCode != 204) {
      throw Exception('Remove member failed: ${response.body}');
    }
  }

  /// Leave a group
  Future<void> leaveGroup(int roomId) async {
    final response = await _apiClient.delete(
      '/api/v1/chatrooms/$roomId/groups/leave/',
    );

    if (response.statusCode != 204) {
      throw Exception('Leave group failed: ${response.body}');
    }
  }

  /// Dissolve a group (owner only)
  Future<void> dissolveGroup(int roomId) async {
    final response = await _apiClient.delete(
      '/api/v1/chatrooms/$roomId/groups/dissolve/',
    );

    if (response.statusCode != 204) {
      throw Exception('Dissolve group failed: ${response.body}');
    }
  }
}

/// Data transfer object for group chat details
class GroupChatDto {
  const GroupChatDto({
    required this.id,
    required this.name,
    required this.avatar,
    required this.members,
    required this.type,
    required this.createdOn,
    required this.latestMessage,
    required this.isAdmin,
    required this.isOwner,
  });

  final int id;
  final String name;
  final AttachmentModel? avatar;
  final List<UserWithAvatarModel> members;
  final ChatRoomType type;
  final DateTime? createdOn;
  final MessageReceiveModel? latestMessage;
  final bool isAdmin;
  final bool isOwner;

  factory GroupChatDto.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic value) {
      if (value is bool) {
        return value;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == 'true' || normalized == '1';
      }
      if (value is num) {
        return value != 0;
      }
      return false;
    }

    final avatarJson = json['avatar'];
    final latestMessageJson = json['latestMessage'];
    final membersJson = json['members'] as List<dynamic>? ?? [];
    final rawIsAdmin =
        json.containsKey('isAdmin') ? json['isAdmin'] : json['admin'];
    final rawIsOwner =
        json.containsKey('isOwner') ? json['isOwner'] : json['owner'];

    return GroupChatDto(
      id: (json['id'] ?? 0) as int,
      name: (json['name'] ?? '').toString(),
      avatar: avatarJson is Map<String, dynamic>
          ? AttachmentModel.fromJson(avatarJson)
          : null,
      members: membersJson
          .whereType<Map<String, dynamic>>()
          .map((m) => UserWithAvatarModel.fromJson(m))
          .toList(),
      type: parseChatRoomType(json['type'] as String?),
      createdOn: DateTime.tryParse((json['createdOn'] ?? '').toString()),
      latestMessage: latestMessageJson is Map<String, dynamic>
          ? MessageReceiveModel.fromJson(latestMessageJson)
          : null,
      isAdmin: parseBool(rawIsAdmin),
      isOwner: parseBool(rawIsOwner),
    );
  }

  /// Convert to ChatRoomModel for use with existing UI
  ChatRoomModel toChatRoomModel() {
    return ChatRoomModel(
      id: id,
      name: name,
      avatar: avatar,
      membersUsername: members
          .map((m) => (m.username ?? '').trim())
          .where((username) => username.isNotEmpty)
          .toList(),
      type: type,
      createdOn: createdOn,
      pinned: false,
      latestMessage: latestMessage,
    );
  }
}
