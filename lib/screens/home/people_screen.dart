import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_room_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_rooms_provider.dart';
import '../../providers/user_search_provider.dart';
import '../../services/chat_room_service.dart';
import '../../services/invitation_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_avatar.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoadingBlocked = false;
  Set<String> _blockedUsernames = {};
  List<String> _blockedDisplayNames = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBlockedUsers();
    });
  }

  Future<void> _removeFriend(ChatRoomModel room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xoá bạn bè'),
          content: const Text(
              'Hành động này sẽ xoá người bạn và cuộc trò chuyện tương ứng. Tiếp tục?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xoá'),
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
        const SnackBar(content: Text('Đã xoá bạn bè')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xoá bạn thất bại: $e')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadBlockedUsers() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingBlocked = true;
    });

    try {
      final blocked = await context.read<UserService>().listBlockedUsers();
      if (!mounted) {
        return;
      }

      setState(() {
        _blockedUsernames = blocked
            .map((item) => (item.username ?? '').trim())
            .where((item) => item.isNotEmpty)
            .toSet();
        _blockedDisplayNames = blocked
            .map((item) => item.displayLabel)
            .where((item) => item.trim().isNotEmpty)
            .toList();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBlocked = false;
        });
      }
    }
  }

  Future<void> _blockUser(String username) async {
    final userService = context.read<UserService>();
    final roomsProvider = context.read<ChatRoomsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await userService.blockUser(username);
      await _loadBlockedUsers();
      await roomsProvider.loadRooms();
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Đã chặn @$username')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Chặn người dùng thất bại: $e')),
      );
    }
  }

  Future<void> _unblockUser(String username) async {
    final userService = context.read<UserService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await userService.unblockUser(username);
      await _loadBlockedUsers();
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Đã bỏ chặn @$username')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Bỏ chặn thất bại: $e')),
      );
    }
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
                title: const Text('Gửi lời mời kết bạn'),
                onTap: () => Navigator.pop(context, 'friend'),
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: const Text('Mời vào nhóm'),
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
          const SnackBar(content: Text('Đã gửi lời mời kết bạn')),
        );
      } catch (e) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gửi lời mời thất bại: $e')),
        );
      }
      return;
    }

    final controller = TextEditingController();

    final chatGroupId = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mời vào nhóm'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Nhập ID nhóm chat (ChatGroupId)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () {
                final id = int.tryParse(controller.text.trim());
                Navigator.pop(context, id);
              },
              child: const Text('Gửi'),
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
        const SnackBar(content: Text('Đã gửi lời mời')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gửi lời mời thất bại: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserSearchProvider>();
    final roomsProvider = context.watch<ChatRoomsProvider>();
    final currentUsername = context.watch<AuthProvider>().username;
    final normalizedQuery = _searchController.text.trim().toLowerCase();

    final friends = roomsProvider.rooms
        .where((room) => room.type == ChatRoomType.duo)
        .where((room) {
      if (normalizedQuery.isEmpty) {
        return true;
      }

      final friendName = room.displayNameFor(currentUsername).toLowerCase();
      if (friendName.contains(normalizedQuery)) {
        return true;
      }

      final friendUsername =
          (room.duoPeerFor(currentUsername) ?? '').toLowerCase();
      if (friendUsername.contains(normalizedQuery)) {
        return true;
      }

      final latestPreview =
          room.latestPreviewFor(currentUsername).toLowerCase();
      return latestPreview.contains(normalizedQuery);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Tìm kiếm người dùng và bạn bè',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        if (provider.isLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView(
            children: [
              if (friends.isNotEmpty || normalizedQuery.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 6, 14, 6),
                  child: Text(
                    'Bạn bè',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                ...friends.map((room) {
                  final friendName = room.displayNameFor(currentUsername);
                  final peerUsername = room.duoPeerFor(currentUsername) ?? '';
                  final isBlocked = _blockedUsernames.contains(peerUsername);
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
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'remove') {
                          _removeFriend(room);
                          return;
                        }

                        if (peerUsername.isEmpty) {
                          return;
                        }

                        if (value == 'block') {
                          _blockUser(peerUsername);
                        } else if (value == 'unblock') {
                          _unblockUser(peerUsername);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'remove',
                          child: Text('Xoá bạn bè'),
                        ),
                        PopupMenuItem<String>(
                          value: isBlocked ? 'unblock' : 'block',
                          child:
                              Text(isBlocked ? 'Bỏ chặn' : 'Chặn người dùng'),
                        ),
                      ],
                      icon: const Icon(Icons.more_vert),
                    ),
                  );
                }),
                if (friends.isEmpty && normalizedQuery.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Không tìm thấy bạn bè nào khớp.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                const Divider(height: 24),
              ],
              if (_isLoadingBlocked)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_blockedDisplayNames.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 4, 14, 6),
                  child: Text(
                    'Người dùng đã chặn',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                ..._blockedDisplayNames.map((name) => ListTile(
                      leading: const Icon(Icons.block),
                      title: Text(name),
                    )),
                const Divider(height: 24),
              ],
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 4, 14, 6),
                child: Text(
                  'Tìm người',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (normalizedQuery.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: Center(
                    child: Text('Gõ để tìm kiếm người dùng và bạn bè'),
                  ),
                )
              else if (!provider.isLoading && provider.users.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 26),
                  child: Center(
                    child: Text(
                        'Không tìm thấy người dùng cho "${_searchController.text.trim()}".'),
                  ),
                )
              else
                ...provider.users.map((user) {
                  final displayName = user.displayLabel;
                  final username = user.username ?? '';
                  final isBlocked = _blockedUsernames.contains(username);
                  return ListTile(
                    leading: AppAvatar(
                      url: user.avatar?.source,
                      name: displayName,
                    ),
                    title: Text(displayName),
                    subtitle: username.isNotEmpty && username != displayName
                        ? Text('@$username')
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.tonal(
                          onPressed: user.username == null || isBlocked
                              ? null
                              : () => _inviteUser(user.username!),
                          child: const Text('Mời'),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: isBlocked ? 'Bỏ chặn' : 'Chặn người dùng',
                          onPressed: username.isEmpty
                              ? null
                              : () {
                                  if (isBlocked) {
                                    _unblockUser(username);
                                  } else {
                                    _blockUser(username);
                                  }
                                },
                          icon: Icon(isBlocked ? Icons.lock_open : Icons.block),
                        ),
                      ],
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
