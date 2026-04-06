import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/profile/screens/appearance_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text('Cài đặt'),
        backgroundColor: appBarBg,
        foregroundColor: isDarkMode ? null : Colors.white,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.white),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Settings search
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildSection(context, [
            _item(Icons.shield_outlined, 'Tài khoản và bảo mật'),
            _item(Icons.lock_outline, 'Quyền riêng tư'),
          ]),
          const _SectionDivider(),
          _buildSection(context, [
            _item(Icons.pie_chart_outline, 'Dữ liệu trên máy'),
            _item(Icons.cloud_sync_outlined, 'Sao lưu và khôi phục'),
          ]),
          const _SectionDivider(),
          _buildSection(context, [
            _item(Icons.notifications_outlined, 'Thông báo'),
            _item(Icons.chat_outlined, 'Tin nhắn'),
            _item(Icons.call_outlined, 'Cuộc gọi'),
            _item(Icons.access_time, 'Nhật ký'),
            _item(Icons.contacts_outlined, 'Danh bạ'),
            _item(
              Icons.color_lens_outlined,
              'Giao diện và ngôn ngữ',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppearanceSettingsScreen(),
                  ),
                );
              },
            ),
          ]),
          const _SectionDivider(),
          _buildSection(context, [
            _item(Icons.info_outline, 'Thông tin về VNALO'),
            _item(Icons.help_outline, 'Liên hệ hỗ trợ'),
            _item(Icons.swap_horiz, 'Chuyển tài khoản'),
          ]),
          const _SectionDivider(),
          _buildLogoutButton(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, List<Widget> items) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final itemBgColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final dividerColor = isDarkMode ? const Color(0xFF333333) : const Color(0xFFE5E7EB);

    final List<Widget> children = [];
    for (int i = 0; i < items.length; i++) {
        children.add(items[i]);
        if (i < items.length - 1) {
            children.add(Divider(height: 1, thickness: 0.5, indent: 56, endIndent: 0, color: dividerColor));
        }
    }

    return Container(
      color: itemBgColor,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final itemBgColor = isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: itemBgColor,
          foregroundColor: isDarkMode ? Colors.white : Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () {
          // TODO: Logout
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 20),
            SizedBox(width: 8),
            Text('Đăng xuất', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF9CA3AF)),
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
