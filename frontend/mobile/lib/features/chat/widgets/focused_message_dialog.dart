import 'package:flutter/material.dart';
import 'package:vnalo_mobile/features/chat/widgets/message_action_menu.dart';
import 'package:vnalo_mobile/models/message_model.dart';

class FocusedMessageDialog extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Offset position;
  final Size size;
  final Widget child; // The bubble widget to show in focus
  final Function(String action) onAction;

  const FocusedMessageDialog({
    super.key,
    required this.message,
    required this.isMine,
    required this.position,
    required this.size,
    required this.child,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    
    // Estimated height for the menu (Emoji box + spacing + Action box)
    const double estimatedMenuHeight = 520.0;
    const double spacing = 16.0;
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
          // Dark background (interactive)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: Colors.black.withOpacity(0.7),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          
          // The Bubble (Highlighted)
          Positioned(
            top: bubbleTop,
            left: position.dx,
            width: size.width,
            child: child,
          ),
          
          // The Action Menu (Always Below)
          Positioned(
            top: bubbleTop + size.height + spacing,
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: MessageActionMenu(
                message: message,
                isMine: isMine,
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
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) => FocusedMessageDialog(
          message: message,
          isMine: isMine,
          position: position,
          size: size,
          child: child,
          onAction: onAction,
        ),
        transitionsBuilder: (context, animation, secondAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}
