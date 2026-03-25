import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_rooms_provider.dart';
import 'providers/invitation_provider.dart';
import 'providers/user_search_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/auth_service.dart';
import 'services/chat_room_service.dart';
import 'services/group_chat_service.dart';
import 'services/invitation_service.dart';
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

class _MessengerAppState extends State<MessengerApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'Messenger App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: auth.isLoading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : auth.isAuthenticated
              ? const HomeScreen()
              : const LoginScreen(),
    );
  }
}

List<SingleChildWidget> createAppProviders({
  required AuthService authService,
  required ChatRoomService chatRoomService,
  required GroupChatService groupChatService,
  required UserService userService,
  required InvitationService invitationService,
  required MessageService messageService,
  required RealtimeService realtimeService,
  required UnreadStateService unreadStateService,
  required TokenStorageService tokenStorage,
}) {
  return [
    Provider.value(value: authService),
    Provider.value(value: chatRoomService),
    Provider.value(value: groupChatService),
    Provider.value(value: userService),
    Provider.value(value: invitationService),
    Provider.value(value: messageService),
    Provider.value(value: realtimeService),
    Provider.value(value: unreadStateService),
    Provider.value(value: tokenStorage),
    ChangeNotifierProvider(
      create: (_) => AuthProvider(
        authService: authService,
        realtimeService: realtimeService,
        tokenStorage: tokenStorage,
        userService: userService,
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
  ];
}
