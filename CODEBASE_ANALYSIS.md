# Chat App Codebase Search - Client-Side Firebase & Error Handling Analysis

## Executive Summary

This is a **Flutter-based chat application** with a Java/Spring Boot backend. The frontend implements Firebase Cloud Messaging (FCM), WebSocket real-time messaging, comprehensive error handling, and automatic token refresh logic.

---

## 1. PROJECT STRUCTURE

### Main Directory Layout
```
/mnt/d/code/chatapp/
├── chatapp/                    # Backend (Java/Kotlin Spring Boot)
│   └── src/main/
├── chatapp-flutter/            # Frontend (Dart/Flutter)
│   ├── lib/
│   ├── web/                    # Web build
│   ├── android/                # Android build
│   ├── ios/                    # iOS build
│   ├── pubspec.yaml            # Dependencies
│   └── .env.json               # Configuration
└── [Documentation files]
```

### Frontend Technologies
- **Framework**: Flutter (Dart)
- **HTTP Client**: `http` package v1.2.2
- **State Management**: Provider v6.1.2
- **Push Notifications**: Firebase Messaging v16.1.3
- **Firebase Core**: v4.6.0
- **Real-time Communication**: STOMP (WebSocket) via `stomp_dart_client` v3.0.1
- **Local Notifications**: `flutter_local_notifications` v21.0.0
- **Storage**: `shared_preferences` v2.3.2

---

## 2. CLIENT-SIDE FIREBASE SETUP

### Entry Point: `lib/main.dart`
**Location**: `/mnt/d/code/chatapp/chatapp-flutter/lib/main.dart`

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init only for native platforms (not web)
  if (!kIsWeb) {
    try {
      await initFirebase();
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }
  }

  // Rest of app setup...
}
```

**Key Points**:
- Graceful Firebase initialization with error handling
- Web builds skip Firebase (no service worker implementation)
- Continues app startup even if Firebase init fails

### Firebase Initialization: `lib/firebase_init_native.dart`
**Location**: `/mnt/d/code/chatapp/chatapp-flutter/lib/firebase_init_native.dart`

```dart
import 'package:firebase_core/firebase_core.dart';

Future<void> initFirebase() async {
  await Firebase.initializeApp();
}
```

**Architecture**:
- Uses Dart conditional imports: `firebase_init_native.dart` for Android/iOS, `firebase_init_stub.dart` for web
- Minimal bootstrap - relies on `google-services.json` and Firebase config

### Firebase Configuration Files

#### Android Configuration
**Location**: `/mnt/d/code/chatapp/chatapp-flutter/android/app/google-services.json`
- Contains Firebase project ID, API keys, and app credentials
- Referenced in `build.gradle` with Google Services plugin

**build.gradle Snippet**:
```gradle
plugins {
    id "com.google.gms.google-services"  // Firebase plugin
}

dependencies {
    implementation platform("com.google.firebase:firebase-bom:34.11.0")
}
```

#### Web Configuration
**Location**: `/mnt/d/code/chatapp/chatapp-flutter/web/`
- Standard Flutter web PWA setup (no Firebase web SDK initialization)
- `index.html` loads Flutter bootstrap only
- `manifest.json` contains PWA metadata

#### Environment Configuration
**Location**: `/mnt/d/code/chatapp/chatapp-flutter/.env.json`
```json
{
  "API_BASE_URL": "https://desktop-42ob98u.tail7d52f9.ts.net"
}
```

Fallbacks in `lib/core/app_constants.dart`:
- Web: `http://localhost:8080`
- Android Emulator: `http://10.0.2.2:8080` (special emulator network alias)
- Physical Android: `http://localhost:8080`

---

## 3. FCM TOKEN REGISTRATION

### Primary Implementation: `lib/services/firebase_messaging_service_native.dart`
**Location**: `/mnt/d/code/chatapp/chatapp-flutter/lib/services/firebase_messaging_service_native.dart`

