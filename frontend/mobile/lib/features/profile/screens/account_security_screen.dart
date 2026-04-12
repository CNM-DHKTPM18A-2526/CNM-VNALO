import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/profile/screens/personal_info_screen.dart';
import 'package:vnalo_mobile/features/profile/screens/update_password_screen.dart';

class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final auth = context.watch<AuthProvider?>();
    final user = auth?.user;
    final displayName = user?.displayName ?? 'Người dùng';
    final pageBg = isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground;
    final sectionBg = isDarkMode ? DarkColors.surface : LightColors.surface;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.sectionDivider;
    final textColor = isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary;
    final subTextColor = isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary;
    final iconColor = isDarkMode ? DarkColors.textHint : LightColors.textHint;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text(
          'Tài khoản và bảo mật',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: isDarkMode
            ? null
            : Container(decoration: const BoxDecoration(gradient: AppColors.appBarGradient)),
      ),
      body: ListView(
        children: [
          _sectionTitle('Tài khoản'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: sectionBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: dividerColor),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              leading: AvatarWidget(
                imageUrl: user?.avatarUrl,
                name: displayName,
                size: 52,
              ),
              title: Text('Thông tin cá nhân', style: TextStyle(fontSize: 15, color: subTextColor)),
              subtitle: Text(
                displayName,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2, color: textColor),
              ),
              trailing: Icon(Icons.chevron_right, color: iconColor),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          _tile(
            context,
            icon: Icons.phone_outlined,
            title: 'Số điện thoại',
            subtitle: user?.phone ?? 'Chưa cập nhật',
            backgroundColor: sectionBg,
            isDarkMode: isDarkMode,
          ),
          _divider(dividerColor),
          _tile(
            context,
            icon: Icons.email_outlined,
            title: 'Email',
            subtitle: 'Chưa liên kết',
            backgroundColor: sectionBg,
            isDarkMode: isDarkMode,
          ),
          _divider(dividerColor),
          _tile(
            context,
            icon: Icons.qr_code_2,
            title: 'Mã QR của tôi',
            backgroundColor: sectionBg,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 10),
          _sectionTitle('Bảo mật'),
          _tile(
            context,
            icon: Icons.verified_user_outlined,
            title: 'Kiểm tra bảo mật',
            subtitle: '3 vấn đề bảo mật cần xử lý',
            backgroundColor: sectionBg,
            isDarkMode: isDarkMode,
            subtitleColor: AppColors.warning,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: iconColor),
              ],
            ),
          ),
          _divider(dividerColor),
          _tile(
            context,
            icon: Icons.lock_person_outlined,
            title: 'Khóa Vnalo',
            subtitle: 'Đang tắt',
            backgroundColor: sectionBg,
            isDarkMode: isDarkMode,
            trailingText: 'Đang tắt',
          ),
          const SizedBox(height: 10),
          _sectionTitle('Đăng nhập'),
          _tile(
            context,
            icon: Icons.security_outlined,
            title: 'Bảo mật 2 lớp',
            subtitle: 'Thêm hình thức xác nhận để bảo vệ tài khoản khi đăng nhập trên thiết bị mới',
            backgroundColor: sectionBg,
            isDarkMode: isDarkMode,
            trailing: Switch(
              value: false,
              onChanged: (_) {},
              activeColor: AppColors.primary,
            ),
          ),
          _divider(dividerColor),
          _tile(
            context,
            icon: Icons.phone_android_outlined,
            title: 'Thiết bị đăng nhập',
            subtitle: 'Quản lý các thiết bị bạn sử dụng để đăng nhập',
            backgroundColor: sectionBg,
            isDarkMode: isDarkMode,
          ),
          _divider(dividerColor),
          _tile(
            context,
            icon: Icons.lock_outline,
            title: 'Mật khẩu',
            backgroundColor: sectionBg,
            isDarkMode: isDarkMode,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UpdatePasswordScreen()),
              );
            },
          ),
          _divider(dividerColor),
          _tile(
            context,
            icon: Icons.no_accounts_outlined,
            title: 'Xóa tài khoản',
            backgroundColor: sectionBg,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    required Color backgroundColor,
    required bool isDarkMode,
    Color? subtitleColor,
    String? trailingText,
    Widget? trailing,
  }) {
    final textColor = isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary;
    final iconColor = isDarkMode ? DarkColors.textHint : LightColors.textHint;
    return Container(
      color: backgroundColor,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          highlightColor: AppColors.itemPressBackground,
          splashColor: AppColors.itemPressBackground.withValues(alpha: 0.7),
          onTap: onTap,
          child: ListTile(
            leading: Icon(icon, color: iconColor),
            title: Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
            ),
            subtitle: subtitle == null
                ? null
                : Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: subtitleColor ?? (isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary)),
                  ),
            trailing: trailing ??
                (trailingText == null
                    ? Icon(Icons.chevron_right, color: iconColor)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            trailingText,
                            style: TextStyle(color: iconColor, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right, color: iconColor),
                        ],
                      )),
          ),
        ),
      ),
    );
  }

  Widget _divider(Color dividerColor) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 56,
      color: dividerColor,
    );
  }
}
