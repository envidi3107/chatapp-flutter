import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_rooms_provider.dart';
import '../../providers/invitation_provider.dart';
import '../../providers/user_search_provider.dart';
import '../../services/realtime_service.dart';
import 'chat_list_screen.dart';
import 'create_group_screen.dart';
import 'invitations_screen.dart';
import 'people_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  StreamSubscription? _invitationNotificationSub;
  StreamSubscription? _profileSub;
  InvitationProvider? _invitationProvider;

  static const _tabs = [
    ChatListScreen(),
    PeopleScreen(),
    InvitationsScreen(),
  ];

  static const _tabTitles = ['Chats', 'People', 'Invitations'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invitationProvider = context.read<InvitationProvider>();
      _invitationProvider = invitationProvider;
      invitationProvider.startRealtime();
      invitationProvider.loadInvitations();

      _invitationNotificationSub =
          context.read<RealtimeService>().invitationStream.listen((invitation) {
        if (!mounted || !invitation.isPending) {
          return;
        }

        final sender = invitation.sender?.username ?? 'Someone';
        final text = invitation.isFriendInvitation
            ? '$sender sent you a friend request'
            : '$sender invited you to a group';

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(text),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'View',
                onPressed: () {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _tabIndex = 2;
                  });
                },
              ),
            ),
          );
      });

      _profileSub = context.read<RealtimeService>().profileStream.listen((profile) {
        if (!mounted) {
          return;
        }

        context.read<AuthProvider>().applyProfileRealtime(profile);
        context.read<ChatRoomsProvider>().applyUserProfileUpdate(profile);
        context.read<UserSearchProvider>().applyUserProfileUpdate(profile);
        context.read<InvitationProvider>().applyUserProfileUpdate(profile);
      });
    });
  }

  @override
  void dispose() {
    _invitationNotificationSub?.cancel();
    _profileSub?.cancel();
    _invitationProvider?.stopRealtime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final invitationProvider = context.watch<InvitationProvider>();
    final pendingInvites = invitationProvider.pendingCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabTitles[_tabIndex],
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
            icon: const Icon(Icons.manage_accounts_outlined),
            tooltip: 'Profile',
          ),
          if (_tabIndex == 0)
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreateGroupScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.group_add),
              tooltip: 'Create group',
            ),
          if (_tabIndex == 0)
            IconButton(
              onPressed: () {
                context.read<AuthProvider>().logout();
              },
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Logout ${auth.displayName}',
            ),
        ],
      ),
      body: IndexedStack(index: _tabIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          setState(() => _tabIndex = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'People',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pendingInvites > 0,
              label: Text(pendingInvites > 99 ? '99+' : '$pendingInvites'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: pendingInvites > 0,
              label: Text(pendingInvites > 99 ? '99+' : '$pendingInvites'),
              child: const Icon(Icons.notifications),
            ),
            label: 'Invites',
          ),
        ],
      ),
    );
  }
}
