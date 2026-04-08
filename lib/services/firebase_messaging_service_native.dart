import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_client.dart';
import '../models/fcm_notification_payload.dart';
import 'local_notification_service.dart';
import 'fcm_token_manager_service.dart';
import 'notification_settings_service.dart';

class FirebaseMessagingService {
  FirebaseMessagingService({
    required this.localNotificationService,
    required this.apiClient,
  });

  final LocalNotificationService localNotificationService;
  final ApiClient apiClient;
  late final NotificationSettingsService _notificationSettingsService;
  late final FcmTokenManagerService _tokenManager;
  bool _pushEnabled = true;

  final StreamController<FcmNotificationPayload> _tapController =
      StreamController<FcmNotificationPayload>.broadcast();

  Stream<FcmNotificationPayload> get tapStream => _tapController.stream;

  Future<void> initialize() async {
    _notificationSettingsService = NotificationSettingsService(apiClient);

    // Initialize the token manager
    _tokenManager = FcmTokenManagerService(apiClient: apiClient);

    // Don't block the app - run FCM init in background
    unawaited(_initializeAsync());
  }

  Future<void> _initializeAsync() async {
    try {
      print('[FCM] Requesting permission...');
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('[FCM] Permission granted');
    } catch (e) {
      print('[FCM] Permission request failed (non-fatal): $e');
      // Non-fatal: app continues even if permission fails
    }

    try {
      _pushEnabled = await _notificationSettingsService.getPushEnabled();
      if (_pushEnabled) {
        await _registerCurrentToken();
      } else {
        print('[FCM] Push notifications disabled by user settings');
      }
    } catch (e) {
      print('[FCM] Failed to load push settings or register token: $e');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('[FCM] Token refreshed: $newToken');
      if (_pushEnabled) {
        _tokenManager.registerTokenWithRetry(newToken);
      }
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    try {
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      print('[FCM] getInitialMessage failed: $e');
      // Non-fatal: app continues even if this fails
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    try {
      print('[FCM] Foreground message: ${message.data}');
      final data = message.data;
      final type = data['type'] as String?;
      final title =
          message.notification?.title ?? data['title'] ?? 'New notification';
      final body = message.notification?.body ?? data['body'] ?? '';

      switch (type) {
        case 'message':
          final roomId = int.tryParse(data['roomId'] ?? '0');
          if (roomId != null && roomId > 0) {
            localNotificationService.showMessageNotification(
              roomId: roomId,
              title: title,
              body: body,
            );
          }
          break;
        case 'invitation':
        case 'group_invitation':
          final invitationId = int.tryParse(data['invitationId'] ?? '0');
          if (invitationId != null && invitationId > 0) {
            localNotificationService.showInvitationNotification(
              invitationId: invitationId,
              title: title,
              body: body,
            );
          }
          break;
        case 'group_added':
        case 'group_member_removed':
          final roomId = int.tryParse(data['roomId'] ?? '0');
          if (roomId != null && roomId > 0) {
            localNotificationService.showGroupAddedNotification(
              roomId: roomId,
              title: title,
              body: body,
            );
          }
          break;
      }
    } catch (e) {
      print('[FCM] Error handling foreground message: $e');
      // Non-fatal: app continues even if notification handling fails
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    try {
      final data = message.data;
      final payload = FcmNotificationPayload.fromData(data);
      _tapController.add(payload);
    } catch (e) {
      print('[FCM] Error handling notification tap: $e');
      // Non-fatal: app continues even if tap handling fails
    }
  }

  Future<void> syncPushPreference(bool enabled) async {
    _pushEnabled = enabled;
    if (!_pushEnabled) {
      print('[FCM] Push preference set to disabled');
      return;
    }

    await _registerCurrentToken();
  }

  Future<void> _registerCurrentToken() async {
    try {
      print('[FCM] Getting token...');
      final token = await FirebaseMessaging.instance.getToken();
      print('[FCM] Token = $token');
      if (token != null && token.isNotEmpty) {
        await _tokenManager.registerTokenWithRetry(token);
      } else {
        print('[FCM] getToken() returned null or empty');
      }
    } catch (e) {
      print('[FCM] Failed to get token: $e');
    }
  }

  void dispose() {
    _tapController.close();
    _tokenManager.dispose();
  }
}
