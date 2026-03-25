import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_credentials.dart';
import '../models/user_with_avatar_model.dart';
import '../services/auth_service.dart';
import '../services/realtime_service.dart';
import '../services/token_storage_service.dart';
import '../services/user_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthService authService,
    required RealtimeService realtimeService,
    required TokenStorageService tokenStorage,
    required UserService userService,
  })  : _authService = authService,
        _realtimeService = realtimeService,
        _tokenStorage = tokenStorage,
        _userService = userService;

  final AuthService _authService;
  final RealtimeService _realtimeService;
  final TokenStorageService _tokenStorage;
  final UserService _userService;

  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _username;
  UserWithAvatarModel? _profile;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  UserWithAvatarModel? get profile => _profile;
  String get displayName => _profile?.displayLabel ?? (_username ?? '');
  String? get avatarUrl => _profile?.avatar?.source;
  String? get error => _error;

  Future<void> bootstrap() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _tokenStorage.getAccessToken();
      _username = await _tokenStorage.getUsername();
      _isAuthenticated = token != null && token.isNotEmpty;
      if (_isAuthenticated) {
        await _realtimeService.connect();
        await _loadMyProfile();
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tokenPair = await _authService.login(
        UserCredentials(username: username, password: password),
      );

      await _tokenStorage.saveTokens(tokenPair);
      await _tokenStorage.saveUsername(username);
      await _realtimeService.connect();
      _username = username;
      await _loadMyProfile();
      _isAuthenticated = true;
      return true;
    } catch (e) {
      _error = e.toString();
      _isAuthenticated = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.register(
        UserCredentials(username: username, password: password),
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    _realtimeService.disconnect();
    await _tokenStorage.clear();
    _isAuthenticated = false;
    _username = null;
    _profile = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateMyProfile({
    required String displayName,
    XFile? avatar,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final updated = await _userService.updateMyProfile(
        displayName: displayName,
        avatar: avatar,
      );

      _profile = updated;
      _username = updated.username ?? _username;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void applyProfileRealtime(UserWithAvatarModel profile) {
    final eventUsername = profile.username;
    if (eventUsername == null || eventUsername.isEmpty || eventUsername != _username) {
      return;
    }

    _profile = profile;
    notifyListeners();
  }

  Future<void> _loadMyProfile() async {
    try {
      final profile = await _userService.getMyProfile();
      _profile = profile;
      _username = profile.username ?? _username;
    } catch (_) {
      // Keep app usable even if profile endpoint is temporarily unavailable.
    }
  }
}
