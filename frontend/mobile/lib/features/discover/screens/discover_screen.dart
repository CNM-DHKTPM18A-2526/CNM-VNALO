import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'package:vnalo_mobile/features/search/screens/unified_search_screen.dart';
import 'package:vnalo_mobile/core/models/menu_item_model.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  void _openQrScanner(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : LightColors.scaffold,
      appBar: AppBar(
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        elevation: 0,
        forceMaterialTransparency: !isDarkMode,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.appBarGradient,
                ),
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
                  const Icon(Icons.search, size: 24, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    common.search,
                    style: const TextStyle(
                      color: Colors.white,
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
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: () => _openQrScanner(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildServicesSection(context, isDarkMode),
        ],
      ),
    );
  }

  List<MenuItem> _getDiscoverServices(BuildContext context) {
    final common = CommonTexts.of(context);
    return [
      MenuItem(
        key: 'vnaloAi',
        icon: Icons.psychology_outlined,
        title: 'Trợ lý ảo VNALO AI',
        subtitle: 'Hỏi đáp, dịch thuật & tóm tắt thông minh',
        onTap: () {
          final aiProvider = context.read<AiAssistantProvider>();
          aiProvider.summonMascot();
        },
      ),
      MenuItem(
        key: 'vnShop',
        icon: Icons.storefront,
        title: 'VNALO Shop',
        subtitle: common.shoppingService,
      ),
      MenuItem(
        key: 'games',
        icon: Icons.games,
        title: common.gamesService,
        subtitle: common.gamesSubtitle,
      ),
      MenuItem(
        key: 'news',
        icon: Icons.newspaper,
        title: common.newsService,
        subtitle: common.newsSubtitle,
      ),
      MenuItem(
        key: 'qrScanner',
        icon: Icons.qr_code_scanner,
        title: common.qrScannerTitle,
        subtitle: common.qrScannerSubtitle,
        onTap: () => _openQrScanner(context),
      ),
    ];
  }

  Widget _buildServicesSection(BuildContext context, bool isDarkMode) {
    final services = _getDiscoverServices(context);
    return Container(
      color: isDarkMode ? DarkColors.surface : Colors.white,
      child: Column(
        children: List.generate(services.length, (index) {
          final item = services[index];
          return Column(
            children: [
              _DiscoverItem(
                itemKey: item.key,
                icon: item.icon,
                title: item.title,
                subtitle: item.subtitle ?? '',
                onTap: item.onTap,
              ),
              if (index < services.length - 1) _buildDivider(isDarkMode),
            ],
          );
        }),
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
  final String itemKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _DiscoverItem({
    required this.itemKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isPremium = itemKey == 'vnaloAi';

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isPremium ? null : (isDarkMode ? DarkColors.primary : AppColors.primary).withValues(alpha: 0.1),
          gradient: isPremium
              ? const LinearGradient(
                  colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: isPremium ? Colors.white : (isDarkMode ? DarkColors.primary : AppColors.primary)),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: isPremium && isDarkMode ? Colors.orange.shade300 : null)),
      subtitle: Text(subtitle, style: isPremium && isDarkMode ? TextStyle(color: Colors.orange.shade100.withOpacity(0.7)) : null),
      trailing: Icon(Icons.chevron_right, color: isDarkMode ? DarkColors.textHint : Colors.grey.shade300),
      onTap: onTap,
    );
  }
}
