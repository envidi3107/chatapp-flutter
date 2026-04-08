/// Agora configuration constants
/// 
/// To get your Agora App ID:
/// 1. Go to https://console.agora.io/
/// 2. Create an account and create a new project
/// 3. Copy your App ID and replace <YOUR_APP_ID_HERE> with it
class AgoraConfig {
  /// Your Agora App ID
  /// Replace this with your actual Agora App ID from https://console.agora.io/
  static const String appId = 'e87bb2aeeb484976a55d554766cd705c';

  /// Token for authentication (optional for testing)
  /// For production, you should generate tokens from your server
  /// Leave null for testing with security off
  static const String? token = null;

  /// Default channel name for testing
  static const String defaultChannelName = 'flutter-test-channel';

  /// Default user ID (0 = auto-assigned by Agora)
  static const int defaultUid = 0;
}
