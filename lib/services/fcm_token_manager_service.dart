import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

class FcmTokenManagerService {
  FcmTokenManagerService({
    required this.apiClient,
  });

  final ApiClient apiClient;

  // Configuration constants
  static const int _maxRetries = 5;
  static const Duration _initialBackoff = Duration(seconds: 2);
  static const double _backoffMultiplier = 1.5;
  static const Duration _maxBackoff = Duration(minutes: 1);

  int _retryCount = 0;
  Timer? _retryTimer;
  String? _lastToken;
  DateTime? _lastAttemptTime;

  Future<bool> registerTokenWithRetry(String token) async {
    if (token.isEmpty) {
      debugPrint('[FCM] Empty token provided, skipping registration');
      return false;
    }

    _lastToken = token;
    _lastAttemptTime = DateTime.now();

    try {
      return await _attemptRegistration(token);
    } catch (e) {
      debugPrint('[FCM] Initial registration failed: $e');
      _scheduleRetry(token);
      return false;
    }
  }

  Future<bool> _attemptRegistration(String token) async {
    debugPrint(
      '[FCM] Attempting to register token (attempt ${_retryCount + 1}/$_maxRetries)',
    );

    final response = await apiClient.postJson(
      '/api/v1/users/fcm-token/',
      {'token': token},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      debugPrint('[FCM] Token registered successfully');
      _resetRetryState();
      return true;
    }

    debugPrint(
      '[FCM] Token registration returned ${response.statusCode}, will retry',
    );
    throw Exception('FCM token registration failed: ${response.statusCode}');
  }

  void _scheduleRetry(String token) {
    if (_retryCount >= _maxRetries) {
      debugPrint(
          '[FCM] Max retries reached ($_maxRetries). Stopping retry attempts.');
      _resetRetryState();
      return;
    }

    _retryCount++;
    final backoff = _calculateBackoff(_retryCount);

    debugPrint('[FCM] Scheduling retry in ${backoff.inSeconds} seconds '
        '(attempt $_retryCount/$_maxRetries)');

    _retryTimer?.cancel();
    _retryTimer = Timer(backoff, () {
      _performRetry(token);
    });
  }

  /// Performs the actual retry attempt
  Future<void> _performRetry(String token) async {
    try {
      final success = await _attemptRegistration(token);
      if (!success) {
        _scheduleRetry(token);
      }
    } catch (_) {
      _scheduleRetry(token);
    }
  }

  Duration _calculateBackoff(int retryAttempt) {
    double exponentialMultiplier = _backoffMultiplier;
    for (int i = 1; i < retryAttempt; i++) {
      exponentialMultiplier *= _backoffMultiplier;
    }

    final backoffMilliseconds =
        (_initialBackoff.inMilliseconds * exponentialMultiplier).toInt();

    final backoffDuration = Duration(milliseconds: backoffMilliseconds);
    return backoffDuration > _maxBackoff ? _maxBackoff : backoffDuration;
  }

  void _resetRetryState() {
    _retryCount = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  Future<void> retryNow() async {
    if (_lastToken == null) {
      debugPrint('[FCM] No token to retry');
      return;
    }

    _retryTimer?.cancel();
    _resetRetryState();
    await registerTokenWithRetry(_lastToken!);
  }

  String getRetryState() {
    final tokenPreview = _lastToken == null
        ? 'None'
        : _lastToken!
            .substring(0, _lastToken!.length < 10 ? _lastToken!.length : 10);

    return 'Retry Count: $_retryCount/$_maxRetries, '
        'Last Attempt: ${_lastAttemptTime ?? "Never"}, '
        'Last Token: $tokenPreview...';
  }

  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryCount = 0;
  }
}
