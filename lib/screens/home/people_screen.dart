import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_room_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_rooms_provider.dart';
import '../../providers/user_search_provider.dart';
import '../../services/chat_room_service.dart';
import '../../services/invitation_service.dart';
import '../../widgets/app_avatar.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  Future<void> _removeFriend(ChatRoomModel room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove friend'),
          content: const Text('This will remove this friend and chat room. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    final chatRoomService = context.read<ChatRoomService>();
    final roomsProvider = context.read<ChatRoomsProvider>();

    try {
      await chatRoomService.removeFriend(roomId: room.id);
      await roomsProvider.loadRooms();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend removed')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Remove friend failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      context.read<UserSearchProvider>().search(value);
    });
  }

  Future<void> _inviteUser(String username) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt_1),
                title: const Text('Send friend request'),
                onTap: () => Navigator.pop(context, 'friend'),
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: const Text('Invite to group'),
                onTap: () => Navigator.pop(context, 'group'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || mode == null) {
      return;
    }

    if (mode == 'friend') {
      try {
        await context.read<InvitationService>().sendInvitation(
              receiverUserName: username,
            );

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent')),
        );
      } catch (e) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send invitation failed: $e')),
        );
      }
      return;
    }

    final controller = TextEditingController();

    final chatGroupId = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Invite to group'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter chatGroupId',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final id = int.tryParse(controller.text.trim());
                Navigator.pop(context, id);
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (!mounted || chatGroupId == null) {
      return;
    }

    try {
      await context.read<InvitationService>().sendInvitation(
            receiverUserName: username,
            chatGroupId: chatGroupId,
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation sent')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send invitation failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserSearchProvider>();
    final roomsProvider = context.watch<ChatRoomsProvider>();
    final currentUsername = context.watch<AuthProvider>().username;

    final friends = roomsProvider.rooms
        .where((room) => room.type == ChatRoomType.duo)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search username',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        if (provider.isLoading)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView(
            children: [
              if (friends.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 6, 14, 6),
                  child: Text(
                    'Friends',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                ...friends.map((room) {
                  final friendName = room.displayNameFor(currentUsername);
                  return ListTile(
                    leading: AppAvatar(
                      url: room.avatar?.source,
                      name: friendName,
                    ),
                    title: Text(friendName),
                    subtitle: Text(
                      room.latestPreviewFor(currentUsername),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove friend',
                      onPressed: () => _removeFriend(room),
                      icon: const Icon(Icons.person_remove_alt_1),
                    ),
                  );
                }),
                const Divider(height: 24),
              ],
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 4, 14, 6),
                child: Text(
                  'Find people',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (provider.users.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: Center(
                    child: Text('Find users by username'),
                  ),
                )
              else
                ...provider.users.map((user) {
                  final displayName = user.displayLabel;
                  final username = user.username ?? '';
                  return ListTile(
                    leading: AppAvatar(
                      url: user.avatar?.source,
                      name: displayName,
                    ),
                    title: Text(displayName),
                    subtitle: username.isNotEmpty && username != displayName
                        ? Text('@$username')
                        : null,
                    trailing: FilledButton.tonal(
                      onPressed: user.username == null
                          ? null
                          : () => _inviteUser(user.username!),
                      child: const Text('Invite'),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}
