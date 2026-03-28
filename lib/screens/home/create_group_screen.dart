import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_with_avatar_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_rooms_provider.dart';
import '../../services/group_chat_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_avatar.dart';
import '../chat/chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();
  final Map<int, UserWithAvatarModel> _selectedUsersById = {};

  Timer? _debounce;
  List<UserWithAvatarModel> _searchResults = const [];
  bool _isSearching = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchUsers(query);
    });
  }

  Future<void> _searchUsers(String query) async {
    final userService = context.read<UserService>();
    final authProvider = context.read<AuthProvider>();

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = const [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final users = await userService.searchUsers(query: trimmed);
      final currentUsername = authProvider.username;
      final filtered = users.where((user) {
        final id = user.id;
        final username = user.username;
        if (id == null || username == null || username.isEmpty) {
          return false;
        }
        return username != currentUsername;
      }).toList();

      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = filtered;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _searchResults = const [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search user failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _createGroup() async {
    final roomsProvider = context.read<ChatRoomsProvider>();
    final authProvider = context.read<AuthProvider>();
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    if (_selectedUsersById.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 2 members')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final dto = await context.read<GroupChatService>().createGroup(
            name: groupName,
            memberIds: _selectedUsersById.keys.toList(),
          );

      final room = dto.toChatRoomModel();
      if (!mounted) {
        return;
      }

      roomsProvider.upsertRoom(room);
      final currentUsername = authProvider.username;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            roomId: room.id,
            roomName: room.displayNameFor(currentUsername),
            peerUsername: null,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create group failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _toggleUser(UserWithAvatarModel user) {
    final id = user.id;
    if (id == null) {
      return;
    }

    setState(() {
      if (_selectedUsersById.containsKey(id)) {
        _selectedUsersById.remove(id);
      } else {
        _selectedUsersById[id] = user;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final selectedUsers = _selectedUsersById.values.toList()
      ..sort((a, b) => a.displayLabel.compareTo(b.displayLabel));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: TextField(
              controller: _groupNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Group name',
                hintText: 'Enter group name',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search username to add',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              children: [
                Text(
                  'Selected: ${_selectedUsersById.length}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 10),
                Text(
                  'Minimum 2 members',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                ),
              ],
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (selectedUsers.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: selectedUsers
                    .map(
                      (user) => InputChip(
                        label: Text(user.displayLabel),
                        onDeleted: () {
                          _toggleUser(user);
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 6),
          Expanded(
            child: !hasQuery
                ? const Center(
                    child: Text('Search users to add members'),
                  )
                : _searchResults.isEmpty && !_isSearching
                    ? const Center(
                        child: Text('No users found'),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          final id = user.id;
                          final selected =
                              id != null && _selectedUsersById.containsKey(id);

                          return ListTile(
                            leading: AppAvatar(
                              url: user.avatar?.source,
                              name: user.displayLabel,
                            ),
                            title: Text(user.displayLabel),
                            subtitle: user.displayName != null &&
                                    user.displayName!.trim().isNotEmpty &&
                                    user.username != null &&
                                    user.username!.trim().isNotEmpty
                                ? Text('@${user.username!}')
                                : null,
                            trailing: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline_rounded,
                              color: selected ? const Color(0xFF168AFF) : null,
                            ),
                            onTap: id == null ? null : () => _toggleUser(user),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: FilledButton(
                onPressed: _isSubmitting ? null : _createGroup,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create group chat'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
