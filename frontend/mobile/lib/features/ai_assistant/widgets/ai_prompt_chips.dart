import 'package:flutter/material.dart';

class AiPromptChips extends StatelessWidget {
  static const openContactsPrompt = 'Mở danh bạ';

  final ValueChanged<String> onSelected;
  final bool compact;

  const AiPromptChips({
    super.key,
    required this.onSelected,
    this.compact = false,
  });

  static const _prompts = <String>[
    'Tóm tắt đoạn chat này',
    'Dịch tin nhắn gần nhất',
    'Soạn tin cho An là mình tới trễ',
    openContactsPrompt,
  ];

  static const _compactPrompts = <String>[
    'Tóm tắt chat',
    'Dịch tin gần nhất',
    'Soạn tin cho An',
    openContactsPrompt,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: compact ? 38 : 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(12, compact ? 2 : 4, 12, 4),
        itemBuilder: (context, index) {
          final prompt = _prompts[index];
          final label = compact ? _compactPrompts[index] : prompt;
          return ActionChip(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
            label: Text(
              label,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            avatar: Icon(
              Icons.auto_awesome,
              size: 14,
              color: isDark ? Colors.cyanAccent : const Color(0xFF2563EB),
            ),
            backgroundColor:
                isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFEFF6FF),
            side: BorderSide(
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : const Color(0xFFBFDBFE),
            ),
            visualDensity: VisualDensity.compact,
            onPressed: () => onSelected(prompt),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _prompts.length,
      ),
    );
  }
}
