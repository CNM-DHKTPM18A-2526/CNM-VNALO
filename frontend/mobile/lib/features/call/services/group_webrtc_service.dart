import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vnalo_mobile/config/call_config.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class Participant {
  final String odUserId;
  final String displayName;
  final String? avatarUrl;
  RTCPeerConnection? peerConnection;
  MediaStream? remoteStream;
  bool isConnected;
  bool isMuted;
  bool isCameraOff;
  bool isScreenSharing;

  Participant({
    required this.odUserId,
    required this.displayName,
    this.avatarUrl,
    this.peerConnection,
    this.remoteStream,
    this.isConnected = false,
    this.isMuted = false,
    this.isCameraOff = false,
    this.isScreenSharing = false,
  });
}

class GroupWebRtcService extends ChangeNotifier {
  final SocketService _socketService;
  final String conversationId;
  final String callId;
  final String currentUserId;
  final String displayName;
  final bool audioOnly;

  MediaStream? _localStream;
  final Map<String, Participant> _participants = {};
  StreamSubscription<Map<String, dynamic>>? _groupCallSub;

  bool _isInitialized = false;
  bool _isEnded = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _isUsingFrontCamera = true;
  bool _isAccepted = false;
  String? _errorMessage;
  DateTime? _connectedAt;

  GroupWebRtcService({
    required SocketService socketService,
    required this.conversationId,
    required this.callId,
    required this.currentUserId,
    required this.displayName,
    this.audioOnly = false,
  }) : _socketService = socketService;

  bool get isInitialized => _isInitialized;
  bool get isEnded => _isEnded;
  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isUsingFrontCamera => _isUsingFrontCamera;
  bool get isConnected => _connectedAt != null;
  bool get isAccepted => _isAccepted;
  String? get errorMessage => _errorMessage;
  DateTime? get connectedAt => _connectedAt;
  int get participantCount => _participants.values.where((p) => p.isConnected).length + 1;
  List<Participant> get participants => _participants.values.toList();
  MediaStream? get localStream => _localStream;

  /// Start listening to socket signals without initializing media
  void startSignalListening() {
    if (_groupCallSub != null) return;
    debugPrint('[GroupWebRtcService] Starting signal listening');
    _groupCallSub = _socketService.onGroupCallSignal.listen(_onGroupSignalEvent);
  }

  /// Initialize as CALLER — start the call immediately
  Future<void> initialize({List<String>? targetUserIds}) async {
    if (_isInitialized || _isEnded) return;
    _isInitialized = true;
    _isAccepted = true; // Caller is always accepted
    _errorMessage = null;
    _isCameraOff = audioOnly;
    notifyListeners();

    startSignalListening();

    try {
      await _requestPermissions();
      await _openLocalMedia();

      _socketService.emitGroupCallStarted(
        conversationId: conversationId,
        callId: callId,
        audioOnly: audioOnly,
        senderUserId: currentUserId,
        senderName: displayName,
        targetUserIds: targetUserIds,
      );
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Không thể khởi tạo cuộc gọi nhóm: $e';
      debugPrint('[GroupWebRtcService] init error: $_errorMessage');
      _safeEnd();
    }
  }

  /// Accept call as CALLEE — initialize media then join
  Future<void> acceptCall() async {
    if (_isAccepted || _isEnded) return;
    _isAccepted = true;
    _errorMessage = null;
    _isCameraOff = audioOnly;
    notifyListeners();

    startSignalListening();

    try {
      await _requestPermissions();
      await _openLocalMedia();

      // Emit join signal so the caller knows we've joined
      _socketService.emitGroupCallJoin(
        conversationId: conversationId,
        callId: callId,
        senderUserId: currentUserId,
        senderName: displayName,
      );
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Không thể tham gia cuộc gọi: $e';
      debugPrint('[GroupWebRtcService] accept error: $_errorMessage');
      _safeEnd();
    }
  }

  Future<void> _requestPermissions() async {
    final micStatus = await Permission.microphone.request();
    if (micStatus.isDenied || micStatus.isPermanentlyDenied) {
      throw 'Quyền micro bị từ chối';
    }
    if (!audioOnly) {
      final camStatus = await Permission.camera.request();
      if (camStatus.isDenied || camStatus.isPermanentlyDenied) {
        throw 'Quyền camera bị từ chối';
      }
    }
  }

