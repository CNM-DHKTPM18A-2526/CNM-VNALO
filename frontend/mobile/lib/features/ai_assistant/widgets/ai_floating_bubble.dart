import 'package:flutter/material.dart';
import 'package:o3d/o3d.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/screens/mascot_gallery_screen.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_chat_board.dart';
import 'dart:math';

class AiFloatingBubble extends StatefulWidget {
  const AiFloatingBubble({super.key});

  @override
  State<AiFloatingBubble> createState() => _AiFloatingBubbleState();
}

class _AiFloatingBubbleState extends State<AiFloatingBubble> with SingleTickerProviderStateMixin {
  Offset _position = const Offset(20, 100);
  final O3DController _o3dController = O3DController();

  bool _isDragging = false;
  bool _isHoveringTrash = false;

  late AnimationController _animationController;
  late AnimationController _pulseController;
  Animation<Offset>? _positionAnimation;
  Animation<double>? _scaleAnimation;

  double _currentScale = 0.8; // Default compact size at edge

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animationController.addListener(() {
      if (_positionAnimation != null) {
        setState(() {
          _position = _positionAnimation!.value;
        });
      }
      if (_scaleAnimation != null) {
        setState(() {
          _currentScale = _scaleAnimation!.value;
        });
      }
    });

    // Schedule an initial snap to edge so it starts properly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
         _snapToEdge();
      }
    });

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _animationController.stop();
    setState(() {
      _isDragging = true;
      _isHoveringTrash = false;
      // Expand to full size when driving
      _scaleAnimation = Tween<double>(begin: _currentScale, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
      );
    });
    _animationController.forward(from: 0);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _position += details.delta;

      final screenSize = MediaQuery.of(context).size;
      final trashCenter = Offset(screenSize.width / 2, screenSize.height - 80);
      
      // Center of the 120x120 bubble
      final mascotCenter = Offset(_position.dx + 60, _position.dy + 60);

      // Hitbox logic (snap to trash)
      if ((mascotCenter - trashCenter).distance < 80) {
        _isHoveringTrash = true;
        // Suction effect towards the trash bin
        _position = Offset(screenSize.width / 2 - 60, screenSize.height - 140);
      } else {
        _isHoveringTrash = false;
      }
    });
  }

  void _onPanEnd(DragEndDetails details, AiAssistantProvider provider) {
    setState(() {
      _isDragging = false;
    });

    if (_isHoveringTrash) {
      provider.hideMascot();
      _isHoveringTrash = false;
      _position = const Offset(20, 100); // Reset position
      return;
    }

    _snapToEdge();
  }

  void _snapToEdge() {
    final screenSize = MediaQuery.of(context).size;
    final isLeft = _position.dx + 60 < screenSize.width / 2;
    
    final targetX = isLeft ? -10.0 : screenSize.width - 110.0; // Slightly off edge
    double targetY = _position.dy;
    
    // Prevent hiding in top/bottom areas
    if (targetY < 40) targetY = 40;
    if (targetY > screenSize.height - 160) targetY = screenSize.height - 160;

    _positionAnimation = Tween<Offset>(begin: _position, end: Offset(targetX, targetY)).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    _scaleAnimation = Tween<double>(begin: _currentScale, end: 0.8).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AiAssistantProvider>();

    if (!aiProvider.isMascotVisible) return const SizedBox.shrink();

    return Positioned.fill(
      child: Stack(
        children: [
          if (_isDragging)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isHoveringTrash ? 80 : 60,
                  height: _isHoveringTrash ? 80 : 60,
                  decoration: BoxDecoration(
                    color: _isHoveringTrash ? Colors.redAccent.withOpacity(0.9) : Colors.black54,
                    shape: BoxShape.circle,
                    boxShadow: _isHoveringTrash
                        ? [const BoxShadow(color: Colors.red, blurRadius: 20, spreadRadius: 5)]
                        : [],
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: _isHoveringTrash ? 40 : 30,
                  ),
                ),
              ),
            ),
            
          // Generative UI Chat Board
          if (aiProvider.aiResponse.isNotEmpty && !_isDragging)
            Positioned(
              left: _position.dx < MediaQuery.of(context).size.width / 2 ? _position.dx + 110 : null,
              right: _position.dx >= MediaQuery.of(context).size.width / 2 ? MediaQuery.of(context).size.width - _position.dx + 10 : null,
              top: max(_position.dy - 50, 60),
              child: AiChatBoard(
                onClose: () => aiProvider.clearAiResponse(),
              ),
            ),

          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: (details) => _onPanEnd(details, aiProvider),
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
                child: Transform.scale(
                  scale: _currentScale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBubbleIndicator(aiProvider),
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final isSpeaking = aiProvider.state == AiState.speaking;
                          final dy = isSpeaking ? sin(_pulseController.value * pi) * -5.0 : 0.0;
                          return Transform.translate(
                            offset: Offset(0, dy),
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    isSpeaking 
                                      ? Colors.greenAccent.withOpacity(0.3 + 0.2 * _pulseController.value) 
                                      : Colors.blue.withOpacity(0.1),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.5, 1.0],
                                ),
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: ClipOval(
                          child: O3D(
                            key: ValueKey(aiProvider.currentMascot.id), // Force rebuild
                            controller: _o3dController,
                            src: aiProvider.currentMascot.modelUrl,
                            autoPlay: true,
                            cameraTarget: CameraTarget(0, 0, 0),
                            cameraOrbit: CameraOrbit(0, 75, 105),
                          ),
                        ),
                      ),
                      if (aiProvider.state != AiState.idle && aiProvider.state != AiState.speaking)
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
            ),
          ),
        ],
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
