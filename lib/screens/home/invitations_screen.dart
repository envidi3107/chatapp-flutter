import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/chat_rooms_provider.dart';
import '../../providers/invitation_provider.dart';
import '../../widgets/app_avatar.dart';

class InvitationsScreen extends StatefulWidget {
  const InvitationsScreen({super.key});

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  InvitationProvider? _provider;

  Future<void> _replyAndRefresh({
    required int invitationId,
    required bool accept,
  }) async {
    final invitationProvider = context.read<InvitationProvider>();
    final chatRoomsProvider = context.read<ChatRoomsProvider>();

    await invitationProvider.reply(
      invitationId: invitationId,
      accept: accept,
    );

    // Some backend flows do not push room-creation event to the acceptor,
    // so refresh chat rooms explicitly to update chat list and friends list.
    await chatRoomsProvider.loadRooms();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<InvitationProvider>();
      _provider = provider;
      provider.startRealtime();
      provider.loadInvitations();
    });
  }

  @override
  void dispose() {
    _provider?.stopRealtime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvitationProvider>();
    final groupAddedNotifications = provider.groupAddedNotifications;
    final hasInvites = provider.items.isNotEmpty;
    final hasGroupNotices = groupAddedNotifications.isNotEmpty;

    if (provider.isLoading && !hasInvites && !hasGroupNotices) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: provider.loadInvitations,
      child: (!hasInvites && !hasGroupNotices)
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Không có lời mời hoặc thông báo nào')),
              ],
            )
          : ListView(
              children: [
                if (hasGroupNotices) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      'Thông báo nhóm',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  ...groupAddedNotifications.map(
                    (notification) => Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      color:
                          notification.isRead ? null : const Color(0xFFEAF4FF),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.group_add_rounded),
                        ),
                        title: Text(
                          notification.roomName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${notification.addedBy} đã thêm bạn vào nhóm này.',
                        ),
                        trailing: IconButton(
                          tooltip: 'Bỏ qua',
                          onPressed: () {
                            provider.removeGroupAddedNotification(notification);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ),
                  ),
                ],
                if (hasInvites) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      'Lời mời',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  ...provider.items.map((item) {
                    final senderName = item.sender?.displayLabel ?? 'Không rõ';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            AppAvatar(
                              url: item.sender?.avatar?.source,
                              name: senderName,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    senderName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Phòng #${item.chatRoomId ?? '-'}',
                                    style:
                                        TextStyle(color: Colors.grey.shade700),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.statusLabel,
                                    style:
                                        TextStyle(color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                            ),
                            if (item.isPending) ...[
                              IconButton.filledTonal(
                                onPressed: () async {
                                  await _replyAndRefresh(
                                    invitationId: item.id,
                                    accept: true,
                                  );
                                },
                                icon: const Icon(Icons.check),
                              ),
                              const SizedBox(width: 4),
                              IconButton.filledTonal(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red.shade50,
                                ),
                                onPressed: () async {
                                  await _replyAndRefresh(
                                    invitationId: item.id,
                                    accept: false,
                                  );
                                },
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
    );
  }
}
