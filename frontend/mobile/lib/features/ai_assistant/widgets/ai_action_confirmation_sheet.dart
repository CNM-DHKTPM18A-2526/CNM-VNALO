import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/theme/app_typography.dart';

enum AiActionConfirmationResult { cancelled, confirmed, alternate }

class AiActionConfirmationSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String confirmLabel;
  final String cancelLabel;
  final String? alternateLabel;
  final String? primaryDetail;
  final String? secondaryDetail;
  final String? primaryDetailLabel;
  final String? secondaryDetailLabel;
  final bool destructive;

  const AiActionConfirmationSheet({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.confirmLabel,
    this.cancelLabel = 'Hủy',
    this.alternateLabel,
    this.primaryDetail,
    this.secondaryDetail,
    this.primaryDetailLabel,
    this.secondaryDetailLabel,
    this.destructive = false,
  });

  static Future<bool> show(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String confirmLabel,
    String cancelLabel = 'Hủy',
    String? alternateLabel,
    String? primaryDetail,
    String? secondaryDetail,
    String? primaryDetailLabel,
    String? secondaryDetailLabel,
    bool destructive = false,
  }) async {
    final result = await showForResult(
      context,
      icon: icon,
      title: title,
      description: description,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      alternateLabel: alternateLabel,
      primaryDetail: primaryDetail,
      secondaryDetail: secondaryDetail,
      primaryDetailLabel: primaryDetailLabel,
      secondaryDetailLabel: secondaryDetailLabel,
      destructive: destructive,
    );
    return result == AiActionConfirmationResult.confirmed;
  }

  static Future<AiActionConfirmationResult> showForResult(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String confirmLabel,
    String cancelLabel = 'Hủy',
    String? alternateLabel,
    String? primaryDetail,
    String? secondaryDetail,
    String? primaryDetailLabel,
    String? secondaryDetailLabel,
    bool destructive = false,
  }) async {
    return await showModalBottomSheet<AiActionConfirmationResult>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder:
              (_) => AiActionConfirmationSheet(
                icon: icon,
                title: title,
                description: description,
                confirmLabel: confirmLabel,
                cancelLabel: cancelLabel,
                alternateLabel: alternateLabel,
                primaryDetail: primaryDetail,
                secondaryDetail: secondaryDetail,
                primaryDetailLabel: primaryDetailLabel,
                secondaryDetailLabel: secondaryDetailLabel,
                destructive: destructive,
              ),
        ) ??
        AiActionConfirmationResult.cancelled;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = destructive ? AppColors.error : AppColors.primary;
    final sheetBackground = isDark ? DarkColors.surface : Colors.white;
    final textPrimary =
        isDark ? DarkColors.textPrimary : LightColors.textPrimary;
    final textSecondary =
        isDark ? DarkColors.textSecondary : const Color(0xFF475569);
    final secondaryButtonBg =
        isDark ? DarkColors.surfaceLight : AppColors.itemPressBackground;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: sheetBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            isDark ? Colors.white24 : AppColors.sectionDivider,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: accent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            title,
                            style: AppTypography.titleMedium.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: AppTypography.bodyMedium.copyWith(
                      height: 1.45,
                      color: textSecondary,
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
                        borderRadius: BorderRadius.circular(14),
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
                            _DetailBlock(
                              label: primaryDetailLabel ?? 'Đích đến',
                              value: primaryDetail!,
                              color: textPrimary,
                              labelColor: textSecondary,
                              emphasized: true,
                            ),
                          if (secondaryDetail != null) ...[
                            if (primaryDetail != null)
                              const SizedBox(height: 12),
                            _DetailBlock(
                              label: secondaryDetailLabel ?? 'Nội dung',
                              value: secondaryDetail!,
                              color: textSecondary,
                              labelColor: textSecondary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed:
                          () => Navigator.of(
                            context,
                          ).pop(AiActionConfirmationResult.confirmed),
                      child: Text(
                        confirmLabel,
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (alternateLabel != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed:
                            () => Navigator.of(
                              context,
                            ).pop(AiActionConfirmationResult.alternate),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: BorderSide(
                            color: accent.withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          alternateLabel!,
                          style: AppTypography.labelLarge.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                          () => Navigator.of(
                            context,
                          ).pop(AiActionConfirmationResult.cancelled),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: secondaryButtonBg,
                        foregroundColor: textPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        cancelLabel,
                        style: AppTypography.labelLarge.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color labelColor;
  final bool emphasized;

  const _DetailBlock({
    required this.label,
    required this.value,
    required this.color,
    required this.labelColor,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: emphasized ? 2 : 6,
          overflow: TextOverflow.ellipsis,
          style: (emphasized
                  ? AppTypography.labelLarge
                  : AppTypography.bodyMedium)
              .copyWith(
                color: color,
                height: 1.4,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
              ),
        ),
      ],
    );
  }
}
