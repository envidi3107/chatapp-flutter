import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/video_call_provider.dart';
import '../../services/message_service.dart';
import '../../services/realtime_service.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
    this.isCaller = false,
  }) : super(key: key);

  final int roomId;
  final String roomName;
  final bool isCaller;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final ScrollController _infoScrollController = ScrollController();
  bool _showInfoPanel = false;
  final Stopwatch _callTimer = Stopwatch();
  Timer? _timerTick;
  String _elapsedLabel = '00:00';
  StreamSubscription<VideoCallRejectedEvent>? _rejectedSub;

  @override
  void initState() {
    super.initState();
    _callTimer.start();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final elapsed = _callTimer.elapsed;
      final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() => _elapsedLabel = '$m:$s');
    });

    // Only the caller needs to hear about rejections
    if (widget.isCaller) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _rejectedSub = context.read<RealtimeService>().videoCallRejectedStream.listen((event) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${event.rejectedBy} đã từ chối cuộc gọi của bạn'),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
        });
      });
    }
  }

  @override
  void dispose() {
    _rejectedSub?.cancel();
    _timerTick?.cancel();
    _callTimer.stop();
    _infoScrollController.dispose();
    super.dispose();
  }

  Future<void> _endCallAndPop() async {
    final provider = context.read<VideoCallProvider>();
    final messageService = context.read<MessageService>();
    final elapsed = _callTimer.elapsed;
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final durationLabel = '$m:$s';

    await provider.endCall();

    // Only the caller sends the end-call message
    if (widget.isCaller && widget.roomId != 0) {
      try {
        await messageService.sendMessage(
          roomId: widget.roomId,
          text: '📞 Cuộc gọi video đã kết thúc · $durationLabel',
        );
      } catch (_) {}
    }

    if (mounted) Navigator.of(context).pop();
  }

  Widget _buildVideoView(int uid) {
    final provider = context.read<VideoCallProvider>();
    final isLocal = uid == 0;
    final rtcEngine = provider.agoraService.engine;
    final channelName = provider.channelName;

    return Container(
      color: Colors.black,
      child: AgoraVideoView(
        controller: isLocal
            ? VideoViewController(
                rtcEngine: rtcEngine,
                canvas: const VideoCanvas(uid: 0),
              )
            : VideoViewController.remote(
                rtcEngine: rtcEngine,
                canvas: VideoCanvas(uid: uid),
                connection: RtcConnection(channelId: channelName),
              ),
      ),
    );
  }

  List<Widget> _getRenderViews() {
    final provider = context.watch<VideoCallProvider>();
    final List<Widget> list = [_buildVideoView(0)];
    for (final uid in provider.remoteUsers) {
      list.add(_buildVideoView(uid));
    }
    return list;
  }

  Widget _videoView(Widget view) {
    return Expanded(
      child: Container(color: Colors.black, child: view),
    );
  }

  Widget _expandedVideoRow(List<Widget> views) {
    return Expanded(
      child: Row(children: views.map(_videoView).toList()),
    );
  }

  Widget _viewRows(List<Widget> views) {
    switch (views.length) {
      case 1:
        return Container(
          color: Colors.black,
          child: Column(children: [_videoView(views[0])]),
        );
      case 2:
        return Container(
          color: Colors.black,
          child: Column(children: [
            _expandedVideoRow([views[0]]),
            _expandedVideoRow([views[1]]),
          ]),
        );
      case 3:
        return Container(
          color: Colors.black,
          child: Column(children: [
            _expandedVideoRow(views.sublist(0, 2)),
            _expandedVideoRow(views.sublist(2, 3)),
          ]),
        );
      default:
        // 4+ participants: 2 rows of 2
        return Container(
          color: Colors.black,
          child: Column(children: [
            _expandedVideoRow(views.sublist(0, 2)),
            _expandedVideoRow(views.sublist(2, views.length > 4 ? 4 : views.length)),
          ]),
        );
    }
  }

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
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              GestureDetector(
                onTap: () => setState(() => _showInfoPanel = false),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Consumer<VideoCallProvider>(
            builder: (context, provider, _) => SizedBox(
              height: 150,
              child: SingleChildScrollView(
                controller: _infoScrollController,
                child: Text(
                  provider.agoraService.infoStrings.isNotEmpty
                      ? provider.agoraService.infoStrings.join('\n')
                      : 'No events yet',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Consumer<VideoCallProvider>(
        builder: (context, provider, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mute button
              _ControlButton(
                icon: provider.isMuted ? Icons.mic_off : Icons.mic,
                label: provider.isMuted ? 'Unmute' : 'Mute',
                active: provider.isMuted,
                onPressed: () => provider.toggleMute(),
              ),

              // Camera toggle
              _ControlButton(
                icon: provider.isCameraOff ? Icons.videocam_off : Icons.videocam,
                label: provider.isCameraOff ? 'Cam On' : 'Cam Off',
                active: provider.isCameraOff,
                onPressed: () => provider.toggleCamera(),
              ),

              // End call
              GestureDetector(
                onTap: _endCallAndPop,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 6),
                    const Text('End', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),

              // Switch camera
              _ControlButton(
                icon: Icons.switch_camera,
                label: 'Flip',
                active: false,
                onPressed: () => provider.switchCamera(),
              ),

              // Info button
              _ControlButton(
                icon: Icons.info_outline,
                label: 'Info',
                active: _showInfoPanel,
                onPressed: () => setState(() => _showInfoPanel = !_showInfoPanel),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _endCallAndPop();
        return false; // We navigate manually
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _endCallAndPop,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.roomName,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  Consumer<VideoCallProvider>(
                    builder: (context, provider, _) => Text(
                      '${provider.remoteUsers.length + 1} người tham gia',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _elapsedLabel,
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            // Video grid – rebuild when remoteUsers changes
            Consumer<VideoCallProvider>(
              builder: (context, _, __) {
                final views = _getRenderViews();
                return _viewRows(views);
              },
            ),

            // Info panel
            if (_showInfoPanel)
              Positioned(
                bottom: 120,
                left: 16,
                right: 16,
                child: _infoPanel(),
              ),

            // Toolbar
            _toolbar(),

            // Status toast
            Consumer<VideoCallProvider>(
              builder: (context, provider, _) {
                if (provider.statusMessage.isEmpty) return const SizedBox.shrink();
                final isError = provider.statusMessage.toLowerCase().contains('error');
                return Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isError ? Colors.red.withOpacity(0.8) : Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      provider.statusMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: active ? Colors.blueAccent : Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: active ? Colors.white : Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}
