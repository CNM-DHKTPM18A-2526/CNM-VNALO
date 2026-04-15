import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class WebRtcCallService extends ChangeNotifier {
  static const int _defaultRingTimeoutSeconds = int.fromEnvironment(
    'CALL_RING_TIMEOUT_SECONDS',
    defaultValue: 38,
  );

  final SocketService _socketService;
  final String conversationId;
  final String callId;
  final String currentUserId;
  final String peerUserId;
  final bool audioOnly;
  final bool isCaller;
  final int ringTimeoutSeconds;
  final Map<String, dynamic>? initialSdp;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  StreamSubscription<Map<String, dynamic>>? _signalSubscription;
  final List<RTCIceCandidate> _pendingCandidates = [];
  Timer? _ringTimeoutTimer;

  bool _isInitializing = false;
  bool _isConnected = false;
  bool _isEnded = false;
  bool _isMicrophoneEnabled = true;
  bool _isSpeakerOn = true;
  bool _isCameraEnabled = true;
  bool _isUsingFrontCamera = true;
  String? _errorMessage;
  DateTime? _connectedAt;
  bool _hasRemoteDescription = false;
  String? _lastEndReason;
  bool _isAccepted = false;

  WebRtcCallService({
    required SocketService socketService,
    required this.conversationId,
    required this.callId,
    required this.currentUserId,
    required this.peerUserId,
    required this.audioOnly,
    required this.isCaller,
    this.initialSdp,
    int? ringTimeoutSeconds,
  }) : ringTimeoutSeconds =
           (ringTimeoutSeconds == null || ringTimeoutSeconds <= 0)
               ? _defaultRingTimeoutSeconds
               : ringTimeoutSeconds,
       _socketService = socketService;

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
  String? get lastEndReason => _lastEndReason;
  bool get isAccepted => _isAccepted;

  String get _logPrefix =>
      '[WebRtcCallService][callId=$callId][conv=$conversationId][peer=$peerUserId]';

  Future<void> initialize() async {
    if (_isInitializing || _peerConnection != null) return;
    _isInitializing = true;
    _errorMessage = null;
    _isCameraEnabled = !audioOnly;
    notifyListeners();

    _signalSubscription = _socketService.onCallSignal.listen(_onSignalEvent);
    debugPrint(
      '$_logPrefix initialize() start isCaller=$isCaller audioOnly=$audioOnly timeout=$ringTimeoutSeconds hasInitialSdp=${initialSdp != null}',
    );

    try {
      // Proactive permission check
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

      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          // Placeholder for TURN servers - requires credentials for production
          // {
          //   'urls': 'turn:your-turn-server.com:3478',
          //   'username': 'user',
          //   'credential': 'password'
          // },
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(configuration);
      debugPrint('$_logPrefix peerConnection created');
      _registerPeerCallbacks();

      if (isCaller) {
        _isAccepted = true; 
        await _openLocalMedia();
        await Helper.setSpeakerphoneOn(_isSpeakerOn);
        await _createAndSendOffer();
        _startRingTimeoutCountdown();
      } else {
        // Callee: Immediately process initial offer if provided
        if (initialSdp != null) {
          await _handleOffer(initialSdp!);
        }
        await Helper.setSpeakerphoneOn(_isSpeakerOn);
      }
    } catch (e) {
      _errorMessage = _mapInitError(e);
      debugPrint('$_logPrefix initialize() failed error=$_errorMessage');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  String _mapInitError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') || text.contains('notallowed') || text.contains('từ chối')) {
      return 'Không có quyền truy cập camera/micro. Vui lòng cấp quyền rồi thử lại.';
    }
    return 'Không thể khởi tạo cuộc gọi: $error';
  }

  void _registerPeerCallbacks() {
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isEmpty) return;
      _remoteStream = event.streams.first;
      debugPrint('$_logPrefix onTrack remote stream attached');
      notifyListeners();
    };

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      _socketService.sendCallIceCandidate(
        conversationId: conversationId,
        callId: callId,
        targetUserId: peerUserId,
        senderUserId: currentUserId,
        candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };

    _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('$_logPrefix onConnectionState=$state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        if (!_isConnected) {
          _isConnected = true;
          _connectedAt = DateTime.now();
          _ringTimeoutTimer?.cancel();
          notifyListeners();
        }
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
         _isConnected = false;
         notifyListeners();
      }
    };

    _peerConnection?.onSignalingState = (RTCSignalingState state) {
      debugPrint('$_logPrefix onSignalingState=$state');
    };

    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('$_logPrefix onIceConnectionState=$state');
      // Fallback for older WebRTC versions if onConnectionState is not consistent
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        if (!_isConnected) {
          _isConnected = true;
          _connectedAt = DateTime.now();
          _ringTimeoutTimer?.cancel();
          notifyListeners();
        }
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
    debugPrint(
      '$_logPrefix local media opened tracks=${_localStream?.getTracks().length ?? 0}',
    );
    final tracks = _localStream?.getTracks() ?? const <MediaStreamTrack>[];
    for (final track in tracks) {
      await _peerConnection?.addTrack(track, _localStream!);
    }
  }

  Future<void> acceptCall() async {
    if (_isAccepted || _isEnded) return;
    debugPrint('$_logPrefix acceptCall()');

    try {
      _isAccepted = true;
      notifyListeners();

      await _openLocalMedia();
      
      if (_hasRemoteDescription) {
        await _createAndSendAnswer();
      }
    } catch (e) {
      _errorMessage = 'Không thể chấp nhận cuộc gọi: $e';
      debugPrint('$_logPrefix acceptCall() failed error=$_errorMessage');
      notifyListeners();
    }
  }

  Future<void> _createAndSendAnswer() async {
    final pc = _peerConnection;
    if (pc == null) return;

    final answer = await pc.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': audioOnly ? 0 : 1,
    });
    await pc.setLocalDescription(answer);
    debugPrint('$_logPrefix local answer created and set');

    _socketService.sendCallAnswer(
      conversationId: conversationId,
      callId: callId,
      targetUserId: peerUserId,
      senderUserId: currentUserId,
      sdp: {'type': answer.type, 'sdp': answer.sdp},
    );
  }

  Future<void> _createAndSendOffer() async {
    final pc = _peerConnection;
    if (pc == null) return;

    final offer = await pc.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': audioOnly ? 0 : 1,
    });
    await pc.setLocalDescription(offer);
    debugPrint('$_logPrefix local offer created and set');

    _socketService.sendCallOffer(
      conversationId: conversationId,
      callId: callId,
      targetUserId: peerUserId,
      senderUserId: currentUserId,
      audioOnly: audioOnly,
      sdp: {'type': offer.type, 'sdp': offer.sdp},
    );
  }

  void _startRingTimeoutCountdown() {
    _ringTimeoutTimer?.cancel();
    if (!isCaller || ringTimeoutSeconds <= 0) return;

    _ringTimeoutTimer = Timer(Duration(seconds: ringTimeoutSeconds), () async {
      if (_isEnded || _isConnected) return;
      _errorMessage =
          'Người nhận chưa bắt máy sau $ringTimeoutSeconds giây. Cuộc gọi đã tự động kết thúc.';
      debugPrint(
        '$_logPrefix ring timeout reached after $ringTimeoutSeconds seconds',
      );
      notifyListeners();
      await endCall(reason: 'no-answer-timeout');
    });
  }

  Future<void> _onSignalEvent(Map<String, dynamic> signal) async {
    if (_isEnded) return;

    final signalConversationId = signal['conversationId']?.toString();
    final signalCallId = signal['callId']?.toString();
    if (signalConversationId != conversationId || signalCallId != callId) {
      return;
    }

    final senderUserId = _extractUserId(signal, ['senderUserId', 'senderId', 'fromUserId']);
    if (senderUserId != null && senderUserId.isNotEmpty && senderUserId != peerUserId) {
      return;
    }

    final type = signal['type']?.toString();
    if (type == null || type.isEmpty) return;
    
    // De-duplication check: if we already have the remote description for this type, skip.
    if (type == 'offer' && _hasRemoteDescription && !isCaller) {
      debugPrint('$_logPrefix skipping duplicate offer signal');
      return;
    }

    debugPrint('$_logPrefix received signal type=$type');

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
          await endCall(
            notifyPeer: false,
            reason: signal['reason']?.toString() ?? 'remote-ended',
          );
          break;
      }
    } catch (e) {
      debugPrint('$_logPrefix error processing signal type=$type: $e');
    }
  }

  String? _extractUserId(Map<String, dynamic> signal, List<String> keys) {
    for (final key in keys) {
      final value = signal[key]?.toString();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
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
    debugPrint('$_logPrefix remote offer set');
    _hasRemoteDescription = true;
    await _flushPendingCandidates();

    if (_isAccepted) {
      await _createAndSendAnswer();
    }
  }

  Future<void> _handleAnswer(Map<String, dynamic> signal) async {
    final pc = _peerConnection;
    if (pc == null) return;
    final sdpMap = Map<String, dynamic>.from(signal['sdp'] ?? {});

    final answer = RTCSessionDescription(
      sdpMap['sdp']?.toString() ?? '',
      sdpMap['type']?.toString() ?? 'answer',
    );

    // Guard against setting duplicate answers or racing signals
    if (pc.signalingState == RTCSignalingState.RTCSignalingStateStable) {
      debugPrint('$_logPrefix ignoring answer as pc is already stable');
      return;
    }

    await pc.setRemoteDescription(answer);
    debugPrint('$_logPrefix remote answer set');
    _hasRemoteDescription = true;
    await _flushPendingCandidates();
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> signal) async {
    final pc = _peerConnection;
    if (pc == null) return;

    final candidateMap = Map<String, dynamic>.from(signal['candidate'] ?? {});
    final candidateString = candidateMap['candidate']?.toString();
    if (candidateString == null) return;

    final candidate = RTCIceCandidate(
      candidateString,
      candidateMap['sdpMid']?.toString(),
      candidateMap['sdpMLineIndex'] is int
          ? candidateMap['sdpMLineIndex'] as int
          : int.tryParse(candidateMap['sdpMLineIndex']?.toString() ?? ''),
    );

    if (!_hasRemoteDescription) {
      debugPrint('$_logPrefix queue ICE candidate before remote description');
      _pendingCandidates.add(candidate);
      return;
    }

    debugPrint('$_logPrefix add ICE candidate immediately');
    await pc.addCandidate(candidate);
  }

  Future<void> _flushPendingCandidates() async {
    if (!_hasRemoteDescription || _pendingCandidates.isEmpty) return;
    final pc = _peerConnection;
    if (pc == null) return;

    for (final candidate in List<RTCIceCandidate>.from(_pendingCandidates)) {
      await pc.addCandidate(candidate);
    }
    debugPrint('$_logPrefix flushed ${_pendingCandidates.length} queued ICE candidates');
    _pendingCandidates.clear();
  }

  Future<void> toggleMicrophone() async {
    final audioTracks = _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[];
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
    final videoTracks = _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (videoTracks.isEmpty) return;

    _isCameraEnabled = !_isCameraEnabled;
    for (final track in videoTracks) {
      track.enabled = _isCameraEnabled;
    }
    notifyListeners();
  }

  Future<void> switchCamera() async {
    if (audioOnly) return;
    final videoTracks = _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (videoTracks.isEmpty) return;

    await Helper.switchCamera(videoTracks.first);
    _isUsingFrontCamera = !_isUsingFrontCamera;
    notifyListeners();
  }

  Future<void> endCall({
    bool notifyPeer = true,
    String reason = 'hangup',
  }) async {
    if (_isEnded) return;

    debugPrint('$_logPrefix endCall notifyPeer=$notifyPeer reason=$reason');

    _isEnded = true;
    _isConnected = false;
    _lastEndReason = reason;
    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = null;

    if (notifyPeer) {
      _socketService.endCall(
        conversationId: conversationId,
        callId: callId,
        targetUserId: peerUserId,
        senderUserId: currentUserId,
        reason: reason,
      );
    }

    await _signalSubscription?.cancel();
    _signalSubscription = null;

    try {
      await _peerConnection?.close();
    } catch (_) {}
    _peerConnection = null;
    _pendingCandidates.clear();
    _hasRemoteDescription = false;

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

    final remoteTracks = _remoteStream?.getTracks() ?? const <MediaStreamTrack>[];
    for (final track in remoteTracks) {
      track.stop();
    }
    await _remoteStream?.dispose();
    _remoteStream = null;
  }

  @override
  void dispose() {
    _ringTimeoutTimer?.cancel();
    unawaited(endCall(notifyPeer: false));
    super.dispose();
  }
}
