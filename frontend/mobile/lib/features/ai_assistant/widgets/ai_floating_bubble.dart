import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vnalo_mobile/features/ai_assistant/models/mascot_metadata.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/screens/ai_conversation_screen.dart';
import 'package:vnalo_mobile/features/ai_assistant/screens/mascot_gallery_screen.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_chat_board.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_robot_avatar.dart';

class AiFloatingBubble extends StatefulWidget {
  const AiFloatingBubble({super.key});

  @override
  State<AiFloatingBubble> createState() => _AiFloatingBubbleState();
}

class _AiFloatingBubbleState extends State<AiFloatingBubble>
    with TickerProviderStateMixin {
  static const double _bubbleSize = 78;
  static const double _bubbleRadius = _bubbleSize / 2;
  static const double _bubbleRootHeight = 108;
  static const String _positionXPrefKey = 'vnalo_ai_bubble_x';
  static const String _positionYPrefKey = 'vnalo_ai_bubble_y';
  static const double _trashHoverDistance = 72;
  static const double _trashAttractionDistance = 126;
  static const double _trashActivationBandFromBottom = 260;

  Offset _position = const Offset(20, 100);

  bool _isDragging = false;
  bool _isHoveringTrash = false;
  bool _isBoardExpanded = false;
  String? _dismissedAssistantEntryId;

  DateTime? _ignoreTapUntil;

  late final AnimationController _snapController;
  Animation<Offset>? _positionAnimation;
  Animation<double>? _scaleAnimation;

  double _currentScale = 0.86;
  Size? _lastViewportSize;
  double? _lastViewInsetsBottom;
  double? _lastPaddingTop;

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
        _restorePositionAndSnap();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mediaQuery = MediaQuery.of(context);
    final viewportChanged =
        _lastViewportSize != mediaQuery.size ||
        _lastViewInsetsBottom != mediaQuery.viewInsets.bottom ||
        _lastPaddingTop != mediaQuery.padding.top;

    _lastViewportSize = mediaQuery.size;
    _lastViewInsetsBottom = mediaQuery.viewInsets.bottom;
    _lastPaddingTop = mediaQuery.padding.top;

    if (viewportChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDragging) {
          return;
        }
        final clamped = _clampToViewport(_position);
        if ((clamped - _position).distance > 0.5) {
          setState(() {
            _positionAnimation = null;
            _position = clamped;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event, MascotMetadata mascot) {
    // 3D model support removed - always use bubbleControl mode
  }

  void _onPointerExit() {
    // 3D model support removed - no mode switching needed
  }

  void _onPanStart(DragStartDetails details) {
    _snapController.stop();
    setState(() {
      _positionAnimation = null;
      _scaleAnimation = null;
      _isDragging = true;
      _isHoveringTrash = false;
      _currentScale = 1.0;
    });
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      final screenSize = MediaQuery.of(context).size;
      final rawPosition = _position + details.delta;
      final clamped = _clampToViewport(rawPosition);

      final distance = _distanceToTrashZone(clamped, screenSize);
      final inTrashBand = _isInTrashBand(clamped, screenSize);

      _position = clamped;

      if (inTrashBand && distance < _trashAttractionDistance) {
        final target = Offset(
          screenSize.width / 2 - _bubbleRadius,
          _trashCenterY(screenSize) - _bubbleRadius,
        );
        final attraction = ((_trashAttractionDistance - distance) /
                _trashAttractionDistance)
            .clamp(0.0, 1.0);
        final lerpFactor = 0.08 + attraction * 0.18;
        _position = Offset.lerp(_position, target, lerpFactor)!;
      }

      final hovering = inTrashBand && distance < _trashHoverDistance;
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
      _ignoreTapUntil = DateTime.now().add(const Duration(milliseconds: 220));
    });

    final screenSize = MediaQuery.of(context).size;
    final shouldDrop =
        _isHoveringTrash ||
        _isWithinTrashDropZone(_position, screenSize, hoverPadding: 10);

    if (shouldDrop) {
      await HapticFeedback.mediumImpact();
      await provider.hideMascot(reason: 'trash_drop');
      if (!mounted) {
        return;
      }
      setState(() {
        _isHoveringTrash = false;
        _isBoardExpanded = false;
        _position = const Offset(20, 100);
      });
      await _persistPosition(_position);
      return;
    }

    _snapToEdge();
  }

  Future<void> _restorePositionAndSnap() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedX = prefs.getDouble(_positionXPrefKey);
    final savedY = prefs.getDouble(_positionYPrefKey);
    if (savedX != null && savedY != null) {
      setState(() {
        _position = _clampToViewport(Offset(savedX, savedY));
      });
    }
    _snapToEdge();
  }

  Future<void> _persistPosition(Offset position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_positionXPrefKey, position.dx);
    await prefs.setDouble(_positionYPrefKey, position.dy);
  }

  bool _isInTrashBand(Offset position, Size screenSize) {
    final mascotCenterY = position.dy + _bubbleRadius;
    return mascotCenterY >
        (_trashCenterY(screenSize) - _trashActivationBandFromBottom);
  }

  double _distanceToTrashZone(Offset position, Size screenSize) {
    final trashCenter = Offset(screenSize.width / 2, _trashCenterY(screenSize));
    final mascotCenter = Offset(
      position.dx + _bubbleRadius,
      position.dy + _bubbleRadius,
    );
    return (mascotCenter - trashCenter).distance;
  }

  bool _isWithinTrashDropZone(
    Offset position,
    Size screenSize, {
    double hoverPadding = 0,
  }) {
    if (!_isInTrashBand(position, screenSize)) {
      return false;
    }

    return _distanceToTrashZone(position, screenSize) <=
        (_trashHoverDistance + hoverPadding);
  }

  double _trashCenterY(Size screenSize) {
    final mediaQuery = MediaQuery.of(context);
    return screenSize.height -
        mediaQuery.viewInsets.bottom -
        mediaQuery.padding.bottom -
        80;
  }

  Offset _clampToViewport(Offset candidate) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final padding = mediaQuery.padding;
    final viewInsets = mediaQuery.viewInsets;
    const horizontalInset = 8.0;
    const verticalInset = 8.0;
    final minX = padding.left + horizontalInset;
    final maxX =
        screenSize.width - padding.right - _bubbleSize - horizontalInset;
    final minY = padding.top + verticalInset;
    final maxY = max(
      minY,
      screenSize.height -
          viewInsets.bottom -
          padding.bottom -
          (_bubbleRootHeight + 18),
    );

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
    final target = _clampToViewport(Offset(targetX, _position.dy));
    final viewportDiagonal = sqrt(
      (screenSize.width * screenSize.width) +
          (screenSize.height * screenSize.height),
    );
    final distanceRatio =
        viewportDiagonal <= 0
            ? 0.0
            : ((_position - target).distance / viewportDiagonal).clamp(
              0.0,
              1.0,
            );
    _snapController.duration = Duration(
      milliseconds: (150 + (distanceRatio * 250)).clamp(150, 400).toInt(),
    );

    _positionAnimation = Tween<Offset>(begin: _position, end: target).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: _currentScale, end: 0.86).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    );

    unawaited(_persistPosition(target));
    _snapController.forward(from: 0);
  }

  Widget _buildTrashZone() {
    final mediaQuery = MediaQuery.of(context);
    return Positioned(
      bottom: 40 + mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedContainer(
          key: const ValueKey('ai_bubble_trash_zone'),
          duration: const Duration(milliseconds: 180),
          width: _isHoveringTrash ? 84 : 62,
          height: _isHoveringTrash ? 84 : 62,
          decoration: BoxDecoration(
            color:
                _isHoveringTrash
                    ? Colors.redAccent.withValues(alpha: 0.9)
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
        color = Colors.white.withValues(alpha: 0.5);
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
            color: color.withValues(alpha: 0.48),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildMascotSurface(AiAssistantProvider provider) {
    // Always use 2D avatar - 3D model support removed due to package dependency issues
    return ClipOval(
      child: AiRobotAvatar(
        state: provider.state,
        emotion: provider.currentEmotion,
        size: _bubbleSize,
        onTap: () {
          _toggleBoard(provider);
        },
      ),
    );
  }

  Widget _buildLayeredGestureMask(AiAssistantProvider provider) {
    return IgnorePointer(
      ignoring: false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: (details) {
          _onPanEnd(details, provider);
        },
        onTap: () {
          if (_ignoreTapUntil != null &&
              DateTime.now().isBefore(_ignoreTapUntil!)) {
            return;
          }
          _toggleBoard(provider);
        },
        onLongPress:
            () => provider.onPrimaryAction(source: 'bubble_long_press'),
      ),
    );
  }

  void _toggleBoard(AiAssistantProvider provider) {
    final latestAssistantEntryId = _latestAssistantEntryId(provider);
    setState(() {
      if (_isBoardExpanded) {
        _dismissedAssistantEntryId = latestAssistantEntryId;
      } else {
        _dismissedAssistantEntryId = null;
      }
      _isBoardExpanded = !_isBoardExpanded;
    });
  }

  String? _latestAssistantEntryId(AiAssistantProvider provider) {
    for (final entry in provider.conversationHistory.reversed) {
      if (entry.role == AiConversationRole.assistant) {
        return entry.entryId;
      }
    }
    return null;
  }

  Future<void> _openMascotGallery() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MascotGalleryScreen()),
    );
  }

  Future<void> _openAiConversation() async {
    if (mounted) {
      context.read<AiAssistantProvider>().enterConversationSurface(
        reason: 'bubble_open_conversation',
      );
      setState(() {
        _isBoardExpanded = false;
      });
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiConversationScreen()),
    );
    if (mounted) {
      context.read<AiAssistantProvider>().leaveConversationSurface(
        reason: 'bubble_close_conversation',
      );
    }
  }

  Widget _buildMascotContainer(AiAssistantProvider provider) {
    return Transform.scale(
      scale: _currentScale,
      child: SizedBox(
        width: _bubbleSize + 8,
        height: _bubbleSize + 8,
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
                            ? Colors.greenAccent.withValues(alpha: 0.24)
                            : Colors.blueAccent.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                      stops: const [0.52, 1.0],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  child: _buildMascotSurface(provider),
                ),
                Positioned.fill(child: _buildLayeredGestureMask(provider)),
                Positioned(
                  top: 2,
                  left: 2,
                  child: GestureDetector(
                    key: const ValueKey('ai_bubble_toggle_board'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggleBoard(provider),
                    onLongPress: _openAiConversation,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color:
                            _isBoardExpanded
                                ? Colors.blueAccent.withValues(alpha: 0.84)
                                : Colors.black.withValues(alpha: 0.62),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.42),
                        ),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    key: const ValueKey('ai_bubble_open_gallery'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _openMascotGallery,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.62),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.42),
                        ),
                      ),
                      child: const Icon(
                        Icons.tune,
                        color: Colors.white,
                        size: 14,
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
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final viewInsets = mediaQuery.viewInsets;
    final padding = mediaQuery.padding;
    final availableHeight = max(240.0, screenSize.height - viewInsets.bottom);

    const boardPadding = 12.0;
    final boardWidth = min(320.0, screenSize.width - (boardPadding * 2));
    final compactHeightLimit = max(
      220.0,
      availableHeight - padding.top - padding.bottom - 24.0,
    );
    final boardHeight = min(392.0, compactHeightLimit);

    final prefersRightDock = _position.dx < screenSize.width / 2;
    final desiredLeft =
        prefersRightDock
            ? _position.dx + _bubbleSize - 8
            : _position.dx - boardWidth + 8;
    final boardLeft =
        desiredLeft
            .clamp(boardPadding, screenSize.width - boardWidth - boardPadding)
            .toDouble();

    final desiredTop = _position.dy - (boardHeight * 0.34);
    final minBoardTop = padding.top + 8.0;
    final maxBoardTop = max(
      minBoardTop,
      availableHeight - boardHeight - padding.bottom - 16.0,
    );
    final boardTop = desiredTop.clamp(minBoardTop, maxBoardTop).toDouble();

    final latestAssistantEntryId = _latestAssistantEntryId(aiProvider);
    final hasNewBubbleResponse =
        aiProvider.aiResponse.isNotEmpty &&
        aiProvider.shouldBubbleAutoShowResponse &&
        latestAssistantEntryId != null &&
        latestAssistantEntryId != _dismissedAssistantEntryId;
    final showBoard =
        !_isDragging && (_isBoardExpanded || hasNewBubbleResponse);

    if (!aiProvider.isMascotVisible) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Stack(
        children: [
          if (_isDragging) _buildTrashZone(),
          if (showBoard)
            Positioned(
              left: boardLeft,
              top: boardTop,
              child: AiChatBoard(
                onClose: () {
                  setState(() {
                    _isBoardExpanded = false;
                    _dismissedAssistantEntryId = latestAssistantEntryId;
                  });
                },
                onClear: aiProvider.clearAiResponse,
                onOpenConversation: _openAiConversation,
                maxWidth: boardWidth,
                maxHeight: boardHeight,
                onSubmitPrompt: (text) async {
                  setState(() {
                    _isBoardExpanded = true;
                  });
                  await aiProvider.submitTextPrompt(
                    text,
                    source: 'bubble_chat_board',
                    surface: AiResponseSurface.bubble,
                  );
                },
              ),
            ),
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: Column(
              key: const ValueKey('ai_bubble_root'),
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBubbleIndicator(aiProvider),
                const SizedBox(height: 10),
                _buildMascotContainer(aiProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
