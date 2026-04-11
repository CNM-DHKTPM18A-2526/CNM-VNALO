import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/models/quick_action_item.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'package:vnalo_mobile/features/common/widgets/quick_actions_sheet.dart';
import 'package:vnalo_mobile/features/contacts/screens/add_friend_screen.dart';
import 'package:vnalo_mobile/features/search/screens/unified_search_screen.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  void _openQrScanner(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
  }

  void _openQuickActions(BuildContext context) {
    showQuickActionsSheet(
      context,
      items: [
        QuickActionItem(
          icon: Icons.person_add_alt_1_outlined,
          title: 'Thêm bạn',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddFriendScreen()),
            );
          },
        ),
        QuickActionItem(
          icon: Icons.group_add_outlined,
          title: 'Tạo nhóm',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tạo nhóm sẽ được nối ở module chat nhóm.')),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg =
        isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final searchHint = isDarkMode ? DarkColors.textHint : Colors.white.withValues(alpha: 0.8);

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: appBarBg,
        surfaceTintColor: appBarBg,
        elevation: 0,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
              ),
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const UnifiedSearchScreen(
                  initialTab: SearchInitialTab.discover,
                  searchTag: 'search_bar_discover',
                ),
              ),
            );
          },
          child: Hero(
            tag: 'search_bar_discover',
            child: Material(
              color: Colors.transparent,
              child: Row(
                children: [
                  Icon(Icons.search, size: 24, color: searchHint),
                  const SizedBox(width: 8),
                  Text(
                    'Tìm kiếm',
                    style: TextStyle(
                      color: searchHint,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner, color: searchHint),
            onPressed: () => _openQrScanner(context),
          ),
          IconButton(
            icon: Icon(Icons.add, color: searchHint),
            onPressed: () => _openQuickActions(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          Container(
            color: isDarkMode ? DarkColors.surface : Colors.white,
            child: Column(
              children: [
                const _DiscoverItem(
                  icon: Icons.storefront,
                  title: 'VNALO Shop',
                  subtitle: 'Mua sắm trực tuyến',
                ),
                _buildDivider(isDarkMode),
                const _DiscoverItem(
                  icon: Icons.games,
                  title: 'Trò chơi',
                  subtitle: 'Chơi cùng bạn bè',
                ),
                _buildDivider(isDarkMode),
                const _DiscoverItem(
                  icon: Icons.newspaper,
                  title: 'Tin tức',
                  subtitle: 'Cập nhật mới nhất',
                ),
                _buildDivider(isDarkMode),
                _DiscoverItem(
                  icon: Icons.qr_code_scanner,
                  title: 'Quét QR',
                  subtitle: 'Đăng nhập web, thanh toán, kết bạn',
                  onTap: () {
                    _openQrScanner(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 72,
      color: isDarkMode ? DarkColors.divider : AppColors.sectionDivider,
    );
  }
}

class _DiscoverItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _DiscoverItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right, color: isDarkMode ? DarkColors.textHint : Colors.grey.shade300),
      onTap: onTap,
    );
  }
}
