import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/call/models/call_log_message.dart';
import 'package:vnalo_mobile/features/call/services/webrtc_call_service.dart';
import 'package:vnalo_mobile/features/call/services/ringtone_service.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/services/socket_service.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class VideoCallScreen extends StatefulWidget {
  final String conversationId;
  final String callId;
  final String peerUserId;
  final String peerName;
  final String? peerAvatar;
  final bool isCaller;
  final Map<String, dynamic>? initialSdp;

  const VideoCallScreen({
    super.key,
    required this.conversationId,
    required this.callId,
    required this.peerUserId,
    required this.peerName,
    this.peerAvatar,
    required this.isCaller,
    this.initialSdp,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late WebRtcCallService _callService;
  final RingtoneService _ringtoneService = RingtoneService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  Timer? _durationTimer;
  int _callDurationSeconds = 0;
  bool _logSent = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _initializeCall();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _initializeCall() async {
    final auth = context.read<AuthProvider>();
    final socket = context.read<SocketService>();

    _callService = WebRtcCallService(
      socketService: socket,
      conversationId: widget.conversationId,
      callId: widget.callId,
      currentUserId: auth.user!.id,
      peerUserId: widget.peerUserId,
      audioOnly: false,
      isCaller: widget.isCaller,
      initialSdp: widget.initialSdp,
    );

    _callService.addListener(_onServiceUpdate);
    await _callService.initialize();

    if (_callService.errorMessage != null || _callService.isEnded) {
      return;
    }

    if (widget.isCaller) {
      await _ringtoneService.startDialing();
    } else {
      await _ringtoneService.startRinging();
    }
  }

  void _onServiceUpdate() {
    if (!mounted) return;

    if (_callService.localStream != null && _localRenderer.srcObject == null) {
      _localRenderer.srcObject = _callService.localStream;
    }

    if (_callService.remoteStream != null && _remoteRenderer.srcObject == null) {
      _remoteRenderer.srcObject = _callService.remoteStream;
    }

    if (_callService.isConnected && _durationTimer == null) {
      _ringtoneService.stop();
      _startDurationTimer();
      _startHideControlsTimer();
    }

    if (_callService.isEnded) {
      _ringtoneService.stop();
      _durationTimer?.cancel();
      _hideControlsTimer?.cancel();
      _sendCallLogIfNeeded();
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) Navigator.of(context).pop();
      });
    }

    setState(() {});
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDurationSeconds++;
        });
      }
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _callService.isConnected) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideControlsTimer();
  }

  void _sendCallLogIfNeeded() {
    if (_logSent || !widget.isCaller) return;
    _logSent = true;

    final chatProvider = context.read<ChatProvider>();
    final outcome = _deriveOutcome();

    final log = CallLogMessage(
      callId: widget.callId,
      conversationId: widget.conversationId,
      callerId: widget.isCaller ? _callService.currentUserId : widget.peerUserId,
      calleeId: widget.isCaller ? widget.peerUserId : _callService.currentUserId,
      mediaType: CallMediaType.video,
      outcome: outcome,
      durationSeconds: _callDurationSeconds,
      createdAt: DateTime.now(),
    );

    chatProvider.sendMessage(
      conversationId: widget.conversationId,
      content: log.toMessageContent(),
    );
  }

  CallOutcome _deriveOutcome() {
    if (_callService.connectedAt != null) {
      return CallOutcome.answered;
    }

    switch (_callService.lastEndReason) {
      case 'declined':
        return CallOutcome.declined;
      case 'busy':
        return CallOutcome.busy;
      case 'no-answer-timeout':
        return CallOutcome.missed;
      case 'failed':
      case 'permission-denied':
        return CallOutcome.failed;
      default:
        return CallOutcome.missed;
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _hideControlsTimer?.cancel();
    _callService.removeListener(_onServiceUpdate);
    _callService.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _ringtoneService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Remote Video
            _buildRemoteVideo(),

            // Local Video (Overlay)
            _buildLocalVideoOverlay(),

            // Overlay Info (Name, Status)
            if (_showControls || !_callService.isConnected)
              _buildTopOverlay(),

            // Error Overlay
            if (_callService.errorMessage != null)
              _buildErrorOverlay(),

            // Bottom Controls
            if (_showControls || !_callService.isConnected)
              _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    if (_callService.remoteStream == null || !_callService.isConnected) {
      return Container(
        color: const Color(0xFF1A1A1A),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLargeAvatar(),
              const SizedBox(height: 24),
              Text(
                widget.peerName,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildStatusText(),
            ],
          ),
        ),
      );
    }

    return RTCVideoView(
      _remoteRenderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }

  Widget _buildLocalVideoOverlay() {
    if (_callService.localStream == null || _callService.isEnded) return const SizedBox.shrink();

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      right: 16,
      top: (_showControls || !_callService.isConnected) ? 100 : 32,
      child: Container(
        width: 120,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        clipBehavior: Clip.hardEdge,
        child: _callService.isCameraEnabled
            ? RTCVideoView(
                _localRenderer,
                mirror: _callService.isUsingFrontCamera,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            : const Center(child: Icon(Icons.videocam_off, color: Colors.white54)),
      ),
    );
  }

  Widget _buildLargeAvatar() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 4),
        image: widget.peerAvatar != null
            ? DecorationImage(image: NetworkImage(widget.peerAvatar!), fit: BoxFit.cover)
            : null,
      ),
      child: widget.peerAvatar == null
          ? const Icon(Icons.person, size: 80, color: Colors.white54)
          : null,
    );
  }

  Widget _buildTopOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => _callService.endCall(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.peerName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_callService.isConnected)
                    _buildDurationDisplay(),
                ],
              ),
            ),
            if (_callService.isConnected)
              IconButton(
                icon: const Icon(Icons.switch_camera, color: Colors.white),
                onPressed: () => _callService.switchCamera(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationDisplay() {
    final minutes = _callDurationSeconds ~/ 60;
    final seconds = _callDurationSeconds % 60;
    return Text(
      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      style: const TextStyle(color: Colors.white70, fontSize: 14),
    );
  }

  Widget _buildStatusText() {
    String status = '';
    if (_callService.isEnded) {
      status = 'Cuộc gọi kết thúc';
    } else if (_callService.isInitializing) {
      status = 'Đang khởi tạo...';
    } else if (widget.isCaller) {
      status = 'Đang gọi...';
    } else {
      status = 'Cuộc gọi đến...';
    }

    return Text(status, style: const TextStyle(color: Colors.white70, fontSize: 18));
  }

  Widget _buildErrorOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
        child: Text(
          _callService.errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: _callService.isEnded
            ? const SizedBox.shrink()
            : (!widget.isCaller && !_callService.isAccepted)
                ? _buildIncomingControls()
                : _buildActiveControls(),
      ),
    );
  }

  Widget _buildIncomingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: Icons.call_end,
          color: Colors.red,
          onPressed: () => _callService.endCall(reason: 'declined'),
        ),
        _buildControlButton(
          icon: Icons.videocam,
          color: Colors.green,
          onPressed: () => _callService.acceptCall(),
        ),
      ],
    );
  }

  Widget _buildActiveControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: _callService.isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
          color: _callService.isMicrophoneEnabled ? Colors.white24 : Colors.redAccent,
          onPressed: () => _callService.toggleMicrophone(),
        ),
        _buildControlButton(
          icon: _callService.isCameraEnabled ? Icons.videocam : Icons.videocam_off,
          color: _callService.isCameraEnabled ? Colors.white24 : Colors.redAccent,
          onPressed: () => _callService.toggleCamera(),
        ),
        _buildControlButton(
          icon: Icons.call_end,
          color: Colors.red,
          onPressed: () => _callService.endCall(),
        ),
        _buildControlButton(
          icon: _callService.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
          color: _callService.isSpeakerOn ? AppColors.primary : Colors.white24,
          onPressed: () => _callService.toggleSpeaker(),
        ),
      ],
    );
  }

  Widget _buildControlButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
