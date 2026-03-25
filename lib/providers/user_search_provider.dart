import 'package:flutter/foundation.dart';

import '../models/user_with_avatar_model.dart';
import '../services/user_service.dart';

class UserSearchProvider extends ChangeNotifier {
  UserSearchProvider(this._userService);

  final UserService _userService;

  bool _isLoading = false;
  String? _error;
  List<UserWithAvatarModel> _users = const [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<UserWithAvatarModel> get users => _users;

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _users = const [];
      _error = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _users = await _userService.searchUsers(query: query);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void applyUserProfileUpdate(UserWithAvatarModel profile) {
    final username = (profile.username ?? '').trim();
    if (username.isEmpty || _users.isEmpty) {
      return;
    }

    var changed = false;
    final next = _users.map((item) {
      if ((item.username ?? '').trim() != username) {
        return item;
      }

      changed = true;
      return profile;
    }).toList();

    if (!changed) {
      return;
    }

    _users = next;
    notifyListeners();
  }
}
