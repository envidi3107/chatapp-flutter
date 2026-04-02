import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/chat_room_model.dart';
import 'app_avatar.dart';

class ChatRoomTile extends StatelessWidget {
  const ChatRoomTile({
    super.key,
    required this.room,
    required this.currentUsername,
    required this.unreadCount,
    required this.isPeerOnline,
    required this.isPinned,
    required this.onTap,
    this.onLongPress,
  });

  final ChatRoomModel room;
  final String? currentUsername;
  final int unreadCount;
  final bool isPeerOnline;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final latest = room.latestMessage;
    final displayName = room.displayNameFor(currentUsername);
    final latestPreview = room.latestPreviewFor(currentUsername);
    final hasUnread = unreadCount > 0;

    // Smart date/time formatting
    final dateText = _formatDate(latest?.sentOn);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.bgInput.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Avatar with online dot
              AppAvatar(
                url: room.avatar?.source,
                name: displayName,
                radius: 28,
                showOnlineDot: isPeerOnline,
              ),
              const SizedBox(width: 12),

              // Name + preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight:
                            hasUnread ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      latestPreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight:
                            hasUnread ? FontWeight.w500 : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Time + badge column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date text
                  if (dateText.isNotEmpty)
                    Text(
                      dateText,
                      style: TextStyle(
                        color: hasUnread
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            hasUnread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),

                  const SizedBox(height: 5),

                  // Unread badge OR pin icon
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.unread,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else if (isPinned)
                    const Icon(
                      Icons.push_pin_rounded,
                      size: 16,
                      color: AppColors.textHint,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) return DateFormat('HH:mm').format(dt);
    if (diff == 1) return 'Hôm qua';
    if (diff < 7) {
      const days = ['CN', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];
      return days[dt.weekday % 7];
    }
    return DateFormat('dd/MM').format(dt);
  }
}
