import 'dart:convert';

import 'api_client.dart';

class NotificationSettingsService {
  const NotificationSettingsService(this._apiClient);

  final ApiClient _apiClient;

  Future<bool> getPushEnabled() async {
    final response =
        await _apiClient.get('/api/v1/users/me/notification-settings/');

    if (response.statusCode != 200) {
      throw Exception('Load notification settings failed: ${response.body}');
    }

    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    return body['pushEnabled'] == true;
  }

  Future<bool> updatePushEnabled(bool enabled) async {
    final response = await _apiClient.putJson(
      '/api/v1/users/me/notification-settings/',
      {'pushEnabled': enabled},
    );

    if (response.statusCode != 200) {
      throw Exception('Update notification settings failed: ${response.body}');
    }

    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    return body['pushEnabled'] == true;
  }
}
