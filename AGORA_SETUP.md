# Agora Video Call Integration Guide

This document explains the video call feature integration using Agora RTC Engine in your Flutter chat application.

## What's Been Created

### 1. **Agora Configuration** (`lib/core/agora_config.dart`)

- Contains your Agora App ID configuration
- Stores default channel and user settings
- Replace `<YOUR_APP_ID_HERE>` with your actual App ID from https://console.agora.io/

### 2. **Agora Service** (`lib/services/agora_service.dart`)

- Core service for managing Agora RTC Engine operations
- Handles:
  - Engine initialization
  - Channel joining/leaving
  - Audio mute toggle
  - Camera on/off toggle
  - Camera switching (front/back)
  - Event handling (user join, offline, video frames)
  - Detailed logging

### 3. **Video Call Provider** (`lib/providers/video_call_provider.dart`)

- State management for video calls using ChangeNotifier
- Provides:
  - Call initialization
  - User state management (remote users list)
  - Mute/camera controls
  - Status messages
  - Integration with Agora service

### 4. **Video Call Screens**

- **Join Video Call Screen** (`lib/screens/chat/join_video_call_screen.dart`)
  - Channel name input form
  - Permission request handling (camera + microphone)
  - Configuration guidance for users
  - Join button with loading state

- **Video Call Screen** (`lib/screens/chat/video_call_screen.dart`)
  - Video grid layout (supports 1-4 participants)
  - Responsive layout based on participant count
  - Toolbar with controls:
    - Mute/unmute audio (mic icon)
    - Switch camera front/back (swap camera icon)
    - Toggle video on/off (videocam icon)
    - End call (red phone icon)
    - Info panel (logs)
  - Real-time status messages
  - Participant counter

### 5. **Dependencies Added** (`pubspec.yaml`)

- `agora_rtc_engine: ^6.2.0` - Agora SDK for Flutter
- `permission_handler: ^11.4.0` - Permission management

### 6. **Android Configuration** (`android/app/src/main/AndroidManifest.xml`)

- Added `android.permission.CAMERA` permission
- Already had `android.permission.RECORD_AUDIO` permission

## Setup Instructions

### Step 1: Get Your Agora App ID

1. Go to https://console.agora.io/
2. Sign up or log in to your account
3. Go to **Projects** tab
4. Click **Create** to create a new project
5. Fill in project name and use case
6. Copy your **App ID**

### Step 2: Configure App ID

1. Open `lib/core/agora_config.dart`
2. Replace `<YOUR_APP_ID_HERE>` with your actual Agora App ID:

```dart
class AgoraConfig {
  static const String appId = 'YOUR_ACTUAL_APP_ID_HERE';
  // ... rest of config
}
```

### Step 3: Update Dependencies

Run this command in your Flutter project root:

```bash
flutter pub get
```

### Step 4: Install Agora SDK (iOS only)

If you're developing for iOS, update your iOS build configuration:

```bash
cd ios
pod install
cd ..
```

### Step 5: Configure Permissions (Optional)

#### Android (Already Done)

- `android.permission.CAMERA` - Already added
- `android.permission.RECORD_AUDIO` - Already added

#### iOS (If building for iOS)

Add these to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to enable video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access for video calls and audio communication</string>
```

## How to Use

### Launching Video Call from Your App

Add a button in your chat screen or home screen to launch video calls:

```dart
import 'package:flutter/material.dart';
import 'screens/chat/join_video_call_screen.dart';

