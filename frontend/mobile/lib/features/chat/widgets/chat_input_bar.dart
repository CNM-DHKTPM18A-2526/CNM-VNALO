import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;

  const ChatInputBar({super.key, required this.onSend});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    widget.onSend(text);
    _controller.clear();
    setState(() => _hasText = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: LightColors.surfaceLight,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.emoji_emotions_outlined),
              onPressed: () {},
              color: LightColors.textHint,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged:
                    (value) =>
                        setState(() => _hasText = value.trim().isNotEmpty),
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Nhap tin nhan...',
                  filled: true,
                  fillColor: LightColors.scaffold,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (_hasText)
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.primary),
                onPressed: _send,
              )
            else
              IconButton(
                icon: const Icon(Icons.mic, color: LightColors.textHint),
                onPressed: () {},
              ),
          ],
        ),
      ),
    );
  }
}
