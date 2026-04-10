import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vnalo_mobile/services/socket_service.dart';
import 'package:permission_handler/permission_handler.dart';

enum CallState { idle, ringing, connected, ended }

class CallProvider extends ChangeNotifier {
  final SocketService _socketService;
  
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  CallState _state = CallState.idle;
  bool _isVideoCall = false;
  String? _targetUserId;
  String? _currentCallId;
  
  // Getters
  CallState get state => _state;
  bool get isVideoCall => _isVideoCall;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  
  StreamSubscription? _incomingSub;
  StreamSubscription? _answeredSub;
  StreamSubscription? _signalSub;
  StreamSubscription? _endedSub;

  CallProvider(this._socketService) {
    _listenToSignaling();
  }

  void _listenToSignaling() {
    _incomingSub = _socketService.onCallIncoming.listen((data) {
      if (_state != CallState.idle) return; // Busy
      
      _currentCallId = data['conversationId'];
      _targetUserId = data['callerId'];
      _isVideoCall = data['isVideo'];
      _state = CallState.ringing;
      notifyListeners();
      
      // UI will show IncomingCallDialog based on this state
    });

    _answeredSub = _socketService.onCallAnswered.listen((data) async {
      if (data['accepted']) {
        _state = CallState.connected;
        notifyListeners();
      } else {
        _cleanupCall();
      }
    });

    _signalSub = _socketService.onCallSignal.listen((data) async {
      final signal = data['signal'];
      if (signal['type'] == 'offer') {
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(signal['sdp'], signal['type']),
        );
        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        _socketService.sendCallSignal(
          targetUserId: _targetUserId!,
          signal: {'type': answer.type, 'sdp': answer.sdp},
        );
      } else if (signal['type'] == 'answer') {
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(signal['sdp'], signal['type']),
        );
      } else if (signal['candidate'] != null) {
        await _peerConnection?.addCandidate(
          RTCIceCandidate(
            signal['candidate'],
            signal['sdpMid'],
            signal['sdpMLineIndex'],
          ),
        );
      }
    });

    _endedSub = _socketService.onCallEnded.listen((_) {
      _cleanupCall();
    });
  }

  Future<void> startCall({
    required String targetUserId,
    required String conversationId,
    required bool isVideo,
  }) async {
    _targetUserId = targetUserId;
    _currentCallId = conversationId;
    _isVideoCall = isVideo;
    _state = CallState.ringing;
    
    await _initRTC();
    
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    _socketService.initiateCall(
      targetUserId: targetUserId,
      conversationId: conversationId,
      isVideo: isVideo,
    );
    
    _socketService.sendCallSignal(
      targetUserId: targetUserId,
      signal: {'type': offer.type, 'sdp': offer.sdp},
    );
    
    notifyListeners();
  }

  Future<void> acceptCall() async {
    if (_targetUserId == null) return;
    
    await _initRTC();
    _socketService.answerCall(targetUserId: _targetUserId!, accepted: true);
    _state = CallState.connected;
    notifyListeners();
  }

  void rejectCall() {
    if (_targetUserId != null) {
      _socketService.answerCall(targetUserId: _targetUserId!, accepted: false);
    }
    _cleanupCall();
  }

  void endCall() {
    if (_targetUserId != null) {
      _socketService.endCall(targetUserId: _targetUserId!);
    }
    _cleanupCall();
  }

  Future<void> _initRTC() async {
    // Request permissions
    await [Permission.microphone, Permission.camera].request();

    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
        {'url': 'stun:stun1.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (candidate) {
      if (_targetUserId != null) {
        _socketService.sendCallSignal(
          targetUserId: _targetUserId!,
          signal: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        );
      }
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        notifyListeners();
      }
    };

    // Get local stream
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': _isVideoCall ? {
        'facingMode': 'user',
        'width': '640',
        'height': '480',
      } : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    notifyListeners();
  }

  void _cleanupCall() {
    _state = CallState.idle;
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _remoteStream?.dispose();
    _peerConnection?.dispose();
    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    _targetUserId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _answeredSub?.cancel();
    _signalSub?.cancel();
    _endedSub?.cancel();
    _cleanupCall();
    super.dispose();
  }
}
