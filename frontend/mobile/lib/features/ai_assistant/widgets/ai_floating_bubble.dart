import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/models/mascot_metadata.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/screens/ai_conversation_screen.dart';
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
  static const double _trashHoverDistance = 72;
  static const double _trashAttractionDistance = 126;
  static const double _trashActivationBandFromBottom = 260;

  Offset _position = const Offset(20, 100);
  Widget _buildMascotSurface(AiAssistantProvider provider) {
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
    return GestureDetector(
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
        provider.onPrimaryAction(source: 'bubble_mask');
      },
    );
  }

  void _toggleBoard() {
    setState(() {
      _isBoardExpanded = !_isBoardExpanded;
    });
  }

  Future<void> _openMascotGallery() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MascotGalleryScreen()),
    );
  }

  Future<void> _openAiConversation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiConversationScreen()),
    );
  }

  Widget _buildMascotContainer(AiAssistantProvider provider) {
    return Transform.scale(
      scale: _currentScale,
      child: SizedBox(
        width: _bubbleSize,
        height: _bubbleSize,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
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
                top: -10,
                left: -8,
                child: GestureDetector(
                  key: const ValueKey('ai_bubble_toggle_board'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleBoard,
                  onLongPress: _openAiConversation,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color:
                          _isBoardExpanded
                              ? Colors.blueAccent.withValues(alpha: 0.84)
                              : Colors.black.withValues(alpha: 0.62),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
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
                      color: Colors.black.withValues(alpha: 0.62),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AiAssistantProvider>();
    final screenSize = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final availableHeight = max(240.0, screenSize.height - viewInsets.bottom);

    const boardPadding = 12.0;
    final boardWidth = min(340.0, screenSize.width - (boardPadding * 2));
    final boardHeight = min(420.0, availableHeight * 0.56);

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
    final boardTop =
        desiredTop
            .clamp(56.0, max(56.0, availableHeight - boardHeight - 16.0))
            .toDouble();

    final showBoard =
        !_isDragging && (_isBoardExpanded || aiProvider.aiResponse.isNotEmpty);

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
                  aiProvider.clearAiResponse();
                  setState(() {
                    _isBoardExpanded = false;
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
