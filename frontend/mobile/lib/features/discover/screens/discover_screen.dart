import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg =
        isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final searchHint = isDarkMode ? DarkColors.textHint : Colors.white.withOpacity(0.8);

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
