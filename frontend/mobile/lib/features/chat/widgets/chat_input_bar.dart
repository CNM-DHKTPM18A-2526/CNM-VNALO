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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? DarkColors.surface : LightColors.surface,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? DarkColors.divider : AppColors.sectionDivider,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.emoji_emotions_outlined, size: 28),
                onPressed: () {},
                color: isDarkMode ? DarkColors.textSecondary : Colors.grey.shade600,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: (value) => setState(() => _hasText = value.trim().isNotEmpty),
                  minLines: 1,
                  maxLines: 5,
                  style: TextStyle(
                    fontSize: 17,
                    color: isDarkMode ? Colors.white : LightColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tin nhắn',
                    hintStyle: TextStyle(
                      color: isDarkMode ? DarkColors.textHint : Colors.grey.shade400,
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_hasText)
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary, size: 28),
                  onPressed: _send,
                  padding: const EdgeInsets.all(8),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.more_horiz, size: 28),
                      onPressed: () {},
                      color: isDarkMode ? DarkColors.textSecondary : Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.mic_none, size: 28),
                      onPressed: () {},
                      color: isDarkMode ? DarkColors.textSecondary : Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.image_outlined, size: 28),
                      onPressed: () {},
                      color: isDarkMode ? DarkColors.textSecondary : Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
