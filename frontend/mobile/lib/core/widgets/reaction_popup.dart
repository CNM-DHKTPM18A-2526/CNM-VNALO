import 'package:flutter/material.dart';

class ReactionItem {
  final String type;
  final String emoji;
  final Color color;

  const ReactionItem({required this.type, required this.emoji, required this.color});
}

const List<ReactionItem> reactions = [
  ReactionItem(type: 'LOVE', emoji: '❤️', color: Colors.red),
  ReactionItem(type: 'HAHA', emoji: '😂', color: Colors.orange),
  ReactionItem(type: 'WOW', emoji: '😮', color: Colors.amber),
  ReactionItem(type: 'SAD', emoji: '😢', color: Colors.blue),
  ReactionItem(type: 'ANGRY', emoji: '😡', color: Colors.deepOrange),
];

class ReactionPopup extends StatefulWidget {
  final Offset position;
  final Function(String) onReactionSelected;

  const ReactionPopup({
    super.key,
    required this.position,
    required this.onReactionSelected,
  });

  @override
  State<ReactionPopup> createState() => _ReactionPopupState();
}

class _ReactionPopupState extends State<ReactionPopup> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // Position the popup above the thumb icon, clamp so it doesn't go off-screen
    double left = widget.position.dx - 16;
    double top = widget.position.dy - 72;
    if (left + 280 > screenSize.width) left = screenSize.width - 284;
    if (left < 4) left = 4;

    return Stack(
      children: [
        // Dismiss tap area
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(color: Colors.transparent),
        ),
        Positioned(
          left: left,
          top: top,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2C2C2E)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: reactions.map((reaction) {
                    return _ReactionButton(
                      reaction: reaction,
                      onTap: () {
                        widget.onReactionSelected(reaction.type);
                        Navigator.of(context).pop();
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReactionButton extends StatefulWidget {
  final ReactionItem reaction;
  final VoidCallback onTap;

  const _ReactionButton({required this.reaction, required this.onTap});

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton> with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _sizeAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _sizeAnimation = Tween<double>(begin: 30, end: 42).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _hoverController.forward(),
      onTapUp: (_) {
        _hoverController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _hoverController.reverse(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedBuilder(
          animation: _sizeAnimation,
          builder: (context, _) {
            return SizedBox(
              width: _sizeAnimation.value,
              height: _sizeAnimation.value,
              child: Center(
                child: Text(
                  widget.reaction.emoji,
                  style: TextStyle(fontSize: _sizeAnimation.value * 0.8),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
