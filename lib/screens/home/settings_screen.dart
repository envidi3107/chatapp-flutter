import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/language_option.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_avatar.dart';
import '../auth/login_screen.dart';
import 'profile_screen.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoTranslate = false;
  bool _smartSummary = false;
  bool _readReceipts = true;

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Đăng xuất', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất không?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  Future<void> _pickLanguage() async {
    final auth = context.read<AuthProvider>();
    final current = LanguageOption.findByCode(auth.profile?.language);

    final result = await showModalBottomSheet<LanguageOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _LanguagePickerSheet(current: current),
    );

    if (result != null && mounted) {
      await auth.updateMyProfile(
        displayName: auth.displayName,
        language: result.code,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = LanguageOption.findByCode(auth.profile?.language);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        title: const Text(
          'Cài đặt & Tuỳ chỉnh',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── User Header ──
          _buildUserHeader(auth),
          const SizedBox(height: 20),

          // ── CÀI ĐẶT AI ──
          _buildSectionLabel('CÀI ĐẶT AI'),
          _buildCard([
            _buildToggleTile(
              icon: Icons.translate_rounded,
              iconColor: const Color(0xFF168AFF),
              title: 'Tự động dịch',
              subtitle: 'Dịch tin nhắn tức thì',
              value: _autoTranslate,
              onChanged: (v) => setState(() => _autoTranslate = v),
            ),
            _buildDivider(),
            _buildToggleTile(
              icon: Icons.summarize_rounded,
              iconColor: const Color(0xFF7C5CFC),
              title: 'Tóm tắt thông minh',
              subtitle: 'Tóm tắt các cuộc hội thoại dài',
              value: _smartSummary,
              onChanged: (v) => setState(() => _smartSummary = v),
            ),
          ]),
          const SizedBox(height: 20),

          // ── TÀI KHOẢN ──
          _buildSectionLabel('TÀI KHOẢN'),
          _buildCard([
            _buildNavTile(
              icon: Icons.person_outline_rounded,
              title: 'Thông tin cá nhân',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
            _buildDivider(),
            _buildNavTile(
              icon: Icons.language_rounded,
              title: 'Ngôn ngữ',
              trailing: lang != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(lang.flagEmoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Text(lang.name,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary, size: 18),
                      ],
                    )
                  : null,
              onTap: _pickLanguage,
            ),
            _buildDivider(),
            _buildNavTile(
              icon: Icons.card_membership_outlined,
              title: 'Gói đăng ký',
              trailingLabel: 'MIỄN PHÍ',
              trailingColor: const Color(0xFF0A8F47),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tính năng đang phát triển')),
                );
              },
            ),
            _buildDivider(),
            _buildNavTile(
              icon: Icons.shield_outlined,
              title: 'Mật khẩu & Bảo mật',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── QUYỀN RIÊNG TƯ ──
          _buildSectionLabel('QUYỀN RIÊNG TƯ'),
          _buildCard([
            _buildNavTile(
              icon: Icons.block_outlined,
              title: 'Người dùng đã chặn',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tính năng đang phát triển')),
                );
              },
            ),
            _buildDivider(),
            _buildToggleTile(
              icon: Icons.visibility_outlined,
              iconColor: AppColors.primary,
              title: 'Xác nhận đã đọc',
              value: _readReceipts,
              onChanged: (v) => setState(() => _readReceipts = v),
            ),
          ]),
          const SizedBox(height: 20),

          // ── THÔNG BÁO ──
          _buildSectionLabel('THÔNG BÁO'),
          _buildCard([
            _buildNavTile(
              icon: Icons.notifications_outlined,
              title: 'Thông báo đẩy',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tính năng đang phát triển')),
                );
              },
            ),
            _buildDivider(),
            _buildNavTile(
              icon: Icons.volume_up_outlined,
              title: 'Âm thanh & Rung',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tính năng đang phát triển')),
                );
              },
            ),
            _buildDivider(),
            _buildToggleTile(
              icon: Icons.do_not_disturb_on_outlined,
              iconColor: AppColors.textSecondary,
              title: 'Không làm phiền',
              value: false,
              onChanged: (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tính năng đang phát triển')),
                );
              },
            ),
          ]),
          const SizedBox(height: 16),

          // Version
          const Center(
            child: Text(
              'Phiên bản v1.0.0',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: _confirmLogout,
              child: const Text(
                'Đăng xuất',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildUserHeader(AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          AppAvatar(
            url: auth.avatarUrl,
            name: auth.displayName,
            radius: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.displayName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${auth.username ?? ''}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 54, color: AppColors.border);
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingLabel,
    Color? trailingColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 18),
      ),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))
          : null,
      trailing: trailing ??
          (trailingLabel != null
              ? Text(trailingLabel,
                  style: TextStyle(
                    color: trailingColor ?? AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ))
              : const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary)),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.textSecondary).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 18),
      ),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))
          : null,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    );
  }
}

// ─────────────────────── Language Picker Sheet ───────────────────────

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({this.current});
  final LanguageOption? current;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  final _searchController = TextEditingController();
  List<LanguageOption> _filtered = LanguageOption.popular;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? LanguageOption.popular
          : LanguageOption.popular
              .where((l) =>
                  l.name.toLowerCase().contains(q) ||
                  l.nativeName.toLowerCase().contains(q) ||
                  l.code.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Chọn ngôn ngữ',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm ngôn ngữ...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text('Không tìm thấy ngôn ngữ',
                          style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final lang = _filtered[index];
                        final isSelected = widget.current?.code == lang.code;
                        return ListTile(
                          onTap: () => Navigator.of(context).pop(lang),
                          leading: Text(lang.flagEmoji,
                              style: const TextStyle(fontSize: 28)),
                          title: Text(lang.name,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text(lang.nativeName,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13)),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
