import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/call/models/call_log_message.dart';
import 'package:vnalo_mobile/features/call/services/webrtc_call_service.dart';
import 'package:vnalo_mobile/features/call/services/ringtone_service.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/services/socket_service.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class VoiceCallScreen extends StatefulWidget {
  final String conversationId;
  final String callId;
  final String peerUserId;
  final String peerName;
  final String? peerAvatar;
  final bool isCaller;
  final Map<String, dynamic>? initialSdp;

  const VoiceCallScreen({
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
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  late WebRtcCallService _callService;
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

    _callService = WebRtcCallService(
      socketService: socket,
      conversationId: widget.conversationId,
      callId: widget.callId,
      currentUserId: auth.user!.id,
      peerUserId: widget.peerUserId,
      audioOnly: true,
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

    if (_callService.isConnected && _durationTimer == null) {
      _ringtoneService.stop();
      _startDurationTimer();
    }

    if (_callService.isEnded) {
      _ringtoneService.stop();
      _durationTimer?.cancel();
      _sendCallLogIfNeeded();
      Future.delayed(const Duration(milliseconds: 800), () {
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

  void _sendCallLogIfNeeded() {
    if (_logSent || !widget.isCaller) return; // Only caller sends the log to avoid duplicates
    _logSent = true;

    final chatProvider = context.read<ChatProvider>();
    final outcome = _deriveOutcome();

    final log = CallLogMessage(
      callId: widget.callId,
      conversationId: widget.conversationId,
      callerId: widget.isCaller ? _callService.currentUserId : widget.peerUserId,
      calleeId: widget.isCaller ? widget.peerUserId : _callService.currentUserId,
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
        // If caller canceled before connect, map to missed for recipient. 
        // Logic: if duration is 0 and it was hung up, it's missed.
        return CallOutcome.missed;
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _callService.removeListener(_onServiceUpdate);
    _callService.dispose();
    _ringtoneService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            _buildPeerInfo(),
            const Spacer(),
            _buildCallStatus(),
            const SizedBox(height: 48),
            _buildControls(),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildPeerInfo() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 4),
            image: widget.peerAvatar != null
                ? DecorationImage(
                    image: NetworkImage(widget.peerAvatar!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: widget.peerAvatar == null
              ? const Icon(Icons.person, size: 80, color: Colors.white54)
              : null,
        ),
        const SizedBox(height: 24),
        Text(
          widget.peerName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCallStatus() {
    String status = '';
    if (_callService.isEnded) {
      status = 'Cuộc gọi kết thúc';
    } else if (_callService.isConnected) {
      final minutes = _callDurationSeconds ~/ 60;
      final seconds = _callDurationSeconds % 60;
      status = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else if (_callService.isInitializing) {
      status = 'Đang khởi tạo...';
    } else if (widget.isCaller) {
      status = 'Đang gọi...';
    } else {
      status = 'Cuộc gọi đến...';
    }

    if (_callService.errorMessage != null) {
      status = _callService.errorMessage!;
    }

    return Text(
      status,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: _callService.errorMessage != null ? Colors.redAccent : Colors.white70,
        fontSize: 18,
      ),
    );
  }

  Widget _buildControls() {
    if (_callService.isEnded) return const SizedBox.shrink();

    // If callee and not accepted yet, show Accept/Decline
    if (!widget.isCaller && !_callService.isAccepted) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.call_end,
            color: Colors.red,
            onPressed: () => _callService.endCall(reason: 'declined'),
          ),
          _buildControlButton(
            icon: Icons.call,
            color: Colors.green,
            onPressed: () => _callService.acceptCall(),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: _callService.isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
          color: _callService.isMicrophoneEnabled ? Colors.white24 : Colors.redAccent,
          onPressed: () => _callService.toggleMicrophone(),
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

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
      ],
    );
  }
}
