import 'package:flutter/material.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';

class AiStatusPill extends StatelessWidget {
  final AiState state;
  final bool compact;
  final bool degraded;
  final String providerStatus;

  const AiStatusPill({
    super.key,
    required this.state,
    this.compact = false,
    this.degraded = false,
    this.providerStatus = 'LIVE_PROVIDER_ACTIVE',
  });

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _resolveVisualState();

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

  (String, Color, IconData) _resolveVisualState() {
    if (providerStatus == 'AI_PROVIDER_TIMEOUT') {
      return ('Phản hồi chậm', const Color(0xFFF59E0B), Icons.timer_outlined);
    }

    if (providerStatus == 'AI_NETWORK_UNAVAILABLE') {
      return ('Mất kết nối', const Color(0xFFF59E0B), Icons.wifi_off_rounded);
    }

    if (providerStatus == 'AI_ENDPOINT_NOT_FOUND') {
      return ('Sai cấu hình', const Color(0xFFEF4444), Icons.error_outline);
    }

    if (providerStatus == 'AI_AUTH_REQUIRED') {
      return ('Cần đăng nhập', const Color(0xFFEF4444), Icons.lock_outline);
    }

    if (providerStatus == 'AI_RATE_LIMITED') {
      return ('Gửi quá nhanh', const Color(0xFFF59E0B), Icons.speed_rounded);
    }

    if (providerStatus == 'AI_PROVIDER_UNAVAILABLE') {
      return (
        'AI tạm gián đoạn',
        const Color(0xFFF59E0B),
        Icons.warning_amber_rounded,
      );
    }

    if (providerStatus == 'FALLBACK_PROVIDER_ACTIVE' || degraded) {
      return (
        'Chế độ dự phòng',
        const Color(0xFFF59E0B),
        Icons.shield_outlined,
      );
    }

    return switch (state) {
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
  }
}
