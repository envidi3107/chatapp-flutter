import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/agora_config.dart';
import '../core/app_constants.dart';
import '../providers/video_call_provider.dart';
import 'video_call_screen.dart';

class JoinVideoCallScreen extends StatefulWidget {
  const JoinVideoCallScreen({Key? key}) : super(key: key);

  @override
  State<JoinVideoCallScreen> createState() => _JoinVideoCallScreenState();
}

class _JoinVideoCallScreenState extends State<JoinVideoCallScreen> {
  final _channelController = TextEditingController();
  bool _validateError = false;

  @override
  void dispose() {
    _channelController.dispose();
    super.dispose();
  }

  /// Request camera and microphone permissions
  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.microphone,
      Permission.camera,
    ].request();

    final microphoneGranted =
        statuses[Permission.microphone]?.isGranted ?? false;
    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;

    if (!cameraGranted || !microphoneGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Camera and microphone permissions are required for video calls',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }

    return true;
  }

  /// Join video call
  Future<void> _joinCall() async {
    setState(() {
      _validateError = _channelController.text.isEmpty;
    });

    if (_validateError) {
      return;
    }

    // Check if App ID is configured
    if (AgoraConfig.appId == '<YOUR_APP_ID_HERE>') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please configure your Agora App ID in lib/core/agora_config.dart',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    // Request permissions
    final permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      return;
    }

    // Initialize and join call
    if (!mounted) return;
    final provider = context.read<VideoCallProvider>();
    await provider.initializeCall(_channelController.text);

    // Navigate to video call screen if successfully initialized
    if (provider.isInitialized && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const VideoCallScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Call'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              // Agora logo
              Image.network(
                'https://www.agora.io/en/wp-content/uploads/2019/07/agora-symbol-vertical.png',
                height: 100,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.video_call,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Agora Group Video Call',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // Channel name input
              Container(
                width: 300,
                child: TextFormField(
                  controller: _channelController,
                  decoration: InputDecoration(
                    labelText: 'Channel Name',
                    labelStyle: const TextStyle(color: Colors.blue),
                    hintText: AgoraConfig.defaultChannelName,
                    hintStyle: const TextStyle(color: Colors.black45),
                    errorText:
                        _validateError ? 'Channel name is mandatory' : null,
                    border: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),

              // Join button
              Consumer<VideoCallProvider>(
                builder: (context, provider, child) {
                  return MaterialButton(
                    onPressed: provider.isLoading ? null : _joinCall,
                    height: 50,
                    color: Colors.blueAccent,
                    disabledColor: Colors.blueAccent.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: provider.isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'Join Call',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                              ),
                            ],
                          ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // Status message
              Consumer<VideoCallProvider>(
                builder: (context, provider, child) {
                  if (provider.statusMessage.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: provider.statusMessage.contains('Error')
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: provider.statusMessage.contains('Error')
                            ? Colors.red
                            : Colors.blue,
                      ),
                    ),
                    child: Text(
                      provider.statusMessage,
                      style: TextStyle(
                        color: provider.statusMessage.contains('Error')
                            ? Colors.red.shade700
                            : Colors.blue.shade700,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),

              const SizedBox(height: 50),

              // Info box about App ID
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.info, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          'Configuration Required',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'To use video calls, please:\n\n'
                      '1. Go to https://console.agora.io/\n'
                      '2. Create a project and copy your App ID\n'
                      '3. Update lib/core/agora_config.dart with your App ID',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
