import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/chat_room_service.dart';
import 'services/group_chat_service.dart';
import 'services/invitation_service.dart';
import 'services/message_service.dart';
import 'services/realtime_service.dart';
import 'services/token_storage_service.dart';
import 'services/unread_state_service.dart';
import 'services/user_service.dart';

void main() {
  final tokenStorage = TokenStorageService();
  final apiClient = ApiClient(tokenStorage: tokenStorage);

  final authService = AuthService(apiClient);
  final chatRoomService = ChatRoomService(apiClient);
  final groupChatService = GroupChatService(apiClient);
  final messageService = MessageService(apiClient);
  final invitationService = InvitationService(apiClient);
  final userService = UserService(apiClient);
  final realtimeService = RealtimeService(tokenStorage);
  final unreadStateService = UnreadStateService();

  runApp(
    MultiProvider(
      providers: createAppProviders(
        authService: authService,
        chatRoomService: chatRoomService,
        groupChatService: groupChatService,
        userService: userService,
        invitationService: invitationService,
        messageService: messageService,
        realtimeService: realtimeService,
        unreadStateService: unreadStateService,
        tokenStorage: tokenStorage,
      ),
      child: const MessengerApp(),
    ),
  );
}
