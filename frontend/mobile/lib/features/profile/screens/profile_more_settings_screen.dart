import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/profile/screens/account_security_screen.dart';

class ProfileMoreSettingsScreen extends StatelessWidget {
  const ProfileMoreSettingsScreen({super.key, required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final sectionBg = isDarkMode ? DarkColors.surface : Colors.white;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.sectionDivider;
    final textColor = isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary;
    final sectionLabel = isDarkMode ? DarkColors.textHint : const Color(0xFF5E7A93);

    Widget item(String title, {VoidCallback? onTap}) {
      return ListTile(
        tileColor: sectionBg,
        title: Text(title, style: TextStyle(color: textColor, fontSize: 16)),
        onTap: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title Ä‘ang dÃ¹ng fallback táº¡m thá»i.')),
              );
            },
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
              ),
        title: Text(displayName),
      ),
      body: ListView(
        children: [
          Container(
            color: sectionBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                item('ThÃ´ng tin'),
                Divider(height: 1, indent: 16, color: dividerColor),
                item('Äá»•i áº£nh Ä‘áº¡i diá»‡n'),
                Divider(height: 1, indent: 16, color: dividerColor),
                item('Äá»•i áº£nh bÃ¬a'),
                Divider(height: 1, indent: 16, color: dividerColor),
                item('Cáº­p nháº­t giá»›i thiá»‡u báº£n thÃ¢n'),
                Divider(height: 1, indent: 16, color: dividerColor),
                item('VÃ­ cá»§a tÃ´i'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            color: sectionBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Text('CÃ i Ä‘áº·t', style: TextStyle(color: sectionLabel, fontWeight: FontWeight.w600)),
                ),
                item('MÃ£ QR cá»§a tÃ´i'),
                Divider(height: 1, indent: 16, color: dividerColor),
                item('Quyá»n riÃªng tÆ°'),
                Divider(height: 1, indent: 16, color: dividerColor),
                item(
                  'Quáº£n lÃ½ tÃ i khoáº£n',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => const AccountSecurityScreen()),
                    );
                  },
                ),
                Divider(height: 1, indent: 16, color: dividerColor),
                item('CÃ i Ä‘áº·t chung'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