#### Token Lifecycle Management
```dart
Future<void> _initializeAsync() async {
  try {
    print('FCM: Requesting permission...');
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('FCM: Permission granted');
  } catch (e) {
    print('FCM: Permission request failed (non-fatal): $e');
  }

  // Get initial token
  try {
    print('FCM: Getting token...');
    final token = await FirebaseMessaging.instance.getToken();
    print('FCM: Token = $token');
    if (token != null) {
      await _sendTokenToBackend(token);
    }
  } catch (e) {
    print('FCM: Failed to get token: $e');
  }

  // Listen for token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    print('FCM: Token refreshed');
    _sendTokenToBackend(newToken);
  });
}
```

**Key Patterns**:
1. Non-blocking initialization: uses `unawaited()` to avoid blocking app
2. Per-step error handling: continues even if permission fails
3. Token refresh listener: automatically registers when token refreshes
4. Print statements for debugging (not throwing)

#### Token Backend Registration
```dart
Future<void> _sendTokenToBackend(String token) async {
  try {
    print('FCM: Sending token to backend...');
    await apiClient.postJson(
      '/api/v1/users/fcm-token/',
      {'token': token},
    );
    print('FCM: Token registered successfully');
  } catch (e) {
    print('FCM: Failed to register FCM token: $e');
  }
}
```

**Endpoint**: `POST /api/v1/users/fcm-token/`
**Request Body**: `{"token": "..."}`
**Error Handling**: Silent failure (logged but not thrown)

### Message Handlers
```dart
void _handleForegroundMessage(RemoteMessage message) {
  final data = message.data;
  final type = data['type'] as String?;
  
  switch (type) {
    case 'message':
      // Show message notification
      break;
    case 'invitation':
    case 'group_invitation':
      // Show invitation notification
      break;
    case 'group_added':
    case 'group_member_removed':
      // Show group notification
      break;
  }
}

void _handleNotificationTap(RemoteMessage message) {
  final data = message.data;
  final payload = FcmNotificationPayload.fromData(data);
  _tapController.add(payload);
}
```

**Notification Stream**: Exposed to app via `tapStream` for navigation handling

---

## 4. NETWORK ERROR HANDLING PATTERNS

### API Client Core: `lib/services/api_client.dart`
**Location**: `/mnt/d/code/chatapp/chatapp-flutter/lib/services/api_client.dart`

#### Automatic Token Refresh with Retry

```dart
Future<http.Response> _sendWithRefresh(
  Future<http.Response> Function() execute, {
  required bool authRequired,
}) async {
  var response = await execute();

  // If 401 with bearer token error, try refreshing
  if (authRequired &&
      response.statusCode == 401 &&
      _isBearerTokenError(response) &&
      await _refreshToken()) {
    response = await execute();  // Retry after refresh
  }

  return response;
}

bool _isBearerTokenError(http.BaseResponse response) {
  final authHeader = response.headers['www-authenticate'] ?? '';
  return authHeader.toLowerCase().startsWith('bearer ');
}
```

**Pattern**: 
1. Execute request
2. Check for 401 + Bearer token error
3. Attempt token refresh
4. Retry request with new token
5. Return result

#### Token Refresh Implementation

```dart
Future<bool> _refreshToken() async {
  final refreshToken = await _tokenStorage.getRefreshToken();
  if (refreshToken == null || refreshToken.isEmpty) {
    return false;
  }

  final response = await _httpClient.post(
    _uri('/api/v1/users/token/refresh/'),
    headers: const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({'refresh': refreshToken}),
  );

  if (response.statusCode != 200) {
    await _tokenStorage.clear();  // Clear invalid tokens
    return false;
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final access = (body['access'] ?? '').toString();
  if (access.isEmpty) {
    await _tokenStorage.clear();
    return false;
  }

  // Save new access token, keep refresh token
  final currentRefresh = await _tokenStorage.getRefreshToken() ?? refreshToken;
  await _tokenStorage.saveTokens(
    TokenPairModel(access: access, refresh: currentRefresh),
  );
  return true;
}
```

