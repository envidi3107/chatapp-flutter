import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/user_with_avatar_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/app_avatar.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  Timer? _debounce;
  List<UserWithAvatarModel> _searchResults = const [];
  bool _isSearching = false;

  @override
  void dispose() {
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
        SnackBar(content: Text('Tìm kiếm thất bại: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _addFriend(UserWithAvatarModel user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã gửi lời mời kết bạn tới ${user.displayLabel}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        title: const Text('Thêm bạn', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm bằng Tên đăng nhập',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.person_search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.bgInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          Expanded(
            child: !hasQuery
                ? Center(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tính năng quét mã QR đang được phát triển')),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Quét mã QR', style: TextStyle(fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  )
                : _searchResults.isEmpty && !_isSearching
                    ? const Center(
                        child: Text('Không tìm thấy người dùng', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          
                          return ListTile(
                            leading: AppAvatar(
                              url: user.avatar?.source,
                              name: user.displayLabel,
                              radius: 20,
                            ),
                            title: Text(
                              user.displayLabel,
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                            ),
                            subtitle: user.displayName != null &&
                                    user.displayName!.trim().isNotEmpty &&
                                    user.username != null &&
                                    user.username!.trim().isNotEmpty
                                ? Text('@${user.username!}', style: const TextStyle(color: AppColors.textSecondary))
                                : null,
                            trailing: OutlinedButton(
                              onPressed: () => _addFriend(user),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                minimumSize: const Size(0, 36),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: const Text('Kết bạn'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
