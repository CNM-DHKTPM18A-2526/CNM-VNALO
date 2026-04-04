import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/profile/screens/appearance_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
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
          _item(Icons.shield_outlined, 'Tài khoản và bảo mật'),
          _item(Icons.lock_outline, 'Quyền riêng tư'),
          const _SectionDivider(),
          _item(Icons.phone_android_outlined, 'Dữ liệu trên máy'),
          _item(Icons.cloud_sync_outlined, 'Sao lưu và khôi phục'),
          const _SectionDivider(),
          _item(Icons.notifications_outlined, 'Thông báo'),
          _item(Icons.chat_outlined, 'Tin nhắn'),
          _item(Icons.call_outlined, 'Cuộc gọi'),
          _item(Icons.access_time, 'Nhật ký'),
          _item(Icons.contacts_outlined, 'Danh bạ'),
          _item(
            Icons.palette_outlined,
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
          const _SectionDivider(),
          _item(Icons.info_outline, 'Thông tin về VNALO'),
          _item(Icons.help_outline, 'Liên hệ hỗ trợ'),
          _item(Icons.swap_horiz, 'Chuyển tài khoản'),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFFD1D5DB)),
      onTap: onTap,
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 16,
      thickness: 8,
      color:
          Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1A1A)
              : const Color(0xFFF0F0F0),
    );
  }
}
