import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vnalo_mobile/features/chat/widgets/message_action_menu.dart';
import 'package:vnalo_mobile/models/message_model.dart';

class FocusedMessageDialog extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Offset position;
  final Size size;
  final Widget child; // The bubble widget to show in focus
  final bool isCloud;
  final bool isPinned;
  final bool isAiAssistant;
  final Function(String action) onAction;

  const FocusedMessageDialog({
    super.key,
    required this.message,
    required this.isMine,
    required this.position,
    required this.size,
    required this.child,
    required this.onAction,
    this.isCloud = false,
    this.isPinned = false,
    this.isAiAssistant = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;
          
          // Minimum menu height we want to preserve
          const double minMenuHeight = 250.0;
          const double preferredMenuHeight = 500.0;
          const double spacing = 12.0;
          const double margin = 16.0;
          const double topThreshold = 60.0; // Avoid being too close to top

          // 1. Calculate how much space we have for the bubble
          double availableForBubble = h - minMenuHeight - spacing - margin - safeAreaTop - topThreshold;
          
          double effectiveBubbleHeight = size.height;
          if (effectiveBubbleHeight > availableForBubble) {
            effectiveBubbleHeight = availableForBubble;
          }

          // 2. Determine bubble top
          double bubbleTop = position.dy;
          double menuTop = bubbleTop + effectiveBubbleHeight + spacing;
          
          // If menu goes off bottom, shift everything up
          if (menuTop + preferredMenuHeight > h - margin) {
             double shift = (menuTop + preferredMenuHeight) - (h - margin);
             bubbleTop -= shift;
             // Ensure it doesn't go above safe area
             if (bubbleTop < safeAreaTop + topThreshold) {
                bubbleTop = safeAreaTop + topThreshold;
             }
             menuTop = bubbleTop + effectiveBubbleHeight + spacing;
          }

          // 3. Final calculations for menu height
          double availableMenuHeight = h - menuTop - margin;
          if (availableMenuHeight < minMenuHeight) {
            // This happens if effectiveBubbleHeight was still too large, 
            // recalculate everything based on absolute minimums
            availableMenuHeight = minMenuHeight;
            menuTop = h - margin - availableMenuHeight;
            bubbleTop = menuTop - spacing - effectiveBubbleHeight;
          }

          return Stack(
            children: [
              // 1. Background
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(color: Colors.black.withValues(alpha: 0.4)),
                ),
              ),

              // 2. Bubble
              Positioned(
                top: bubbleTop,
                left: position.dx,
                width: size.width,
                height: effectiveBubbleHeight,
                child: ClipRect(
                  child: Material(
                    color: Colors.transparent,
                    child: child,
                  ),
                ),
              ),

              // 3. Menu
              Positioned(
                top: menuTop,
                left: 20,
                right: 20,
                height: availableMenuHeight,
                child: Material(
                  color: Colors.transparent,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MessageActionMenu(
                          message: message,
                          isMine: isMine,
                          isCloud: isCloud,
                          isPinned: isPinned,
                          isAiAssistant: isAiAssistant,
                          onAction: onAction,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static void show(
    BuildContext context, {
    required Message message,
    required bool isMine,
    required Offset position,
    required Size size,
    required Widget child,
    required Function(String action) onAction,
    bool isCloud = false,
    bool isPinned = false,
    bool isAiAssistant = false,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) => FocusedMessageDialog(
          message: message,
          isMine: isMine,
          isCloud: isCloud,
          isPinned: isPinned,
          isAiAssistant: isAiAssistant,
          position: position,
          size: size,
          onAction: onAction,
          child: child,
        ),
        transitionsBuilder: (context, animation, secondAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}
