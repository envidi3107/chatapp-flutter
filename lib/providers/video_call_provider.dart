import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/agora_config.dart';
import '../services/agora_service.dart';

class VideoCallProvider with ChangeNotifier {
  late AgoraService _agoraService;

  String _channelName = '';
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  List<int> _remoteUsers = [];
  String _statusMessage = '';
  bool _isLoading = false;

  // Getters
  String get channelName => _channelName;
  bool get isInitialized => _isInitialized;
  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  List<int> get remoteUsers => _remoteUsers;
  String get statusMessage => _statusMessage;
  bool get isLoading => _isLoading;
  AgoraService get agoraService => _agoraService;

  VideoCallProvider() {
    _agoraService = AgoraService();
    _setupAgoraCallbacks();
  }

  /// Setup callbacks from Agora service
  void _setupAgoraCallbacks() {
    _agoraService.onUserJoined = () {
      _remoteUsers = List.from(_agoraService.remoteUsers);
      notifyListeners();
    };

    _agoraService.onUserOffline = () {
      _remoteUsers = List.from(_agoraService.remoteUsers);
      notifyListeners();
    };

    _agoraService.onLocalUserJoined = () {
      _statusMessage = 'Successfully joined channel: $_channelName';
      notifyListeners();
    };

    _agoraService.onRemoteVideoFrame = () {
      notifyListeners();
    };

    _agoraService.onInfo = (msg) {
      _statusMessage = msg;
      notifyListeners();
    };

    _agoraService.onError = (error) {
      _statusMessage = 'Error: $error';
      notifyListeners();
    };
  }

  /// Initialize the video call
  Future<void> initializeCall(String channelName) async {
    if (channelName.isEmpty) {
      _statusMessage = 'Channel name cannot be empty';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _channelName = channelName;
    _statusMessage = 'Initializing video call...';
    notifyListeners();

    try {
      // Check if App ID is configured
      if (AgoraConfig.appId == '<YOUR_APP_ID_HERE>') {
        throw Exception(
          'Agora App ID not configured. Please set your App ID in agora_config.dart',
        );
      }

      await _agoraService.initAgora(
        appId: AgoraConfig.appId,
        channelName: channelName,
        token: AgoraConfig.token,
        uid: AgoraConfig.defaultUid,
      );

      _isInitialized = true;
      _statusMessage = 'Call initialized successfully';
    } catch (e) {
      _statusMessage = 'Failed to initialize call: $e';
      debugPrint('Error initializing call: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle mute
  Future<void> toggleMute() async {
    try {
      await _agoraService.toggleMute();
      _isMuted = _agoraService.isMuted;
      notifyListeners();
    } catch (e) {
      _statusMessage = 'Error toggling mute: $e';
      notifyListeners();
    }
  }

  /// Toggle camera
  Future<void> toggleCamera() async {
    try {
      await _agoraService.toggleVideo();
      _isCameraOff = _agoraService.isCameraOff;
      notifyListeners();
    } catch (e) {
      _statusMessage = 'Error toggling camera: $e';
      notifyListeners();
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    try {
      await _agoraService.switchCamera();
      _statusMessage = 'Camera switched';
      notifyListeners();
    } catch (e) {
      _statusMessage = 'Error switching camera: $e';
      notifyListeners();
    }
  }

  /// End the call
  Future<void> endCall() async {
    try {
      await _agoraService.leaveChannel();
      _isInitialized = false;
      _remoteUsers.clear();
      _isMuted = false;
      _isCameraOff = false;
      _statusMessage = 'Call ended';
      notifyListeners();
    } catch (e) {
      _statusMessage = 'Error ending call: $e';
      notifyListeners();
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _agoraService.dispose();
    super.dispose();
  }
}
