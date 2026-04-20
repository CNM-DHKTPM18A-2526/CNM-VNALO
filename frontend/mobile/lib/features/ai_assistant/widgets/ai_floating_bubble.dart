import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:o3d/o3d.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/models/mascot_metadata.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/screens/mascot_gallery_screen.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_chat_board.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_robot_avatar.dart';

enum _BubbleInputMode { bubbleControl, mascotInteract }

class AiFloatingBubble extends StatefulWidget {
  const AiFloatingBubble({super.key});

  @override
  State<AiFloatingBubble> createState() => _AiFloatingBubbleState();
}

class _AiFloatingBubbleState extends State<AiFloatingBubble>
    with TickerProviderStateMixin {
  static const double _bubbleSize = 120;
  static const double _bubbleRadius = _bubbleSize / 2;
  static const double _dragHandleThreshold = 38;
  static const double _trashHoverDistance = 86;
  static const double _trashAttractionDistance = 165;

  Offset _position = const Offset(20, 100);
  final O3DController _o3dController = O3DController();

  bool _isDragging = false;
  bool _isHoveringTrash = false;
  _BubbleInputMode _inputMode = _BubbleInputMode.bubbleControl;

  late final AnimationController _snapController;
  Animation<Offset>? _positionAnimation;
  Animation<double>? _scaleAnimation;

  double _currentScale = 0.86;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
      final hasPositionUpdate = _positionAnimation != null;
      final hasScaleUpdate = _scaleAnimation != null;
      if (!hasPositionUpdate && !hasScaleUpdate) {
        return;
      }
      setState(() {
        if (hasPositionUpdate) {
          _position = _positionAnimation!.value;
        }
        if (hasScaleUpdate) {
          _currentScale = _scaleAnimation!.value;
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _snapToEdge();
      }
    });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event, MascotMetadata mascot) {
    final local = event.localPosition;
    final center = const Offset(_bubbleRadius, _bubbleRadius);
    final distance = (local - center).distance;

    final resolvedMode =
        mascot.uses3dModel && distance < _dragHandleThreshold
            ? _BubbleInputMode.mascotInteract
            : _BubbleInputMode.bubbleControl;

    if (_inputMode != resolvedMode) {
      HapticFeedback.selectionClick();
      setState(() {
        _inputMode = resolvedMode;
      });
    }
  }

  void _onPointerExit() {
    if (_isDragging) {
      return;
    }
    if (_inputMode != _BubbleInputMode.bubbleControl) {
      setState(() {
        _inputMode = _BubbleInputMode.bubbleControl;
      });
    }
  }

  void _onPanStart(DragStartDetails details) {
    _snapController.stop();
    setState(() {
      _inputMode = _BubbleInputMode.bubbleControl;
      _isDragging = true;
      _isHoveringTrash = false;
      _scaleAnimation = Tween<double>(begin: _currentScale, end: 1.0).animate(
        CurvedAnimation(parent: _snapController, curve: Curves.easeOut),
      );
    });
    HapticFeedback.selectionClick();
    _snapController.forward(from: 0);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      final screenSize = MediaQuery.of(context).size;
      final rawPosition = _position + details.delta;
      final clamped = _clampToViewport(rawPosition, screenSize);

      final trashCenter = Offset(screenSize.width / 2, screenSize.height - 80);
      final mascotCenter = Offset(
        clamped.dx + _bubbleRadius,
        clamped.dy + _bubbleRadius,
      );
      final distance = (mascotCenter - trashCenter).distance;

      _position = clamped;

      if (distance < _trashAttractionDistance) {
        final target = Offset(
          screenSize.width / 2 - _bubbleRadius,
          screenSize.height - 140,
        );
        final attraction = ((_trashAttractionDistance - distance) /
                _trashAttractionDistance)
            .clamp(0.0, 1.0);
        final lerpFactor = 0.14 + attraction * 0.42;
        _position = Offset.lerp(_position, target, lerpFactor)!;
      }

      final hovering = distance < _trashHoverDistance;
      if (hovering && !_isHoveringTrash) {
        HapticFeedback.selectionClick();
      }
      _isHoveringTrash = hovering;
    });
  }

  Future<void> _onPanEnd(
    DragEndDetails details,
    AiAssistantProvider provider,
  ) async {
    setState(() {
      _isDragging = false;
    });

    if (_isHoveringTrash) {
      await HapticFeedback.mediumImpact();
      await provider.hideMascot(reason: 'trash_drop');
      if (!mounted) {
        return;
      }
      setState(() {
        _isHoveringTrash = false;
        _position = const Offset(20, 100);
      });
      return;
    }

    _snapToEdge();
  }

  Offset _clampToViewport(Offset candidate, Size screenSize) {
    final minX = -(_bubbleSize * 0.2);
    final maxX = screenSize.width - (_bubbleSize * 0.8);
    final minY = 40.0;
    final maxY = screenSize.height - 200;

    return Offset(
      candidate.dx.clamp(minX, maxX),
      candidate.dy.clamp(minY, maxY),
    );
  }

  void _snapToEdge() {
    final screenSize = MediaQuery.of(context).size;
    final isLeft = _position.dx + _bubbleRadius < screenSize.width / 2;

    final targetX =
        isLeft
            ? -(_bubbleSize * 0.23)
            : screenSize.width - (_bubbleSize * 0.77);
    var targetY = _position.dy;

    if (targetY < 40) {
      targetY = 40;
    }
    if (targetY > screenSize.height - 200) {
      targetY = screenSize.height - 200;
    }

    _positionAnimation = Tween<Offset>(
      begin: _position,
      end: Offset(targetX, targetY),
    ).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: _currentScale, end: 0.86).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    );

    _snapController.forward(from: 0);
  }

  Widget _buildTrashZone() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: _isHoveringTrash ? 84 : 62,
          height: _isHoveringTrash ? 84 : 62,
          decoration: BoxDecoration(
            color:
                _isHoveringTrash
                    ? Colors.redAccent.withOpacity(0.9)
                    : Colors.black54,
            shape: BoxShape.circle,
            boxShadow:
                _isHoveringTrash
                    ? [
                      const BoxShadow(
                        color: Colors.redAccent,
                        blurRadius: 24,
                        spreadRadius: 6,
                      ),
                    ]
                    : [],
          ),
          child: Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: _isHoveringTrash ? 42 : 30,
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
      case AiState.idle:
        color = Colors.white.withOpacity(0.5);
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.48),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildStateHint(AiAssistantProvider provider) {
    if (provider.state == AiState.idle || provider.state == AiState.speaking) {
      return const SizedBox.shrink();
    }

    final text =
        provider.state == AiState.listening ? 'Đang nghe...' : 'Đang xử lý...';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.72),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildMascotSurface(AiAssistantProvider provider) {
    final mascot = provider.currentMascot;

    if (mascot.uses3dModel) {
      return ClipOval(
        child: O3D(
          key: ValueKey(mascot.id),
          controller: _o3dController,
          src: mascot.modelUrl!,
          autoPlay: true,
          disableZoom: true,
          cameraTarget:
              provider.state == AiState.thinking
                  ? CameraTarget(0, 0.45, 0)
                  : CameraTarget(0, 0, 0),
          cameraOrbit: CameraOrbit(0, 75, 105),
        ),
      );
    }

    return ClipOval(
      child: AiRobotAvatar(
        state: provider.state,
        emotion: provider.currentEmotion,
        onTap: () {
          provider.onPrimaryAction(source: 'robot_avatar');
        },
      ),
    );
  }

  Widget _buildLayeredGestureMask(AiAssistantProvider provider) {
    return IgnorePointer(
      ignoring: _inputMode == _BubbleInputMode.mascotInteract && !_isDragging,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: (details) {
          _onPanEnd(details, provider);
        },
        onTap: () {
          provider.onPrimaryAction(source: 'bubble_mask');
        },
      ),
    );
  }

  Future<void> _openMascotGallery() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MascotGalleryScreen()),
    );
  }

  Widget _buildMascotContainer(AiAssistantProvider provider) {
    final use3d = provider.currentMascot.uses3dModel;

    return Transform.scale(
      scale: _currentScale,
      child: SizedBox(
        width: _bubbleSize,
        height: _bubbleSize,
        child: Listener(
          onPointerDown: (event) {
            _onPointerDown(event, provider.currentMascot);
          },
          onPointerCancel: (_) => _onPointerExit(),
          onPointerUp: (_) => _onPointerExit(),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onExit: (_) => _onPointerExit(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: _bubbleSize,
                  height: _bubbleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        provider.state == AiState.speaking
                            ? Colors.greenAccent.withOpacity(0.24)
                            : Colors.blueAccent.withOpacity(0.14),
                        Colors.transparent,
                      ],
                      stops: const [0.52, 1.0],
                    ),
                    border: Border.all(
                      color:
                          _inputMode == _BubbleInputMode.bubbleControl
                              ? Colors.white.withOpacity(0.45)
                              : Colors.transparent,
                    ),
                  ),
                  child: _buildMascotSurface(provider),
                ),
                Positioned.fill(child: _buildLayeredGestureMask(provider)),
                Positioned(
                  top: -10,
                  right: -8,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openMascotGallery,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.62),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.tune,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
                if (use3d)
                  Positioned(
                    bottom: -8,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _inputMode == _BubbleInputMode.mascotInteract
                            ? 'Xoay mascot 3D'
                            : 'Kéo bubble',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AiAssistantProvider>();

    if (!aiProvider.isMascotVisible) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Stack(
        children: [
          if (_isDragging) _buildTrashZone(),
          if (aiProvider.aiResponse.isNotEmpty && !_isDragging)
            Positioned(
              left:
                  _position.dx < MediaQuery.of(context).size.width / 2
                      ? _position.dx + _bubbleSize - 8
                      : null,
              right:
                  _position.dx >= MediaQuery.of(context).size.width / 2
                      ? MediaQuery.of(context).size.width - _position.dx + 8
                      : null,
              top: max(_position.dy - 40, 60),
              child: AiChatBoard(onClose: aiProvider.clearAiResponse),
            ),
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBubbleIndicator(aiProvider),
                const SizedBox(height: 8),
                _buildMascotContainer(aiProvider),
                _buildStateHint(aiProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
