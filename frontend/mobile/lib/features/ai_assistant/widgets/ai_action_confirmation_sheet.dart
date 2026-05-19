import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class AiActionConfirmationSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String confirmLabel;
  final String? primaryDetail;
  final String? secondaryDetail;
  final bool destructive;

  const AiActionConfirmationSheet({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.confirmLabel,
    this.primaryDetail,
    this.secondaryDetail,
    this.destructive = false,
  });

  static Future<bool> show(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String confirmLabel,
    String? primaryDetail,
    String? secondaryDetail,
    bool destructive = false,
  }) async {
    return await showModalBottomSheet<bool>(
          context: context,
          useSafeArea: true,
          showDragHandle: true,
          backgroundColor: Theme.of(context).cardColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder:
              (_) => AiActionConfirmationSheet(
                icon: icon,
                title: title,
                description: description,
                confirmLabel: confirmLabel,
                primaryDetail: primaryDetail,
                secondaryDetail: secondaryDetail,
                destructive: destructive,
              ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = destructive ? const Color(0xFFDC2626) : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              height: 1.45,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          if (primaryDetail != null || secondaryDetail != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color:
                      isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (primaryDetail != null)
                    Text(
                      primaryDetail!,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  if (secondaryDetail != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      secondaryDetail!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Hủy'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
