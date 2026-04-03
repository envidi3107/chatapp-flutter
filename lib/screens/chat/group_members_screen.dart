import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';

import '../../models/user_with_avatar_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_rooms_provider.dart';
import '../../services/group_chat_service.dart';
import '../../services/realtime_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_avatar.dart';

enum _GroupMemberNoticeType {
  added,
  removed,
  left,
}

class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({
    super.key,
    required this.roomId,
  });

  final int roomId;

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Map<int, UserWithAvatarModel> _selectedUsersById = {};
  final ImagePicker _picker = ImagePicker();

  Timer? _searchDebounce;
  StreamSubscription<GroupUpdatedEvent>? _groupUpdatedSub;
  StreamSubscription<GroupMembersAddedEvent>? _membersAddedSub;
  StreamSubscription<GroupMemberRemovedEvent>? _memberRemovedSub;
  GroupChatDto? _group;
  XFile? _selectedAvatarFile;
  Uint8List? _selectedAvatarBytes;
  List<UserWithAvatarModel> _searchResults = const [];
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isSubmitting = false;
  String? _error;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _subscribeGroupUpdated();
    _subscribeGroupMembersAdded();
    _subscribeGroupMemberRemoved();
    unawaited(_loadGroup());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _groupUpdatedSub?.cancel();
    _membersAddedSub?.cancel();
    _memberRemovedSub?.cancel();
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _subscribeGroupMembersAdded() {
    _membersAddedSub =
        context.read<RealtimeService>().groupMembersAddedStream.listen((event) {
      if (!mounted ||
          event.roomId != widget.roomId ||
          event.newMembers.isEmpty) {
        return;
      }

      final membersText = event.newMembers.join(', ');
      final addedBy = (event.addedBy ?? '').trim();
      final text = addedBy.isEmpty
          ? '$membersText joined the group.'
          : '$addedBy added $membersText.';

      unawaited(_loadGroup(showLoading: false));
      unawaited(context.read<ChatRoomsProvider>().loadRooms());

      _showGroupMemberNotice(
        text: text,
        type: _GroupMemberNoticeType.added,
      );
    });
  }

  void _subscribeGroupUpdated() {
    _groupUpdatedSub =
        context.read<RealtimeService>().groupUpdatedStream.listen((event) {
      if (!mounted || event.roomId != widget.roomId) {
        return;
      }

      if (_selectedAvatarFile != null || _selectedAvatarBytes != null) {
        setState(() {
          _selectedAvatarFile = null;
          _selectedAvatarBytes = null;
        });
      }

      unawaited(_loadGroup(showLoading: false));
    });
  }

  void _subscribeGroupMemberRemoved() {
    _memberRemovedSub = context
        .read<RealtimeService>()
        .groupMemberRemovedStream
        .listen((event) {
      if (!mounted || event.roomId != widget.roomId) {
        return;
      }

      final isLeft = event.action == 'left';
      final username = (event.removedUsername ?? '').trim();
      final actionBy = (event.actionBy ?? '').trim();
      final fallback = isLeft
          ? 'A member left the group.'
          : 'A member was removed from the group.';
      final text = username.isEmpty
          ? fallback
          : isLeft
              ? '$username left the group.'
              : actionBy.isEmpty || actionBy == username
                  ? '$username was removed from the group.'
                  : '$actionBy removed $username from the group.';

      unawaited(_loadGroup(showLoading: false));
      unawaited(context.read<ChatRoomsProvider>().loadRooms());

      _showGroupMemberNotice(
        text: text,
        type: isLeft
            ? _GroupMemberNoticeType.left
            : _GroupMemberNoticeType.removed,
      );
    });
  }

  void _showGroupMemberNotice({
    required String text,
    required _GroupMemberNoticeType type,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final (icon, backgroundColor) = switch (type) {
      _GroupMemberNoticeType.added => (
          Icons.person_add_alt_1_rounded,
          const Color(0xFF0B6BCB)
        ),
      _GroupMemberNoticeType.removed => (
          Icons.person_remove_alt_1_rounded,
          const Color(0xFFB54708)
        ),
      _GroupMemberNoticeType.left => (
          Icons.logout_rounded,
          const Color(0xFF0D7A43)
        ),
    };

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyError(Object error, {required String fallback}) {
    final text = error.toString().trim();
    final apiMatch = RegExp('"title":"([^"]+)"').firstMatch(text);
    if (apiMatch != null && (apiMatch.group(1) ?? '').isNotEmpty) {
      return apiMatch.group(1)!;
    }

    final clean = text.replaceFirst('Exception: ', '');
    if (clean.isEmpty) {
      return fallback;
    }

    return clean;
  }

  Future<void> _loadGroup({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final dto =
          await context.read<GroupChatService>().getGroupDetails(widget.roomId);
      if (!mounted) {
        return;
      }

      setState(() {
        _group = dto;
        _groupNameController.text = dto.name;
        _error = null;
      });

      final pendingQuery = _searchController.text.trim();
      if (pendingQuery.isNotEmpty) {
        unawaited(_searchUsers(pendingQuery));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _friendlyError(
          error,
          fallback: 'Cannot load group members.',
        );
      });
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_searchUsers(query));
    });
  }

  Future<void> _searchUsers(String query) async {
    final trimmed = query.trim();
    final group = _group;
    if (group == null) {
      return;
    }

    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = const [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final users =
          await context.read<UserService>().searchUsers(query: trimmed);
      if (!mounted || _searchController.text.trim() != trimmed) {
        return;
      }

      final memberIds =
          group.members.map((member) => member.id).whereType<int>().toSet();
      final myUsername = context.read<AuthProvider>().username;

      final filtered = users.where((user) {
        final userId = user.id;
        final username = (user.username ?? '').trim();
        if (userId == null || username.isEmpty) {
          return false;
        }
        if (memberIds.contains(userId)) {
          return false;
        }
        if (myUsername != null && username == myUsername) {
          return false;
        }
        return true;
      }).toList();

      setState(() {
        _searchResults = filtered;
        _searchError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _searchResults = const [];
        _searchError = _friendlyError(
          error,
          fallback: 'Search users failed.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _toggleUser(UserWithAvatarModel user) {
    final userId = user.id;
    if (userId == null) {
      return;
    }

    setState(() {
      if (_selectedUsersById.containsKey(userId)) {
        _selectedUsersById.remove(userId);
      } else {
        _selectedUsersById[userId] = user;
      }
    });
  }

  Future<void> _pickGroupAvatar() async {
    if (_isSubmitting) {
      return;
    }

    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) {
      return;
    }

    final bytes = await picked.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedAvatarFile = picked;
      _selectedAvatarBytes = bytes;
    });
  }

  Future<void> _updateGroupProfile() async {
    final group = _group;
    if (group == null || !group.isAdmin) {
      return;
    }

    final nextName = _groupNameController.text.trim();
    if (nextName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên nhóm không được để trống.')),
      );
      return;
    }

    final hasNameChanged = nextName != group.name.trim();
    final hasAvatarChanged = _selectedAvatarFile != null;

    if (!hasNameChanged && !hasAvatarChanged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có thay đổi nào để lưu.')),
      );
      return;
    }

    final roomsProvider = context.read<ChatRoomsProvider>();
    setState(() {
      _isSubmitting = true;
    });

    try {
      final updated = await context.read<GroupChatService>().updateGroupProfile(
            roomId: widget.roomId,
            name: hasNameChanged ? nextName : null,
            avatar: _selectedAvatarFile,
          );
      if (!mounted) {
        return;
      }

      setState(() {
        _group = updated;
        _groupNameController.text = updated.name;
        _selectedAvatarFile = null;
        _selectedAvatarBytes = null;
      });

      roomsProvider.upsertRoom(updated.toChatRoomModel());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group information updated.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyError(
              error,
              fallback: 'Cập nhật thông tin thất bại.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _addSelectedMembers() async {
    final group = _group;
    if (group == null || _selectedUsersById.isEmpty) {
      return;
    }
    final roomsProvider = context.read<ChatRoomsProvider>();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final dto = await context.read<GroupChatService>().addMembers(
            roomId: widget.roomId,
            memberIds: _selectedUsersById.keys.toList(),
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _group = dto;
        _selectedUsersById.clear();
        _searchResults = const [];
        _searchError = null;
        _searchController.clear();
      });

      roomsProvider.upsertRoom(dto.toChatRoomModel());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm thành viên thành công.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyError(
              error,
              fallback: 'Add members failed.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _removeMember(UserWithAvatarModel member) async {
    final userId = member.id;
    if (userId == null) {
      return;
    }
    final roomsProvider = context.read<ChatRoomsProvider>();

    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('Xoá thành viên',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Text('Bạn có chắc xoá ${member.displayLabel} khỏi nhóm?',
              style: const TextStyle(color: AppColors.textPrimary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xoá'),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true || !mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await context.read<GroupChatService>().removeMember(
            roomId: widget.roomId,
            userId: userId,
          );

      if (!mounted) {
        return;
      }

      await _loadGroup(showLoading: false);
      await roomsProvider.loadRooms();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member removed successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyError(
              error,
              fallback: 'Remove member failed.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _leaveGroup() async {
    final roomsProvider = context.read<ChatRoomsProvider>();
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('Rời nhóm',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text('Bạn có chắc chắn muốn rời nhóm?',
              style: TextStyle(color: AppColors.textPrimary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Rời nhóm'),
            ),
          ],
        );
      },
    );

    if (shouldLeave != true || !mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await context.read<GroupChatService>().leaveGroup(widget.roomId);
      if (!mounted) {
        return;
      }

      await roomsProvider.loadRooms();
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyError(
              error,
              fallback: 'Leave group failed.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _dissolveGroup() async {
    final roomsProvider = context.read<ChatRoomsProvider>();
    final shouldDissolve = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('Giải tán nhóm',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            'Hành động này sẽ xoá nhóm vĩnh viễn và toàn bộ tin nhắn. Tiếp tục?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Giải tán'),
            ),
          ],
        );
      },
    );

    if (shouldDissolve != true || !mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await context.read<GroupChatService>().dissolveGroup(widget.roomId);
      if (!mounted) {
        return;
      }

      await roomsProvider.loadRooms();
      if (!mounted) {
        return;
      }

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyError(
              error,
              fallback: 'Dissolve group failed.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final myUserId = context.watch<AuthProvider>().profile?.id;

    if (_isLoading && group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thành viên nhóm')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thành viên nhóm')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Không thể tải thành viên.',
                    style: const TextStyle(color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _isLoading ? null : () => _loadGroup(),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final members = [...group.members]..sort((a, b) {
        final aIsMe = myUserId != null && a.id == myUserId;
        final bIsMe = myUserId != null && b.id == myUserId;
        if (aIsMe && !bIsMe) {
          return -1;
        }
        if (!aIsMe && bIsMe) {
          return 1;
        }
        return a.displayLabel.compareTo(b.displayLabel);
      });
    final selectedUsers = _selectedUsersById.values.toList()
      ..sort((a, b) => a.displayLabel.compareTo(b.displayLabel));
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text('Thành viên (${group.members.length})',
            style: const TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : () => _loadGroup(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        children: [
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thông tin nhóm',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Stack(
                      children: [
                        _selectedAvatarBytes != null
                            ? CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFFDCEBFF),
                                backgroundImage:
                                    MemoryImage(_selectedAvatarBytes!),
                              )
                            : AppAvatar(
                                url: group.avatar?.source,
                                name: group.name,
                                radius: 28,
                              ),
                        if (group.isAdmin)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: InkWell(
                              onTap: _isSubmitting ? null : _pickGroupAvatar,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF168AFF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _groupNameController,
                        enabled: group.isAdmin && !_isSubmitting,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Group name',
                          hintText: 'Enter group name',
                        ),
                      ),
                    ),
                  ],
                ),
                if (group.isAdmin) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _pickGroupAvatar,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Choose avatar'),
                      ),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _updateGroupProfile,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save changes'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: group.isOwner
                  ? const Color(0xFFEAF7EF)
                  : const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: group.isOwner
                    ? const Color(0xFFA9D8B8)
                    : const Color(0xFFFFD08A),
              ),
            ),
            child: Text(
              group.isOwner
                  ? 'You are the group owner. You can edit group info, remove members, and dissolve this group.'
                  : group.isAdmin
                      ? 'You are a group admin. You can edit group information.'
                      : 'Only group owner can remove members.',
              style: TextStyle(
                color: group.isOwner
                    ? const Color(0xFF0D7A43)
                    : group.isAdmin
                        ? const Color(0xFF0B6BCB)
                        : const Color(0xFF7A4A00),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...members.map(
            (member) {
              final memberId = member.id;
              final isMe = myUserId != null && memberId == myUserId;
              final canRemove = group.isOwner && !isMe && memberId != null;
              final username = (member.username ?? '').trim();
              final hasSecondaryName =
                  (member.displayName ?? '').trim().isNotEmpty &&
                      username.isNotEmpty;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: AppAvatar(
                  url: member.avatar?.source,
                  name: member.displayLabel,
                  radius: 22,
                ),
                title: Text(member.displayLabel),
                subtitle: hasSecondaryName ? Text('@$username') : null,
                trailing: isMe
                    ? Text(
                        group.isOwner ? 'You (Owner)' : 'You',
                        style: const TextStyle(
                          color: Color(0xFF168AFF),
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : canRemove
                        ? IconButton(
                            icon: const Icon(Icons.person_remove_outlined),
                            tooltip: 'Remove',
                            onPressed: _isSubmitting
                                ? null
                                : () => _removeMember(member),
                          )
                        : null,
              );
            },
          ),
          const Divider(height: 22),
          Text(
            'Add members',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search username to add',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _searchError!,
                style: const TextStyle(color: Color(0xFFB3261E)),
              ),
            ),
          if (selectedUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: selectedUsers
                    .map(
                      (user) => InputChip(
                        label: Text(user.displayLabel),
                        onDeleted: () => _toggleUser(user),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (hasQuery && !_isSearching && _searchResults.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('No users found'),
            ),
          ..._searchResults.map(
            (user) {
              final id = user.id;
              final isSelected =
                  id != null && _selectedUsersById.containsKey(id);
              final username = (user.username ?? '').trim();
              final hasSecondaryName =
                  (user.displayName ?? '').trim().isNotEmpty &&
                      username.isNotEmpty;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: AppAvatar(
                  url: user.avatar?.source,
                  name: user.displayLabel,
                  radius: 22,
                ),
                title: Text(user.displayLabel),
                subtitle: hasSecondaryName ? Text('@$username') : null,
                trailing: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.add_circle_outline_rounded,
                  color: isSelected ? const Color(0xFF168AFF) : null,
                ),
                onTap: id == null || _isSubmitting
                    ? null
                    : () => _toggleUser(user),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.icon(
              onPressed: _isSubmitting || _selectedUsersById.isEmpty
                  ? null
                  : _addSelectedMembers,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text('Add selected (${_selectedUsersById.length})'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: group.isOwner
              ? FilledButton.icon(
                  onPressed: _isSubmitting ? null : _dissolveGroup,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB42318),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Dissolve group'),
                )
              : OutlinedButton(
                  onPressed: _isSubmitting ? null : _leaveGroup,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  child: const Text('Leave group'),
                ),
        ),
      ),
    );
  }
}
