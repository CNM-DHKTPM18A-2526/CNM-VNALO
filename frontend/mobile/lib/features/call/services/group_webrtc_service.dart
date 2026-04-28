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

  RTCPeerConnection? _localPeerConnection;
  MediaStream? _localStream;
  final Map<String, Participant> _participants = {};
  StreamSubscription<Map<String, dynamic>>? _groupCallSub;

  bool _isInitialized = false;
  bool _isEnded = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _isScreenSharing = false;
  bool _isUsingFrontCamera = true;
  String? _errorMessage;
  DateTime? _connectedAt;
  int _participantCount = 0;

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
  bool get isScreenSharing => _isScreenSharing;
  bool get isUsingFrontCamera => _isUsingFrontCamera;
  bool get isConnected => _connectedAt != null;
  String? get errorMessage => _errorMessage;
  DateTime? get connectedAt => _connectedAt;
  int get participantCount => _participantCount;
  List<Participant> get participants => _participants.values.toList();
  MediaStream? get localStream => _localStream;

  Future<void> initialize() async {
    if (_isInitialized || _isEnded) return;
    _isInitialized = true;
    _errorMessage = null;
    _isCameraOff = audioOnly;
    notifyListeners();

    _groupCallSub = _socketService.onGroupCallSignal.listen(_onGroupSignalEvent);

    try {
      final micStatus = await Permission.microphone.request();
      if (micStatus.isDenied || micStatus.isPermanentlyDenied) {
        throw 'Quyen micro bi tu choi';
      }
      if (!audioOnly) {
        final camStatus = await Permission.camera.request();
        if (camStatus.isDenied || camStatus.isPermanentlyDenied) {
          throw 'Quyen camera bi tu choi';
        }
      }

      final config = {
        'iceServers': CallConfig.getIceServers(),
        'sdpSemantics': 'unified-plan',
      };
      _localPeerConnection = await createPeerConnection(config);
      _registerLocalCallbacks();
      await _openLocalMedia();

      _socketService.emitGroupCallStarted(
        conversationId: conversationId,
        callId: callId,
        audioOnly: audioOnly,
      );
      await Helper.setSpeakerphoneOn(_isSpeakerOn);

      _participantCount = 1;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Khong the khoi tao cuoc goi nhom: $e';
      debugPrint('[GroupWebRtcService] init error: $_errorMessage');
      _safeEnd();
    }
  }

  void _registerLocalCallbacks() {
    _localPeerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isEmpty) return;
      // Find the participant that sent this track by checking peer connections
      for (final p in _participants.values) {
        p.remoteStream = event.streams.first;
        p.isConnected = true;
      }
      _participantCount = _participants.values.where((p2) => p2.isConnected).length + 1;
      notifyListeners();
    };

    _localPeerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      for (final p in _participants.values) {
        _socketService.emitGroupCallIceCandidate(
          conversationId: conversationId,
          callId: callId,
          targetUserId: p.odUserId,
          candidate: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        );
      }
    };

    _localPeerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[GroupWebRtc] connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _connectedAt ??= DateTime.now();
        notifyListeners();
      }
    };
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
    for (final track in _localStream!.getTracks()) {
      await _localPeerConnection?.addTrack(track, _localStream!);
    }
    notifyListeners();
  }

  Future<void> _onGroupSignalEvent(Map<String, dynamic> signal) async {
    if (_isEnded) return;
    final type = signal['type']?.toString();
    if (type == null) return;

    final senderId = signal['senderUserId']?.toString() ?? signal['fromUserId']?.toString() ?? '';
    if (senderId == currentUserId || senderId.isEmpty) return;

    switch (type) {
      case 'started':
        await _handleParticipantJoined(senderId, signal);
        break;
      case 'join':
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
      case 'leave':
        _handleParticipantLeft(senderId);
        break;
      case 'ended':
        _safeEnd();
        break;
    }
  }

  Future<void> _handleParticipantJoined(String odUserId, Map<String, dynamic> signal) async {
    if (_participants.containsKey(odUserId)) return;

    final participant = Participant(
      odUserId: odUserId,
      displayName: signal['senderName']?.toString() ?? odUserId,
      avatarUrl: signal['senderAvatarUrl']?.toString(),
    );
    _participants[odUserId] = participant;
    _participantCount = _participants.length + 1;
    notifyListeners();

    final pc = await createPeerConnection({
      'iceServers': CallConfig.getIceServers(),
      'sdpSemantics': 'unified-plan',
    });
    _participants[odUserId]!.peerConnection = pc;
    _participants[odUserId]!.isConnected = false;

    // CRITICAL: Add local tracks so the remote participant can receive our audio/video
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _participants[odUserId]!.remoteStream = event.streams.first;
        _participants[odUserId]!.isConnected = true;
        _participantCount = _participants.values.where((p2) => p2.isConnected).length + 1;
        notifyListeners();
      }
    };

    pc.onIceCandidate = (candidate) {
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
      );
    };

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    _socketService.emitGroupCallOffer(
      conversationId: conversationId,
      callId: callId,
      targetUserId: odUserId,
      sdp: {'type': offer.type, 'sdp': offer.sdp},
    );
  }

  Future<void> _handleOffer(String odUserId, Map<String, dynamic> signal) async {
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

    final pc = await createPeerConnection({
      'iceServers': CallConfig.getIceServers(),
      'sdpSemantics': 'unified-plan',
    });

    // CRITICAL: Add local tracks so the remote participant can receive our audio/video
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    // Assign to map entry directly to avoid nullable warning
    _participants[odUserId]!.peerConnection = pc;
    _participants[odUserId]!.isConnected = false;

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _participants[odUserId]!.remoteStream = event.streams.first;
        _participants[odUserId]!.isConnected = true;
        _participantCount = _participants.values.where((p2) => p2.isConnected).length + 1;
        notifyListeners();
      }
    };

    pc.onIceCandidate = (candidate) {
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
      );
    };

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
    );
  }

  Future<void> _handleAnswer(String odUserId, Map<String, dynamic> signal) async {
    final participant = _participants[odUserId];
    final pc = participant?.peerConnection;
    if (pc == null) return;

    final sdpMap = Map<String, dynamic>.from(signal['sdp'] ?? {});
    await pc.setRemoteDescription(
      RTCSessionDescription(sdpMap['sdp']?.toString() ?? '', 'answer'),
    );
  }

  Future<void> _handleIceCandidate(String odUserId, Map<String, dynamic> signal) async {
    final participant = _participants[odUserId];
    final pc = participant?.peerConnection;
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
    _participantCount = _participants.values.where((p) => p.isConnected).length + 1;
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
    _socketService.emitGroupCallEnded(
      conversationId: conversationId,
      callId: callId,
    );
    _safeEnd();
  }

  void _safeEnd() {
    _isEnded = true;
    _groupCallSub?.cancel();
    _localPeerConnection?.close();
    for (final p in _participants.values) {
      p.peerConnection?.close();
    }
    _participants.clear();
    _localPeerConnection = null;
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
