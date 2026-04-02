import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attachment_model.dart';
import '../models/message_receive_model.dart';
import '../models/user_with_avatar_model.dart';
import 'app_avatar.dart';

class SeenAvatarInfo {
  const SeenAvatarInfo({
    required this.user,
    required this.seenAt,
  });

  final UserWithAvatarModel user;
  final DateTime? seenAt;
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.onLongPress,
    this.deliveryStatus,
    this.translatedText,
    this.isTranslating = false,
    this.seenByAvatars = const [],
    this.senderName,
    this.senderAvatarUrl,
    this.showSenderName = false,
    this.showSenderAvatar = false,
    this.reserveSenderAvatarSpace = false,
    this.topSpacing = 4,
  });

  final MessageReceiveModel message;
  final bool isMine;
  final VoidCallback onLongPress;
  final String? deliveryStatus;
  final String? translatedText;
  final bool isTranslating;
  final List<SeenAvatarInfo> seenByAvatars;
  final String? senderName;
  final String? senderAvatarUrl;
  final bool showSenderName;
  final bool showSenderAvatar;
  final bool reserveSenderAvatarSpace;
  final double topSpacing;

  String _seenTooltip(SeenAvatarInfo info) {
    final name = info.user.displayLabel;
    final seenAt = info.seenAt;
    if (seenAt == null) {
      return '$name\n\u0110\u00e3 xem';
    }

    final seenLabel = DateFormat('HH:mm dd/MM/yyyy').format(seenAt.toLocal());
    return '$name\n\u0110\u00e3 xem l\u00fac $seenLabel';
  }

  void _openImageViewer(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImageView(imageUrl: imageUrl),
      ),
    );
  }

  bool _isImageAttachment(AttachmentModel attachment) {
    if (attachment.type == AttachmentType.image) {
      return true;
    }

    final source = attachment.source?.toLowerCase() ?? '';
    return source.endsWith('.png') ||
        source.endsWith('.jpg') ||
        source.endsWith('.jpeg') ||
        source.endsWith('.gif') ||
        source.endsWith('.webp') ||
        source.endsWith('.bmp') ||
        source.endsWith('.svg') ||
        source.endsWith('.heic') ||
        source.endsWith('.heif');
  }

  @override
  Widget build(BuildContext context) {
    final sentOn = message.sentOn;
    final imageUrls = message.attachments
        .where(_isImageAttachment)
        .map((item) => item.source)
        .whereType<String>()
        .where((source) => source.isNotEmpty)
        .toList();
    final hasText = (message.message ?? '').isNotEmpty;
    final hasVisibleImages = imageUrls.isNotEmpty;
    final normalizedTranslatedText = (translatedText ?? '').trim();
    final hasTranslatedText = normalizedTranslatedText.isNotEmpty;
    final senderLabel = (senderName ?? '').trim().isEmpty
        ? (message.sender ?? 'User')
        : senderName!.trim();
    final showAvatarSlot = !isMine && (showSenderAvatar || reserveSenderAvatarSpace);
    final showReadReceipt = isMine && (seenByAvatars.isNotEmpty || deliveryStatus != null);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showAvatarSlot) ...[
            SizedBox(
              width: 34,
              child: showSenderAvatar
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 2),
                      child: AppAvatar(
                        url: senderAvatarUrl,
                        name: senderLabel,
                        radius: 12,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Padding(
              padding: EdgeInsets.only(top: topSpacing),
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMine && showSenderName)
                    Padding(
                      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 1),
                      child: Text(
                        senderLabel,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onLongPress: onLongPress,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(10, 0, 10, 3),
                      constraints: const BoxConstraints(maxWidth: 280),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMine ? const Color(0xFF168AFF) : const Color(0xFFE8EBEF),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMine ? 18 : 6),
                          bottomRight: Radius.circular(isMine ? 6 : 18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                        if (imageUrls.isNotEmpty)
                          ...imageUrls.map(
                            (url) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GestureDetector(
                                onTap: () => _openImageViewer(context, url),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    url,
                                    width: 220,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 220,
                                      height: 120,
                                      color: Colors.black12,
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Cannot load image',
                                        style: TextStyle(
                                          color: isMine ? Colors.white70 : Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (hasText)
                          Text(
                            message.message!,
                            style: TextStyle(
                              color: isMine ? Colors.white : Colors.black87,
                              fontSize: 15,
                              height: 1.25,
                            ),
                          ),
                        if (!hasText && !hasVisibleImages)
                          Text(
                            'Tin nhan da bi xoa',
                            style: TextStyle(
                              color: isMine ? Colors.white70 : Colors.black54,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        if (isTranslating) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isMine ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Dang dich sang tieng Viet...',
                                style: TextStyle(
                                  color: isMine ? Colors.white70 : Colors.black54,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (!isTranslating && hasTranslatedText) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? Colors.white.withOpacity(0.18)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isMine
                                    ? Colors.white.withOpacity(0.35)
                                    : const Color(0xFFD5D9E0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMine
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ban dich tieng Viet',
                                  style: TextStyle(
                                    color: isMine ? Colors.white70 : Colors.black54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  normalizedTranslatedText,
                                  style: TextStyle(
                                    color: isMine ? Colors.white : Colors.black87,
                                    fontSize: 14,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (sentOn != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('HH:mm').format(sentOn),
                            style: TextStyle(
                              color: isMine
                                  ? Colors.white.withOpacity(0.85)
                                  : Colors.black45,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        ],
                      ),
                    ),
                  ),
                  if (showReadReceipt)
                    Container(
                      margin: const EdgeInsets.only(right: 14, top: 1),
                      child: seenByAvatars.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final viewer in seenByAvatars.take(5))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 2),
                                    child: Tooltip(
                                      message: _seenTooltip(viewer),
                                      waitDuration: const Duration(milliseconds: 180),
                                      child: AppAvatar(
                                        url: viewer.user.avatar?.source,
                                        name: viewer.user.displayLabel,
                                        radius: 8,
                                      ),
                                    ),
                                  ),
                                if (seenByAvatars.length == 1) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '\u0110\u00e3 xem',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                                if (seenByAvatars.length > 5) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '+${seenByAvatars.length - 5}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : Text(
                              deliveryStatus ?? '',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),
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

class _FullScreenImageView extends StatelessWidget {
  const _FullScreenImageView({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                'Cannot load image',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