**Failure Scenarios**:
- No refresh token → return false
- Refresh endpoint returns non-200 → clear tokens and return false
- Missing access token in response → clear tokens and return false

#### Multipart Upload with Retry

```dart
Future<http.StreamedResponse> postMultipart(
  String path, {
  required Map<String, String> fields,
  required Future<List<http.MultipartFile>> Function() buildFiles,
}) async {
  final request = http.MultipartRequest('POST', _uri(path));
  request.headers.addAll(await _buildHeaders(authRequired: true));
  request.fields.addAll(fields);
  request.files.addAll(await buildFiles());
  
  var streamed = await request.send();

  // Retry if 401 with token refresh
  if (streamed.statusCode == 401 &&
      _isBearerTokenError(streamed) &&
      await _refreshToken()) {
    final retry = http.MultipartRequest('POST', _uri(path));
    // Rebuild request with new token
    retry.headers.addAll(await _buildHeaders(authRequired: true));
    retry.fields.addAll(fields);
    retry.files.addAll(await buildFiles());
    streamed = await retry.send();
  }

  return streamed;
}
```

**Note**: Rebuilds files from callback on retry (avoids stream exhaustion)

### Authentication Service: `lib/services/auth_service.dart`
**Location**: `/mnt/d/code/chatapp/chatapp-flutter/lib/services/auth_service.dart`

```dart
Future<TokenPairModel> login(UserCredentials credentials) async {
  try {
    final response = await _apiClient.postJson(
      '/api/v1/users/token/',
      credentials.toJson(),
      authRequired: false,
    );

    if (response.statusCode != 200) {
      throw Exception(_buildAuthError('Login failed', response.body));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return TokenPairModel.fromJson(body);
  } catch (e) {
    throw Exception(_friendlyNetworkError(e));
  }
}

String _friendlyNetworkError(Object error) {
  final raw = error.toString();
  final lowered = raw.toLowerCase();

  // Detect network connectivity issues
  if (lowered.contains('xmlhttprequest error') ||
      lowered.contains('failed host lookup') ||
      lowered.contains('connection refused')) {
    return 'Khong ket noi duoc toi server. Kiem tra backend dang chay va URL API_BASE_URL.';
  }

  return raw;
}

String _buildAuthError(String prefix, String body) {
  try {
    final data = jsonDecode(body);
    if (data is Map<String, dynamic>) {
      final detail = data['detail'] ?? data['message'] ?? data['error'];
      if (detail != null && detail.toString().trim().isNotEmpty) {
        return '$prefix: ${detail.toString().trim()}';
      }
    }
  } catch (_) {
    // Fallback for non-JSON responses
  }

  final trimmed = body.trim();
  return trimmed.isEmpty ? prefix : '$prefix: $trimmed';
}
```

**Error Classification**:
- Network errors: Friendly Vietnamese message
- Authentication errors: Parse server response for details
- JSON parse errors: Return raw error message

---

## 5. RETRY LOGIC & RECONNECTION

### Real-Time Service: `lib/services/realtime_service.dart`
**Location**: `/mnt/d/code/chatapp/chatapp-flutter/lib/services/realtime_service.dart`

#### WebSocket Connection Management

