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

    if (provider.isLoading && provider.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: provider.loadInvitations,
      child: provider.items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No invitations')),
              ],
            )
          : ListView.builder(
              itemCount: provider.items.length,
              itemBuilder: (context, index) {
                final item = provider.items[index];
                final senderName = item.sender?.displayLabel ?? 'Unknown';

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                'Room #${item.chatRoomId ?? '-'}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.statusLabel,
                                style: TextStyle(color: Colors.grey.shade700),
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
                            icon: const Icon(Icons.close, color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
