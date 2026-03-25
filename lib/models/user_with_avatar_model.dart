import 'attachment_model.dart';

class UserWithAvatarModel {
  const UserWithAvatarModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatar,
  });

  final int? id;
  final String? username;
  final String? displayName;
  final AttachmentModel? avatar;

  String get displayLabel {
    final name = (displayName ?? '').trim();
    if (name.isNotEmpty) {
      return name;
    }

    final user = (username ?? '').trim();
    if (user.isNotEmpty) {
      return user;
    }

    return 'Unknown user';
  }

  UserWithAvatarModel copyWith({
    int? id,
    String? username,
    String? displayName,
    AttachmentModel? avatar,
    bool clearAvatar = false,
  }) {
    return UserWithAvatarModel(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatar: clearAvatar ? null : (avatar ?? this.avatar),
    );
  }

  factory UserWithAvatarModel.fromJson(Map<String, dynamic> json) {
    final avatarJson = json['avatar'];
    return UserWithAvatarModel(
      id: json['id'] as int?,
      username: json['username'] as String?,
      displayName: json['displayName'] as String?,
      avatar: avatarJson is Map<String, dynamic>
          ? AttachmentModel.fromJson(avatarJson)
          : null,
    );
  }
}
