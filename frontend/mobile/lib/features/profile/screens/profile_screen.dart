import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/profile/screens/settings_screen.dart';

/// Profile tab ("Cá nhân") — shows user avatar + name + quick links.
/// Tapping the ⚙️ gear icon navigates to the full Settings page.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg =
        isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final searchHint = isDarkMode ? DarkColors.textHint : Colors.white.withOpacity(0.8);
    final auth = context.watch<AuthProvider>();
    final displayName = auth.user?.displayName ?? 'Người dùng';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0068FF), Color(0xFF00A2ED)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
        title: Row(
          children: [
            Icon(Icons.search, size: 24, color: searchHint),
            const SizedBox(width: 8),
            Text(
              'Tìm kiếm',
              style: TextStyle(color: searchHint, fontSize: 16, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: searchHint),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // User header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                AvatarWidget(
                  imageUrl: auth.user?.avatarUrl,
                  name: displayName,
                  size: 60,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Quick menu items
          _menuItem(
            context,
            icon: Icons.cloud_outlined,
            iconColor: AppColors.primary,
            title: 'VNALO Cloud',
            subtitle: 'Không gian lưu trữ dữ liệu trên đám mây',
          ),
          _menuItem(
            context,
            icon: Icons.folder_outlined,
            iconColor: AppColors.primary,
            title: 'My Documents',
            subtitle: 'Lưu trữ các tin nhắn quan trọng',
          ),
          _menuItem(
            context,
            icon: Icons.phone_android_outlined,
            iconColor: AppColors.primary,
            title: 'Dữ liệu trên máy',
            subtitle: 'Quản lý dữ liệu VNALO của bạn',
          ),
          _menuItem(
            context,
            icon: Icons.qr_code_rounded,
            iconColor: AppColors.primary,
            title: 'Ví QR',
            subtitle: 'Lưu trữ và xuất trình các mã QR quan trọng',
          ),
          const _SectionDivider(),
          _menuItem(
            context,
            icon: Icons.shield_outlined,
            iconColor: AppColors.primary,
            title: 'Tài khoản và bảo mật',
          ),
          _menuItem(
            context,
            icon: Icons.lock_outline,
            iconColor: AppColors.primary,
            title: 'Quyền riêng tư',
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 28),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFFD1D5DB)),
      onTap: onTap,
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 8);
  }
}
