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
                SnackBar(content: Text('$title đang dùng fallback tạm thời.')),
              );
            },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.sectionBackground,
      appBar: AppBar(
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
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
                item('Thông tin'),
                Divider(height: 1, indent: 16, color: dividerColor),
                item('Đổi ảnh đại diện'),
                Divider(height: 1, indent: 16, color: dividerColor),
                item('Đổi ảnh bìa'),
                Divider(height: 1, indent: 16, color: dividerColor),
                item('Cập nhật giới thiệu bản thân'),
                Divider(height: 1, indent: 16, color: dividerColor),
                item('Ví của tôi'),
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
                  child: Text('Cài đặt', style: TextStyle(color: sectionLabel, fontWeight: FontWeight.w600)),
                ),
                item('Mã QR của tôi'),
                Divider(height: 1, indent: 16, color: dividerColor),
                item('Quyền riêng tư'),
                Divider(height: 1, indent: 16, color: dividerColor),
                item(
                  'Quản lý tài khoản',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => const AccountSecurityScreen()),
                    );
                  },
                ),
                Divider(height: 1, indent: 16, color: dividerColor),
                item('Cài đặt chung'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
