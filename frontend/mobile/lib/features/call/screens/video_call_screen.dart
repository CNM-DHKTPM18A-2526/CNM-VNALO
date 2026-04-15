import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/call/models/call_log_message.dart';
import 'package:vnalo_mobile/features/call/services/webrtc_call_service.dart';
import 'package:vnalo_mobile/features/call/services/ringtone_service.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/services/socket_service.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';

class VideoCallScreen extends StatefulWidget {
  final String conversationId;
  final String callId;
  final String targetUserId;
  final String targetDisplayName;
  final String? targetAvatarUrl;
  final bool isCaller;
  final Map<String, dynamic>? initialSdp; // KEPT SIGNALLING FIX

  const VideoCallScreen({
    super.key,
    required this.conversationId,
    required this.callId,
    required this.targetUserId,
    required this.targetDisplayName,
    this.targetAvatarUrl,
    required this.isCaller,
    this.initialSdp,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  // KEPT SIGNALLING FIX: Use nullable and sync init to prevent LateInitializationError
  WebRtcCallService? _callService;
  final RingtoneService _ringtoneService = RingtoneService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  Timer? _durationTimer;
  int _callDurationSeconds = 0;
  bool _logSent = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _renderersInitialized = false;

  @override
  void initState() {
    super.initState();
    _syncInitializeService();
    _asyncInitWork();
  }

  void _syncInitializeService() {
    // KEPT SIGNALLING FIX: Initialize service before any async wait
    final auth = context.read<AuthProvider>();
    final socket = context.read<SocketService>();

    _callService = WebRtcCallService(
      socketService: socket,
      conversationId: widget.conversationId,
      callId: widget.callId,
      currentUserId: auth.user!.id,
      peerUserId: widget.targetUserId,
      audioOnly: false,
      isCaller: widget.isCaller,
      initialSdp: widget.initialSdp,
    );

    _callService!.addListener(_onServiceUpdate);
  }

  Future<void> _asyncInitWork() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (mounted) setState(() => _renderersInitialized = true);

    if (_callService != null) {
      await _callService!.initialize();
      if (_callService!.errorMessage != null || _callService!.isEnded) return;

      if (widget.isCaller) {
        await _ringtoneService.startDialing();
      } else {
        await _ringtoneService.startRinging();
      }
    }
  }

  void _onServiceUpdate() {
    if (!mounted || _callService == null) return;

    if (_renderersInitialized) {
      if (_callService!.localStream != null &&
          _localRenderer.srcObject != _callService!.localStream) {
        _localRenderer.srcObject = _callService!.localStream;
      }
      if (_callService!.remoteStream != null &&
          _remoteRenderer.srcObject != _callService!.remoteStream) {
        _remoteRenderer.srcObject = _callService!.remoteStream;
      }
    }

    if (_callService!.isConnected && _durationTimer == null) {
      _ringtoneService.stop();
      _startDurationTimer();
      _startHideControlsTimer();
    }

    if (_callService!.isEnded) {
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
        setState(() => _callDurationSeconds++);
      }
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _callService?.isConnected == true && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) _startHideControlsTimer();
    });
  }

  void _sendCallLogIfNeeded() {
    if (_logSent || !widget.isCaller || _callService == null) return;
    _logSent = true;

    final chatProvider = context.read<ChatProvider>();
    final outcome = _deriveOutcome();

    final log = CallLogMessage(
      callId: widget.callId,
      conversationId: widget.conversationId,
      callerId:
          widget.isCaller ? _callService!.currentUserId : widget.targetUserId,
      calleeId:
          widget.isCaller ? widget.targetUserId : _callService!.currentUserId,
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
    if (_callService?.connectedAt != null) return CallOutcome.answered;
    switch (_callService?.lastEndReason) {
      case 'declined':
        return CallOutcome.declined;
      case 'busy':
        return CallOutcome.busy;
      case 'no-answer-timeout':
        return CallOutcome.missed;
      case 'failed':
        return CallOutcome.failed;
      default:
        return CallOutcome.missed;
    }
  }

  void _endCallAndClose() {
    _callService?.endCall();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _hideControlsTimer?.cancel();
    _callService?.removeListener(_onServiceUpdate);
    _callService?.dispose();
    _ringtoneService.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_callService == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ROLLBACK TO ORIGINAL UI WIDGETS FROM MAIN BRANCH
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Remote Video
            Positioned.fill(
              child:
                  _callService!.remoteStream != null && _renderersInitialized
                      ? RTCVideoView(
                        _remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                      : _RemotePlaceholder(
                        name: widget.targetDisplayName,
                        avatarUrl: widget.targetAvatarUrl,
                        status: _buildStatusText(),
                      ),
            ),

            // Local Video Preview
            if (_callService!.localStream != null && _renderersInitialized)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: Container(
                  width: 100,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),

            // UI Overlays
            AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: SafeArea(
                child: Stack(
                  children: [
                    // Top Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          _TopCircleIconButton(
                            icon: Icons.keyboard_arrow_down,
                            onTap: _endCallAndClose,
                          ),
                        ],
                      ),
                    ),
                    // Caller Info in Waiting State
                    if (!_callService!.isConnected)
                      Positioned(
                        top: 100,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            Text(
                              widget.targetDisplayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(color: Colors.black45, blurRadius: 15),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _buildStatusText(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(color: Colors.black45, blurRadius: 10),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Remote Participant Info Card (if connected)
            if (_callService!.isConnected)
              Positioned(
                top: MediaQuery.of(context).padding.top + 80,
                left: 16,
                child: _SmallParticipantView(
                  displayName: widget.targetDisplayName,
                  status: _buildStatusText(),
                ),
              ),

            // Bottom Panel
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
                    color: Colors.black.withValues(alpha: 0.25),
                    child: _buildCallControls(_callService!),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildStatusText() {
    if (_callService == null) return '';
    if (_callService!.errorMessage != null) return _callService!.errorMessage!;
    if (_callService!.isEnded) return 'Cuộc gọi kết thúc';
    if (_callService!.isConnected) {
      final m = _callDurationSeconds ~/ 60;
      final s = _callDurationSeconds % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    if (_callService!.isInitializing) return 'Đang khởi tạo...';
    if (widget.isCaller) return 'Đang gọi...';
    return isAccepted ? 'Đang trả lời...' : 'Cuộc gọi đến...';
  }

  bool get isAccepted => _callService?.isAccepted ?? false;

  Widget _buildCallControls(WebRtcCallService callService) {
    if (callService.isEnded) {
      return const SizedBox(height: 80);
    }

    if (!widget.isCaller && !callService.isAccepted) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _VideoActionButton(
            icon: Icons.call_end,
            label: 'Từ chối',
            onTap: () => callService.endCall(reason: 'declined'),
            active: false,
            destructive: true,
          ),
          _VideoActionButton(
            icon: Icons.videocam,
            label: 'Chấp nhận',
            onTap: () => callService.acceptCall(),
            active: true,
            color: const Color(0xFF4CD964),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _VideoActionButton(
          icon:
              callService.isCameraEnabled ? Icons.videocam : Icons.videocam_off,
          label: 'Camera',
          onTap: () => unawaited(callService.toggleCamera()),
          active: callService.isCameraEnabled,
        ),
        _VideoActionButton(
          icon:
              callService.isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
          label: 'Mic',
          onTap: () => unawaited(callService.toggleMicrophone()),
          active: callService.isMicrophoneEnabled,
        ),
        _VideoActionButton(
          icon: Icons.call_end,
          label: 'Kết thúc',
          onTap: _endCallAndClose,
          active: false,
          destructive: true,
        ),
        _VideoActionButton(
          icon: Icons.more_horiz,
          label: 'Thêm',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tính năng đang phát triển')),
            );
          },
          active: true,
        ),
      ],
    );
  }
}

class _TopCircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopCircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: 28)),
      ),
    );
  }
}

class _SmallParticipantView extends StatelessWidget {
  final String displayName;
  final String status;

  const _SmallParticipantView({required this.displayName, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RemotePlaceholder extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String status;

  const _RemotePlaceholder({
    required this.name,
    required this.avatarUrl,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF020617), Color(0xFF0F172A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AvatarWidget(imageUrl: avatarUrl, name: name, size: 112),
          const SizedBox(height: 20),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            status,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final bool active;
  final bool destructive;
  final Color? color;

  const _VideoActionButton({
    required this.icon,
    this.label,
    required this.onTap,
    required this.active,
    this.destructive = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        color ??
        (destructive
            ? const Color(0xFFFF3B30)
            : Colors.black.withValues(alpha: 0.5));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                if (destructive)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Center(child: Icon(icon, color: Colors.white, size: 34)),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
