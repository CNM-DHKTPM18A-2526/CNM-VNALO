import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class WebRtcCallService extends ChangeNotifier {
  final SocketService _socketService;
  final String conversationId;
  final String callId;
  final String currentUserId;
  final String peerUserId;
  final bool audioOnly;
  final bool isCaller;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  StreamSubscription<Map<String, dynamic>>? _signalSubscription;

  bool _isInitializing = false;
  bool _isConnected = false;
  bool _isEnded = false;
  bool _isMicrophoneEnabled = true;
  bool _isSpeakerOn = true;
  bool _isCameraEnabled = true;
  bool _isUsingFrontCamera = true;
  String? _errorMessage;
  DateTime? _connectedAt;

  WebRtcCallService({
    required SocketService socketService,
    required this.conversationId,
    required this.callId,
    required this.currentUserId,
    required this.peerUserId,
    required this.audioOnly,
    required this.isCaller,
  }) : _socketService = socketService;

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get isInitializing => _isInitializing;
  bool get isConnected => _isConnected;
  bool get isEnded => _isEnded;
  bool get isMicrophoneEnabled => _isMicrophoneEnabled;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isCameraEnabled => _isCameraEnabled;
  bool get isUsingFrontCamera => _isUsingFrontCamera;
  String? get errorMessage => _errorMessage;
  DateTime? get connectedAt => _connectedAt;

  Future<void> initialize() async {
    if (_isInitializing || _peerConnection != null) return;
    _isInitializing = true;
    _errorMessage = null;
    _isCameraEnabled = !audioOnly;
    notifyListeners();

    _signalSubscription = _socketService.onCallSignal.listen(_onSignalEvent);

    try {
      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
      };

      _peerConnection = await createPeerConnection(configuration);
      _registerPeerCallbacks();
      await _openLocalMedia();
      await Helper.setSpeakerphoneOn(_isSpeakerOn);

      if (isCaller) {
        await _createAndSendOffer();
      }
    } catch (e) {
      _errorMessage = 'Không thể khởi tạo cuộc gọi: $e';
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  void _registerPeerCallbacks() {
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isEmpty) return;
      _remoteStream = event.streams.first;
      notifyListeners();
    };

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      _socketService.sendCallIceCandidate(
        conversationId: conversationId,
        callId: callId,
        targetUserId: peerUserId,
        candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };

    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        if (!_isConnected) {
          _isConnected = true;
          _connectedAt = DateTime.now();
          notifyListeners();
        }
      }

      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        _isConnected = false;
        notifyListeners();
      }
    };
  }

  Future<void> _openLocalMedia() async {
    final mediaConstraints = {
      'audio': true,
      'video':
          audioOnly
              ? false
              : {
                'facingMode': 'user',
                'width': 1280,
                'height': 720,
                'frameRate': 30,
              },
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    final tracks = _localStream?.getTracks() ?? const <MediaStreamTrack>[];
    for (final track in tracks) {
      await _peerConnection?.addTrack(track, _localStream!);
    }
  }

  Future<void> _createAndSendOffer() async {
    final pc = _peerConnection;
    if (pc == null) return;

    final offer = await pc.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': audioOnly ? 0 : 1,
    });
    await pc.setLocalDescription(offer);

    _socketService.sendCallOffer(
      conversationId: conversationId,
      callId: callId,
      targetUserId: peerUserId,
      sdp: {'type': offer.type, 'sdp': offer.sdp},
    );
  }

  Future<void> _onSignalEvent(Map<String, dynamic> signal) async {
    if (_isEnded) return;

    final signalConversationId = signal['conversationId']?.toString();
    final signalCallId = signal['callId']?.toString();
    if (signalConversationId != conversationId || signalCallId != callId) {
      return;
    }

    final type = signal['type']?.toString();
    if (type == null || type.isEmpty) return;

    try {
      switch (type) {
        case 'offer':
          if (!isCaller) {
            await _handleOffer(signal);
          }
          break;
        case 'answer':
          if (isCaller) {
            await _handleAnswer(signal);
          }
          break;
        case 'ice-candidate':
          await _handleIceCandidate(signal);
          break;
        case 'end':
          await endCall(notifyPeer: false);
          break;
      }
    } catch (e) {
      _errorMessage = 'Lỗi xử lý tín hiệu cuộc gọi: $e';
      notifyListeners();
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> signal) async {
    final pc = _peerConnection;
    if (pc == null) return;
    final sdpMap = Map<String, dynamic>.from(signal['sdp'] ?? {});

    final offer = RTCSessionDescription(
      sdpMap['sdp']?.toString() ?? '',
      sdpMap['type']?.toString() ?? 'offer',
    );

    await pc.setRemoteDescription(offer);
    final answer = await pc.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': audioOnly ? 0 : 1,
    });
    await pc.setLocalDescription(answer);

    _socketService.sendCallAnswer(
      conversationId: conversationId,
      callId: callId,
      targetUserId: peerUserId,
      sdp: {'type': answer.type, 'sdp': answer.sdp},
    );
  }

  Future<void> _handleAnswer(Map<String, dynamic> signal) async {
    final pc = _peerConnection;
    if (pc == null) return;
    final sdpMap = Map<String, dynamic>.from(signal['sdp'] ?? {});

    final answer = RTCSessionDescription(
      sdpMap['sdp']?.toString() ?? '',
      sdpMap['type']?.toString() ?? 'answer',
    );

    await pc.setRemoteDescription(answer);
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> signal) async {
    final pc = _peerConnection;
    if (pc == null) return;

    final candidateMap = Map<String, dynamic>.from(signal['candidate'] ?? {});
    final candidate = RTCIceCandidate(
      candidateMap['candidate']?.toString(),
      candidateMap['sdpMid']?.toString(),
      candidateMap['sdpMLineIndex'] is int
          ? candidateMap['sdpMLineIndex'] as int
          : int.tryParse(candidateMap['sdpMLineIndex']?.toString() ?? ''),
    );

    await pc.addCandidate(candidate);
  }

  Future<void> toggleMicrophone() async {
    final audioTracks =
        _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    if (audioTracks.isEmpty) return;

    _isMicrophoneEnabled = !_isMicrophoneEnabled;
    for (final track in audioTracks) {
      track.enabled = _isMicrophoneEnabled;
    }
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await Helper.setSpeakerphoneOn(_isSpeakerOn);
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    if (audioOnly) return;
    final videoTracks =
        _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (videoTracks.isEmpty) return;

    _isCameraEnabled = !_isCameraEnabled;
    for (final track in videoTracks) {
      track.enabled = _isCameraEnabled;
    }
    notifyListeners();
  }

  Future<void> switchCamera() async {
    if (audioOnly) return;
    final videoTracks =
        _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (videoTracks.isEmpty) return;

    await Helper.switchCamera(videoTracks.first);
    _isUsingFrontCamera = !_isUsingFrontCamera;
    notifyListeners();
  }

  Future<void> endCall({bool notifyPeer = true}) async {
    if (_isEnded) return;

    _isEnded = true;
    _isConnected = false;

    if (notifyPeer) {
      _socketService.endCall(
        conversationId: conversationId,
        callId: callId,
        targetUserId: peerUserId,
      );
    }

    await _signalSubscription?.cancel();
    _signalSubscription = null;

    try {
      await _peerConnection?.close();
    } catch (_) {}
    _peerConnection = null;

    await _disposeStreams();
    notifyListeners();
  }

  Future<void> _disposeStreams() async {
    final localTracks = _localStream?.getTracks() ?? const <MediaStreamTrack>[];
    for (final track in localTracks) {
      track.stop();
    }
    await _localStream?.dispose();
    _localStream = null;

    final remoteTracks =
        _remoteStream?.getTracks() ?? const <MediaStreamTrack>[];
    for (final track in remoteTracks) {
      track.stop();
    }
    await _remoteStream?.dispose();
    _remoteStream = null;
  }

  @override
  void dispose() {
    unawaited(endCall(notifyPeer: false));
    super.dispose();
  }
}
