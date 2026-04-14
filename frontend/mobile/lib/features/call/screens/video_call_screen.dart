import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/call/models/call_log_message.dart';
import 'package:vnalo_mobile/features/call/services/webrtc_call_service.dart';
import 'package:vnalo_mobile/features/call/utils/call_duration_formatter.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  final String targetUserId;
  final String targetDisplayName;
  final String? targetAvatarUrl;

  const VideoCallScreen({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.targetUserId,
    required this.targetDisplayName,
    this.targetAvatarUrl,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final WebRtcCallService _callService;
  late final RTCVideoRenderer _localRenderer;
  late final RTCVideoRenderer _remoteRenderer;
  late final Timer _ticker;

  bool _logSent = false;
  String? _initError;

  String get _callId =>
      'video-${DateTime.now().millisecondsSinceEpoch}-${widget.currentUserId}';

  @override
  void initState() {
    super.initState();
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();

    _callService = WebRtcCallService(
      socketService: context.read<SocketService>(),
      conversationId: widget.conversationId,
      callId: _callId,
      currentUserId: widget.currentUserId,
      peerUserId: widget.targetUserId,
      audioOnly: false,
      isCaller: true,
    )..addListener(_onCallStateChanged);

    unawaited(_initRenderersAndCall());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initRenderersAndCall() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      await _callService.initialize();
      _syncRenderers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = 'Không thể khởi tạo màn hình video: $e';
      });
    }
  }

  void _syncRenderers() {
    _localRenderer.srcObject = _callService.localStream;
    _remoteRenderer.srcObject = _callService.remoteStream;
  }

  void _onCallStateChanged() {
    _syncRenderers();
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
      callerId: widget.currentUserId,
      calleeId: widget.targetUserId,
      mediaType: CallMediaType.video,
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
      return formatCallDuration(duration);
    }

    if (_callService.isInitializing) {
      return 'Đang khởi tạo video...';
    }

    return 'Đang gọi video...';
  }

  @override
  void dispose() {
    _ticker.cancel();
    _sendCallLogIfNeeded();
    _callService.removeListener(_onCallStateChanged);
    _callService.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white70,
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  _initError!,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _endCallAndClose,
                  child: const Text('Thoát'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final remoteStream = _callService.remoteStream;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child:
                _callService.isConnected && remoteStream != null
                    ? RTCVideoView(
                      _remoteRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                    : (_callService.localStream != null
                        ? RTCVideoView(
                          _localRenderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          mirror: true,
                        )
                        : _RemotePlaceholder(
                          name: widget.targetDisplayName,
                          avatarUrl: widget.targetAvatarUrl,
                          status: _buildStatusText(),
                        )),
          ),
          // Dark overlay to make UI more readable during ringing with local camera
          if (!_callService.isConnected)
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.15)),
            ),
          // Backdrop for top controls shadow
          if (!_callService.isConnected)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: SafeArea(
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
                        _TopCircleIconButton(
                          icon: Icons.cached,
                          onTap: () => unawaited(_callService.switchCamera()),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Image/Avatar during ringing
                  if (!_callService.isConnected) ...[
                    AvatarWidget(
                      imageUrl: widget.targetAvatarUrl,
                      name: widget.targetDisplayName,
                      size: 100,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.targetDisplayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
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
                    const Spacer(),
                  ],
                ],
              ),
            ),
          ),
          // Remote Participant Overlay (if connected)
          if (_callService.isConnected)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 16,
              child: _SmallParticipantView(
                displayName: widget.targetDisplayName,
                status: _buildStatusText(),
              ),
            ),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _VideoActionButton(
                        icon:
                            _callService.isCameraEnabled
                                ? Icons.videocam
                                : Icons.videocam_off,
                        label: 'Camera',
                        onTap: () => unawaited(_callService.toggleCamera()),
                        active: _callService.isCameraEnabled,
                      ),
                      _VideoActionButton(
                        icon:
                            _callService.isMicrophoneEnabled
                                ? Icons.mic
                                : Icons.mic_off,
                        label: 'Mic',
                        onTap: () => unawaited(_callService.toggleMicrophone()),
                        active: _callService.isMicrophoneEnabled,
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
                          // Placeholder for future features (Filters, Screen Sharing, etc.)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tính năng đang phát triển'),
                            ),
                          );
                        },
                        active: true,
                      ),
                    ],
                  ),
                ),
              ),
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

class _SmallParticipantView extends StatelessWidget {
  final String displayName;
  final String status;

  const _SmallParticipantView({
    required this.displayName,
    required this.status,
  });

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

  const _VideoActionButton({
    required this.icon,
    this.label,
    required this.onTap,
    required this.active,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        destructive
            ? const Color(0xFFFF3B30) // Solid Red like Zalo
            : Colors.black.withValues(alpha: 0.5); // Đồng bộ với Appbar

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
