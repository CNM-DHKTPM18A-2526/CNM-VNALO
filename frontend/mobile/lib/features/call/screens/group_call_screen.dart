import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/call/services/group_webrtc_service.dart';
import 'package:vnalo_mobile/features/call/services/group_call_tracker.dart';
import 'package:vnalo_mobile/features/call/services/ringtone_service.dart';
import 'package:vnalo_mobile/services/socket_service.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/core/utils/avatar_resolver.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:vnalo_mobile/features/call/models/call_log_message.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';

class GroupCallScreen extends StatefulWidget {
  final String conversationId;
  final String callId;
  final String conversationName;
  final String? conversationAvatarUrl;
  final bool audioOnly;
  final bool isCaller;
  final List<String> initialSelectedMembers;
  // Caller info for incoming calls
  final String? callerName;
  final String? callerAvatarUrl;
  // Member avatar URLs for the ringing header
  final List<String?> memberAvatarUrls;

  const GroupCallScreen({
    super.key,
    required this.conversationId,
    required this.callId,
    required this.conversationName,
    this.conversationAvatarUrl,
    this.audioOnly = false,
    this.isCaller = true,
    this.initialSelectedMembers = const [],
    this.callerName,
    this.callerAvatarUrl,
    this.memberAvatarUrls = const [],
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
  int _callDurationSeconds = 0;
  bool _isConnecting = true;
  Timer? _durationTimer;
  Timer? _hideControlsTimer;
  bool _showControls = true;
  late GroupCallTracker _callTracker;
  bool _isPopped = false;

  @override
  void initState() {
    super.initState();
    _callTracker = context.read<GroupCallTracker>();
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
    _service.startSignalListening();
    await _localRenderer.initialize();
    if (mounted) setState(() => _renderersReady = true);

    if (widget.isCaller) {
      // Caller: initialize immediately (starts call)
      await _service.initialize(targetUserIds: widget.initialSelectedMembers);
      _callTracker.startCall(ActiveCallInfo(
        callId: widget.callId,
        conversationId: widget.conversationId,
        conversationName: widget.conversationName,
        conversationAvatarUrl: widget.conversationAvatarUrl,
        audioOnly: widget.audioOnly,
        isCaller: true,
        startedAt: DateTime.now(),
        participantUserIds: {},
      ));
      if (mounted) setState(() => _isConnecting = false);
    } else {
      // Callee: play ringtone while waiting for user to accept/decline
      _ringtoneService.startRinging();
    }

    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Wakelock may not be available on this platform.
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _onServiceUpdate() {
    if (!mounted) return;

    if (_service.localStream != null &&
        _localRenderer.srcObject != _service.localStream) {
      _localRenderer.srcObject = _service.localStream;
    }

    // Track remote renderers
    final currentIds = _service.participants.map((p) => p.odUserId).toSet();
    _remoteRenderers.removeWhere((id, renderer) {
      if (!currentIds.contains(id)) {
        renderer.dispose();
        return true;
      }
      return false;
    });

    for (final p in _service.participants) {
      if (p.remoteStream != null && _remoteRenderers[p.odUserId] == null) {
        _initRemoteRenderer(p.odUserId, p.remoteStream!);
      }
      if (p.remoteStream != null && _callTracker.activeCall != null) {
        _callTracker.addParticipant(p.odUserId);
      }
    }

    // We no longer auto-end the call if participants.isEmpty, 
    // allowing the user to decide when to hang up.

    if (_service.isConnected && _durationTimer == null) {
      _ringtoneService.stop();
      _startDurationTimer();
      _startHideControlsTimer();
    }

    if (_service.isEnded) {
      _sendCallLog();
      _callTracker.endCallForConversation(widget.conversationId);
      _ringtoneService.stop();
      if (mounted && !_isPopped) {
        _isPopped = true;
        Navigator.pop(context);
      }
      return;
    }

    setState(() {});
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callDurationSeconds++);
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _service.isConnected && _showControls) {
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

  Future<void> _initRemoteRenderer(String odUserId, MediaStream stream) async {
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = stream;
    _remoteRenderers[odUserId] = renderer;
    if (mounted) setState(() {});
  }

  void _acceptCall() {
    _ringtoneService.stop();
    setState(() => _isConnecting = false);

    _callTracker.startCall(ActiveCallInfo(
      callId: widget.callId,
      conversationId: widget.conversationId,
      conversationName: widget.conversationName,
      conversationAvatarUrl: widget.conversationAvatarUrl,
      audioOnly: widget.audioOnly,
      isCaller: false,
      startedAt: DateTime.now(),
      participantUserIds: {},
    ));

    _service.acceptCall();
    _startHideControlsTimer();
  }

  void _declineCall() {
    _ringtoneService.stop();
    _service.endCall();
    _callTracker.endCallForConversation(widget.conversationId);
    if (!_isPopped) {
      _isPopped = true;
      Navigator.pop(context);
    }
  }

  bool _logSent = false;

  void _sendCallLog() {
    if (_logSent) return;
    _logSent = true;

    // Only the caller sends the "Official" log for the group call to avoid duplicates.
    // If the call never connected (duration 0), we might skip or log as missed.
    if (!widget.isCaller) return;

    final auth = context.read<AuthProvider>();
    final log = CallLogMessage(
      callId: widget.callId,
      conversationId: widget.conversationId,
      callerId: auth.user!.id,
      calleeId: 'group',
      mediaType: widget.audioOnly ? CallMediaType.voice : CallMediaType.video,
      outcome: _callDurationSeconds > 0 ? CallOutcome.answered : CallOutcome.canceled,
      durationSeconds: _callDurationSeconds,
      createdAt: DateTime.now(),
      isGroup: true,
    );

    context.read<ChatProvider>().sendMessage(
      conversationId: widget.conversationId,
      content: log.toMessageContent(),
    );
  }

  void _endCallAndClose() {
    _sendCallLog();
    _service.endCall();
    _callTracker.endCallForConversation(widget.conversationId);
    if (!_isPopped) {
      _isPopped = true;
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _hideControlsTimer?.cancel();
    _service.removeListener(_onServiceUpdate);
    _service.dispose();
    _ringtoneService.dispose();
    _localRenderer.dispose();
    for (final r in _remoteRenderers.values) {
      r.dispose();
    }
    try {
      WakelockPlus.disable();
    } catch (_) {
      // Wakelock may not have been enabled or already released.
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String get _formattedDuration {
    final mins = _callDurationSeconds ~/ 60;
    final secs = _callDurationSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // === INCOMING CALL (Callee, not yet accepted) — Image 3 ===
    if (!widget.isCaller && _isConnecting) {
      return _buildIncomingCallView();
    }

    // === CALLER WAITING (No one joined yet) — Image 2 ===
    if (widget.isCaller && _service.participants.isEmpty && !_service.isConnected) {
      return _buildCallerWaitingView();
    }

    // === ACTIVE CALL (Connected) — Image 5 ===
    return _buildActiveCallView();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // IMAGE 2: CALLER WAITING — local camera background + group info + controls
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildCallerWaitingView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: local camera full-screen (mirror)
          if (_service.localStream != null && _renderersReady && !widget.audioOnly)
            Positioned.fill(
              child: RTCVideoView(
                _localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF020617), Color(0xFF0F172A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

          // Top bar: back (left) + flip camera (right)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleIconBtn(
                    icon: Icons.arrow_back_ios_new,
                    onTap: _endCallAndClose,
                  ),
                  _CircleIconBtn(
                    icon: Icons.flip_camera_ios_outlined,
                    onTap: () => _service.switchCamera(),
                  ),
                ],
              ),
            ),
          ),

          // Center: group member avatars + group name + "Đang đổ chuông"
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Overlapping member avatars
                _buildOverlappingAvatars(),
                const SizedBox(height: 16),
                Text(
                  widget.conversationName,
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
                  'Đang đổ chuông',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    shadows: const [Shadow(color: Colors.black45, blurRadius: 10)],
                  ),
                ),
              ],
            ),
          ),