// In your widget:
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JoinVideoCallScreen(),
      ),
    );
  },
  child: const Text('Start Video Call'),
)
```

### Video Call Flow

1. **User clicks "Start Video Call"** → Navigates to `JoinVideoCallScreen`
2. **User enters channel name** → Name for the call group
3. **User clicks "Join"** → App requests permissions
4. **Permissions granted** → `VideoCallScreen` initializes Agora engine
5. **User joins call** → Video grid displayed with local video and any remote participants
6. **Controls available**:
   - Mute/unmute microphone
   - Turn camera on/off
   - Switch camera (front/back)
   - End call
7. **Other users join same channel** → Their videos appear in grid automatically
8. **User ends call** → Leaves channel and returns to previous screen

## Key Features

### Audio/Video Controls

- **Mute Button** (mic icon)
  - Mutes/unmutes your microphone
  - Visual indicator shows current state
  - White button = unmuted, Blue button = muted

- **Camera Toggle** (videocam icon)
  - Turns camera on/off
  - White= camera on, Blue = camera off

- **Switch Camera** (swap camera icon)
  - Toggles between front and back camera

- **End Call** (red phone icon)
  - Leaves channel and ends call
  - Returns to previous screen

### Video Layout

The app automatically arranges video based on participant count:

- **1 person**: Full screen video
- **2 people**: Split screen (top/bottom)
- **3 people**: 2 on top, 1 on bottom
- **4 people**: 2x2 grid

### Status Messages

- Real-time status updates shown at top of screen
- Green background for success messages
- Red background for error messages
- Info panel shows detailed event logs (tap info icon to toggle)

## Testing Video Calls

### Single Device Testing

1. Run the app on your device/emulator
2. Open the app in multiple windows/browsers if using web
3. Enter same channel name in both
4. Click Join in both
5. Both should appear in each other's video grid

### Multiple Device Testing

1. Install app on multiple devices
2. Use same channel name on all devices
3. Click Join on all devices
4. All devices should see each other's video

## Security Notes

### For Production

1. **Token Generation**: Currently using `token: null` (security off)
   - For production, generate tokens from your backend server
   - Update `AgoraConfig.token` with server-generated tokens
   - Implement token refresh mechanism

2. **App ID Protection**:
   - Never commit actual App ID to public repositories
   - Use environment variables or secure configuration
   - Example update for `agora_config.dart`:

```dart
class AgoraConfig {
  static const String appId = String.fromEnvironment('AGORA_APP_ID');
  // Generate tokens from your backend
  static String? getToken(String channelName, int uid) {
    // Call your backend to get a token
    return null; // Placeholder
  }
}
```

3. **Permissions**:
   - App always requests permissions at runtime
   - Users can grant/deny permissions
   - App gracefully handles permission denials

## Troubleshooting

### Issue: "App ID not configured" message

**Solution**:

- Check `lib/core/agora_config.dart`
- Make sure App ID is set and not the placeholder string

### Issue: Permission denied for camera/microphone

**Solution**:

- Grant permissions when prompted
- Go to app settings and enable camera/microphone permissions
- Restart the app if permissions still don't work

### Issue: Cannot see remote user's video

**Solution**:

- Ensure both devices are using the same channel name
- Check internet connection on both devices
- Verify Agora servers are accessible in your region
- Make sure remote user's camera is turned on

### Issue: App crashes on initiation

**Solution**:

- Update your `flutter pub get` to get latest dependencies
- Check if your Android targetSdkVersion is 31 or higher
- For iOS, run `cd ios && pod install && cd ..`

### Issue: Audio/video not working

**Solution**:

- Check device audio settings
- Ensure microphone is not muted in system settings
- Try switching camera to refresh connection
- Restart the app

## Architecture Overview

```
┌─────────────────────────────────┐
│   JoinVideoCallScreen           │
│  (Channel name input & perms)   │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│   VideoCallProvider             │
│  (State management)             │
├─────────────────────────────────┤
│ - isInitialized                 │
│ - remoteUsers list              │
│ - isMuted state                 │
│ - isCameraOff state             │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│   AgoraService                  │
│  (Low-level Agora operations)   │
├─────────────────────────────────┤
│ - initAgora()                   │
│ - Event handlers                │
│ - toggleMute()                  │
│ - switchCamera()                │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│   AgoraRtcEngine (SDK)          │
│   (Native Agora implementation) │
└─────────────────────────────────┘
```

## Useful Resources

- **Agora Documentation**: https://docs.agora.io/en/Video/landing-page?platform=Flutter
- **Flutter Agora SDK**: https://pub.dev/packages/agora_rtc_engine
- **Permission Handler**: https://pub.dev/packages/permission_handler
- **Agora Console**: https://console.agora.io/

## Next Steps

### To enhance video calling, consider adding:

1. **Call Invitations**: Send invitations before joining
2. **Screen Sharing**: Share screen during calls
3. **Chat During Call**: Text chat alongside video
4. **Call Recording**: Record video calls
5. **Custom Extensions**: Beauty effects, noise suppression
6. **Custom Layouts**: Pinned speaker view, gallery view
7. **Call History**: Track previous calls
8. **Call Scheduling**: Schedule calls for later

## Support

For issues or questions:

1. Check Agora documentation: https://docs.agora.io/
2. Review the troubleshooting section above
3. Check your internet connection
4. Verify App ID is correctly configured
5. Check device permissions

---

**Happy video calling! 📹**
