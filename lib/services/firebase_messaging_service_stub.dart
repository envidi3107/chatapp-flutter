import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/fcm_notification_payload.dart';
import 'api_client.dart';
import 'local_notification_service.dart';

class FirebaseMessagingService {
  FirebaseMessagingService({
    required this.localNotificationService,
    required this.apiClient,
  });

  final LocalNotificationService localNotificationService;
  final ApiClient apiClient;

  final StreamController<FcmNotificationPayload> _tapController =
      StreamController<FcmNotificationPayload>.broadcast();

  Stream<FcmNotificationPayload> get tapStream => _tapController.stream;

  Future<void> initialize() async {
    if (kIsWeb) return;
    print('FCM: initialize() called but no native implementation available');
  }

  Future<void> syncPushPreference(bool enabled) async {
    if (kIsWeb) return;
  }

  void dispose() => _tapController.close();
}
