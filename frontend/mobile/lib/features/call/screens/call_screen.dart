import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/call/providers/call_provider.dart';

class CallScreen extends StatefulWidget {
  final String remoteUserName;
  final String? remoteAvatarUrl;

  const CallScreen({
    super.key,
    required this.remoteUserName,
    this.remoteAvatarUrl,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, call, child) {
        if (call.state == CallState.ended || call.state == CallState.idle) {
          // Auto-pop when call ends
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }

        if (call.localStream != null) {
          _localRenderer.srcObject = call.localStream;
        }
        if (call.remoteStream != null) {
          _remoteRenderer.srcObject = call.remoteStream;
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Remote Video (Full Screen)
              if (call.isVideoCall && call.remoteStream != null)
                Positioned.fill(
                  child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                )
              else
                // Voice Call Background
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blueGrey.shade900, Colors.black],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: widget.remoteAvatarUrl != null
                                ? NetworkImage(widget.remoteAvatarUrl!)
                                : null,
                            child: widget.remoteAvatarUrl == null
                                ? Text(widget.remoteUserName[0], style: const TextStyle(fontSize: 40))
                                : null,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.remoteUserName,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            call.state == CallState.ringing ? 'Đang gọi...' : 'Đang trò chuyện',
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Local Video (Floating)
              if (call.isVideoCall && call.localStream != null)
                Positioned(
                  top: 50,
                  right: 20,
                  width: 120,
                  height: 160,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                  ),
                ),

              // Bottom Controls
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: Icons.mic_off,
                      color: Colors.white24,
                      onPressed: () {}, // TODO: Toggle Mic
                    ),
                    _buildControlButton(
                      icon: Icons.call_end,
                      color: Colors.red,
                      onPressed: () => call.endCall(),
                      isLarge: true,
                    ),
                    _buildControlButton(
                      icon: call.isVideoCall ? Icons.videocam_off : Icons.volume_up,
                      color: Colors.white24,
                      onPressed: () {}, // TODO: Toggle Video/Speaker
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isLarge = false,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: isLarge ? 70 : 55,
        height: isLarge ? 70 : 55,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: isLarge ? 35 : 28),
      ),
    );
  }
}
