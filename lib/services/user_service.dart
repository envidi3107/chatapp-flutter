import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/user_presence_model.dart';
import '../models/user_block_status_model.dart';
import '../models/user_with_avatar_model.dart';
import 'api_client.dart';

class UserService {
  const UserService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<UserWithAvatarModel>> searchUsers({
    required String query,
    int limit = 10,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/users/search/',
      query: {
        'q': query,
        'limit': limit,
      },
      authRequired: false,
    );

    if (response.statusCode != 200) {
      throw Exception('Search user failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return body
        .whereType<Map<String, dynamic>>()
        .map(UserWithAvatarModel.fromJson)
        .toList();
  }

  Future<UserPresenceModel> getPresence(String username) async {
    final response = await _apiClient.get(
      '/api/v1/users/$username/presence/',
    );

    if (response.statusCode != 200) {
      throw Exception('Load presence failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return UserPresenceModel.fromJson(body);
  }

  Future<UserWithAvatarModel> getMyProfile() async {
    final response = await _apiClient.get('/api/v1/users/me/');

    if (response.statusCode != 200) {
      throw Exception('Load profile failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return UserWithAvatarModel.fromJson(body);
  }

  Future<UserWithAvatarModel> updateMyProfile({
    required String displayName,
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
          filename: avatar.name.isEmpty ? 'avatar_upload.bin' : avatar.name,
        ),
      ];
    }

    final streamed = await _apiClient.putMultipart(
      '/api/v1/users/me/',
      fields: {
        'displayName': displayName,
      },
      buildFiles: buildFiles,
    );

    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Update profile failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return UserWithAvatarModel.fromJson(body);
  }

  Future<List<UserWithAvatarModel>> listBlockedUsers() async {
    final response = await _apiClient.get('/api/v1/users/blocks/');

    if (response.statusCode != 200) {
      throw Exception('Load blocked users failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return body
        .whereType<Map<String, dynamic>>()
        .map(UserWithAvatarModel.fromJson)
        .toList();
  }

  Future<void> blockUser(String username) async {
    final response = await _apiClient.postJson(
      '/api/v1/users/$username/block/',
      const {},
    );

    if (response.statusCode != 204) {
      throw Exception('Block user failed: ${response.body}');
    }
  }

  Future<void> unblockUser(String username) async {
    final response = await _apiClient.delete('/api/v1/users/$username/block/');

    if (response.statusCode != 204) {
      throw Exception('Unblock user failed: ${response.body}');
    }
  }

  Future<UserBlockStatusModel> getBlockStatus(String username) async {
    final response = await _apiClient.get('/api/v1/users/$username/block-status/');

    if (response.statusCode != 200) {
      throw Exception('Load block status failed: ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return UserBlockStatusModel.fromJson(body);
  }
}
