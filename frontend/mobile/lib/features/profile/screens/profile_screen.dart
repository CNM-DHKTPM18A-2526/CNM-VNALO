import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/profile/screens/account_security_screen.dart';
import 'package:vnalo_mobile/features/profile/screens/profile_detail_screen.dart';
import 'package:vnalo_mobile/features/profile/screens/settings_screen.dart';
import 'package:vnalo_mobile/features/search/screens/unified_search_screen.dart';
import 'package:vnalo_mobile/core/models/menu_item_model.dart';
import 'package:vnalo_mobile/features/chat/screens/my_documents_screen.dart';

/// Profile tab ("Cá nhân") — shows user avatar + name + quick links.
/// Tapping the avatar/name area navigates to the full ProfileDetailScreen.
/// Tapping the ⚙️ gear icon navigates to the Settings page.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().refreshCurrentUser();
    });
  }

  Future<void> _updateAvatar() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.updateAvatar(File(picked.path));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Cập nhật ảnh đại diện thành công'
              : (auth.error ?? 'Cập nhật ảnh đại diện thất bại'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final searchHint = isDarkMode
        ? DarkColors.textHint
        : Colors.white.withValues(alpha: 0.8);
    final pageBg = isDarkMode ? Colors.black : AppColors.sectionBackground;
    final sectionBg = isDarkMode ? DarkColors.surface : Colors.white;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.sectionDivider;
    final auth = context.watch<AuthProvider>();
    final displayName = auth.user?.displayName ?? 'Người dùng';

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: isDarkMode ? appBarBg : Colors.transparent,
        elevation: 0,
        forceMaterialTransparency: true,
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
                builder: (_) => const UnifiedSearchScreen(searchTag: 'search_bar_profile'),
              ),
            );
          },
          child: Hero(
            tag: 'search_bar_profile',
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
            icon: Icon(Icons.settings_outlined, color: searchHint),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // User header — tappable to open profile detail
          Material(
            color: sectionBg,
            child: InkWell(
              highlightColor: AppColors.itemPressBackground,
              splashColor: AppColors.itemPressBackground.withValues(alpha: 0.7),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileDetailScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        AvatarWidget(
                          imageUrl: auth.user?.avatarUrl,
                          name: displayName,
                          size: 60,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _updateAvatar,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                    const Icon(Icons.chevron_right,
                        color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const _SectionDivider(),
          ..._buildSections(context),
        ],
      ),
    );
  }

  List<MenuSection> _getMenuSections(BuildContext context) {
    return [
      MenuSection(
        items: [
          MenuItem(
            key: 'vnCloud',
            icon: Icons.cloud_outlined,
            title: 'vnCloud',
            subtitle: 'Không gian lưu trữ dữ liệu trên đám mây',
            onTap: () {},
          ),
          MenuItem(
            key: 'vnStyle',
            icon: Icons.auto_fix_high_outlined,
            title: 'vnStyle - Nổi bật trên Vnalo',
            subtitle: 'Hình nền và nhạc cho cuộc gọi Vnalo',
            onTap: () {},
          ),
          MenuItem(
            key: 'myDocuments',
            icon: Icons.folder_outlined,
            title: 'My Documents',
            subtitle: 'Lưu trữ các tin nhắn quan trọng',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyDocumentsScreen()),
              );
            },
          ),
        ],
      ),
      MenuSection(
        items: [
          MenuItem(
            key: 'deviceData',
            icon: Icons.pie_chart_outline,
            title: 'Dữ liệu trên máy',
            subtitle: 'Quản lý dữ liệu VNALO của bạn',
            onTap: () {},
          ),
          MenuItem(
            key: 'qrWallet',
            icon: Icons.qr_code_rounded,
            title: 'Ví QR',
            subtitle: 'Lưu trữ và xuất trình các mã QR quan trọng',
            onTap: () {},
          ),
          MenuItem(
            key: 'vnPay',
            icon: Icons.account_balance_wallet_outlined,
            title: 'Vnalo Pay (Sắp ra mắt)',
            subtitle: 'Thanh toán tiện lợi, bảo mật',
            onTap: () {},
          ),
        ],
      ),
      MenuSection(
        items: [
          MenuItem(
            key: 'security',
            icon: Icons.shield_outlined,
            title: 'Tài khoản và bảo mật',
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => const AccountSecurityScreen(),
                ),
              );
            },
          ),
          MenuItem(
            key: 'privacy',
            icon: Icons.lock_outline,
            title: 'Quyền riêng tư',
            onTap: () {},
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildSections(BuildContext context) {
    final sections = _getMenuSections(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final sectionBg = isDarkMode ? DarkColors.surface : Colors.white;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.sectionDivider;

    return sections.expand((section) {
      return [
        Container(
          color: sectionBg,
          child: Column(
            children: List.generate(section.items.length, (index) {
              final item = section.items[index];
              return Column(
                children: [
                  _menuItem(
                    context,
                    itemKey: item.key,
                    normalBg: sectionBg,
                    icon: item.icon,
                    iconColor: item.iconColor ?? AppColors.primary,
                    title: item.title,
                    subtitle: item.subtitle,
                    onTap: item.onTap,
                  ),
                  if (index < section.items.length - 1)
                    Divider(height: 1, indent: 70, color: dividerColor),
                ],
              );
            }),
          ),
        ),
        const _SectionDivider(),
      ];
    }).toList();
  }

  Widget _menuItem(
    BuildContext context, {
    required String itemKey,
    required Color normalBg,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final subtitleColor = Theme.of(context).brightness == Brightness.dark
        ? DarkColors.textSecondary
        : LightColors.textHint;
    return Material(
      color: normalBg,
      child: InkWell(
        highlightColor: AppColors.itemPressBackground,
        splashColor: AppColors.itemPressBackground.withValues(alpha: 0.7),
        onTap: onTap,
        child: ListTile(
          leading: Icon(icon, color: iconColor, size: 28),
          title: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: subtitleColor),
                )
              : null,
          trailing: Icon(
            Icons.chevron_right,
            size: 20,
            color: Theme.of(context).brightness == Brightness.dark
                ? DarkColors.textHint
                : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 10);
  }
}
