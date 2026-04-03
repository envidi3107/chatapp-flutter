import 'attachment_model.dart';
import 'user_with_avatar_model.dart';

class MessageReceiveModel {
  const MessageReceiveModel({
    required this.id,
    required this.sender,
    required this.senderProfile,
    required this.message,
    required this.sentOn,
    required this.attachments,
    required this.seenBy,
  });

  final int? id;
  final String? sender;
  final UserWithAvatarModel? senderProfile;
  final String? message;
  final DateTime? sentOn;
  final List<AttachmentModel> attachments;
  final List<UserWithAvatarModel> seenBy;

  MessageReceiveModel copyWith({
    int? id,
    String? sender,
    UserWithAvatarModel? senderProfile,
    String? message,
    DateTime? sentOn,
    List<AttachmentModel>? attachments,
    List<UserWithAvatarModel>? seenBy,
  }) {
    return MessageReceiveModel(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      senderProfile: senderProfile ?? this.senderProfile,
      message: message ?? this.message,
      sentOn: sentOn ?? this.sentOn,
      attachments: attachments ?? this.attachments,
      seenBy: seenBy ?? this.seenBy,
    );
  }

  factory MessageReceiveModel.fromJson(Map<String, dynamic> json) {
    final senderRaw = json['sender'];
    final senderProfileJson = json['senderProfile'] ??
        (senderRaw is Map<String, dynamic> ? senderRaw : null);
    final senderProfile = senderProfileJson is Map<String, dynamic>
        ? UserWithAvatarModel.fromJson(senderProfileJson)
        : null;
    final sender = senderRaw is String
        ? senderRaw
        : (senderRaw is Map<String, dynamic>
            ? senderRaw['username']?.toString()
            : null);
    final attachmentsRaw = json['attachments'] as List<dynamic>? ?? const [];
    final seenByRaw = json['seenBy'] as List<dynamic>? ?? const [];
    return MessageReceiveModel(
      id: json['id'] as int?,
      sender: (sender ?? senderProfile?.username)?.toString(),
      senderProfile: senderProfile,
      message: json['message'] as String?,
      sentOn: DateTime.tryParse((json['sentOn'] ?? '').toString()),
      attachments: attachmentsRaw
          .whereType<Map<String, dynamic>>()
          .map(AttachmentModel.fromJson)
          .toList(),
      seenBy: seenByRaw
          .whereType<Map<String, dynamic>>()
          .map(UserWithAvatarModel.fromJson)
          .toList(),
    );
  }
}
