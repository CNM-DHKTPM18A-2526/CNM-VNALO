import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/call/services/group_webrtc_service.dart';
import 'package:vnalo_mobile/services/socket_service.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:vnalo_mobile/features/call/services/ringtone_service.dart';

class GroupCallScreen extends StatefulWidget {
  final String conversationId;
  final String callId;
  final String conversationName;
  final String? conversationAvatarUrl;
  final bool audioOnly;
  final bool isCaller;

  const GroupCallScreen({
    super.key,
    required this.conversationId,
    required this.callId,
    required this.conversationName,
    this.conversationAvatarUrl,
    this.audioOnly = false,
    this.isCaller = true,
  });

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  late GroupWebRtcService _service;
  final RingtoneService _ringtoneService = RingtoneService();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _renderersReady = false;
  bool _showControls = true;
  int _callDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initService();
    _asyncInit();
  }

  void _initService() {
    final auth = context.read<AuthProvider>();
    final socket = context.read<SocketService>();

    _service = GroupWebRtcService(
      socketService: socket,
      conversationId: widget.conversationId,
      callId: widget.callId,
      currentUserId: auth.user!.id,
      displayName: auth.user?.displayName ?? 'Unknown',
      audioOnly: widget.audioOnly,
    );
    _service.addListener(_onServiceUpdate);
  }

  Future<void> _asyncInit() async {
    await _localRenderer.initialize();
    if (mounted) setState(() => _renderersReady = true);

    await _service.initialize();
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  void _onServiceUpdate() {
    if (!mounted) return;

    if (_service.localStream != null &&
        _localRenderer.srcObject != _service.localStream) {
      _localRenderer.srcObject = _service.localStream;
    }

    for (final p in _service.participants) {
      if (p.remoteStream != null && _remoteRenderers[p.odUserId] == null) {
        _initRemoteRenderer(p.odUserId, p.remoteStream!);
      }
    }

    setState(() {});
  }

  Future<void> _initRemoteRenderer(String odUserId, MediaStream stream) async {
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = stream;
    _remoteRenderers[odUserId] = renderer;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    _service.dispose();
    _ringtoneService.dispose();
    _localRenderer.dispose();
    for (final r in _remoteRenderers.values) {
      r.dispose();
    }
    try {
      WakelockPlus.disable();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(),
            _buildParticipantGrid(),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
      ),
    );
  }

  Widget _buildParticipantGrid() {
    final participants = _service.participants;
    final totalCount = participants.length + 1;

    if (_service.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _service.errorMessage!,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Quay lai'),
            ),
          ],
        ),
      );
    }

    if (!_service.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Dang khoi tao cuoc goi nhom...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _getGridLayout(totalCount);
        final cols = layout[0].toInt();
        final cellAspectRatio = layout[2];

        return Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 80,
            left: 4,
            right: 4,
            bottom: 160,
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: cellAspectRatio,
            ),
            itemCount: totalCount,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildLocalTile(constraints, 0, 0);
              }
              final p = participants[index - 1];
              return _buildRemoteTile(p, constraints, 0, 0);
            },
          ),
        );
      },
    );
  }

  int _getGridCols(int count) {
    if (count == 1) return 1;
    if (count == 2) return 2;
    if (count <= 4) return 2;
    if (count <= 6) return 3;
    if (count <= 9) return 3;
    return 4;
  }

  /// Returns grid dimensions [cols, rows, cellAspectRatio] for a given participant count.
  List<double> _getGridLayout(int count) {
    switch (count) {
      case 1: return [1, 1, 1.0];
      case 2: return [2, 1, 0.75];
      case 3: return [3, 1, 0.9];
      case 4: return [2, 2, 1.0];
      case 5:
      case 6: return [3, 2, 0.85];
      case 7:
      case 8:
      case 9: return [3, 3, 0.85];
      default: return [4.0, (count / 4).ceilToDouble(), 0.8];
    }
  }

  Widget _buildLocalTile(BoxConstraints constraints, double cellW, double cellH) {
    final size = constraints.maxWidth * 0.35;
    final isConnected = _service.isConnected;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!widget.audioOnly && _renderersReady)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _service.isCameraOff
                  ? Container(color: const Color(0xFF1E293B))
                  : RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AvatarWidget(
                    name: _service.displayName,
                    size: size * 0.35,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_service.displayName} (Ban)',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          if (_service.isMuted)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.mic_off, color: Colors.white, size: 18),
              ),
            ),
          if (_service.isCameraOff && !widget.audioOnly)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.videocam_off, color: Colors.white, size: 18),
              ),
            ),
          if (!isConnected)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Dang ket noi...',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRemoteTile(Participant p, BoxConstraints constraints, double cellW, double cellH) {
    final size = constraints.maxWidth * 0.35;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!widget.audioOnly && _remoteRenderers[p.odUserId] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: p.isCameraOff
                  ? Container(color: const Color(0xFF1E293B))
                  : RTCVideoView(
                      _remoteRenderers[p.odUserId]!,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AvatarWidget(
                    imageUrl: p.avatarUrl,
                    name: p.displayName,
                    size: size * 0.35,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.displayName,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!p.isConnected)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Dang ket noi...',
                        style: TextStyle(color: Colors.orange, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          if (p.isMuted)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.mic_off, color: Colors.white, size: 18),
              ),
            ),
          if (p.isCameraOff && !widget.audioOnly)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.videocam_off, color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: _showControls ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.group, color: Colors.white70, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        widget.conversationName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${_service.participantCount} nguoi)',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _GroupCallButton(
                        icon: _service.isMuted ? Icons.mic_off : Icons.mic,
                        label: _service.isMuted ? 'Bat tieng' : 'Tat tieng',
                        isActive: !_service.isMuted,
                        onTap: () => _service.toggleMute(),
                      ),
                      if (!widget.audioOnly)
                        _GroupCallButton(
                          icon: _service.isCameraOff ? Icons.videocam_off : Icons.videocam,
                          label: _service.isCameraOff ? 'Bat cam' : 'Tat cam',
                          isActive: !_service.isCameraOff,
                          onTap: () => _service.toggleCamera(),
                        ),
                      _GroupCallButton(
                        icon: Icons.call_end,
                        label: 'Ket thuc',
                        isDestructive: true,
                        onTap: () {
                          _service.endCall();
                          Navigator.pop(context);
                        },
                      ),
                      if (!widget.audioOnly)
                        _GroupCallButton(
                          icon: Icons.cameraswitch,
                          label: 'Doi cam',
                          onTap: () => _service.switchCamera(),
                        ),
                      _GroupCallButton(
                        icon: _service.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                        label: _service.isSpeakerOn ? 'Loa' : 'Tai nghe',
                        isActive: _service.isSpeakerOn,
                        onTap: () => _service.toggleSpeaker(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupCallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isDestructive;

  const _GroupCallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = true,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDestructive
        ? Colors.red
        : (isActive ? Colors.white24 : Colors.white12);
    final iconColor = isDestructive ? Colors.white : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
