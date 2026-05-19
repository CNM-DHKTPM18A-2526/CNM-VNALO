import 'package:flutter/material.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';

class AiStatusPill extends StatelessWidget {
  final AiState state;
  final bool compact;

  const AiStatusPill({super.key, required this.state, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (state) {
      AiState.listening => ('Đang nghe', const Color(0xFFEF4444), Icons.mic),
      AiState.thinking => (
        'Đang xử lý',
        const Color(0xFF2563EB),
        Icons.auto_awesome,
      ),
      AiState.speaking => (
        'Đang phản hồi',
        const Color(0xFF16A34A),
        Icons.volume_up,
      ),
      AiState.idle => ('Sẵn sàng', const Color(0xFF64748B), Icons.bolt),
    };

    return Semantics(
      label: 'Trạng thái trợ lý AI: $label',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 12 : 14, color: color),
            if (!compact) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
