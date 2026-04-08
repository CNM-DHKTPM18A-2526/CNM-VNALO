import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/models/quick_action_item.dart';

Future<void> showQuickActionsSheet(
  BuildContext context, {
  required List<QuickActionItem> items,
}) async {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
            children: items
                .map(
                  (item) => ListTile(
                    leading: Icon(item.icon, color: const Color(0xFF8C93A3)),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      item.onTap();
                    },
                  ),
                )
                .toList(),
          ),
        ),
      );
    },
  );
}
