import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/call/models/call_log_message.dart';
import 'package:vnalo_mobile/features/call/services/webrtc_call_service.dart';
import 'package:vnalo_mobile/features/call/utils/call_duration_formatter.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class VoiceCallScreen extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  final String targetUserId;
  final String targetDisplayName;
  final String? targetAvatarUrl;

  const VoiceCallScreen({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.targetUserId,
    required this.targetDisplayName,
    this.targetAvatarUrl,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  late final WebRtcCallService _callService;
  late final Timer _ticker;
  bool _logSent = false;

  String get _callId =>
      'voice-${DateTime.now().millisecondsSinceEpoch}-${widget.currentUserId}';

  @override
  void initState() {
    super.initState();
    _callService = WebRtcCallService(
      socketService: context.read<SocketService>(),
      conversationId: widget.conversationId,
      callId: _callId,
      currentUserId: widget.currentUserId,
      peerUserId: widget.targetUserId,
      audioOnly: true,
      isCaller: true,
    )..addListener(_onCallStateChanged);

    unawaited(_callService.initialize());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onCallStateChanged() {
    if (!mounted) return;
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
      callerId: widget.currentUserId,
      calleeId: widget.targetUserId,
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

    return 'Đang gọi...';
  }

  @override
  void dispose() {
    _ticker.cancel();
    _sendCallLogIfNeeded();
    _callService.removeListener(_onCallStateChanged);
    _callService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF086CFF),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.25),
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
            Positioned.fill(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _TopCircleIconButton(
                          icon: Icons.arrow_back,
                          onTap: _endCallAndClose,
                        ),
                        _TopCircleIconButton(
                          icon: Icons.videocam_outlined,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Dùng nút video ở chat để bắt đầu video call',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      _RingLayer(size: 280, alpha: 0.12),
                      _RingLayer(size: 224, alpha: 0.14),
                      _RingLayer(size: 172, alpha: 0.18),
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                            width: 2,
                          ),
                        ),
                        child: AvatarWidget(
                          imageUrl: widget.targetAvatarUrl,
                          name: widget.targetDisplayName,
                          size: 126,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.targetDisplayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _buildStatusText(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _BottomControl(
                          icon:
                              _callService.isSpeakerOn
                                  ? Icons.volume_up
                                  : Icons.hearing_disabled,
                          label: 'Loa',
                          onTap: () => unawaited(_callService.toggleSpeaker()),
                          destructive: !_callService.isSpeakerOn,
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
                          onTap:
                              () => unawaited(_callService.toggleMicrophone()),
                          destructive: !_callService.isMicrophoneEnabled,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
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
          width: 1.2,
        ),
      ),
    );
  }
}

class _BottomControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _BottomControl({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(36),
          child: Ink(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color:
                  destructive
                      ? const Color(0xFFEF4444)
                      : Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
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
