import 'package:flutter/material.dart';
import 'package:o3d/o3d.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/screens/mascot_gallery_screen.dart';

class AiFloatingBubble extends StatefulWidget {
  const AiFloatingBubble({super.key});

  @override
  State<AiFloatingBubble> createState() => _AiFloatingBubbleState();
}

class _AiFloatingBubbleState extends State<AiFloatingBubble> {
  Offset _position = const Offset(20, 100);
  final O3DController _o3dController = O3DController();

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AiAssistantProvider>();

    if (!aiProvider.isMascotVisible) return const SizedBox.shrink();

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        onTap: () {
          if (aiProvider.state == AiState.idle) {
            aiProvider.startListening();
          } else {
            aiProvider.stopListening();
          }
        },
        onLongPress: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MascotGalleryScreen()),
          );
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBubbleIndicator(aiProvider),
              const SizedBox(height: 8),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.blue.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: ClipOval(
                  child: O3D(
                    key: ValueKey(aiProvider.currentMascot.id), // Force rebuild when mascot changes
                    controller: _o3dController,
                    src: aiProvider.currentMascot.modelUrl,
                    autoPlay: true,
                    cameraTarget: CameraTarget(0, 0, 0),
                    cameraOrbit: CameraOrbit(0, 75, 105),
                  ),
                ),
              ),
              if (aiProvider.state != AiState.idle)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      aiProvider.state == AiState.listening ? "Đang nghe..." : "...",
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubbleIndicator(AiAssistantProvider provider) {
    Color color;
    switch (provider.state) {
      case AiState.listening:
        color = Colors.redAccent;
        break;
      case AiState.thinking:
        color = Colors.blueAccent;
        break;
      case AiState.speaking:
        color = Colors.greenAccent;
        break;
      default:
        color = Colors.white.withOpacity(0.5);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}
