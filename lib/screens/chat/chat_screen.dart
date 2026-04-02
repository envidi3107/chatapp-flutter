import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/chat_rooms_provider.dart';
import '../../models/message_receive_model.dart';
import '../../models/user_block_status_model.dart';
import '../../models/user_with_avatar_model.dart';
import '../../services/message_service.dart';
import '../../services/realtime_service.dart';
import '../../services/user_service.dart';
import 'group_members_screen.dart';
import '../../widgets/message_bubble.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.peerUsername,
  });

  final int roomId;
  final String roomName;
  final String? peerUsername;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(
        messageService: context.read<MessageService>(),
        realtimeService: context.read<RealtimeService>(),
        roomId: roomId,
        currentUsername: context.read<AuthProvider>().username,
      )
        ..loadMessages()
        ..startRealtime(),
      child: _ChatView(
        roomId: roomId,
        roomName: roomName,
        peerUsername: peerUsername,
      ),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({
    required this.roomId,
    required this.roomName,
    required this.peerUsername,
  });

  final int roomId;
  final String roomName;
  final String? peerUsername;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  List<XFile> _pickedFiles = [];
  ChatRoomsProvider? _chatRoomsProvider;
  ChatProvider? _chatProvider;
  StreamSubscription<PresenceUpdateEvent>? _presenceSub;
  StreamSubscription<UserWithAvatarModel>? _profileSub;
  StreamSubscription<UserBlockStatusModel>? _blockStatusSub;
  StreamSubscription<FriendRemovedEvent>? _roomRemovedSub;
  StreamSubscription<GroupMembersAddedEvent>? _groupMembersAddedSub;
  StreamSubscription<GroupMemberRemovedEvent>? _groupMemberRemovedSub;
  StreamSubscription<TypingStatusEvent>? _typingSub;
  StreamSubscription<ReadStatusEvent>? _readSub;
  Timer? _typingDebounce;
  Timer? _typingVisibleTimer;
  Timer? _typingDotsTicker;
  Timer? _readSyncDebounce;
  bool _isTypingSent = false;
  bool _isPeerTyping = false;
  String? _typingSender;
  int _typingDots = 1;
  String? _myUsername;
  final Map<String, DateTime> _readAtByUser = {};
  final Map<String, UserWithAvatarModel> _readerByUsername = {};
  bool _isPresenceLoading = false;
  bool _isBlockStatusLoading = false;
  bool _blockedByMe = false;
  bool _blockedByPeer = false;
  bool _isNavigatingBackToChatList = false;
  bool? _isPeerOnline;
  DateTime? _lastSeenAt;
  late String _roomDisplayName;
  int? _lastSyncedMessageId;
  bool _didInitialAutoScroll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _myUsername = context.read<AuthProvider>().username;
    _roomDisplayName = widget.roomName;
    _chatProvider = context.read<ChatProvider>();
    _chatProvider?.addListener(_onChatUpdated);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ChatRoomsProvider>();
      _chatRoomsProvider = provider;
      provider.markRoomOpened(widget.roomId);
      _scheduleReadSync();
    });

    _loadPresence();
    _loadBlockStatus();
    _subscribeRoomRemoved();
    _subscribePresence();
    _subscribeProfile();
    _subscribeBlockStatus();
    _subscribeTyping();
    _subscribeReadStatus();
    _subscribeGroupMembersAdded();
    _subscribeGroupMemberRemoved();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatProvider?.removeListener(_onChatUpdated);
    _chatRoomsProvider?.markRoomClosed(widget.roomId);
    _typingDebounce?.cancel();
    _typingVisibleTimer?.cancel();
    _typingDotsTicker?.cancel();
    _readSyncDebounce?.cancel();
    if (_isTypingSent) {
      unawaited(context.read<ChatProvider>().setTypingStatus(false));
    }
    _presenceSub?.cancel();
    _profileSub?.cancel();
    _blockStatusSub?.cancel();
    _roomRemovedSub?.cancel();
    _groupMembersAddedSub?.cancel();
    _groupMemberRemovedSub?.cancel();
    _typingSub?.cancel();
    _readSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleReadSync();
    }
  }

  void _onChatUpdated() {
    final provider = _chatProvider;
    if (provider == null) {
      return;
    }

    final messages = provider.messages;
    if (messages.isEmpty) {
      return;
    }

    if (!_didInitialAutoScroll) {
      _didInitialAutoScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animated: false);
      });
    }

    final latestId = messages.last.id;
    if (latestId == null || latestId == _lastSyncedMessageId) {
      return;
    }

    _lastSyncedMessageId = latestId;
    _scheduleReadSync();
  }

  void _scrollToBottom({required bool animated}) {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }

    _scrollController.jumpTo(target);
  }

  void _scheduleReadSync() {
    _readSyncDebounce?.cancel();
    _readSyncDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) {
        return;
      }

      unawaited(context.read<ChatProvider>().refreshReadStatus());
    });
  }

  void _subscribeReadStatus() {
    _readSub = context.read<RealtimeService>().roomReadStream(widget.roomId).listen((event) {
      final reader = event.reader;
      final username = reader?.username ?? '';
      if (!mounted || username.isEmpty || username == _myUsername) {
        return;
      }

      setState(() {
        final readAt = event.readAt?.toLocal();
        if (readAt != null) {
          _readAtByUser[username] = readAt;
        }
        if (reader != null) {
          _readerByUsername[username] = reader;
        }
      });
    });
  }

  void _subscribeRoomRemoved() {
    _roomRemovedSub = context.read<RealtimeService>().friendRemovedStream.listen((event) async {
      if (!mounted || _isNavigatingBackToChatList || event.roomId != widget.roomId) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final roomsProvider = context.read<ChatRoomsProvider>();
      final dissolvedBy = (event.dissolvedBy ?? '').trim();
      final isGroupDissolved = dissolvedBy.isNotEmpty;

      if (isGroupDissolved) {
        roomsProvider.queueGroupDissolvedNotice(
          roomId: widget.roomId,
          roomName: widget.roomName,
          dissolvedBy: dissolvedBy,
        );
      }

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            isGroupDissolved
                ? 'Nhóm đã bị giải tán. Đang quay về danh sách chat...'
                : 'This conversation is no longer available.',
          ),
        ),
      );

      await roomsProvider.loadRooms();
      if (!mounted) {
        return;
      }

      navigator.pop(true);
    });
  }

  void _navigateBackToChatList() {
    if (!mounted || _isNavigatingBackToChatList) {
      return;
    }

    _isNavigatingBackToChatList = true;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(true);
      return;
    }

    _isNavigatingBackToChatList = false;
  }

  void _syncRoomDisplayNameFromRoomList() {
    final roomsProvider = context.read<ChatRoomsProvider>();
    final currentUsername = context.read<AuthProvider>().username;
    String? nextName;

    for (final room in roomsProvider.rooms) {
      if (room.id != widget.roomId) {
        continue;
      }
      nextName = room.displayNameFor(currentUsername).trim();
      break;
    }

    if (!mounted ||
        nextName == null ||
        nextName.isEmpty ||
        nextName == _roomDisplayName) {
      return;
    }

    setState(() {
      _roomDisplayName = nextName!;
    });
  }

  void _subscribeGroupMembersAdded() {
    _groupMembersAddedSub =
        context.read<RealtimeService>().groupMembersAddedStream.listen((event) {
      if (!mounted || event.roomId != widget.roomId) {
        return;
      }

      if (event.newMembers.isEmpty) {
        return;
      }

      final membersText = event.newMembers.join(', ');
      final addedBy = (event.addedBy ?? '').trim();
      final text = addedBy.isEmpty
          ? '$membersText joined the group.'
          : '$addedBy added $membersText.';

      _showGroupMemberNotice(
        text: text,
        type: _GroupSystemNoticeType.added,
      );
      unawaited(context.read<ChatRoomsProvider>().loadRooms());
    });
  }

  void _subscribeGroupMemberRemoved() {
    _groupMemberRemovedSub =
        context.read<RealtimeService>().groupMemberRemovedStream.listen((event) {
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

      _showGroupMemberNotice(
        text: text,
        type: isLeft ? _GroupSystemNoticeType.left : _GroupSystemNoticeType.removed,
      );

      unawaited(context.read<ChatRoomsProvider>().loadRooms());
    });
  }

  void _showGroupMemberNotice({
    required String text,
    required _GroupSystemNoticeType type,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final (icon, backgroundColor) = switch (type) {
      _GroupSystemNoticeType.added =>
        (Icons.person_add_alt_1_rounded, const Color(0xFF0B6BCB)),
      _GroupSystemNoticeType.removed =>
        (Icons.person_remove_alt_1_rounded, const Color(0xFFB54708)),
      _GroupSystemNoticeType.left =>
        (Icons.logout_rounded, const Color(0xFF0D7A43)),
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

  _GroupSystemNotice? _groupSystemNoticeFromMessage(MessageReceiveModel item) {
    final raw = (item.message ?? '').trim();
    const prefix = '[GROUP_EVENT:';
    if (!raw.startsWith(prefix)) {
      return null;
    }

    final endIndex = raw.indexOf(']');
    if (endIndex <= prefix.length) {
      return null;
    }

    final typeRaw = raw.substring(prefix.length, endIndex).trim().toUpperCase();
    final text = raw.substring(endIndex + 1).trim();
    if (text.isEmpty) {
      return null;
    }

    final type = switch (typeRaw) {
      'ADDED' => _GroupSystemNoticeType.added,
      'REMOVED' => _GroupSystemNoticeType.removed,
      'LEFT' => _GroupSystemNoticeType.left,
      _ => null,
    };
    if (type == null) {
      return null;
    }

    return _GroupSystemNotice(
      text: text,
      type: type,
      at: item.sentOn?.toLocal() ?? DateTime.now(),
    );
  }

  void _subscribeTyping() {
    _typingSub = context.read<RealtimeService>().roomTypingStream(widget.roomId).listen((event) {
      if (!mounted || event.sender == _myUsername) {
        return;
      }

      _typingVisibleTimer?.cancel();
      if (event.typing) {
        _startTypingDots();
      } else {
        _stopTypingDots();
      }
      setState(() {
        _isPeerTyping = event.typing;
        _typingSender = event.typing ? event.sender : null;
      });

      if (event.typing) {
        _typingVisibleTimer = Timer(const Duration(seconds: 4), () {
          if (!mounted) {
            return;
          }

          setState(() {
            _isPeerTyping = false;
            _typingSender = null;
          });
          _stopTypingDots();
        });
      }
    });
  }

  void _startTypingDots() {
    if (_typingDotsTicker != null) {
      return;
    }

    _typingDotsTicker = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted || !_isPeerTyping) {
        return;
      }

      setState(() {
        _typingDots = _typingDots == 3 ? 1 : _typingDots + 1;
      });
    });
  }

  void _stopTypingDots() {
    _typingDotsTicker?.cancel();
    _typingDotsTicker = null;
    _typingDots = 1;
  }

  String _typingDisplayName() {
    final sender = _typingSender;
    if (sender == null || sender.isEmpty) {
      return _roomDisplayName;
    }

    if (widget.peerUsername != null && sender == widget.peerUsername) {
      return _roomDisplayName;
    }

    return sender;
  }

  void _onTextChanged(String value) {
    final hasText = value.trim().isNotEmpty;

    if (!hasText) {
      _typingDebounce?.cancel();
      if (_isTypingSent) {
        _isTypingSent = false;
        unawaited(context.read<ChatProvider>().setTypingStatus(false));
      }
      return;
    }

    if (!_isTypingSent) {
      _isTypingSent = true;
      unawaited(context.read<ChatProvider>().setTypingStatus(true));
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 1200), () {
      if (!_isTypingSent) {
        return;
      }

      _isTypingSent = false;
      unawaited(context.read<ChatProvider>().setTypingStatus(false));
    });
  }

  Future<void> _loadPresence() async {
    final peer = widget.peerUsername;
    if (peer == null || peer.isEmpty) {
      return;
    }

    setState(() {
      _isPresenceLoading = true;
    });

    try {
      final presence = await context.read<UserService>().getPresence(peer);
      if (!mounted) {
        return;
      }

      setState(() {
        _isPeerOnline = presence.online;
        _lastSeenAt = presence.lastSeenAt?.toLocal();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPeerOnline = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPresenceLoading = false;
        });
      }
    }
  }

  void _subscribePresence() {
    final peer = widget.peerUsername;
    if (peer == null || peer.isEmpty) {
      return;
    }

    _presenceSub = context.read<RealtimeService>().presenceStream.listen((event) {
      final presence = event.presence;
      if (presence == null || presence.username != peer || !mounted) {
        return;
      }

      setState(() {
        _isPeerOnline = presence.online;
        _lastSeenAt = presence.lastSeenAt?.toLocal();
      });
    });
  }

  void _subscribeProfile() {
    final peer = widget.peerUsername;
    if (peer == null || peer.isEmpty) {
      return;
    }

    _profileSub = context.read<RealtimeService>().profileStream.listen((profile) {
      final username = (profile.username ?? '').trim();
      if (!mounted || username != peer) {
        return;
      }

      setState(() {
        _roomDisplayName = profile.displayLabel;
      });
    });
  }

  Future<void> _loadBlockStatus() async {
    final peer = widget.peerUsername;
    if (peer == null || peer.isEmpty) {
      return;
    }

    setState(() {
      _isBlockStatusLoading = true;
    });

    try {
      final status = await context.read<UserService>().getBlockStatus(peer);
      if (!mounted) {
        return;
      }

      setState(() {
        _blockedByMe = status.blockedByMe;
        _blockedByPeer = status.blockedByUser;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBlockStatusLoading = false;
        });
      }
    }
  }

  void _subscribeBlockStatus() {
    final peer = widget.peerUsername;
    if (peer == null || peer.isEmpty) {
      return;
    }

    _blockStatusSub = context.read<RealtimeService>().blockStatusStream.listen((event) {
      if (!mounted || event.username != peer) {
        return;
      }

      setState(() {
        _blockedByMe = event.blockedByMe;
        _blockedByPeer = event.blockedByUser;
      });
    });
  }

  bool get _isMessagingBlocked => _blockedByMe || _blockedByPeer;

  String? _blockedBannerText() {
    if (!_isMessagingBlocked) {
      return null;
    }

    if (_blockedByMe && _blockedByPeer) {
      return 'Both users blocked each other. Unblock to continue messaging.';
    }

    if (_blockedByMe) {
      return 'You blocked this user. Unblock in People tab to continue messaging.';
    }

    return 'This user blocked you on Messenger.';
  }

  String? _presenceLabel() {
    if (_isMessagingBlocked) {
      return 'Blocked';
    }

    if (widget.peerUsername == null || widget.peerUsername!.isEmpty) {
      return null;
    }

    if (_isPresenceLoading && _isPeerOnline == null) {
      return 'Loading status...';
    }

    if (_isPeerOnline == true) {
      return 'Online';
    }

    final seenAt = _lastSeenAt;
    if (seenAt == null) {
      return 'Offline';
    }

    return 'Last seen ${_formatLastSeen(seenAt)}';
  }

  String _formatLastSeen(DateTime value) {
    final seenAt = value.toLocal();
    final now = DateTime.now();
    final isToday =
        seenAt.year == now.year && seenAt.month == now.month && seenAt.day == now.day;
    if (isToday) {
      return 'today at ${DateFormat('HH:mm').format(seenAt)}';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = seenAt.year == yesterday.year &&
        seenAt.month == yesterday.month &&
        seenAt.day == yesterday.day;
    if (isYesterday) {
      return 'yesterday at ${DateFormat('HH:mm').format(seenAt)}';
    }

    return DateFormat('dd/MM/yyyy HH:mm').format(seenAt);
  }

  Future<void> _pickImage() async {
    if (_isMessagingBlocked) {
      return;
    }

    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return;
    }

    setState(() {
      _pickedFiles = [..._pickedFiles, image];
    });
  }

  Future<void> _send() async {
    if (_isMessagingBlocked) {
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty && _pickedFiles.isEmpty) {
      return;
    }

    final sent = await context.read<ChatProvider>().sendMessage(
          text: text,
          attachments: _pickedFiles,
        );

    if (!mounted) {
      return;
    }

    if (!sent) {
      final error = context.read<ChatProvider>().error ?? 'Send failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    if (_isTypingSent) {
      _isTypingSent = false;
      unawaited(context.read<ChatProvider>().setTypingStatus(false));
    }
    _typingDebounce?.cancel();

    _controller.clear();
    setState(() {
      _pickedFiles = [];
    });

    await Future.delayed(const Duration(milliseconds: 150));
    _scrollToBottom(animated: true);
  }

  List<String> _collectTranslationContext({
    required int messageIndex,
    required List<MessageReceiveModel> messages,
  }) {
    const maxContextMessages = 6;
    final context = <String>[];

    for (var i = messageIndex - 1; i >= 0 && context.length < maxContextMessages; i--) {
      final item = messages[i];
      if (_groupSystemNoticeFromMessage(item) != null) {
        continue;
      }

      final text = (item.message ?? '').trim();
      if (text.isEmpty) {
        continue;
      }

      final sender = (item.senderProfile?.displayLabel ?? item.sender ?? '').trim();
      context.add(sender.isEmpty ? text : '$sender: $text');
    }

    return context.reversed.toList(growable: false);
  }

  List<String> _collectRecentSummaryMessages(List<MessageReceiveModel> messages) {
    const maxMessages = 30;
    final collected = <String>[];

    for (var i = messages.length - 1; i >= 0 && collected.length < maxMessages; i--) {
      final item = messages[i];
      if (_groupSystemNoticeFromMessage(item) != null) {
        continue;
      }

      final text = (item.message ?? '').trim();
      if (text.isEmpty) {
        continue;
      }

      final sender = (item.senderProfile?.displayLabel ?? item.sender ?? '').trim();
      collected.add(sender.isEmpty ? text : '$sender: $text');
    }

    return collected.reversed.toList(growable: false);
  }

  Future<void> _summarizeRecentMessages(List<MessageReceiveModel> messages) async {
    final payload = _collectRecentSummaryMessages(messages);
    if (payload.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có tin nhắn văn bản gần đây để tóm tắt')),
      );
      return;
    }

    final summary = await context.read<ChatProvider>().summarizeRecentMessages(
      messages: payload,
      roomName: _roomDisplayName,
    );

    if (!mounted) {
      return;
    }

    if (summary == null) {
      final error = context.read<ChatProvider>().error ?? 'Summarize failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          content: SingleChildScrollView(
            child: MarkdownBody(
              data: summary,
              selectable: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _translateMessage({
    required MessageReceiveModel message,
    required int messageIndex,
    required List<MessageReceiveModel> messages,
    required bool forceRefresh,
  }) async {
    final messageId = message.id;
    final text = (message.message ?? '').trim();
    if (messageId == null || text.isEmpty) {
      return;
    }

    final previousMessages = _collectTranslationContext(
      messageIndex: messageIndex,
      messages: messages,
    );

    final translated = await context.read<ChatProvider>().translateMessage(
      messageId: messageId,
      originalText: text,
      previousMessages: previousMessages,
      forceRefresh: forceRefresh,
    );

    if (!mounted || translated) {
      return;
    }

    final error = context.read<ChatProvider>().error ?? 'Translate failed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  Future<void> _deleteMessage(int messageId) async {
    final deleted = await context.read<ChatProvider>().recallMessage(
          messageId: messageId,
        );

    if (!mounted || deleted) {
      return;
    }

    final error = context.read<ChatProvider>().error ?? 'Delete failed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  void _confirmRecall(int messageId) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete message'),
          content: const Text('This message will be recalled for everyone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_deleteMessage(messageId));
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _openMessageActions({
    required MessageReceiveModel message,
    required bool isMine,
    required int messageIndex,
    required List<MessageReceiveModel> messages,
  }) {
    final messageId = message.id;
    final canDelete = isMine && messageId != null;
    final hasText = (message.message ?? '').trim().isNotEmpty;
    final canTranslate = messageId != null && hasText;

    if (!canDelete && !canTranslate) {
      return;
    }

    final chat = context.read<ChatProvider>();
    final translatedText = chat.translatedTextForMessage(messageId);
    final isTranslating = chat.isTranslatingMessage(messageId);

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canTranslate)
                ListTile(
                  leading: isTranslating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.translate_rounded),
                  title: Text(
                    isTranslating
                        ? 'Dang dich sang tieng Viet...'
                        : translatedText == null
                            ? 'Dich sang tieng Viet'
                            : 'Dich lai sang tieng Viet',
                  ),
                  onTap: isTranslating
                      ? null
                      : () {
                          Navigator.pop(sheetContext);
                          unawaited(_translateMessage(
                            message: message,
                            messageIndex: messageIndex,
                            messages: messages,
                            forceRefresh: translatedText != null,
                          ));
                        },
                ),
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete message'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmRecall(messageId);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final myUsername = context.watch<AuthProvider>().username;
    final presenceLabel = _presenceLabel();
    final blockedBannerText = _blockedBannerText();
    final typingLabel = _isPeerTyping
        ? '${_typingDisplayName()} \u0111ang nh\u1eadp${'.' * _typingDots}'
        : null;
    final isOnline = _isPeerOnline == true;
    final messages = chat.messages;
    final isGroupRoom = widget.peerUsername == null || widget.peerUsername!.isEmpty;

    final senderProfiles = <String, UserWithAvatarModel>{};
    for (final item in messages) {
      final username = (item.sender ?? item.senderProfile?.username ?? '').trim();
      if (username.isEmpty) {
        continue;
      }

      final profile = item.senderProfile;
      if (profile != null) {
        senderProfiles[username] = profile;
      } else if (_readerByUsername.containsKey(username)) {
        senderProfiles[username] = _readerByUsername[username]!;
      }
    }

    int? lastOwnIndex;
    final ownMessageIndexes = <int>[];
    for (var i = 0; i < messages.length; i++) {
      final item = messages[i];
      final senderUsername = (item.sender ?? item.senderProfile?.username ?? '').trim();
      if (myUsername != null && senderUsername == myUsername) {
        ownMessageIndexes.add(i);
      }
    }
    if (ownMessageIndexes.isNotEmpty) {
      lastOwnIndex = ownMessageIndexes.last;
    }

    int? findLastOwnIndexAtOrBefore(DateTime readAt) {
      for (var i = ownMessageIndexes.length - 1; i >= 0; i--) {
        final index = ownMessageIndexes[i];
        final sentOn = messages[index].sentOn;
        if (sentOn != null && !sentOn.isAfter(readAt)) {
          return index;
        }
      }

      return null;
    }

    final seenByIndexMap = <int, Map<String, SeenAvatarInfo>>{};

    void addSeenAvatarToIndex(int index, SeenAvatarInfo info) {
      final username = (info.user.username ?? '').trim();
      if (username.isEmpty || username == myUsername) {
        return;
      }

      final currentMap = seenByIndexMap.putIfAbsent(index, () => {});
      currentMap[username] = info;
    }

    _readAtByUser.forEach((username, readAt) {
      if (username == myUsername) {
        return;
      }

      final targetIndex = findLastOwnIndexAtOrBefore(readAt);
      if (targetIndex == null) {
        return;
      }

      final user = _readerByUsername[username] ??
          UserWithAvatarModel(
            id: null,
            username: username,
            displayName: username,
            avatar: null,
          );

      addSeenAvatarToIndex(
        targetIndex,
        SeenAvatarInfo(user: user, seenAt: readAt),
      );
    });

    final fallbackTargetByUser = <String, int>{};
    final fallbackProfileByUser = <String, UserWithAvatarModel>{};

    for (final index in ownMessageIndexes) {
      final item = messages[index];
      for (final viewer in item.seenBy) {
        final username = (viewer.username ?? '').trim();
        if (username.isEmpty || username == myUsername) {
          continue;
        }

        if (_readAtByUser.containsKey(username)) {
          continue;
        }

        fallbackTargetByUser[username] = index;
        fallbackProfileByUser[username] = viewer;
      }
    }

    fallbackTargetByUser.forEach((username, targetIndex) {
      final user = fallbackProfileByUser[username] ??
          UserWithAvatarModel(
            id: null,
            username: username,
            displayName: username,
            avatar: null,
          );

      addSeenAvatarToIndex(
        targetIndex,
        SeenAvatarInfo(user: user, seenAt: null),
      );
    });

    final seenByAvatarsByIndex = <int, List<SeenAvatarInfo>>{};
    seenByIndexMap.forEach((index, viewersMap) {
      final viewers = viewersMap.values.toList()
        ..sort((a, b) {
          final aTime = a.seenAt?.millisecondsSinceEpoch ?? 0;
          final bTime = b.seenAt?.millisecondsSinceEpoch ?? 0;
          if (aTime != bTime) {
            return bTime.compareTo(aTime);
          }

          return (a.user.username ?? '').compareTo(b.user.username ?? '');
        });
      seenByAvatarsByIndex[index] = viewers;
    });

    final timelineItems = <_ChatTimelineItem>[];
    for (var i = 0; i < messages.length; i++) {
      timelineItems.add(
        _ChatTimelineItem.message(
          index: i,
        ),
      );
    }

    String senderAtTimelineIndex(int index) {
      if (index < 0 || index >= timelineItems.length) {
        return '';
      }
      final messageIndex = timelineItems[index].messageIndex;
      if (messageIndex == null) {
        return '';
      }
      final message = messages[messageIndex];
      if (_groupSystemNoticeFromMessage(message) != null) {
        return '';
      }

      return (message.sender ??
              message.senderProfile?.username ??
              '')
          .trim();
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(radius: 17, child: Icon(Icons.person, size: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _roomDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (presenceLabel != null)
                    Text(
                      presenceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isOnline
                                ? const Color(0xFF0A8F47)
                                : Colors.black54,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isGroupRoom)
            IconButton(
              icon: const Icon(Icons.group_outlined),
              tooltip: 'Group members',
              onPressed: () async {
                final navigator = Navigator.of(context);
                final roomsProvider = context.read<ChatRoomsProvider>();

                final leftGroup = await navigator.push<bool>(
                  MaterialPageRoute(
                    builder: (_) => GroupMembersScreen(roomId: widget.roomId),
                  ),
                );

                if (!mounted) {
                  return;
                }

                if (leftGroup == true) {
                  _navigateBackToChatList();
                  return;
                }

                await roomsProvider.loadRooms();
                if (!mounted) {
                  return;
                }
                _syncRoomDisplayNameFromRoomList();
              },
            ),
          if (chat.isSummarizing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.summarize_rounded),
              tooltip: 'Tóm tắt tin nhắn gần đây',
              onPressed: messages.isEmpty
                  ? null
                  : () => _summarizeRecentMessages(messages),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: chat.loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.isLoading && chat.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: timelineItems.length,
                    itemBuilder: (context, index) {
                    final timeline = timelineItems[index];
                    final messageIndex = timeline.messageIndex!;
                    final item = messages[messageIndex];
                    final systemNotice = _groupSystemNoticeFromMessage(item);
                    if (systemNotice != null) {
                    return _GroupSystemNoticeTile(notice: systemNotice);
                    }

                      final senderUsername =
                          (item.sender ?? item.senderProfile?.username ?? '').trim();
                      final isMine = myUsername != null && senderUsername == myUsername;
                      final senderProfile = senderProfiles[senderUsername];

                    final previousSender = senderAtTimelineIndex(index - 1);
                    final nextSender = senderAtTimelineIndex(index + 1);
                      final isStartSenderBlock = senderUsername != previousSender;
                      final isEndSenderBlock = senderUsername != nextSender;
                      const firstMessageGap = 4.0;
                      const differentSenderGap = 18.0;
                      const sameSenderGap = 1.0;
                      final bubbleTopSpacing = isStartSenderBlock
                      ? (messageIndex == 0 ? firstMessageGap : differentSenderGap)
                          : sameSenderGap;

                      final seenByAvatars = isMine
                      ? (seenByAvatarsByIndex[messageIndex] ?? const <SeenAvatarInfo>[])
                          : const <SeenAvatarInfo>[];

                      String? deliveryStatus;
                    if (isMine && messageIndex == lastOwnIndex) {
                        deliveryStatus = seenByAvatars.isNotEmpty
                            ? '\u0110\u00e3 xem'
                            : '\u0110\u00e3 g\u1eedi';
                      }

                      final translatedText = chat.translatedTextForMessage(item.id);
                      final isTranslating = chat.isTranslatingMessage(item.id);

                      return MessageBubble(
                        message: item,
                        isMine: isMine,
                        deliveryStatus: deliveryStatus,
                        translatedText: translatedText,
                        isTranslating: isTranslating,
                        seenByAvatars: seenByAvatars,
                        senderName: senderProfile?.displayLabel ?? senderUsername,
                        senderAvatarUrl: senderProfile?.avatar?.source,
                        showSenderName: !isMine && isGroupRoom && isStartSenderBlock,
                        showSenderAvatar: !isMine && (!isGroupRoom || isEndSenderBlock),
                        reserveSenderAvatarSpace: !isMine && isGroupRoom,
                        topSpacing: bubbleTopSpacing,
                        onLongPress: () => _openMessageActions(
                          message: item,
                          isMine: isMine,
                          messageIndex: messageIndex,
                          messages: messages,
                        ),
                      );
                    },
                  ),
          ),
          if (_pickedFiles.isNotEmpty)
            SizedBox(
              height: 74,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pickedFiles.length,
                itemBuilder: (context, index) {
                  final file = _pickedFiles[index];
                  return Stack(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        margin: const EdgeInsets.only(left: 8, bottom: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _PickedFilePreview(file: file),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _pickedFiles = _pickedFiles
                                  .where((f) => f.path != file.path)
                                  .toList();
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          if (_isBlockStatusLoading)
            const LinearProgressIndicator(minHeight: 2),
          if (blockedBannerText != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(10, 6, 10, 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD08A)),
              ),
              child: Text(
                blockedBannerText,
                style: const TextStyle(color: Color(0xFF7A4A00), fontSize: 13),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: typingLabel == null ? 0 : 22,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: typingLabel == null
                ? null
                : Text(
                    typingLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF168AFF),
                          fontStyle: FontStyle.italic,
                        ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isMessagingBlocked ? null : _pickImage,
                    icon: const Icon(Icons.image_rounded),
                    color: const Color(0xFF168AFF),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isMessagingBlocked,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 5,
                      onChanged: _onTextChanged,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Aa',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: chat.isSending || _isMessagingBlocked ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF168AFF),
                    ),
                    icon: chat.isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _GroupSystemNoticeType {
  added,
  removed,
  left,
}

class _GroupSystemNotice {
  const _GroupSystemNotice({
    required this.text,
    required this.type,
    required this.at,
  });

  final String text;
  final _GroupSystemNoticeType type;
  final DateTime at;
}

class _ChatTimelineItem {
  const _ChatTimelineItem._({
    required this.messageIndex,
  });

  factory _ChatTimelineItem.message({
    required int index,
  }) {
    return _ChatTimelineItem._(
      messageIndex: index,
    );
  }

  final int? messageIndex;
}

class _GroupSystemNoticeTile extends StatelessWidget {
  const _GroupSystemNoticeTile({required this.notice});

  final _GroupSystemNotice notice;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (notice.type) {
      _GroupSystemNoticeType.added => (Icons.person_add_alt_1_rounded, const Color(0xFF0B6BCB)),
      _GroupSystemNoticeType.removed => (Icons.person_remove_alt_1_rounded, const Color(0xFFB54708)),
      _GroupSystemNoticeType.left => (Icons.logout_rounded, const Color(0xFF0D7A43)),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  notice.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('HH:mm').format(notice.at.toLocal()),
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickedFilePreview extends StatelessWidget {
  const _PickedFilePreview({required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ColoredBox(
            color: Color(0xFFE5E7EB),
            child: Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
