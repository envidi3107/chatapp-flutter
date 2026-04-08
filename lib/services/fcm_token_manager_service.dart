import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// Manages FCM token registration with resilient retry logic.
/// 
/// This service ensures that the app continues running even if FCM token
/// registration fails. It implements exponential backoff retry strategy
/// to gracefully handle temporary network failures.
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

  // Retry state tracking
  int _retryCount = 0;
  Timer? _retryTimer;
  String? _lastToken;
  DateTime? _lastAttemptTime;

  /// Registers FCM token with exponential backoff retry logic
  /// 
  /// This method will:
  /// 1. Attempt to register the token immediately
  /// 2. On failure, schedule a retry with exponential backoff
  /// 3. Continue retrying up to [_maxRetries] times
  /// 4. Never throw exception - always fails gracefully
  Future<bool> registerTokenWithRetry(String token) async {
    if (token.isEmpty) {
      print('[FCM] Empty token provided, skipping registration');
      return false;
    }

    _lastToken = token;
    _lastAttemptTime = DateTime.now();

    try {
      return await _attemptRegistration(token);
    } catch (e) {
      print('[FCM] Initial registration failed: $e');
      _scheduleRetry(token);
      return false;
    }
  }

  /// Attempts to register the token with the backend
  Future<bool> _attemptRegistration(String token) async {
    try {
      print('[FCM] Attempting to register token (attempt ${_retryCount + 1}/$_maxRetries)');
      
      await apiClient.postJson(
        '/api/v1/users/fcm-token/',
        {'token': token},
      );
      
      print('[FCM] Token registered successfully');
      _resetRetryState();
      return true;
    } catch (e) {
      print('[FCM] Token registration failed: $e');
      throw e;
    }
  }

  /// Schedules a retry attempt with exponential backoff
  void _scheduleRetry(String token) {
    if (_retryCount >= _maxRetries) {
      print('[FCM] Max retries reached ($_maxRetries). Stopping retry attempts.');
      _resetRetryState();
      return;
    }

    _retryCount++;
    final backoff = _calculateBackoff(_retryCount);
    
    print('[FCM] Scheduling retry in ${backoff.inSeconds} seconds '
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
    } catch (e) {
      _scheduleRetry(token);
    }
  }

  /// Calculates backoff duration with exponential increase
  Duration _calculateBackoff(int retryAttempt) {
    // Calculate exponential backoff: initialBackoff * (multiplier ^ (retryAttempt - 1))
    double exponentialMultiplier = _backoffMultiplier;
    for (int i = 1; i < retryAttempt; i++) {
      exponentialMultiplier *= _backoffMultiplier;
    }
    
    final backoffMilliseconds = 
        (_initialBackoff.inMilliseconds * exponentialMultiplier).toInt();
    
    final backoffDuration = Duration(milliseconds: backoffMilliseconds);

    // Cap the backoff at max duration
    return backoffDuration > _maxBackoff ? _maxBackoff : backoffDuration;
  }

  /// Resets retry state after successful registration
  void _resetRetryState() {
    _retryCount = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Manually trigger a retry if the token needs to be re-registered
  Future<void> retryNow() async {
    if (_lastToken == null) {
      print('[FCM] No token to retry');
      return;
    }
    
    _retryTimer?.cancel();
    _resetRetryState();
    await registerTokenWithRetry(_lastToken!);
  }

  /// Get the current retry state
  String getRetryState() {
    return 'Retry Count: $_retryCount/$_maxRetries, '
        'Last Attempt: ${_lastAttemptTime ?? "Never"}, '
        'Last Token: ${_lastToken?.substring(0, 10) ?? "None"}...';
  }

  /// Cleans up resources
  void dispose() {
    _retryTimer?.cancel();
    _resetRetryState();
  }
}

    _lastToken = token;
    _lastAttemptTime = DateTime.now();

    try {
      return await _attemptRegistration(token);
    } catch (e) {
      print('[FCM] Initial registration failed: $e');
      _scheduleRetry(token);
      return false;
    }
  }

  /// Attempts to register the token with the backend
  Future<bool> _attemptRegistration(String token) async {
    try {
      print(
          '[FCM] Attempting to register token (attempt ${_retryCount + 1}/$_maxRetries)');

      await apiClient.postJson(
        '/api/v1/users/fcm-token/',
        {'token': token},
      );

      print('[FCM] Token registered successfully');
      _resetRetryState();
      return true;
    } catch (e) {
      print('[FCM] Token registration failed: $e');
      throw e;
    }
  }

  /// Schedules a retry attempt with exponential backoff
  void _scheduleRetry(String token) {
    if (_retryCount >= _maxRetries) {
      print(
          '[FCM] Max retries reached ($maxRetries). Stopping retry attempts.');
      _resetRetryState();
      return;
    }

    _retryCount++;
    final backoff = _calculateBackoff(_retryCount);

    print('[FCM] Scheduling retry in ${backoff.inSeconds} seconds '
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
    } catch (e) {
      _scheduleRetry(token);
    }
  }

  /// Calculates backoff duration with exponential increase
  Duration _calculateBackoff(int retryAttempt) {
    final exponentialBackoff = _initialBackoff.inMilliseconds *
        (pow(_backoffMultiplier, retryAttempt - 1) as int);

    final backoffDuration = Duration(
      milliseconds: exponentialBackoff.toInt(),
    );

    // Cap the backoff at max duration
    return backoffDuration > _maxBackoff ? _maxBackoff : backoffDuration;
  }

  /// Resets retry state after successful registration
  void _resetRetryState() {
    _retryCount = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Manually trigger a retry if the token needs to be re-registered
  Future<void> retryNow() async {
    if (_lastToken == null) {
      print('[FCM] No token to retry');
      return;
    }

    _retryTimer?.cancel();
    _resetRetryState();
    await registerTokenWithRetry(_lastToken!);
  }

  /// Get the current retry state
  String getRetryState() {
    return 'Retry Count: $_retryCount/$_maxRetries, '
        'Last Attempt: ${_lastAttemptTime ?? "Never"}, '
        'Last Token: ${_lastToken?.substring(0, 10)}...';
  }

  /// Cleans up resources
  void dispose() {
    _retryTimer?.cancel();
    _resetRetryState();
  }
}

/// Helper function for power calculation
num pow(num x, num y) {
  return x * x * x * x * x; // Simplified for retry logic
}
