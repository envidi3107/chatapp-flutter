import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class AgoraService {
  late RtcEngine _agoraRtcEngine;

  final remoteUsers = <int>[];
  final infoStrings = <String>[];
  bool _isMuted = false;
  bool _isCameraOff = false;

  // Callbacks
  VoidCallback? onUserJoined;
  VoidCallback? onUserOffline;
  VoidCallback? onLocalUserJoined;
  VoidCallback? onRemoteVideoFrame;
  Function(String)? onError;
  Function(String)? onInfo;

  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  RtcEngine get engine => _agoraRtcEngine;

  /// Initialize Agora RTC Engine
  Future<void> initAgora({
    required String appId,
    required String channelName,
    String? token,
    int uid = 0,
  }) async {
    try {
      _agoraRtcEngine = createAgoraRtcEngine();

      // Initialize engine
      await _agoraRtcEngine.initialize(RtcEngineContext(appId: appId));

      // Enable video
      await _agoraRtcEngine.enableVideo();
      await _agoraRtcEngine.startPreview();

      // Set video configuration
      await _agoraRtcEngine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 1920, height: 1080),
          frameRate: 30,
          bitrate: 3150,
        ),
      );

      // Register event handlers
      _registerEventHandlers();

      // Enable web SDK interoperability
      if (!kIsWeb) {
        await _agoraRtcEngine.enableWebSdkInteroperability(true);
      }

      // Join channel
      await _agoraRtcEngine.joinChannel(
        token: token ?? '',
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(),
      );

      _logInfo('Initializing Agora for channel: $channelName');
    } catch (e) {
      _logError('Agora initialization error: $e');
      rethrow;
    }
  }

  /// Register event handlers for Agora events
  void _registerEventHandlers() {
    _agoraRtcEngine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          _logInfo(
            'Joined channel: ${connection.channelId}, UID: ${connection.localUid}',
          );
          onLocalUserJoined?.call();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          _logInfo('Remote user joined: $remoteUid');
          remoteUsers.add(remoteUid);
          onUserJoined?.call();
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          _logInfo('Remote user offline: $remoteUid');
          remoteUsers.remove(remoteUid);
          onUserOffline?.call();
        },
        onError: (ErrorCodeType err, String msg) {
          _logError('Error: ${err.name} - $msg');
          onError?.call('${err.name}: $msg');
        },
        onFirstRemoteVideoFrame: (RtcConnection connection, int remoteUid,
            int width, int height, int elapsed) {
          _logInfo(
            'First remote video frame from UID: $remoteUid ($width x $height)',
          );
          onRemoteVideoFrame?.call();
        },
      ),
    );
  }

  /// Leave the channel
  Future<void> leaveChannel() async {
    try {
      await _agoraRtcEngine.leaveChannel();
      remoteUsers.clear();
      infoStrings.clear();
      _logInfo('Left channel');
    } catch (e) {
      _logError('Error leaving channel: $e');
    }
  }

  /// Toggle audio mute
  Future<void> toggleMute() async {
    try {
      _isMuted = !_isMuted;
      await _agoraRtcEngine.muteLocalAudioStream(_isMuted);
      _logInfo('Audio ${_isMuted ? 'muted' : 'unmuted'}');
    } catch (e) {
      _logError('Error toggling mute: $e');
    }
  }

  /// Toggle video on/off
  Future<void> toggleVideo() async {
    try {
      _isCameraOff = !_isCameraOff;
      await _agoraRtcEngine.muteLocalVideoStream(_isCameraOff);
      _logInfo('Video camera ${_isCameraOff ? 'off' : 'on'}');
    } catch (e) {
      _logError('Error toggling video: $e');
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    try {
      await _agoraRtcEngine.switchCamera();
      _logInfo('Camera switched');
    } catch (e) {
      _logError('Error switching camera: $e');
    }
  }

  /// Dispose the Agora engine
  Future<void> dispose() async {
    try {
      await leaveChannel();
      await _agoraRtcEngine.release();
      remoteUsers.clear();
      infoStrings.clear();
      _logInfo('Agora engine disposed');
    } catch (e) {
      _logError('Error disposing Agora: $e');
    }
  }

  /// Log info message
  void _logInfo(String message) {
    infoStrings.add(message);
    onInfo?.call(message);
    debugPrint('[Agora Info] $message');
  }

  /// Log error message
  void _logError(String message) {
    final errorMsg = '[ERROR] $message';
    infoStrings.add(errorMsg);
    onError?.call(message);
    debugPrint('[Agora Error] $message');
  }
}
