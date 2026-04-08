/// Example Integration: How to add Video Call button to your Chat Screen
/// 
/// This file shows how to integrate the video call feature into your existing
/// chat application. You can adapt this example to fit your UI design.

import 'package:flutter/material.dart';

// Example 1: Add Video Call button to AppBar
// ============================================
class ChatScreenExample extends StatelessWidget {
  const ChatScreenExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Room'),
        actions: [
          // Add this button to your AppBar to start video calls
          IconButton(
            icon: const Icon(Icons.video_call),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const JoinVideoCallScreen(),
                ),
              );
            },
            tooltip: 'Start Video Call',
          ),
          // ... other actions
        ],
      ),
      body: const Center(
        child: Text('Chat messages here'),
      ),
    );
  }
}

// Example 2: Add Video Call button as a floating button
// ======================================================
class ChatScreenWithFab extends StatelessWidget {
  const ChatScreenWithFab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Room'),
      ),
      body: const Center(
        child: Text('Chat messages here'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const JoinVideoCallScreen(),
            ),
          );
        },
        tooltip: 'Start Video Call',
        child: const Icon(Icons.video_call),
      ),
    );
  }
}

// Example 3: Add Video Call button to custom action menu
// =======================================================
class ChatScreenWithActionMenu extends StatelessWidget {
  const ChatScreenWithActionMenu({Key? key}) : super(key: key);

  void _showCallOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Call Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.video_call, color: Colors.blue),
              title: const Text('Start Video Call'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const JoinVideoCallScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text('Start Audio Call'),
              onTap: () {
                Navigator.pop(context);
                // Add audio call implementation here
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Room'),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.video_call),
                    SizedBox(width: 8),
                    Text('Video Call'),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JoinVideoCallScreen(),
                    ),
                  );
                },
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.info),
                    SizedBox(width: 8),
                    Text('Room Info'),
                  ],
                ),
                onTap: () {
                  // Handle room info
                },
              ),
            ],
          ),
        ],
      ),
      body: const Center(
        child: Text('Chat messages here'),
      ),
    );
  }
}

// Example 4: Quick call button in message list
// =============================================
class ChatMessageWithCallButton extends StatelessWidget {
  final String message;
  final String sender;

  const ChatMessageWithCallButton({
    Key? key,
    required this.message,
    required this.sender,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sender,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // Start video call with this user
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const JoinVideoCallScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.video_call,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );
  }
}

// Required imports for the screens:
// import 'screens/chat/join_video_call_screen.dart';

/*
INTEGRATION CHECKLIST:

1. Import the JoinVideoCallScreen:
   ✓ import 'screens/chat/join_video_call_screen.dart';

2. Choose one of the examples above (or customize):
   ✓ AppBar icon button (Example 1)
   ✓ Floating Action Button (Example 2)
   ✓ Popup menu (Example 3)
   ✓ Per-message button (Example 4)

3. Copy the code to your chat screen

4. Make sure VideoCallProvider is in your providers (already done in app.dart)

5. Test:
   ✓ Click video call button
   ✓ Enter channel name
   ✓ Grant camera & microphone permissions
   ✓ Video call screen should open
   ✓ You should see your camera preview

NEXT STEPS:

1. Set your Agora App ID in lib/core/agora_config.dart
2. Run: flutter pub get
3. Add video call button to your existing chat screen
4. Test the integration
5. Deploy!

For more details, see: AGORA_SETUP.md
*/
