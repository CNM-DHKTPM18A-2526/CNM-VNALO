import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/models/quick_action_item.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

Future<void> showQuickActionsSheet(
  BuildContext context, {
  required List<QuickActionItem> items,
}) async {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final selected = await showModalBottomSheet<QuickActionItem>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final sheetBg = isDarkMode ? DarkColors.surface : Colors.white;
      final dividerColor = isDarkMode ? DarkColors.divider : AppColors.sectionDivider;
      final titleColor = isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary;
      final iconColor = isDarkMode ? DarkColors.textSecondary : AppColors.iconSubtle;

      return Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 56,
                height: 6,
                decoration: BoxDecoration(
                  color: dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(items.length, (index) {
                final item = items[index];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        highlightColor: AppColors.itemPressBackground,
                        splashColor: AppColors.itemPressBackground.withValues(alpha: 0.7),
                        onTap: () => Navigator.pop(sheetContext, item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(item.icon, size: 22, color: iconColor),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (index < items.length - 1)
                      Divider(height: 1, indent: 52, color: dividerColor),
                  ],
                );
              }),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: dividerColor),
                      foregroundColor: titleColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('Hủy'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  selected?.onTap();
}
