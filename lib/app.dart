import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_rooms_provider.dart';
import 'providers/invitation_provider.dart';
import 'providers/user_search_provider.dart';
import 'providers/video_call_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/invitations_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/chatbot_service.dart';
import 'services/chat_room_service.dart';
import 'models/fcm_notification_payload.dart';
import 'services/firebase_messaging_service.dart';
import 'services/group_chat_service.dart';
import 'services/invitation_service.dart';
import 'services/local_notification_service.dart';
import 'services/message_service.dart';
import 'services/realtime_service.dart';
import 'services/token_storage_service.dart';
import 'services/unread_state_service.dart';
import 'services/user_service.dart';

class MessengerApp extends StatefulWidget {
  const MessengerApp({super.key});

  @override
  State<MessengerApp> createState() => _MessengerAppState();
}

class _MessengerAppState extends State<MessengerApp>
    with WidgetsBindingObserver {
  StreamSubscription<FcmNotificationPayload>? _tapSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().bootstrap();

      _tapSub = context
          .read<FirebaseMessagingService>()
          .tapStream
          .listen(_handleNotificationTap);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final realtime = context.read<RealtimeService>();
    if (!realtime.isConnected) return;

    switch (state) {
      case AppLifecycleState.resumed:
        realtime.sendAppPresence(active: true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        realtime.sendAppPresence(active: false);
        break;
    }
  }

  void _handleNotificationTap(FcmNotificationPayload payload) {
    final navigator = Navigator.of(context);

    switch (payload.type) {
      case 'message':
        final roomId = int.tryParse(payload.roomId ?? '0');
        if (roomId != null && roomId > 0) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                roomId: roomId,
                roomName: 'Chat',
              ),
            ),
          );
        }
        break;
      case 'invitation':
      case 'group_invitation':
        navigator.push(
          MaterialPageRoute(builder: (_) => const InvitationsScreen()),
        );
        break;
      case 'group_added':
      case 'group_member_removed':
        final roomId = int.tryParse(payload.roomId ?? '0');
        if (roomId != null && roomId > 0) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                roomId: roomId,
                roomName: 'Group',
              ),
            ),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'Messenger App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: auth.isLoading
          ? const _SplashScreen()
          : auth.isAuthenticated
              ? const HomeScreen()
              : const LoginScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<SingleChildWidget> createAppProviders({
  required ApiClient apiClient,
  required AuthService authService,
  required ChatbotService chatbotService,
  required ChatRoomService chatRoomService,
  required GroupChatService groupChatService,
  required UserService userService,
  required InvitationService invitationService,
  required MessageService messageService,
  required RealtimeService realtimeService,
  required UnreadStateService unreadStateService,
  required TokenStorageService tokenStorage,
  required LocalNotificationService localNotificationService,
}) {
  final firebaseMessagingService = FirebaseMessagingService(
    localNotificationService: localNotificationService,
    apiClient: apiClient,
  );

  return [
    Provider.value(value: apiClient),
    Provider.value(value: authService),
    Provider.value(value: chatbotService),
    Provider.value(value: chatRoomService),
    Provider.value(value: groupChatService),
    Provider.value(value: userService),
    Provider.value(value: invitationService),
    Provider.value(value: messageService),
    Provider.value(value: realtimeService),
    Provider.value(value: unreadStateService),
    Provider.value(value: tokenStorage),
    Provider.value(value: localNotificationService),
    Provider.value(value: firebaseMessagingService),
    ChangeNotifierProvider(
      create: (_) => AuthProvider(
        authService: authService,
        realtimeService: realtimeService,
        tokenStorage: tokenStorage,
        userService: userService,
        firebaseMessagingService: firebaseMessagingService,
      ),
    ),
    ChangeNotifierProvider(
      create: (_) => ChatRoomsProvider(
        chatRoomService,
        realtimeService,
        messageService,
        unreadStateService,
        userService,
      ),
    ),
    ChangeNotifierProvider(
      create: (_) => UserSearchProvider(userService),
    ),
    ChangeNotifierProvider(
      create: (_) => InvitationProvider(
        invitationService,
        realtimeService,
      ),
    ),
    ChangeNotifierProvider(
      create: (_) => VideoCallProvider(),
    ),
  ];
}
