import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/models/quick_action_item.dart';

Future<void> showQuickActionsSheet(
  BuildContext context, {
  required List<QuickActionItem> items,
}) async {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final sheetBg = isDarkMode ? const Color(0xFF272A30) : Colors.white;
  final iconColor = isDarkMode ? const Color(0xFFB0B7C3) : const Color(0xFF5D6470);
  final titleColor = isDarkMode ? Colors.white : const Color(0xFF1F2937);
  final dividerColor = isDarkMode ? const Color(0xFF353A43) : const Color(0xFFE9EDF3);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: sheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              ...List.generate(items.length, (index) {
                final item = items[index];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Icon(item.icon, color: iconColor, size: 28),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        item.onTap();
                      },
                    ),
                    if (index < items.length - 1)
                      Divider(
                        height: 1,
                        thickness: 0.7,
                        indent: 72,
                        color: dividerColor,
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}
