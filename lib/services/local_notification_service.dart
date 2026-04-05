import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService();

  static const AndroidNotificationChannel _messagesChannel =
      AndroidNotificationChannel(
    'chat_messages',
    'Chat messages',
    description: 'Notifications for new chat messages.',
    importance: Importance.max,
  );

  static const AndroidNotificationChannel _invitationsChannel =
      AndroidNotificationChannel(
    'chat_invitations',
    'Invitations',
    description: 'Notifications for friend and group invitations.',
    importance: Importance.max,
  );

  static const AndroidNotificationChannel _groupsChannel =
      AndroidNotificationChannel(
    'chat_groups',
    'Group updates',
    description: 'Notifications for being added to a group.',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _nextNotificationId = 1;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      linux: LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      ),
    );

    await _plugin.initialize(
      settings: initializationSettings,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_messagesChannel);
    await android?.createNotificationChannel(_invitationsChannel);
    await android?.createNotificationChannel(_groupsChannel);

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) {
      return;
    }

    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macos = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    await macos?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> showMessageNotification({
    required int roomId,
    required String title,
    required String body,
  }) {
    return _show(
      channel: _messagesChannel,
      title: title,
      body: body,
      payload: 'message:$roomId',
      threadIdentifier: 'message_$roomId',
    );
  }

  Future<void> showInvitationNotification({
    required int invitationId,
    required String title,
    required String body,
  }) {
    return _show(
      channel: _invitationsChannel,
      title: title,
      body: body,
      payload: 'invitation:$invitationId',
      threadIdentifier: 'invitation_$invitationId',
    );
  }

  Future<void> showGroupAddedNotification({
    required int? roomId,
    required String title,
    required String body,
  }) {
    final resolvedRoomId = roomId ?? 0;
    return _show(
      channel: _groupsChannel,
      title: title,
      body: body,
      payload: 'group:$resolvedRoomId',
      threadIdentifier: 'group_$resolvedRoomId',
    );
  }

  Future<void> _show({
    required AndroidNotificationChannel channel,
    required String title,
    required String body,
    required String payload,
    required String threadIdentifier,
  }) async {
    if (kIsWeb) {
      return;
    }

    await initialize();

    final notificationId = _nextNotificationId++;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        threadIdentifier: threadIdentifier,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        threadIdentifier: threadIdentifier,
      ),
      linux: const LinuxNotificationDetails(),
    );

    await _plugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
