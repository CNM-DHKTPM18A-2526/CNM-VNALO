import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/auth/screens/welcome_screen.dart';
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
          _confirmLogout(context);
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

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEECEC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.red),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Xác nhận đăng xuất',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi thiết bị này?',
            style: TextStyle(fontSize: 15, color: Color(0xFF4B5563), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Đăng xuất',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await context.read<AuthProvider>().logout();
    } finally {
      if (context.mounted) {
        Navigator.pop(context);
      }
    }

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
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
