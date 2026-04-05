import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/chatbot_conversation_model.dart';
import '../../models/chatbot_message_model.dart';
import '../../providers/chatbot_provider.dart';
import '../../services/chatbot_service.dart';

class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          ChatbotProvider(context.read<ChatbotService>())..bootstrap(),
      child: const _ChatbotView(),
    );
  }
}

class _ChatbotView extends StatefulWidget {
  const _ChatbotView();

  @override
  State<_ChatbotView> createState() => _ChatbotViewState();
}

class _ChatbotViewState extends State<_ChatbotView> {
  final _controller = TextEditingController();
  final _mcpSessionController = TextEditingController();
  final _mcpMetadataController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isHistoryVisible = true;

  ChatbotProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ChatbotProvider>();
      _provider = provider;
      provider.addListener(_onProviderUpdated);
      _syncMcpFields(provider);
      _scrollToBottom(animated: false);
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderUpdated);
    _controller.dispose();
    _mcpSessionController.dispose();
    _mcpMetadataController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onProviderUpdated() {
    if (!mounted) {
      return;
    }

    _syncMcpFields(context.read<ChatbotProvider>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: true);
    });
  }

  void _syncMcpFields(ChatbotProvider provider) {
    final nextSessionId = provider.mcpSessionId;
    if (_mcpSessionController.text != nextSessionId) {
      _mcpSessionController.value = TextEditingValue(
        text: nextSessionId,
        selection: TextSelection.collapsed(offset: nextSessionId.length),
      );
    }

    final nextMetadata = provider.mcpMetadata;
    if (_mcpMetadataController.text != nextMetadata) {
      _mcpMetadataController.value = TextEditingValue(
        text: nextMetadata,
        selection: TextSelection.collapsed(offset: nextMetadata.length),
      );
    }
  }

  void _scrollToBottom({required bool animated}) {
    if (!_scrollController.hasClients) {
      return;
    }

    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
      return;
    }

    _scrollController.jumpTo(target);
  }

  Future<void> _send(ChatbotProvider provider) async {
    final input = _controller.text.trim();
    if (input.isEmpty || provider.isStreaming) {
      return;
    }

    _controller.clear();

    final sent = await provider.sendMessage(input);
    if (!mounted || sent) {
      return;
    }

    final error = provider.error ?? 'Gửi tới chatbot thất bại';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(error)),
      );
  }

  Future<void> _confirmAndDeleteConversation(
    ChatbotProvider provider,
    ChatbotConversationModel conversation,
  ) async {
    if (provider.isStreaming || provider.isDeletingConversation) {
      return;
    }

    final title = conversation.title.trim().isEmpty
        ? 'Cuộc trò chuyện ${conversation.id}'
        : conversation.title;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa lịch sử trò chuyện'),
          content: Text(
            'Bạn có chắc muốn xóa "$title"?\nHành động này không thể hoàn tác.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD92D20),
              ),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final deleted = await provider.deleteConversation(conversation.id);
    if (!mounted || deleted) {
      return;
    }

    final error = provider.error ?? 'Xóa lịch sử trò chuyện thất bại';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatbotProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 17,
              backgroundImage: AssetImage('lib/assets/ai_bot_avatar.png'),
              backgroundColor: Colors.transparent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trợ lý AI',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    provider.isStreaming
                        ? 'AI đang phản hồi...'
                        : 'Sẵn sàng hỗ trợ bạn',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.online,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: provider.isLoadingConversations
                ? null
                : () async {
                    await provider.loadConversations();
                  },
            tooltip: 'Làm mới hội thoại chatbot',
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: provider.isStreaming || provider.isCreatingConversation
                ? null
                : () async {
                    await provider.createConversation(
                      openConversationAfterCreate: true,
                    );
                  },
            tooltip: 'Tạo hội thoại chatbot mới',
            icon: provider.isCreatingConversation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_comment_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: provider.isLoadingConversations && provider.conversations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: AppColors.bgDark,
              child: Column(
                children: [
                  _ConversationSelector(
                    conversations: provider.conversations,
                    activeConversationId: provider.activeConversationId,
                    isCreating: provider.isCreatingConversation,
                    isDeleting: provider.isDeletingConversation,
                    isExpanded: _isHistoryVisible,
                    onConversationSelected: provider.openConversation,
                    onDeleteConversation: (conversation) =>
                        _confirmAndDeleteConversation(provider, conversation),
                    onToggleExpanded: () {
                      setState(() {
                        _isHistoryVisible = !_isHistoryVisible;
                      });
                    },
                    onCreateConversation: () => provider.createConversation(
                      openConversationAfterCreate: true,
                    ),
                  ),
                  if (provider.useMcp)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      child: Column(
                        children: [
                          TextField(
                            controller: _mcpSessionController,
                            onChanged: provider.setMcpSessionId,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText:
                                  'MCP session id (cho tích hợp sau này)',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _mcpMetadataController,
                            onChanged: provider.setMcpMetadata,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'MCP context hint (tùy chọn)',
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (provider.error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        border: Border.all(color: const Color(0xFF9F3345)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        provider.error!,
                        style: const TextStyle(
                          color: Color(0xFFFFB4C0),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Expanded(
                    child: provider.activeConversationId == null
                        ? const Center(
                            child: Text(
                              'Tạo cuộc trò chuyện mới để bắt đầu với chatbot',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : _MessagesPanel(
                            messages: provider.messages,
                            streamingText: provider.streamingAssistantText,
                            isLoading: provider.isLoadingMessages,
                            scrollController: _scrollController,
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                      color: AppColors.bgCard,
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: provider.isStreaming
                                ? null
                                : () => provider.setUseMcp(!provider.useMcp),
                            tooltip: provider.useMcp
                                ? 'Tắt MCP mode'
                                : 'Bật MCP mode (chuẩn bị cho tích hợp sau này)',
                            icon: Icon(
                              provider.useMcp
                                  ? Icons.extension
                                  : Icons.extension_off_outlined,
                            ),
                            color: provider.useMcp
                                ? AppColors.primary
                                : AppColors.textHint,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              textInputAction: TextInputAction.send,
                              minLines: 1,
                              maxLines: 5,
                              onSubmitted: (_) => _send(provider),
                              enabled: !provider.isStreaming,
                              decoration: const InputDecoration(
                                hintText: 'Hỏi chatbot...',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton.filled(
                            onPressed: provider.isStreaming
                                ? null
                                : () => _send(provider),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            icon: provider.isStreaming
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
            ),
    );
  }
}

class _ConversationSelector extends StatelessWidget {
  const _ConversationSelector({
    required this.conversations,
    required this.activeConversationId,
    required this.isCreating,
    required this.isDeleting,
    required this.isExpanded,
    required this.onConversationSelected,
    required this.onDeleteConversation,
    required this.onToggleExpanded,
    required this.onCreateConversation,
  });

  final List<ChatbotConversationModel> conversations;
  final int? activeConversationId;
  final bool isCreating;
  final bool isDeleting;
  final bool isExpanded;
  final ValueChanged<int> onConversationSelected;
  final Future<void> Function(ChatbotConversationModel conversation)
      onDeleteConversation;
  final VoidCallback onToggleExpanded;
  final VoidCallback onCreateConversation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.history,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Lịch sử trò chuyện',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed:
                    isCreating || isDeleting ? null : onCreateConversation,
                tooltip: 'Tạo cuộc trò chuyện chatbot mới',
                icon: isCreating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_comment_outlined),
              ),
              IconButton(
                onPressed: onToggleExpanded,
                tooltip: isExpanded ? 'Ẩn lịch sử' : 'Hiện lịch sử',
                icon: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildHistoryList(context),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context) {
    if (conversations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 8, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Chưa có cuộc trò chuyện chatbot nào',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final estimatedHeight = (conversations.length * 78.0).clamp(96.0, 300.0);

    return SizedBox(
      height: estimatedHeight,
      child: ListView.separated(
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final item = conversations[index];
          final isActive = activeConversationId == item.id;

          return Material(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.16)
                : AppColors.bgInput,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onConversationSelected(item.id),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title.trim().isEmpty
                                ? 'Cuộc trò chuyện ${item.id}'
                                : item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight:
                                  isActive ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (item.mcpEnabled)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.extension,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        IconButton(
                          onPressed: isDeleting
                              ? null
                              : () => onDeleteConversation(item),
                          tooltip: 'Xóa lịch sử cuộc trò chuyện này',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.preview.trim().isEmpty
                          ? 'Chưa có tin nhắn trong cuộc trò chuyện này'
                          : item.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatConversationTimestamp(
                          item.updatedOn ?? item.createdOn),
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatConversationTimestamp(DateTime? value) {
    if (value == null) {
      return 'Vừa tạo';
    }

    return DateFormat('dd/MM HH:mm').format(value.toLocal());
  }
}

class _MessagesPanel extends StatelessWidget {
  const _MessagesPanel({
    required this.messages,
    required this.streamingText,
    required this.isLoading,
    required this.scrollController,
  });

  final List<ChatbotMessageModel> messages;
  final String streamingText;
  final bool isLoading;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (isLoading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: messages.length + (streamingText.trim().isEmpty ? 0 : 1),
      itemBuilder: (context, index) {
        if (index >= messages.length) {
          return _ChatbotBubble(
            role: ChatbotRole.assistant,
            content: streamingText,
            createdOn: DateTime.now(),
            isStreaming: true,
          );
        }

        final item = messages[index];
        return _ChatbotBubble(
          role: item.role,
          content: item.content,
          createdOn: item.createdOn,
        );
      },
    );
  }
}

class _ChatbotBubble extends StatelessWidget {
  const _ChatbotBubble({
    required this.role,
    required this.content,
    required this.createdOn,
    this.isStreaming = false,
  });

  final ChatbotRole role;
  final String content;
  final DateTime? createdOn;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final isUser = role == ChatbotRole.user;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isUser ? AppColors.primary : AppColors.bgCard;
    final textColor = isUser ? Colors.white : AppColors.textPrimary;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 3, 12, 3),
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          border: isUser ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isUser)
              Text(
                content,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  height: 1.3,
                ),
              )
            else
              MarkdownBody(
                data: content,
                selectable: true,
                styleSheet:
                    MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              isStreaming
                  ? 'Đang trả lời...'
                  : DateFormat('HH:mm')
                      .format((createdOn ?? DateTime.now()).toLocal()),
              style: TextStyle(
                color: isUser ? Colors.white70 : AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
