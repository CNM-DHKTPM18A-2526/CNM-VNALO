import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/call/services/webrtc_call_service.dart';
import 'package:vnalo_mobile/features/call/utils/call_duration_formatter.dart';
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
    if (!mounted) return;
    Navigator.pop(context);
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
    _callService.removeListener(_onCallStateChanged);
    _callService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              'Voice Call',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            AvatarWidget(
              imageUrl: widget.targetAvatarUrl,
              name: widget.targetDisplayName,
              size: 120,
            ),
            const SizedBox(height: 18),
            Text(
              widget.targetDisplayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _buildStatusText(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CallControlButton(
                    icon:
                        _callService.isMicrophoneEnabled
                            ? Icons.mic
                            : Icons.mic_off,
                    backgroundColor:
                        _callService.isMicrophoneEnabled
                            ? Colors.white.withValues(alpha: 0.18)
                            : const Color(0xFFEF4444),
                    onTap: () => unawaited(_callService.toggleMicrophone()),
                  ),
                  _CallControlButton(
                    icon:
                        _callService.isSpeakerOn
                            ? Icons.volume_up
                            : Icons.hearing_disabled,
                    backgroundColor:
                        _callService.isSpeakerOn
                            ? Colors.white.withValues(alpha: 0.18)
                            : const Color(0xFF334155),
                    onTap: () => unawaited(_callService.toggleSpeaker()),
                  ),
                  _CallControlButton(
                    icon: Icons.call_end,
                    backgroundColor: const Color(0xFFEF4444),
                    onTap: _endCallAndClose,
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

class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _CallControlButton({
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(34),
      child: Ink(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(34),
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}