```dart
class RealtimeService {
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isReconnecting = false;

  Future<void> connect() async {
    if (_isConnected || _isConnecting) {
      return;  // Prevent duplicate connection attempts
    }

    // Proactively refresh token before connecting
    await _apiClient.refreshAccessToken();

    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return;  // Abort if no valid token
    }

    _isConnecting = true;

    _client = StompClient(
      config: StompConfig.sockJS(
        url: '${AppConstants.baseUrl}/socket',
        reconnectDelay: Duration.zero,  // Disable built-in reconnect
        stompConnectHeaders: {
          'Authorization': 'Bearer $accessToken',
        },
        onConnect: (_) {
          _isConnected = true;
          _isConnecting = false;
          _isReconnecting = false;
          _subscribeInvitations();
          _subscribeInvitationReplies();
          // ... subscribe to other channels
          for (final roomId in _requestedRooms) {
            _subscribeRoom(roomId);
          }
        },
        onWebSocketError: (_) {
          _isConnected = false;
          _isConnecting = false;
          // Schedule manual reconnect with fresh token
          Future<void>.delayed(const Duration(seconds: 4))
              .then((_) => reconnectWithFreshToken());
        },
        onStompError: (frame) {
          _isConnected = false;
          _isConnecting = false;
          // Always reconnect regardless of error type
          Future<void>.delayed(const Duration(seconds: 4))
              .then((_) => reconnectWithFreshToken());
        },
        onDisconnect: (_) {
          _isConnected = false;
        },
      ),
    );

    _client!.activate();
  }

  Future<void> reconnectWithFreshToken() async {
    if (_isReconnecting) return;  // Prevent duplicate reconnect attempts
    _isReconnecting = true;
    
    _client?.deactivate();
    _client = null;
    _isConnected = false;
    _isConnecting = false;
    
    _isReconnecting = false;
    await connect();  // Will refresh token and create new connection
  }
}
```

**Reconnection Strategy**:
1. **Disabled built-in reconnect**: `reconnectDelay: Duration.zero`
2. **Manual reconnection**: Custom delay and token refresh
3. **Token refresh before connect**: Ensures fresh credentials
4. **4-second backoff**: Between error and reconnection attempt
5. **Guard flags**: `_isConnecting` and `_isReconnecting` prevent race conditions

#### Subscription Management

```dart
Stream<MessageReceiveModel> roomMessageStream(int roomId) {
  _requestedRooms.add(roomId);

  final controller = _roomControllers.putIfAbsent(
    roomId,
    () => StreamController<MessageReceiveModel>.broadcast(),
  );

  // Subscribe immediately if already connected, otherwise will subscribe on reconnect
  if (_isConnected) {
    _subscribeRoom(roomId);
  }

  return controller.stream;
}
```

**Pattern**: Tracks requested rooms; resubscribes to all after reconnection

---

## 6. PROVIDER-LEVEL ERROR HANDLING

### Authentication Provider: `lib/providers/auth_provider.dart`
**Location**: `/mnt/d/code/chatapp/chatapp-flutter/lib/providers/auth_provider.dart`

```dart
class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _error;

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
      await _firebaseMessagingService?.initialize();
      return true;
    } catch (e) {
      _error = e.toString();  // Expose error to UI
      _isAuthenticated = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
}
```

**State Management Pattern**:
- `_isLoading`: Indicate ongoing operation
- `_error`: Store error message for UI
- `notifyListeners()`: Trigger rebuild on state change
- `finally`: Always reset loading state

### Chat Provider: `lib/providers/chat_provider.dart`
```dart
Future<void> loadMessages() async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    final loaded = await _messageService.listMessages(roomId: _roomId);
    _messages = _sortBySentOn(loaded);
    await _loadPersistedTranslations();
  } catch (e) {
    _error = e.toString();
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

---

## 7. LOCAL NOTIFICATIONS

### Setup: `lib/services/local_notification_service.dart`
**Location**: `/mnt/d/code/chatapp/chatapp-flutter/lib/services/local_notification_service.dart`

```dart
class LocalNotificationService {
  static const AndroidNotificationChannel _messagesChannel =
      AndroidNotificationChannel(
    'chat_messages',
    'Chat messages',
    importance: Importance.max,
  );

