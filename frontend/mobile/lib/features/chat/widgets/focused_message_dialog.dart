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
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    
    // Estimated height for the menu (Emoji box + spacing + Action box)
    const double estimatedMenuHeight = 520.0;
    const double spacing = 12.0;
    const double margin = 16.0;

    // Check if there is enough space below the bubble
    double bubbleTop = position.dy;
    double bubbleBottom = bubbleTop + size.height;
    
    // Calculate how much we need to shift the bubble up if it's too low
    double availableSpaceBelow = screenHeight - bubbleBottom - safeAreaBottom - margin;
    
    if (availableSpaceBelow < estimatedMenuHeight) {
      // Shift upward by the missing amount
      double shift = estimatedMenuHeight - availableSpaceBelow;
      bubbleTop -= shift;
      // Ensure it doesn't go above screen top
      if (bubbleTop < 40) bubbleTop = 40; 
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Dark blurred background
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 200),
              builder: (context, value, child) {
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5 * value, sigmaY: 5 * value),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4 * value),
                    width: double.infinity,
                    height: double.infinity,
                  ),
                );
              },
            ),
          ),
          
          // 2. The Bubble (Highlighted)
          Positioned(
            top: bubbleTop,
            left: position.dx,
            width: size.width,
            child: Hero(
              tag: 'msg_${message.id}',
              child: Material(
                color: Colors.transparent,
                child: child,
              ),
            ),
          ),
          
          // 3. The Action Menu (Always Below)
          Positioned(
            top: bubbleTop + size.height + spacing,
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: MessageActionMenu(
                message: message,
                isMine: isMine,
                isCloud: isCloud,
                isPinned: isPinned,
                onAction: onAction,
              ),
            ),
          ),
        ],
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