  Future<void> _openLocalMedia() async {
    final constraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'mandatory': {
          'googEchoCancellation': true,
          'googNoiseSuppression': true,
          'googHighpassFilter': true,
        },
      },
      'video': audioOnly
          ? false
          : {
              'facingMode': 'user',
              'width': 1280,
              'height': 720,
              'frameRate': 30,
            },
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    notifyListeners();
  }

  /// Create a PeerConnection for a specific participant and add local tracks
  Future<RTCPeerConnection> _createPeerConnectionForParticipant(String odUserId) async {
    final config = {
      'iceServers': CallConfig.getIceServers(),
      'sdpSemantics': 'unified-plan',
    };

    final pc = await createPeerConnection(config);

    // *** CRITICAL: Add local tracks so the remote peer can see/hear us ***
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _participants[odUserId]?.remoteStream = event.streams.first;
        _participants[odUserId]?.isConnected = true;
        _connectedAt ??= DateTime.now();
        notifyListeners();
      }
    };

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      _socketService.emitGroupCallIceCandidate(
        conversationId: conversationId,
        callId: callId,
        targetUserId: odUserId,
        candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
        senderUserId: currentUserId,
      );
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[GroupWebRtc] PC connection state for $odUserId: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _connectedAt ??= DateTime.now();
        notifyListeners();
      }
    };

    return pc;
  }

  Future<void> _onGroupSignalEvent(Map<String, dynamic> signal) async {
    if (_isEnded) return;
    final type = signal['type']?.toString();
    if (type == null) return;

    final senderId = signal['senderUserId']?.toString() ?? signal['fromUserId']?.toString() ?? '';
    debugPrint('[GroupWebRtcService][RECV] signal: $type from: $senderId (current: $currentUserId)');
    
    if (senderId == currentUserId || senderId.isEmpty) return;

    switch (type) {
      case 'started':
      case 'join':
      case 'user-joined':
        debugPrint('[GroupWebRtcService] Participant joining: $senderId');
        await _handleParticipantJoined(senderId, signal);
        break;
      case 'offer':
        await _handleOffer(senderId, signal);
        break;
      case 'answer':
        await _handleAnswer(senderId, signal);
        break;
      case 'ice-candidate':
        await _handleIceCandidate(senderId, signal);
        break;
      case 'user-left':
      case 'leave':
        debugPrint('[GroupWebRtcService] Participant leaving: $senderId');
        _handleParticipantLeft(senderId);
        break;
      case 'ended':
        debugPrint('[GroupWebRtcService] Call ended by server/caller');
        _safeEnd();
        break;
      case 'mute-state':
        _handleMuteStateChange(senderId, signal);
        break;
    }
  }

  void _handleMuteStateChange(String odUserId, Map<String, dynamic> signal) {
    final p = _participants[odUserId];
    if (p == null) return;
    
    if (signal.containsKey('isMuted')) {
      p.isMuted = signal['isMuted'] == true;
    }
    if (signal.containsKey('isCameraOff')) {
      p.isCameraOff = signal['isCameraOff'] == true;
    }
    notifyListeners();
  }

  Future<void> _handleParticipantJoined(String odUserId, Map<String, dynamic> signal) async {
    if (_participants.containsKey(odUserId)) return;
    if (!_isAccepted) return; // Don't create PC if we haven't accepted yet

    final participant = Participant(
      odUserId: odUserId,
      displayName: signal['senderName']?.toString() ?? odUserId,
      avatarUrl: signal['senderAvatarUrl']?.toString(),
    );
    _participants[odUserId] = participant;
    notifyListeners();

    // Create PC with local tracks attached
    final pc = await _createPeerConnectionForParticipant(odUserId);
    _participants[odUserId]!.peerConnection = pc;

    // As the existing party, create and send offer
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    _socketService.emitGroupCallOffer(
      conversationId: conversationId,
      callId: callId,
      targetUserId: odUserId,
      sdp: {'type': offer.type, 'sdp': offer.sdp},
      senderUserId: currentUserId,
    );
  }

  Future<void> _handleOffer(String odUserId, Map<String, dynamic> signal) async {
    if (!_isAccepted) return;

    var participant = _participants[odUserId];
    if (participant == null) {
      participant = Participant(
        odUserId: odUserId,
        displayName: signal['senderName']?.toString() ?? odUserId,
        avatarUrl: signal['senderAvatarUrl']?.toString(),
      );
      _participants[odUserId] = participant;
      notifyListeners();
    }

    // Create PC with local tracks attached
    final pc = await _createPeerConnectionForParticipant(odUserId);
    _participants[odUserId]!.peerConnection = pc;

    final sdpMap = Map<String, dynamic>.from(signal['sdp'] ?? {});
    await pc.setRemoteDescription(
      RTCSessionDescription(sdpMap['sdp']?.toString() ?? '', 'offer'),
    );

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    _socketService.emitGroupCallAnswer(
      conversationId: conversationId,
      callId: callId,
      targetUserId: odUserId,
      sdp: {'type': answer.type, 'sdp': answer.sdp},
      senderUserId: currentUserId,
    );
  }

  Future<void> _handleAnswer(String odUserId, Map<String, dynamic> signal) async {
    final pc = _participants[odUserId]?.peerConnection;
    if (pc == null) return;

    final sdpMap = Map<String, dynamic>.from(signal['sdp'] ?? {});
    await pc.setRemoteDescription(
      RTCSessionDescription(sdpMap['sdp']?.toString() ?? '', 'answer'),
    );
  }

  Future<void> _handleIceCandidate(String odUserId, Map<String, dynamic> signal) async {
    final pc = _participants[odUserId]?.peerConnection;
    if (pc == null) return;

    final candidateMap = Map<String, dynamic>.from(signal['candidate'] ?? {});
    final candidateStr = candidateMap['candidate']?.toString();
    if (candidateStr == null) return;

    await pc.addCandidate(RTCIceCandidate(
      candidateStr,
      candidateMap['sdpMid']?.toString(),
      candidateMap['sdpMLineIndex'] is int
          ? candidateMap['sdpMLineIndex'] as int
          : int.tryParse(candidateMap['sdpMLineIndex']?.toString() ?? ''),
    ));
  }

  void _handleParticipantLeft(String odUserId) {
    _participants[odUserId]?.peerConnection?.close();
    _participants.remove(odUserId);
    notifyListeners();
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    for (final track in _localStream?.getAudioTracks() ?? []) {
      track.enabled = !_isMuted;
    }
    _socketService.emitGroupCallMuteState(
      conversationId: conversationId,
      callId: callId,
      isMuted: _isMuted,
    );
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    if (audioOnly) return;
    _isCameraOff = !_isCameraOff;
    for (final track in _localStream?.getVideoTracks() ?? []) {
      track.enabled = !_isCameraOff;
    }
    _socketService.emitGroupCallMuteState(
      conversationId: conversationId,
      callId: callId,
      isCameraOff: _isCameraOff,
    );
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await Helper.setSpeakerphoneOn(_isSpeakerOn);
    notifyListeners();
  }

  Future<void> switchCamera() async {
    if (audioOnly) return;
    final videoTracks = _localStream?.getVideoTracks() ?? [];
    if (videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks.first);
      _isUsingFrontCamera = !_isUsingFrontCamera;
      notifyListeners();
    }
  }

  Future<void> endCall() async {
    if (_isEnded) return;
    _isEnded = true;
    _socketService.emitGroupCallLeave(
      conversationId: conversationId,
      callId: callId,
      senderUserId: currentUserId,
    );
    _safeEnd();
  }

  void _safeEnd() {
    _isEnded = true;
    _groupCallSub?.cancel();
    for (final p in _participants.values) {
      p.peerConnection?.close();
    }
    _participants.clear();
    final tracks = _localStream?.getTracks() ?? [];
    for (final t in tracks) {
      t.stop();
    }
    _localStream = null;
    notifyListeners();
  }

  @override
  void dispose() {
    endCall();
    super.dispose();
  }
}
