import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/profile/localization/profile_texts.dart';
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
    final t = ProfileTexts.of(context);

    Widget item(String title, {VoidCallback? onTap}) {
      return ListTile(
        tileColor: sectionBg,
        title: Text(title, style: TextStyle(color: textColor, fontSize: 16)),
        onTap: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t.comingSoon)),
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
                item(t.profileInfo),
                Divider(height: 1, indent: 16, color: dividerColor),
                item(t.changeProfilePhoto),
                Divider(height: 1, indent: 16, color: dividerColor),
                item(t.changeCoverPhoto),
                Divider(height: 1, indent: 16, color: dividerColor),
                item(t.updateBio),
                Divider(height: 1, indent: 16, color: dividerColor),
                item(t.myWallet),
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
                  child: Text(t.settings, style: TextStyle(color: sectionLabel, fontWeight: FontWeight.w600)),
                ),
                item(t.myQrCode),
                Divider(height: 1, indent: 16, color: dividerColor),
                item(t.privacy),
                Divider(height: 1, indent: 16, color: dividerColor),
                item(
                  t.accountManagement,
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => const AccountSecurityScreen()),
                    );
                  },
                ),
                Divider(height: 1, indent: 16, color: dividerColor),
                item(t.generalSettings),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
