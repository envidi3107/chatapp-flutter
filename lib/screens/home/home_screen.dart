import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_rooms_provider.dart';
import '../../providers/invitation_provider.dart';
import '../../providers/user_search_provider.dart';
import '../../providers/video_call_provider.dart';
import '../../services/chat_room_service.dart';
import '../../services/realtime_service.dart';
import '../chat/video_call_screen.dart';
import 'add_friend_screen.dart';
import 'chat_list_screen.dart';
import 'chatbot_screen.dart';
import 'create_group_screen.dart';
import 'invitations_screen.dart';
import 'people_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  StreamSubscription? _invitationNotificationSub;
  StreamSubscription? _profileSub;
  StreamSubscription? _videoCallSub;
  InvitationProvider? _invitationProvider;

  static const _tabs = [
    ChatListScreen(),
    InvitationsScreen(),
    PeopleScreen(),
  ];

  int _stackIndexForTab(int tabIndex) {
    switch (tabIndex) {
      case 2:
        return 1;
      case 3:
        return 2;
      case 0:
      default:
        return 0;
    }
  }

  String _titleForTab(int tabIndex) {
    switch (tabIndex) {
      case 2:
        return 'Thông báo';
      case 3:
        return 'Bạn bè';
      case 0:
      default:
        return 'Trò chuyện';
    }
  }

  void _showIncomingCallDialog(VideoCallEvent event) {
    // Play ringtone on Web using JS interop
    _playRingtone();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C2E),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Cuộc gọi đến',
                    style: TextStyle(color: Colors.white60, fontSize: 14, letterSpacing: 1),
                  ),
                  const SizedBox(height: 20),
                  if (event.senderAvatar.isNotEmpty)
                    CircleAvatar(
                      radius: 44,
                      backgroundImage: NetworkImage(event.senderAvatar),
                    )
                  else
                    const CircleAvatar(
                      radius: 44,
                      backgroundColor: Color(0xFF3A3A5C),
                      child: Icon(Icons.person, size: 44, color: Colors.white70),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    event.senderDisplayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Đang gọi video cho bạn...',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 36),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Decline button
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                            _stopRingtone();
                            Navigator.pop(dialogContext);
                            // Notify caller that we rejected
                            try {
                              await context.read<ChatRoomService>().rejectVideoCall(
                                roomId: event.roomId,
                              );
                            } catch (_) {}
                          },
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Từ chối', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      // Accept button
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              _stopRingtone();
                              Navigator.pop(dialogContext);

                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => const Center(child: CircularProgressIndicator()),
                              );

                              try {
                                final provider = context.read<VideoCallProvider>();
                                await provider.initializeCall(
                                  event.channelName,
                                  token: event.agoraToken,
                                  uid: 0,
                                );

                                if (!mounted) return;
                                Navigator.pop(context);

                                if (provider.isInitialized) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => VideoCallScreen(
                                        roomId: event.roomId,
                                        roomName: event.senderDisplayName,
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Không thể tham gia cuộc gọi: $e')),
                                );
                              }
                            },
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.videocam, color: Colors.white, size: 28),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Trả lời', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) => _stopRingtone());
  }

  void _playRingtone() {
    try {
      js.context.callMethod('playRingtone', ['assets/lib/assets/facebook_call.mp3']);
    } catch (_) {}
  }

  void _stopRingtone() {
    try {
      js.context.callMethod('stopRingtone', []);
    } catch (_) {}
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invitationProvider = context.read<InvitationProvider>();
      _invitationProvider = invitationProvider;
      invitationProvider.setInvitesViewActive(_tabIndex == 2);
      invitationProvider.startRealtime();
      invitationProvider.loadInvitations();

      _invitationNotificationSub =
          context.read<RealtimeService>().invitationStream.listen((invitation) {
        if (!mounted || !invitation.isPending) return;
        final sender = invitation.sender?.username ?? 'Ai đó';
        final text = invitation.isFriendInvitation
            ? '$sender đã gửi cho bạn lời mời kết bạn'
            : '$sender đã mời bạn vào nhóm';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(text),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Xem',
                onPressed: () {
                  if (!mounted) return;
                  setState(() => _tabIndex = 2);
                },
              ),
            ),
          );
      });

      _profileSub =
          context.read<RealtimeService>().profileStream.listen((profile) {
        if (!mounted) return;
        context.read<AuthProvider>().applyProfileRealtime(profile);
        context.read<ChatRoomsProvider>().applyUserProfileUpdate(profile);
        context.read<UserSearchProvider>().applyUserProfileUpdate(profile);
        context.read<InvitationProvider>().applyUserProfileUpdate(profile);
      });

      _videoCallSub =
          context.read<RealtimeService>().videoCallStream.listen((event) {
        if (!mounted) return;
        _showIncomingCallDialog(event);
      });
    });
  }

  @override
  void dispose() {
    _invitationProvider?.setInvitesViewActive(false);
    _invitationNotificationSub?.cancel();
    _profileSub?.cancel();
    _videoCallSub?.cancel();
    _invitationProvider?.stopRealtime();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == 4) {
      // Settings tab
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
      return;
    }
    if (index == 1) {
      // AI Chat tab
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChatbotScreen()),
      );
      return;
    }
    _invitationProvider?.setInvitesViewActive(index == 2);
    setState(() => _tabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final invitationProvider = context.watch<InvitationProvider>();
    final pendingInvites = invitationProvider.pendingCount;

    final title = _titleForTab(_tabIndex);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: _buildAppBar(title, auth, pendingInvites),
      body: IndexedStack(
        index: _stackIndexForTab(_tabIndex),
        children: _tabs,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ChatbotScreen()),
          );
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        child: Image.asset('lib/assets/chat_bot_icon.png', width: 64, height: 64),
      ),
      bottomNavigationBar: _buildBottomNav(pendingInvites),
    );
  }

  PreferredSizeWidget _buildAppBar(
      String title, AuthProvider auth, int pendingInvites) {
    return AppBar(
      backgroundColor: AppColors.bgDark,
      elevation: 0,
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      actions: [
        if (_tabIndex == 0) ...[
          // Menu button
          Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: PopupMenuButton<int>(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.add, color: AppColors.textPrimary, size: 20),
              ),
              offset: const Offset(0, 48),
              color: AppColors.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                if (value == 0) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddFriendScreen()),
                  );
                } else if (value == 1) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 0,
                  child: Row(
                    children: [
                      Image.asset('lib/assets/add_friend_icon.png', width: 24, height: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Thêm bạn',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 1,
                  child: Row(
                    children: [
                      Image.asset('lib/assets/add_group_icon.png', width: 24, height: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Tạo nhóm',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_tabIndex != 0) const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBottomNav(int pendingInvites) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Trò chuyện',
                index: 0,
                currentIndex: _tabIndex,
                onTap: _onTabSelected,
              ),
              _NavItem(
                icon: Icons.smart_toy_outlined,
                activeIcon: Icons.smart_toy_rounded,
                label: 'Trợ lý AI',
                index: 1,
                currentIndex: _tabIndex,
                onTap: _onTabSelected,
              ),
              _NavItem(
                icon: Icons.notifications_outlined,
                activeIcon: Icons.notifications_rounded,
                label: 'Thông báo',
                index: 2,
                currentIndex: _tabIndex,
                onTap: _onTabSelected,
                badge: pendingInvites > 0
                    ? (pendingInvites > 99 ? '99+' : '$pendingInvites')
                    : null,
              ),
              _NavItem(
                icon: Icons.people_outline_rounded,
                activeIcon: Icons.people_rounded,
                label: 'Bạn bè',
                index: 3,
                currentIndex: _tabIndex,
                onTap: _onTabSelected,
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label: 'Cài đặt',
                index: 4,
                currentIndex: _tabIndex,
                onTap: _onTabSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Sub-widgets ───────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;
  final String? badge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.badge,
  });

  bool get _isSelected => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _isSelected ? activeIcon : icon,
                    key: ValueKey(_isSelected),
                    color: _isSelected
                        ? AppColors.navSelected
                        : AppColors.navUnselected,
                    size: 24,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    top: -5,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.unread,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: _isSelected
                    ? AppColors.navSelected
                    : AppColors.navUnselected,
                fontSize: 10,
                fontWeight:
                    _isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
