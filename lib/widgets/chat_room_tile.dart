import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final dateText = latest?.sentOn != null
        ? DateFormat('HH:mm').format(latest!.sentOn!)
        : '';

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            AppAvatar(
              url: room.avatar?.source,
              name: displayName,
              radius: 28,
              showOnlineDot: isPeerOnline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    latestPreview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unreadCount > 0
                          ? Colors.black87
                          : Colors.grey.shade700,
                      fontWeight:
                          unreadCount > 0 ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isPinned)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 3),
                    child: Icon(
                      Icons.push_pin_rounded,
                      size: 16,
                      color: Color(0xFF168AFF),
                    ),
                  ),
                if (dateText.isNotEmpty)
                  Text(
                    dateText,
                    style: TextStyle(
                      color: unreadCount > 0
                          ? const Color(0xFF168AFF)
                          : Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight:
                          unreadCount > 0 ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF168AFF),
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
