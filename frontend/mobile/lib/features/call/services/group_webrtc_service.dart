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

      debugPrint('[GroupWebRtcService] Emitting group-call:started');
      _socketService.emitGroupCallStarted(
        conversationId: conversationId,
        callId: callId,
        audioOnly: audioOnly,
        senderUserId: currentUserId,
        senderName: displayName,
        senderAvatarUrl: null,
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

      debugPrint('[GroupWebRtcService] Emitting group-call:join');
      // Emit join signal so the caller knows we've joined
      _socketService.emitGroupCallJoin(
        conversationId: conversationId,
        callId: callId,
        senderUserId: currentUserId,
        senderName: displayName,
        senderAvatarUrl: null,
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
    debugPrint('[GroupWebRtcService] Local media opened, tracks: ${_localStream?.getTracks().length}');
    notifyListeners();
  }

  /// Create a PeerConnection for a specific participant
  Future<RTCPeerConnection> _createPeerConnectionForParticipant(String odUserId) async {
    debugPrint('[GroupWebRtcService] Creating PeerConnection for: $odUserId');
    
    final config = {
      'iceServers': CallConfig.getIceServers(),
      'sdpSemantics': 'unified-plan',
    };

    final pc = await createPeerConnection(config);
    debugPrint('[GroupWebRtcService] PeerConnection created for: $odUserId');

    // *** CRITICAL: Add local tracks so the remote peer can see/hear us ***
    // Use addTrack for more reliable track handling
    if (_localStream != null) {
      debugPrint('[GroupWebRtcService] Adding ${_localStream!.getTracks().length} tracks to PC');
      for (final track in _localStream!.getTracks()) {
        try {
          await pc.addTrack(track, _localStream!);
          debugPrint('[GroupWebRtcService] Added ${track.kind} track to PC for $odUserId');
        } catch (e) {
          debugPrint('[GroupWebRtcService] addTrack failed: $e');
        }
      }
    }

    // onTrack: Called when remote stream arrives
    pc.onTrack = (RTCTrackEvent event) {
      debugPrint('[GroupWebRtcService] onTrack fired for $odUserId, track kind: ${event.track.kind}, streams: ${event.streams.length}');
      
      final participant = _participants[odUserId];
      if (participant == null) {
        debugPrint('[GroupWebRtcService] onTrack but participant $odUserId not found!');
        return;
      }
      
      if (event.streams.isNotEmpty) {
        participant.remoteStream = event.streams.first;
        participant.isConnected = true;
        _connectedAt ??= DateTime.now();
        debugPrint('[GroupWebRtcService] Remote stream set for $odUserId, isConnected=true');
      } else {
        // Fallback: track without stream - mark as connected but stream is null
        // The renderer will show placeholder in this case
        debugPrint('[GroupWebRtcService] No streams in onTrack - track received but no stream');
        participant.isConnected = true;
        _connectedAt ??= DateTime.now();
      }
      
      notifyListeners();
    };

    // onIceCandidate: Send ICE candidates to remote peer
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) {
        debugPrint('[GroupWebRtcService] ICE candidate is null (end of candidates)');
        return;
      }
      debugPrint('[GroupWebRtcService] ICE candidate for $odUserId: ${candidate.candidate!.substring(0, 50)}...');
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

    // onConnectionState: Track connection state
    pc.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[GroupWebRtcService] PC state for $odUserId: $state');
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _connectedAt ??= DateTime.now();
          debugPrint('[GroupWebRtcService] PC Connected for $odUserId!');
          notifyListeners();
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          debugPrint('[GroupWebRtcService] PC Failed for $odUserId - restarting ICE');
          pc.restartIce();
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          debugPrint('[GroupWebRtcService] PC Disconnected for $odUserId');
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          debugPrint('[GroupWebRtcService] PC Closed for $odUserId');
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
          debugPrint('[GroupWebRtcService] PC Connecting for $odUserId...');
          break;
        default:
          break;
      }
    };

    // onIceConnectionState: Alternative connection tracking
    pc.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[GroupWebRtcService] ICE state for $odUserId: $state');
    };

    // Start polling timer to check for remote streams every 2 seconds
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isEnded || _participants[odUserId]?.remoteStream != null) {
        timer.cancel();
        return;
      }
      // Check transceivers periodically
      pc.getTransceivers().then((transceivers) {
        debugPrint('[GroupWebRtcService] Polling: ${transceivers.length} transceivers for $odUserId');
        for (final transceiver in transceivers) {
          if (transceiver.receiver.track != null) {
            debugPrint('[GroupWebRtcService] Polling: Found track in transceiver');
          }
        }
      });
    });

    return pc;
  }

  Future<void> _onGroupSignalEvent(Map<String, dynamic> signal) async {
    if (_isEnded) return;
    
    final type = signal['type']?.toString();
    if (type == null) {
      debugPrint('[GroupWebRtcService] Signal with null type: $signal');
      return;
    }

    // Get sender ID from various possible fields (backend may use different names)
    final senderId = signal['senderUserId']?.toString() ?? 
                     signal['fromUserId']?.toString() ?? 
                     signal['userId']?.toString() ??
                     signal['callerUserId']?.toString() ?? '';
    
    // Get display name from various possible fields
    final senderName = signal['senderName']?.toString() ?? 
                       signal['displayName']?.toString() ??
                       signal['callerName']?.toString() ?? senderId;
    
    // Get avatar from various possible fields  
    final senderAvatarUrl = signal['senderAvatarUrl']?.toString() ?? 
                            signal['avatarUrl']?.toString() ??
                            signal['callerAvatar']?.toString();
    
    debugPrint('[GroupWebRtcService][RECV] type=$type from=$senderId (me=$currentUserId)');
    debugPrint('[GroupWebRtcService][RECV] full signal: $signal');

    // Skip signals from ourselves
    if (senderId == currentUserId) {
      debugPrint('[GroupWebRtcService] Skipping own signal');
      return;
    }

    switch (type) {
      case 'started':
        debugPrint('[GroupWebRtcService] Received started event');
        // This is for incoming call notification - handled by UI
        // Optionally create participant entry for the caller
        if (senderId.isNotEmpty && !_participants.containsKey(senderId)) {
          debugPrint('[GroupWebRtcService] Creating participant from started event: $senderId');
          final participant = Participant(
            odUserId: senderId,
            displayName: senderName,
            avatarUrl: senderAvatarUrl,
          );
          _participants[senderId] = participant;
          notifyListeners();
        }
        break;
        
      case 'join':
        debugPrint('[GroupWebRtcService] Participant sent join: $senderId');
        await _handleParticipantJoined(senderId, signal);
        break;
        
      case 'user-joined':
        debugPrint('[GroupWebRtcService] Participant joined: $senderId');
        await _handleParticipantJoined(senderId, signal);
        break;
        
      case 'offer':
        debugPrint('[GroupWebRtcService] Received offer from: $senderId');
        await _handleOffer(senderId, signal);
        break;
        
      case 'answer':
        debugPrint('[GroupWebRtcService] Received answer from: $senderId');
        await _handleAnswer(senderId, signal);
        break;
        
      case 'ice-candidate':
        debugPrint('[GroupWebRtcService] Received ICE candidate from: $senderId');
        await _handleIceCandidate(senderId, signal);
        break;
        
      case 'user-left':
      case 'leave':
        debugPrint('[GroupWebRtcService] Participant left: $senderId');
        _handleParticipantLeft(senderId);
        break;
        
      case 'ended':
        debugPrint('[GroupWebRtcService] Call ended by server/caller');
        _safeEnd();
        break;
        
      case 'mute-state':
        debugPrint('[GroupWebRtcService] Mute state changed: $senderId');
        _handleMuteStateChange(senderId, signal);
        break;
        
      default:
        debugPrint('[GroupWebRtcService] Unknown signal type: $type');
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

  /// Handle when a participant joins - create offer for them
  Future<void> _handleParticipantJoined(String odUserId, Map<String, dynamic> signal) async {
    debugPrint('[GroupWebRtcService] _handleParticipantJoined: $odUserId, _isAccepted=$_isAccepted');
    
    // Don't create duplicate connections
    if (_participants.containsKey(odUserId)) {
      debugPrint('[GroupWebRtcService] Participant $odUserId already exists');
      return;
    }
    
    // Can only create connection if we've accepted the call
    if (!_isAccepted) {
      debugPrint('[GroupWebRtcService] Not accepted yet, skipping join for $odUserId');
      return;
    }

    // Get display name and avatar from various possible fields
    final displayName = signal['senderName']?.toString() ?? 
                        signal['displayName']?.toString() ??
                        signal['callerName']?.toString() ??
                        odUserId;
    final avatarUrl = signal['senderAvatarUrl']?.toString() ?? 
                      signal['avatarUrl']?.toString() ??
                      signal['callerAvatar']?.toString();

    debugPrint('[GroupWebRtcService] Creating participant: $odUserId, name: $displayName');

    // Create participant entry
    final participant = Participant(
      odUserId: odUserId,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
    _participants[odUserId] = participant;
    notifyListeners();

    // Create peer connection and add tracks
    debugPrint('[GroupWebRtcService] Creating peer connection for $odUserId');
    final pc = await _createPeerConnectionForParticipant(odUserId);
    _participants[odUserId]!.peerConnection = pc;
    debugPrint('[GroupWebRtcService] Peer connection created for $odUserId');

    // Create and send offer
    debugPrint('[GroupWebRtcService] Creating offer for $odUserId');
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    
    debugPrint('[GroupWebRtcService] Sending offer to $odUserId');
    _socketService.emitGroupCallOffer(
      conversationId: conversationId,
      callId: callId,
      targetUserId: odUserId,
      sdp: {'type': offer.type, 'sdp': offer.sdp},
      senderUserId: currentUserId,
    );
    debugPrint('[GroupWebRtcService] Offer sent to $odUserId');
  }

  /// Handle incoming offer - create answer
  Future<void> _handleOffer(String odUserId, Map<String, dynamic> signal) async {
    debugPrint('[GroupWebRtcService] _handleOffer from: $odUserId, _isAccepted=$_isAccepted');
    
    if (!_isAccepted) {
      debugPrint('[GroupWebRtcService] Not accepted yet, skipping offer from $odUserId');
      return;
    }

    // Get display name and avatar from various possible fields
    final displayName = signal['senderName']?.toString() ?? 
                        signal['displayName']?.toString() ??
                        signal['callerName']?.toString() ??
                        odUserId;
    final avatarUrl = signal['senderAvatarUrl']?.toString() ?? 
                      signal['avatarUrl']?.toString() ??
                      signal['callerAvatar']?.toString();

    // Get or create participant
    var participant = _participants[odUserId];
    if (participant == null) {
      debugPrint('[GroupWebRtcService] Creating participant from offer: $odUserId');
      participant = Participant(
        odUserId: odUserId,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      _participants[odUserId] = participant;
      notifyListeners();
    }

    // Check if we already have a PC (shouldn't happen for offer)
    if (_participants[odUserId]!.peerConnection != null) {
      debugPrint('[GroupWebRtcService] PC already exists for $odUserId, reusing');
    } else {
      // Create new peer connection with local tracks
      debugPrint('[GroupWebRtcService] Creating new PC for offer from $odUserId');
      final pc = await _createPeerConnectionForParticipant(odUserId);
      _participants[odUserId]!.peerConnection = pc;
    }

    // Set remote description (the offer)
    final sdpMap = Map<String, dynamic>.from(signal['sdp'] ?? {});
    final sdpStr = sdpMap['sdp']?.toString() ?? '';
    final typeStr = sdpMap['type']?.toString() ?? 'offer';
    
    debugPrint('[GroupWebRtcService] Setting remote description for $odUserId, sdp length: ${sdpStr.length}');
    
    await _participants[odUserId]!.peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdpStr, typeStr),
    );
    debugPrint('[GroupWebRtcService] Remote description set for $odUserId');

    // Create and send answer
    debugPrint('[GroupWebRtcService] Creating answer for $odUserId');
    final answer = await _participants[odUserId]!.peerConnection!.createAnswer();
    await _participants[odUserId]!.peerConnection!.setLocalDescription(answer);
    
    debugPrint('[GroupWebRtcService] Sending answer to $odUserId');
    _socketService.emitGroupCallAnswer(
      conversationId: conversationId,
      callId: callId,
      targetUserId: odUserId,
      sdp: {'type': answer.type, 'sdp': answer.sdp},
      senderUserId: currentUserId,
    );
    debugPrint('[GroupWebRtcService] Answer sent to $odUserId');
  }

  /// Handle incoming answer - complete the connection
  Future<void> _handleAnswer(String odUserId, Map<String, dynamic> signal) async {
    debugPrint('[GroupWebRtcService] _handleAnswer from: $odUserId');
    
    final pc = _participants[odUserId]?.peerConnection;
    if (pc == null) {
      debugPrint('[GroupWebRtcService] No peer connection for $odUserId when receiving answer!');
      // Try to create connection as fallback
      await _handleParticipantJoined(odUserId, {});
      return;
    }

    final sdpMap = Map<String, dynamic>.from(signal['sdp'] ?? {});
    final sdpStr = sdpMap['sdp']?.toString() ?? '';
    final typeStr = sdpMap['type']?.toString() ?? 'answer';
    
    debugPrint('[GroupWebRtcService] Setting remote description (answer) for $odUserId');
    
    await pc.setRemoteDescription(
      RTCSessionDescription(sdpStr, typeStr),
    );
    
    debugPrint('[GroupWebRtcService] Answer applied for $odUserId, waiting for ICE...');
  }

  /// Handle incoming ICE candidate
  Future<void> _handleIceCandidate(String odUserId, Map<String, dynamic> signal) async {
    debugPrint('[GroupWebRtcService] _handleIceCandidate from: $odUserId');
    
    final pc = _participants[odUserId]?.peerConnection;
    if (pc == null) {
      debugPrint('[GroupWebRtcService] No peer connection for $odUserId when receiving ICE candidate!');
      return;
    }

    final candidateMap = Map<String, dynamic>.from(signal['candidate'] ?? {});
    final candidateStr = candidateMap['candidate']?.toString();
    if (candidateStr == null) {
      debugPrint('[GroupWebRtcService] ICE candidate string is null');
      return;
    }

    debugPrint('[GroupWebRtcService] Adding ICE candidate for $odUserId');
    
    await pc.addCandidate(RTCIceCandidate(
      candidateStr,
      candidateMap['sdpMid']?.toString(),
      candidateMap['sdpMLineIndex'] is int
          ? candidateMap['sdpMLineIndex'] as int
          : int.tryParse(candidateMap['sdpMLineIndex']?.toString() ?? ''),
    ));
    
    debugPrint('[GroupWebRtcService] ICE candidate added for $odUserId');
  }

  void _handleParticipantLeft(String odUserId) {
    debugPrint('[GroupWebRtcService] Participant left: $odUserId');
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
    debugPrint('[GroupWebRtcService] Ending call');
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