  Future<void> requestPermissions() async {
    if (kIsWeb) return;  // Skip on web

    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationPermission();
  }
}
```

**Platform Support**:
- Android: Notification channels
- iOS/macOS: Darwin settings
- Linux: Linux-specific settings
- Web: Skipped

---

## 8. FILE LOCATIONS & REFERENCES

### Key Files Summary

| File | Purpose | Type |
|------|---------|------|
| `/mnt/d/code/chatapp/chatapp-flutter/lib/main.dart` | App entry point, Firebase init | Dart |
| `/mnt/d/code/chatapp/chatapp-flutter/lib/firebase_init_native.dart` | Firebase initialization | Dart |
| `/mnt/d/code/chatapp/chatapp-flutter/lib/firebase_init_stub.dart` | Web fallback (no-op) | Dart |
| `/mnt/d/code/chatapp/chatapp-flutter/lib/services/firebase_messaging_service_native.dart` | FCM implementation | Dart |
| `/mnt/d/code/chatapp/chatapp-flutter/lib/services/firebase_messaging_service_stub.dart` | Web fallback | Dart |
| `/mnt/d/code/chatapp/chatapp-flutter/lib/services/api_client.dart` | HTTP client + token refresh | Dart |
| `/mnt/d/code/chatapp/chatapp-flutter/lib/services/auth_service.dart` | Auth + error translation | Dart |
| `/mnt/d/code/chatapp/chatapp-flutter/lib/services/realtime_service.dart` | WebSocket + reconnection | Dart |
| `/mnt/d/code/chatapp/chatapp-flutter/lib/providers/auth_provider.dart` | Auth state + error UI | Dart |
| `/mnt/d/code/chatapp/chatapp-flutter/lib/providers/chat_provider.dart` | Chat state + error handling | Dart |
| `/mnt/d/code/chatapp/chatapp-flutter/android/app/google-services.json` | Android Firebase config | JSON |
| `/mnt/d/code/chatapp/chatapp-flutter/android/app/build.gradle` | Gradle + Firebase plugin | Gradle |
| `/mnt/d/code/chatapp/chatapp-flutter/pubspec.yaml` | Dependencies | YAML |
| `/mnt/d/code/chatapp/chatapp-flutter/.env.json` | API base URL | JSON |
| `/mnt/d/code/chatapp/chatapp-flutter/lib/core/app_constants.dart` | Config + defaults | Dart |
| `/mnt/d/code/chatapp/chatapp-flutter/web/index.html` | Web entry point | HTML |
| `/mnt/d/code/chatapp/chatapp-flutter/web/manifest.json` | PWA manifest | JSON |

---

## 9. ERROR HANDLING PATTERNS SUMMARY

### Pattern 1: Silent Failures (Logging Only)
```dart
// FCM token registration - doesn't break app if fails
Future<void> _sendTokenToBackend(String token) async {
  try {
    await apiClient.postJson('/api/v1/users/fcm-token/', {'token': token});
    print('FCM: Token registered successfully');
  } catch (e) {
    print('FCM: Failed to register FCM token: $e');  // Log but don't throw
  }
}
```

### Pattern 2: Graceful Degradation
```dart
// Firebase init fails, app continues
if (!kIsWeb) {
  try {
    await initFirebase();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    // App continues without push notifications
  }
}
```

### Pattern 3: Automatic Retry with Token Refresh
```dart
// HTTP client retries with fresh token on 401
Future<http.Response> _sendWithRefresh(
  Future<http.Response> Function() execute,
) async {
  var response = await execute();
  
  if (response.statusCode == 401 && 
      _isBearerTokenError(response) &&
      await _refreshToken()) {
    response = await execute();  // Retry
  }
  
  return response;
}
```

### Pattern 4: Exponential Backoff with Token Refresh
```dart
// WebSocket reconnection with 4-second delay and token refresh
onWebSocketError: (_) {
  _isConnected = false;
  Future<void>.delayed(const Duration(seconds: 4))
      .then((_) => reconnectWithFreshToken());
}
```

### Pattern 5: Error Translation for UI
```dart
// Convert network errors to user-friendly messages
String _friendlyNetworkError(Object error) {
  final lowered = error.toString().toLowerCase();
  
  if (lowered.contains('failed host lookup') ||
      lowered.contains('connection refused')) {
    return 'Khong ket noi duoc toi server...';  // Vietnamese
  }
  
  return error.toString();
}
```

### Pattern 6: Try-Catch-Finally for State Management
```dart
Future<bool> login({required String username, required String password}) async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    // Attempt login
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
```

---

## 10. WEB PLATFORM NOTES

### Current Web Setup
- Standard Flutter web build (no service worker)
- No FCM on web (Firebase Web SDK not integrated)
- Uses HTTP client directly to backend
- Environment detection via `kIsWeb` constant

### Web Fallback Strategy
```dart
// Conditional imports
import 'firebase_init_stub.dart'
    if (dart.library.io) 'firebase_init_native.dart';

