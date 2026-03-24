import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg =
        isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final searchHint =
        isDarkMode ? DarkColors.textHint : Colors.white.withValues(alpha: 0.8);
    final searchBg =
        isDarkMode ? const Color(0xFF2B2B2B) : Colors.white.withValues(alpha: 0.25);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        title: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: searchBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: searchHint),
              const SizedBox(width: 8),
              Text(
                'Tìm kiếm',
                style: TextStyle(color: searchHint, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        children: const [
          _DiscoverItem(
            icon: Icons.storefront,
            title: 'VNALO Shop',
            subtitle: 'Mua sắm trực tuyến',
          ),
          _DiscoverItem(
            icon: Icons.games,
            title: 'Trò chơi',
            subtitle: 'Chơi cùng bạn bè',
          ),
          _DiscoverItem(
            icon: Icons.newspaper,
            title: 'Tin tức',
            subtitle: 'Cập nhật mới nhất',
          ),
          _DiscoverItem(
            icon: Icons.qr_code_scanner,
            title: 'Quét QR',
            subtitle: 'Thanh toán, kết bạn',
          ),
        ],
      ),
    );
  }
}

class _DiscoverItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DiscoverItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB)),
    );
  }
}
