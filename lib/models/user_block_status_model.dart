class UserBlockStatusModel {
  const UserBlockStatusModel({
    required this.username,
    required this.blockedByMe,
    required this.blockedByUser,
  });

  final String username;
  final bool blockedByMe;
  final bool blockedByUser;

  bool get canMessage => !blockedByMe && !blockedByUser;

  factory UserBlockStatusModel.fromJson(Map<String, dynamic> json) {
    return UserBlockStatusModel(
      username: (json['username'] ?? '').toString(),
      blockedByMe: json['blockedByMe'] == true,
      blockedByUser: json['blockedByUser'] == true,
    );
  }
}
