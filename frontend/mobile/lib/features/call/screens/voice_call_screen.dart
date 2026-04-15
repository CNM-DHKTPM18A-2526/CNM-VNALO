import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/call/models/call_log_message.dart';
import 'package:vnalo_mobile/features/call/services/webrtc_call_service.dart';
import 'package:vnalo_mobile/features/call/services/ringtone_service.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/call/screens/video_call_screen.dart';
import 'package:vnalo_mobile/features/call/utils/call_id_generator.dart';
import 'package:vnalo_mobile/services/socket_service.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';

class VoiceCallScreen extends StatefulWidget {
  final String conversationId;
  final String callId;
  final String targetUserId;
  final String targetDisplayName;
  final String? targetAvatarUrl;
  final bool isCaller;
  final Map<String, dynamic>? initialSdp; // KEPT SIGNALLING FIX

  const VoiceCallScreen({
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
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  // KEPT SIGNALLING FIX: Synchronous declaration to prevent race conditions
  WebRtcCallService? _callService;
  final RingtoneService _ringtoneService = RingtoneService();
  Timer? _durationTimer;
  int _callDurationSeconds = 0;
  bool _logSent = false;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    final auth = context.read<AuthProvider>();
    final socket = context.read<SocketService>();

    // KEPT SIGNALLING FIX: Pass initialSdp to service
    _callService = WebRtcCallService(
      socketService: socket,
      conversationId: widget.conversationId,
      callId: widget.callId,
      currentUserId: auth.user!.id,
      peerUserId: widget.targetUserId,
      audioOnly: true,
      isCaller: widget.isCaller,
      initialSdp: widget.initialSdp,
    );

    _callService!.addListener(_onServiceUpdate);
    await _callService!.initialize();

    if (_callService!.errorMessage != null || _callService!.isEnded) {
      return;
    }

    if (widget.isCaller) {
      await _ringtoneService.startDialing();
    } else {
      await _ringtoneService.startRinging();
    }
  }

  void _onServiceUpdate() {
    if (!mounted || _callService == null) return;

    if (_callService!.isConnected && _durationTimer == null) {
      _ringtoneService.stop();
      _startDurationTimer();
    }

    if (_callService!.isEnded) {
      _ringtoneService.stop();
      _durationTimer?.cancel();
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

  void _sendCallLogIfNeeded() {
    if (_logSent || !widget.isCaller || _callService == null) return;
    _logSent = true;

    final chatProvider = context.read<ChatProvider>();
    final outcome = _deriveOutcome();

    final log = CallLogMessage(
      callId: widget.callId,
      conversationId: widget.conversationId,
      callerId: widget.isCaller ? _callService!.currentUserId : widget.targetUserId,
      calleeId: widget.isCaller ? widget.targetUserId : _callService!.currentUserId,
      mediaType: CallMediaType.voice,
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

  Future<void> _upgradeToVideoCall() async {
    if (_callService == null || _callService!.isEnded) return;

    await _callService!.endCall(notifyPeer: true, reason: 'upgrade-to-video');

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) => VideoCallScreen(
              conversationId: widget.conversationId,
              callId: generateCallId(
                conversationId: widget.conversationId,
                callerUserId:
                    widget.isCaller
                        ? _callService!.currentUserId
                        : widget.targetUserId,
                audioOnly: false,
              ),
              targetUserId: widget.targetUserId,
              targetDisplayName: widget.targetDisplayName,
              targetAvatarUrl: widget.targetAvatarUrl,
              isCaller: true,
            ),
      ),
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _callService?.removeListener(_onServiceUpdate);
    _callService?.dispose();
    _ringtoneService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_callService == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ROLLBACK TO ORIGINAL UI WIDGETS FROM MAIN BRANCH
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            center: Alignment.center,
            radius: 1.2,
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!_callService!.isConnected) ...[
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
                  _buildControlButtons(_callService!),
                ],
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
    if (_callService!.isInitializing) return 'Đang thiết lập...';
    if (widget.isCaller) return 'Đang gọi...';
    return isAccepted ? 'Đang trả lời...' : 'Cuộc gọi đến...';
  }

  bool get isAccepted => _callService?.isAccepted ?? false;

  Widget _buildControlButtons(WebRtcCallService callService) {
    if (callService.isEnded) {
      return const SizedBox(height: 80);
    }

    if (!widget.isCaller && !callService.isAccepted) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BottomControl(
            icon: Icons.call_end,
            label: 'Từ chối',
            onTap: () => callService.endCall(reason: 'declined'),
            destructive: true,
          ),
          _BottomControl(
            icon: Icons.call,
            label: 'Trả lời',
            onTap: () => callService.acceptCall(),
            active: true,
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BottomControl(
            icon:
                callService.isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
            label: callService.isMicrophoneEnabled ? 'Tắt mic' : 'Bật mic',
            onTap: () => callService.toggleMicrophone(),
            active: !callService.isMicrophoneEnabled,
          ),
          _BottomControl(
            icon: Icons.call_end,
            label: 'Kết thúc',
            onTap: _endCallAndClose,
            destructive: true,
          ),
          _BottomControl(
            icon: callService.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
            label: callService.isSpeakerOn ? 'Loa ngoài' : 'Loa trong',
            onTap: () => callService.toggleSpeaker(),
            active: callService.isSpeakerOn,
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
                      ? const Color(0xFFFF3B30)
                      : Colors.black.withValues(alpha: 0.5),
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