// Runtime checks
if (!kIsWeb) {
  await initFirebase();
}

if (kIsWeb) {
  return;  // Skip local notifications
}
```

**Web Limitations**:
- ❌ No Firebase Cloud Messaging
- ❌ No local notifications
- ✅ Regular HTTP requests with token refresh
- ✅ WebSocket for real-time messaging

---

## 11. KEY FINDINGS

### Architecture Strengths
1. **Separation of Concerns**: Services, providers, models cleanly separated
2. **Non-blocking Operations**: Firebase init won't crash app
3. **Graceful Degradation**: Each component has fallback behavior
4. **Token Refresh Strategy**: Automatic retry with fresh credentials
5. **Real-time Resilience**: Manual reconnection with exponential backoff
6. **Error Localization**: Friendly error messages for users

### Error Handling Flow
```
Network Request
    ↓
[Get Response]
    ↓
[Is 401 Bearer Error?] → YES → [Refresh Token] → [Retry]
                    ↓ NO
                 [Return]
                    ↓
    [Consume in Provider]
        ↓
    [Handle Exception]
        ↓
    [Update UI State]
```

### Token Management
```
App Start
    ↓
[Load Stored Token]
    ↓
[WebSocket Connect] → [Proactive Token Refresh]
    ↓
[HTTP Request] → [401?] → [Refresh & Retry]
    ↓
[Token Expires] → [WebSocket Error] → [Reconnect + Refresh]
```

### Configuration Resolution
```
API_BASE_URL Resolution Order:
1. Environment variable (API_BASE_URL)
2. Build flag (--dart-define=API_BASE_URL=...)
3. Platform-specific default:
   - Android Emulator: 10.0.2.2:8080
   - Android Device: localhost:8080
   - iOS/Mac: localhost:8080
   - Web: localhost:8080
```

---

## 12. DEPENDENCIES GRAPH

```
main.dart
├── firebase_core → Firebase.initializeApp()
├── firebase_messaging → FCM registration & handlers
├── flutter_local_notifications → Local notification channels
├── http → HTTP client for API calls
├── provider → State management & error exposure
├── stomp_dart_client → WebSocket connection & reconnection
├── shared_preferences → Token storage
└── Various services
    ├── ApiClient → HTTP with retry logic
    ├── AuthService → Login with error translation
    ├── RealtimeService → WebSocket + reconnection
    ├── FirebaseMessagingService → FCM + token registration
    └── LocalNotificationService → Notification display
```

---

## 13. SUMMARY TABLE

| Aspect | Implementation | File |
|--------|---|---|
| **Firebase Init** | Non-blocking with try-catch | main.dart |
| **FCM Tokens** | Auto-register + refresh listener | firebase_messaging_service_native.dart |
| **HTTP Retry** | Auto-refresh + single retry | api_client.dart |
| **Auth Errors** | Parse response + friendly messages | auth_service.dart |
| **Real-time Resilience** | Manual reconnect + 4s backoff | realtime_service.dart |
| **State Errors** | Expose to UI via provider | auth_provider.dart, chat_provider.dart |
| **Network Errors** | Detect + localize messages | auth_service.dart |
| **Token Storage** | SharedPreferences | token_storage_service.dart |
| **Web Platform** | Conditional imports + skips | main.dart, firebase_init_stub.dart |

---

## Conclusion

This is a **production-ready error handling implementation** combining:
- Automatic token refresh with single retry
- Manual WebSocket reconnection with exponential backoff  
- Firebase FCM integration with non-blocking initialization
- User-friendly error messaging
- Platform-specific behavior (web vs native)
- State-driven UI updates via Provider

The architecture prioritizes **resilience over failure** - the app continues operating even if individual components fail (Firebase, FCM, initial connections).

