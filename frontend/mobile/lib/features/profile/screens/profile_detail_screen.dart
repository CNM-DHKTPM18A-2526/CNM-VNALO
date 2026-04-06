import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';

class ProfileDetailScreen extends StatelessWidget {
  const ProfileDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final auth = context.watch<AuthProvider>();
    final displayName = auth.user?.displayName ?? 'Người dùng';

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Thông tin cá nhân'),
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
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
      ),
      body: ListView(
        children: [
          Container(
            color: isDarkMode ? const Color(0xFF171717) : Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Row(
              children: [
                AvatarWidget(
                  imageUrl: auth.user?.avatarUrl,
                  name: displayName,
                  size: 64,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        auth.user?.phone ?? 'Chưa có số điện thoại',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode
                              ? const Color(0xFFA3A3A3)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _infoTile(
            context,
            icon: Icons.badge_outlined,
            title: 'Tên hiển thị',
            value: displayName,
          ),
          _infoTile(
            context,
            icon: Icons.phone_outlined,
            title: 'Số điện thoại',
            value: auth.user?.phone ?? 'Chưa cập nhật',
          ),
          _infoTile(
            context,
            icon: Icons.cake_outlined,
            title: 'Ngày sinh',
            value: auth.user?.dob != null
                ? '${auth.user!.dob!.day.toString().padLeft(2, '0')}/${auth.user!.dob!.month.toString().padLeft(2, '0')}/${auth.user!.dob!.year}'
                : 'Chưa cập nhật',
          ),
        ],
      ),
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDarkMode ? const Color(0xFF171717) : Colors.white,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF9CA3AF)),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}
