import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/call/models/call_log_message.dart';
import 'package:vnalo_mobile/features/call/services/webrtc_call_service.dart';
import 'package:vnalo_mobile/features/call/screens/video_call_screen.dart';
import 'package:vnalo_mobile/features/call/utils/call_duration_formatter.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class VoiceCallScreen extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  final String targetUserId;
  final String targetDisplayName;
  final String? targetAvatarUrl;
  final bool isCaller;
  final String? callId;

  const VoiceCallScreen({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.targetUserId,
    required this.targetDisplayName,
    this.targetAvatarUrl,
    this.isCaller = true,
    this.callId,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  late final WebRtcCallService _callService;
  late final Timer _ticker;
  late final String _callId;
  bool _logSent = false;
  bool _didAutoClose = false;

  @override
  void initState() {
    super.initState();
    _callId =
        widget.callId ??
        'voice-${DateTime.now().millisecondsSinceEpoch}-${widget.currentUserId}';
    _callService = WebRtcCallService(
      socketService: context.read<SocketService>(),
      conversationId: widget.conversationId,
      callId: _callId,
      currentUserId: widget.currentUserId,
      peerUserId: widget.targetUserId,
      audioOnly: true,
      isCaller: widget.isCaller,
    )..addListener(_onCallStateChanged);

    unawaited(_callService.initialize());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onCallStateChanged() {
    if (!mounted) return;

    if (_callService.isEnded && !_didAutoClose) {
      _didAutoClose = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }

    setState(() {});
  }

  Future<void> _endCallAndClose() async {
    await _callService.endCall();
    _sendCallLogIfNeeded();
    if (!mounted) return;
    Navigator.pop(context);
  }

  CallOutcome _deriveOutcome() {
    if (_callService.connectedAt != null) {
      return CallOutcome.answered;
    }

    switch (_callService.lastEndReason) {
      case 'declined':
        return CallOutcome.declined;
      case 'missed':
      case 'no-answer-timeout':
        return CallOutcome.missed;
      case 'busy':
        return CallOutcome.busy;
      case 'failed':
      case 'permission-denied':
        return CallOutcome.failed;
      default:
        return CallOutcome.canceled;
    }
  }

  void _sendCallLogIfNeeded() {
    if (_logSent) return;
    _logSent = true;

    final durationSeconds =
        _callService.connectedAt == null
            ? 0
            : DateTime.now().difference(_callService.connectedAt!).inSeconds;

    final payload = CallLogMessage(
      callId: _callId,
      conversationId: widget.conversationId,
      callerId: widget.isCaller ? widget.currentUserId : widget.targetUserId,
      calleeId: widget.isCaller ? widget.targetUserId : widget.currentUserId,
      mediaType: CallMediaType.voice,
      outcome: _deriveOutcome(),
      durationSeconds: durationSeconds,
      createdAt: DateTime.now(),
    );

    context.read<ChatProvider>().sendMessage(
      conversationId: widget.conversationId,
      content: payload.toMessageContent(),
      messageType: 'SYSTEM',
    );
  }

  String _buildStatusText() {
    if (_callService.errorMessage != null) {
      return _callService.errorMessage!;
    }

    if (_callService.isConnected && _callService.connectedAt != null) {
      final duration = DateTime.now().difference(_callService.connectedAt!);
      return 'Đang trò chuyện ${formatCallDuration(duration)}';
    }

    if (_callService.isInitializing) {
      return 'Đang khởi tạo cuộc gọi...';
    }

    return widget.isCaller ? 'Đang gọi...' : 'Cuộc gọi đến...';
  }

  @override
  void dispose() {
    _ticker.cancel();
    _sendCallLogIfNeeded();
    _callService.removeListener(_onCallStateChanged);
    _callService.dispose();
    super.dispose();
  }

  void _upgradeToVideoCall() {
    if (!widget.isCaller) return;
    unawaited(_callService.endCall());
    _sendCallLogIfNeeded();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) => VideoCallScreen(
              conversationId: widget.conversationId,
              currentUserId: widget.currentUserId,
              targetUserId: widget.targetUserId,
              targetDisplayName: widget.targetDisplayName,
              targetAvatarUrl: widget.targetAvatarUrl,
              isCaller: true,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Layering Law: Trong cuộc gọi, ta thường ưu tiên không gian tối chuyên sâu (Premium)
    final backgroundColor =
        isDarkMode ? const Color(0xFF000000) : const Color(0xFF086CFF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Background covers the entire screen, including status bar
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient:
                    isDarkMode
                        ? RadialGradient(
                          center: const Alignment(0, -0.4),
                          radius: 1.2,
                          colors: [
                            const Color(0xFF131313).withValues(alpha: 0.8),
                            const Color(0xFF000000),
                          ],
                        )
                        : const RadialGradient(
                          center: Alignment(0, -0.4),
                          radius: 1.0,
                          colors: [
                            Color(0xFF4EB4FF),
                            Color(0xFF0B6DFF),
                            Color(0xFF0058D6),
                          ],
                        ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TopCircleIconButton(
                        icon: Icons.keyboard_arrow_down,
                        onTap: _endCallAndClose,
                      ),
                      const Text(
                        'VNALO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      _TopCircleIconButton(
                        icon: Icons.videocam,
                        onTap: _upgradeToVideoCall,
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 1),
                // Avatar & Animated Ripples
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!_callService.isConnected) ...[
                      const _AnimatedPulseRing(
                        size: 280,
                        delay: Duration(milliseconds: 0),
                      ),
                      const _AnimatedPulseRing(
                        size: 224,
                        delay: Duration(milliseconds: 800),
                      ),
                      const _AnimatedPulseRing(
                        size: 172,
                        delay: Duration(milliseconds: 1600),
                      ),
                    ] else ...[
                      _RingLayer(size: 280, alpha: 0.08),
                      _RingLayer(size: 224, alpha: 0.1),
                      _RingLayer(size: 172, alpha: 0.12),
                    ],
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: AvatarWidget(
                          imageUrl: widget.targetAvatarUrl,
                          name: widget.targetDisplayName,
                          size: 135,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  widget.targetDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _buildStatusText(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(flex: 4),
                // Bottom Controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _BottomControl(
                        icon:
                            _callService.isSpeakerOn
                                ? Icons.volume_up
                                : Icons.volume_off,
                        label: 'Loa',
                        onTap: () => unawaited(_callService.toggleSpeaker()),
                        active: _callService.isSpeakerOn,
                      ),
                      _BottomControl(
                        icon: Icons.call_end,
                        label: 'Kết thúc',
                        onTap: _endCallAndClose,
                        destructive: true,
                      ),
                      _BottomControl(
                        icon:
                            _callService.isMicrophoneEnabled
                                ? Icons.mic
                                : Icons.mic_off,
                        label: 'Mic',
                        onTap: () => unawaited(_callService.toggleMicrophone()),
                        active: _callService.isMicrophoneEnabled,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

class _RingLayer extends StatelessWidget {
  final double size;
  final double alpha;

  const _RingLayer({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: alpha),
          width: 1.5,
        ),
      ),
    );
  }
}

class _AnimatedPulseRing extends StatefulWidget {
  final double size;
  final Duration delay;

  const _AnimatedPulseRing({required this.size, required this.delay});

  @override
  State<_AnimatedPulseRing> createState() => _AnimatedPulseRingState();
}

class _AnimatedPulseRingState extends State<_AnimatedPulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.2), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 0.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BottomControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool destructive;

  const _BottomControl({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color:
                  destructive
                      ? const Color(0xFFFF3B30) // Solid Red like Zalo
                      : Colors.black.withValues(
                        alpha: 0.5,
                      ), // Đồng bộ với Appbar
              shape: BoxShape.circle,
              boxShadow: [
                if (destructive)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Center(child: Icon(icon, color: Colors.white, size: 36)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
