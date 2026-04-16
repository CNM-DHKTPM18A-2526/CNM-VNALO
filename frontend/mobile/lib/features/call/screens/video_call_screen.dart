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
import 'package:wakelock_plus/wakelock_plus.dart';

class VideoCallScreen extends StatefulWidget {
  final String conversationId;
  final String callId;
  final String targetUserId;
  final String targetDisplayName;
  final String? targetAvatarUrl;
  final bool isCaller;
  final Map<String, dynamic>? initialSdp;

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

  // DRAGGABLE POSITION FOR LOCAL PREVIEW
  Offset _localVideoOffset = const Offset(16, 120);
  final double _popupWidth = 110;
  final double _popupHeight = 165;

  @override
  void initState() {
    super.initState();
    _syncInitializeService();
    _asyncInitWork();
  }

  void _syncInitializeService() {
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

      // Enable WakeLock
      unawaited(WakelockPlus.enable());
    }
  }

  bool _isPopping = false;

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

    if (_callService!.isEnded && !_isPopping) {
      _isPopping = true;
      _ringtoneService.stop();
      _durationTimer?.cancel();
      _hideControlsTimer?.cancel();
      _sendCallLogIfNeeded();
      
      // Snappier return for timeout, standard for others
      final bool isTimeout = _callService!.lastEndReason == 'no-answer-timeout';
      Future.delayed(Duration(milliseconds: isTimeout ? 500 : 1000), () {
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
    unawaited(WakelockPlus.disable());
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

    final bool isConnected = _callService!.isConnected;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. BACKGROUND: MIRRORED LOCAL CAMERA IF WAITING, ELSE REMOTE
            Positioned.fill(
              child:
                  isConnected &&
                          _callService!.remoteStream != null &&
                          _renderersInitialized
                      ? RTCVideoView(
                        _remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                      : (_callService!.localStream != null &&
                              _renderersInitialized
                          ? RTCVideoView(
                            _localRenderer,
                            mirror: true,
                            objectFit:
                                RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitCover,
                          )
                          : _RemotePlaceholder(
                            name: widget.targetDisplayName,
                            avatarUrl: widget.targetAvatarUrl,
                            status: _buildStatusText(),
                          )),
            ),

            // 2. DRAGGABLE LOCAL PREVIEW (CONNECTED ONLY)
            if (isConnected &&
                _callService!.localStream != null &&
                _renderersInitialized)
              Positioned(
                left: _localVideoOffset.dx,
                top: _localVideoOffset.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      final size = MediaQuery.of(context).size;
                      double newX = _localVideoOffset.dx + details.delta.dx;
                      double newY = _localVideoOffset.dy + details.delta.dy;

                      newX = newX.clamp(16.0, size.width - _popupWidth - 16);
                      newY = newY.clamp(80.0, size.height - _popupHeight - 150);

                      _localVideoOffset = Offset(newX, newY);
                    });
                  },
                  child: Container(
                    width: _popupWidth,
                    height: _popupHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // 3. OVERLAYS: ZALO STYLE
            _buildOverlays(isConnected),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlays(bool isConnected) {
    return AnimatedOpacity(
      opacity: _showControls ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Stack(
        children: [
          // Top Bar: Back and Flip
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TopCircleIconButton(
                    icon: Icons.arrow_back_ios_new,
                    onTap: _endCallAndClose,
                  ),
                  _TopCircleIconButton(
                    icon: Icons.flip_camera_ios_outlined,
                    onTap: () => _callService?.switchCamera(),
                    isVisible: isConnected || widget.isCaller,
                  ),
                ],
              ),
            ),
          ),

          // Center-Top Info (Repositioned vertically like Zalo)
          if (!isConnected)
            Positioned(
              top: 100,
              left: 40,
              right: 40,
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipOval(
                      child: AvatarWidget(
                        imageUrl: widget.targetAvatarUrl,
                        name: widget.targetDisplayName,
                        size: 92,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.targetDisplayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 15)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _buildStatusText(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                    ),
                  ),
                ],
              ),
            ),

          if (isConnected)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 20,
              child: _SmallParticipantView(
                displayName: widget.targetDisplayName,
                status: _buildStatusText(),
              ),
            ),

          // Bottom Panel: 4 Buttons like Zalo
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
                  color: Colors.black.withValues(alpha: 0.2),
                  child: _buildCallControls(_callService!),
                ),
              ),
            ),
          ),
        ],
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
    if (widget.isCaller) return 'Đang đổ chuông'; // Zalo style
    return isAccepted ? 'Đang trả lời...' : 'Cuộc gọi đến...';
  }

  bool get isAccepted => _callService?.isAccepted ?? false;

  Widget _buildCallControls(WebRtcCallService callService) {
    if (callService.isEnded) return const SizedBox(height: 80);

    if (!widget.isCaller && !callService.isAccepted) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _VideoActionButton(
            icon: Icons.call_end,
            label: 'Từ chối',
            onTap: () => callService.endCall(reason: 'declined'),
            destructive: true,
          ),
          _VideoActionButton(
            icon: Icons.videocam,
            label: 'Chấp nhận',
            onTap: () => callService.acceptCall(),
            color: const Color(0xFF4CD964),
          ),
        ],
      );
    }

    // Standard 4-button row based on screenshot
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
        ),
      ],
    );
  }
}

class _TopCircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isVisible;

  const _TopCircleIconButton({
    required this.icon,
    required this.onTap,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox(width: 44, height: 44);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: 24)),
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
    this.active = true,
    this.destructive = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Color? backgroundColor;
    Color iconColor = Colors.white;

    if (destructive) {
      backgroundColor = const Color(0xFFFF3B30);
    } else if (active) {
      backgroundColor = Colors.white;
      iconColor = const Color(0xFF0068FF); // Zalo Primary Blue
    } else {
      backgroundColor = color ?? Colors.white.withValues(alpha: 0.15);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
            child: Center(child: Icon(icon, color: iconColor, size: 34)),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 10),
          Text(
            label!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
