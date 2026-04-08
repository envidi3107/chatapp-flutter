import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../providers/video_call_provider.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({Key? key}) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _showInfoPanel = false;
  final ScrollController _infoScrollController = ScrollController();

  @override
  void dispose() {
    _infoScrollController.dispose();
    super.dispose();
  }

  /// Build video view for a single participant
  Widget _buildVideoView(int uid) {
    final isLocal = uid == 0;

    return Container(
      color: Colors.black,
      child: AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: context.read<VideoCallProvider>().agoraService.engine,
          canvas: VideoCanvas(uid: uid),
        ),
      ),
    );
  }

  /// Get list of video widgets for all participants
  List<Widget> _getRenderViews() {
    final provider = context.read<VideoCallProvider>();
    final List<Widget> list = [
      _buildVideoView(0), // Local video
    ];

    // Add remote participant videos
    for (int uid in provider.remoteUsers) {
      list.add(_buildVideoView(uid));
    }

    return list;
  }

  /// Build single video view container
  Widget _videoView(Widget view) {
    return Expanded(
      child: Container(
        color: Colors.black,
        child: view,
      ),
    );
  }

  /// Build expanded video row for multiple videos
  Widget _expandedVideoRow(List<Widget> views) {
    final wrappedViews = views.map<Widget>(_videoView).toList();
    return Expanded(
      child: Row(
        children: wrappedViews,
      ),
    );
  }

  /// Build video grid based on number of participants
  Widget _viewRows() {
    final views = _getRenderViews();

    switch (views.length) {
      case 1:
        return Container(
          color: Colors.black,
          child: Column(
            children: [_videoView(views[0])],
          ),
        );
      case 2:
        return Container(
          color: Colors.black,
          child: Column(
            children: [
              _expandedVideoRow([views[0]]),
              _expandedVideoRow([views[1]]),
            ],
          ),
        );
      case 3:
        return Container(
          color: Colors.black,
          child: Column(
            children: [
              _expandedVideoRow(views.sublist(0, 2)),
              _expandedVideoRow(views.sublist(2, 3)),
            ],
          ),
        );
      case 4:
        return Container(
          color: Colors.black,
          child: Column(
            children: [
              _expandedVideoRow(views.sublist(0, 2)),
              _expandedVideoRow(views.sublist(2, 4)),
            ],
          ),
        );
      default:
        return Container(color: Colors.black);
    }
  }

  /// Build info panel showing logs
  Widget _infoPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 100),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Call Info',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showInfoPanel = false;
                  });
                },
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Consumer<VideoCallProvider>(
            builder: (context, provider, child) {
              return SizedBox(
                height: 150,
                child: SingleChildScrollView(
                  controller: _infoScrollController,
                  child: Text(
                    provider.agoraService.infoStrings.isNotEmpty
                        ? provider.agoraService.infoStrings.join('\n')
                        : 'No events yet',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Build toolbar with control buttons
  Widget _toolbar() {
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          Consumer<VideoCallProvider>(
            builder: (context, provider, child) {
              return RawMaterialButton(
                onPressed: provider.toggleMute,
                shape: const CircleBorder(),
                elevation: 2.0,
                fillColor: provider.isMuted ? Colors.blueAccent : Colors.white,
                padding: const EdgeInsets.all(12.0),
                child: Icon(
                  provider.isMuted ? Icons.mic_off : Icons.mic,
                  color: provider.isMuted ? Colors.white : Colors.blueAccent,
                  size: 20.0,
                ),
              );
            },
          ),

          // End call button
          Consumer<VideoCallProvider>(
            builder: (context, provider, child) {
              return RawMaterialButton(
                onPressed: () async {
                  await provider.endCall();
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                },
                shape: const CircleBorder(),
                elevation: 2.0,
                fillColor: Colors.redAccent,
                padding: const EdgeInsets.all(15.0),
                child: const Icon(
                  Icons.call_end,
                  color: Colors.white,
                  size: 35.0,
                ),
              );
            },
          ),

          // Switch camera button
          Consumer<VideoCallProvider>(
            builder: (context, provider, child) {
              return RawMaterialButton(
                onPressed: provider.switchCamera,
                shape: const CircleBorder(),
                elevation: 2.0,
                fillColor: Colors.white,
                padding: const EdgeInsets.all(12.0),
                child: const Icon(
                  Icons.switch_camera,
                  color: Colors.blueAccent,
                  size: 20.0,
                ),
              );
            },
          ),

          // Toggle video button
          Consumer<VideoCallProvider>(
            builder: (context, provider, child) {
              return RawMaterialButton(
                onPressed: provider.toggleCamera,
                shape: const CircleBorder(),
                elevation: 2.0,
                fillColor:
                    provider.isCameraOff ? Colors.blueAccent : Colors.white,
                padding: const EdgeInsets.all(12.0),
                child: Icon(
                  provider.isCameraOff ? Icons.videocam_off : Icons.videocam,
                  color:
                      provider.isCameraOff ? Colors.white : Colors.blueAccent,
                  size: 20.0,
                ),
              );
            },
          ),

          // Info button
          RawMaterialButton(
            onPressed: () {
              setState(() {
                _showInfoPanel = !_showInfoPanel;
              });
            },
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.white,
            padding: const EdgeInsets.all(12.0),
            child: const Icon(
              Icons.info,
              color: Colors.blueAccent,
              size: 20.0,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // End call before leaving
        final provider = context.read<VideoCallProvider>();
        await provider.endCall();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<VideoCallProvider>(
            builder: (context, provider, child) {
              return Text(
                'Video Call - ${provider.channelName}',
                style: const TextStyle(fontSize: 16),
              );
            },
          ),
          backgroundColor: Colors.black,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Consumer<VideoCallProvider>(
                  builder: (context, provider, child) {
                    return Text(
                      'Participants: ${provider.remoteUsers.length + 1}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Video grid
            _viewRows(),

            // Info panel (optional)
            if (_showInfoPanel)
              Positioned(
                bottom: 120,
                left: 16,
                right: 16,
                child: _infoPanel(),
              ),

            // Toolbar
            _toolbar(),

            // Status message
            Consumer<VideoCallProvider>(
              builder: (context, provider, child) {
                if (provider.statusMessage.isEmpty) {
                  return const SizedBox.shrink();
                }

                final isError = provider.statusMessage.contains('Error') ||
                    provider.statusMessage.contains('error');

                return Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isError
                          ? Colors.red.withOpacity(0.8)
                          : Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      provider.statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
