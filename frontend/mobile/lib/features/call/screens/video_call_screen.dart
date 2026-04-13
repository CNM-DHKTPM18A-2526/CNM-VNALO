import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/call/services/webrtc_call_service.dart';
import 'package:vnalo_mobile/features/call/utils/call_duration_formatter.dart';
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
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _callService.initialize();
    _syncRenderers();
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
    if (!mounted) return;
    Navigator.pop(context);
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
    _callService.removeListener(_onCallStateChanged);
    _callService.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remoteStream = _callService.remoteStream;
    final localStream = _callService.localStream;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child:
                remoteStream != null
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
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 110,
                height: 168,
                color: Colors.black45,
                child:
                    localStream == null
                        ? const Center(child: CircularProgressIndicator())
                        : RTCVideoView(
                          _localRenderer,
                          mirror: _callService.isUsingFrontCamera,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 24,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.targetDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _buildStatusText(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _VideoActionButton(
                  icon:
                      _callService.isMicrophoneEnabled
                          ? Icons.mic
                          : Icons.mic_off,
                  onTap: () => unawaited(_callService.toggleMicrophone()),
                  active: _callService.isMicrophoneEnabled,
                ),
                _VideoActionButton(
                  icon:
                      _callService.isCameraEnabled
                          ? Icons.videocam
                          : Icons.videocam_off,
                  onTap: () => unawaited(_callService.toggleCamera()),
                  active: _callService.isCameraEnabled,
                ),
                _VideoActionButton(
                  icon: Icons.flip_camera_ios,
                  onTap: () => unawaited(_callService.switchCamera()),
                  active: true,
                ),
                _VideoActionButton(
                  icon: Icons.call_end,
                  onTap: _endCallAndClose,
                  active: false,
                  destructive: true,
                ),
              ],
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
  final VoidCallback onTap;
  final bool active;
  final bool destructive;

  const _VideoActionButton({
    required this.icon,
    required this.onTap,
    required this.active,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        destructive
            ? const Color(0xFFEF4444)
            : (active
                ? Colors.white.withValues(alpha: 0.22)
                : const Color(0xFF334155));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
