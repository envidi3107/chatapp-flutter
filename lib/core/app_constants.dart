import 'package:flutter/foundation.dart';

class AppConstants {
  static const String _baseUrlFromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_baseUrlFromEnv.isNotEmpty) {
      return _baseUrlFromEnv;
    }

    // Web and desktop/simulator targets should call localhost directly.
    if (kIsWeb) {
      return 'http://localhost:8080';
    }

    // Android emulator cannot access host localhost directly.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }

    return 'http://localhost:8080';
  }

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String usernameKey = 'username';
}