          // Bottom controls: Camera, Mic, Kết thúc, Thêm
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildFullControls(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlappingAvatars() {
    final avatars = widget.memberAvatarUrls.isNotEmpty
        ? widget.memberAvatarUrls.take(3).toList()
        : <String?>[widget.conversationAvatarUrl];

    final count = avatars.length;
    final avatarSize = 64.0;
    final overlap = 16.0;
    final totalWidth = count * avatarSize - (count - 1) * overlap;

    return SizedBox(
      height: avatarSize + 8,
      width: totalWidth + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < count; i++)
            Positioned(
              left: i * (avatarSize - overlap),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: AvatarWidget(
                  imageUrl: avatars[i],
                  name: widget.conversationName,
                  size: avatarSize,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // IMAGE 3: INCOMING CALL (Callee) — blue bg, caller avatar, accept/decline
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildIncomingCallView() {
    final callerName = widget.callerName ?? widget.conversationName;
    final callerAvatar = widget.callerAvatarUrl ?? widget.conversationAvatarUrl;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Caller avatar
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 3,
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
                    imageUrl: callerAvatar,
                    name: callerName,
                    size: 104,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Caller name
              Text(
                callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              // Invitation text
              Text(
                '$callerName mời bạn vào cuộc gọi nhóm',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(flex: 3),
              // Accept / Decline buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Decline
                    _IncomingActionButton(
                      icon: Icons.call_end,
                      label: 'Từ chối',
                      color: const Color(0xFFFF3B30),
                      onTap: _declineCall,
                    ),
                    // Accept
                    _IncomingActionButton(
                      icon: widget.audioOnly ? Icons.call : Icons.videocam,
                      label: 'Trả lời',
                      color: const Color(0xFF4CD964),
                      onTap: _acceptCall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // IMAGE 5: ACTIVE CALL — remote video top, local video bottom, controls
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildActiveCallView() {
    final participants = _service.participants;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Grid Layout
            if (!widget.audioOnly)
              _buildVideoGrid(participants)
            else
              _buildAudioOnlyView(),

            // Top Overlay: Duration & Group Name
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _CircleIconBtn(
                          icon: Icons.arrow_back_ios_new,
                          onTap: _endCallAndClose,
                        ),
                        const Spacer(),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.conversationName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formattedDuration,
                              style: const TextStyle(
                                color: Color(0xFF4CD964),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        _CircleIconBtn(
                          icon: Icons.flip_camera_ios_outlined,
                          onTap: () => _service.switchCamera(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildFullControls(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoGrid(List<Participant> participants) {
    final allParticipants = [
      _LocalParticipantProxy(
        stream: _service.localStream,
        isCameraOff: _service.isCameraOff,
        displayName: _service.displayName,
        avatarUrl: context.read<AuthProvider>().user?.avatarUrl,
      ),
      ...participants,
    ];

    final count = allParticipants.length;

    if (count <= 2) {
      return Column(
        children: allParticipants.map((p) => Expanded(child: _buildGridItem(p))).toList(),
      );
    } else {
      return GridView.builder(
        padding: EdgeInsets.fromLTRB(4, MediaQuery.of(context).padding.top + 60, 4, 120),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: count <= 4 ? 2 : 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 0.75,
        ),
        itemCount: count,
        itemBuilder: (context, index) => _buildGridItem(allParticipants[index]),
      );
    }
  }

  Widget _buildGridItem(dynamic p) {
    final bool isLocal = p is _LocalParticipantProxy;
    final String userId = isLocal ? 'local' : p.odUserId;
    final String name = isLocal ? p.displayName : p.displayName;
    final String? avatar = isLocal ? p.avatarUrl : p.avatarUrl;
    final bool cameraOff = isLocal ? p.isCameraOff : p.isCameraOff;
    final MediaStream? stream = isLocal ? p.stream : p.remoteStream;

    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1A1A2E),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cameraOff)
            _CameraOffPlaceholder(name: name, avatarUrl: avatar)
          else if (stream != null)
            _buildVideoView(userId, stream, isLocal)
          else
            _CameraOffPlaceholder(name: name, avatarUrl: avatar, isWaiting: true),
          
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isLocal ? 'Bạn' : name,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoView(String userId, MediaStream stream, bool isLocal) {
    if (isLocal) {
      if (!_renderersReady) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        );
      }
      return RTCVideoView(
        _localRenderer,
        mirror: true,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    } else {
      final renderer = _remoteRenderers[userId];
      if (renderer == null) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        );
      }
      return RTCVideoView(
        renderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }
  }

  Widget _buildAudioOnlyView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0068FF), Color(0xFF0050CC)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AvatarWidget(
              imageUrl: widget.conversationAvatarUrl,
              name: widget.conversationName,
              size: 120,
            ),
            const SizedBox(height: 24),
            Text(
              widget.conversationName,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${_service.participantCount} thành viên • $_formattedDuration',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CallActionButton(
          icon: _service.isCameraOff ? Icons.videocam_off : Icons.videocam,
          label: 'Camera',
          onTap: () => _service.toggleCamera(),
          active: !_service.isCameraOff,
        ),
        _CallActionButton(
          icon: _service.isMuted ? Icons.mic_off : Icons.mic,
          label: 'Mic',
          onTap: () => _service.toggleMute(),
          active: !_service.isMuted,
        ),
        _CallActionButton(
          icon: Icons.call_end,
          label: 'Kết thúc',
          onTap: _endCallAndClose,
          destructive: true,
        ),
        _CallActionButton(
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

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconBtn({required this.icon, required this.onTap});

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
        child: Center(child: Icon(icon, color: Colors.white, size: 24)),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool destructive;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = true,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color iconColor = Colors.white;

    if (destructive) {
      bg = const Color(0xFFFF3B30);
    } else {
      bg = Colors.black.withValues(alpha: 0.5);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Center(child: Icon(icon, color: iconColor, size: 30)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _IncomingActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _IncomingActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
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
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(child: Icon(icon, color: Colors.white, size: 34)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CameraOffPlaceholder extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool isWaiting;

  const _CameraOffPlaceholder({
    required this.name,
    this.avatarUrl,
    this.isWaiting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if ((AvatarResolver.resolveUrl(avatarUrl) ?? avatarUrl) != null)
          CachedNetworkImage(
            imageUrl: AvatarResolver.resolveUrl(avatarUrl) ?? avatarUrl!,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            httpHeaders: (context.read<AuthProvider>().accessToken != null &&
                    AvatarResolver.isInternalUrl(AvatarResolver.resolveUrl(avatarUrl) ?? avatarUrl))
                ? {
                    'Authorization': 'Bearer ${context.read<AuthProvider>().accessToken}',
                  }
                : const {},
            placeholder: (_, __) => const SizedBox(),
            errorWidget: (_, __, ___) => const SizedBox(),
          ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: Colors.black.withValues(alpha: 0.6),
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: AvatarWidget(name: name, imageUrl: avatarUrl, size: 80),
              ),
              if (isWaiting) ...[
                const SizedBox(height: 16),
                Text(
                  'Đang chờ kết nối...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LocalParticipantProxy {
  final MediaStream? stream;
  final bool isCameraOff;
  final String displayName;
  final String? avatarUrl;
  _LocalParticipantProxy({
    this.stream,
    required this.isCameraOff,
    required this.displayName,
    this.avatarUrl,
  });
}


