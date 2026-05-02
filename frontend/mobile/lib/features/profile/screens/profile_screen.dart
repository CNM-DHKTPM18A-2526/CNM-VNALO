import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/profile/localization/profile_texts.dart';
import 'package:vnalo_mobile/features/profile/screens/account_security_screen.dart';
import 'package:vnalo_mobile/features/profile/screens/profile_detail_screen.dart';
import 'package:vnalo_mobile/features/profile/screens/settings_screen.dart';
import 'package:vnalo_mobile/features/search/screens/unified_search_screen.dart';
import 'package:vnalo_mobile/core/models/menu_item_model.dart';
import 'package:vnalo_mobile/features/chat/screens/my_documents_screen.dart';
import 'package:vnalo_mobile/features/notifications/providers/notification_provider.dart';

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
      context.read<NotificationProvider>().loadNotifications();
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

    final common = CommonTexts.of(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? common.updateAvatarSuccess
              : (auth.error ?? common.updateAvatarFail),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground;
    final sectionBg = isDarkMode ? DarkColors.surface : Colors.white;
    final auth = context.watch<AuthProvider>();
    final common = CommonTexts.of(context);
    final t = ProfileTexts.of(context);
    final displayName = auth.user?.displayName ?? t.notUpdated;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        elevation: 0,
        forceMaterialTransparency: !isDarkMode,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: BoxDecoration(gradient: AppColors.appBarGradient),
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
                  const Icon(Icons.search, size: 24, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    common.search,
                    style: TextStyle(
                      color: isDarkMode ? DarkColors.textHint : Colors.white.withValues(alpha: 0.7),
                      fontSize: 15,
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
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
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
                                color: isDarkMode ? DarkColors.primary : AppColors.primary,
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
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: isDarkMode ? DarkColors.textHint : Colors.grey),
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
    final t = ProfileTexts.of(context);
    return [
      MenuSection(
        items: [
          MenuItem(
            key: 'vnCloud',
            icon: Icons.cloud_outlined,
            title: t.vnCloud,
            subtitle: t.vnCloudSubtitle,
            onTap: () {},
          ),
          MenuItem(
            key: 'vnStyle',
            icon: Icons.auto_fix_high_outlined,
            title: t.vnStyle,
            subtitle: t.vnStyleSubtitle,
            onTap: () {},
          ),
          MenuItem(
            key: 'myDocuments',
            icon: Icons.folder_outlined,
            title: t.myDocuments,
            subtitle: t.myDocumentsSubtitle,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyDocumentsScreen()),
              );
            },
          ),
          MenuItem(
            key: 'notifications',
            icon: Icons.notifications_none_outlined,
            title: 'Thông báo',
            trailing: Consumer<NotificationProvider>(
              builder: (context, provider, child) {
                final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                if (provider.unreadCount == 0) return Icon(Icons.chevron_right, color: isDarkMode ? DarkColors.textHint : AppColors.iconSubtle);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${provider.unreadCount > 99 ? '99+' : provider.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
            onTap: () {
              // TODO: Navigate to NotificationListScreen
            },
          ),
        ],
      ),
      MenuSection(
        items: [
          MenuItem(
            key: 'deviceData',
            icon: Icons.pie_chart_outline,
            title: t.deviceData,
            subtitle: t.deviceDataSubtitle,
            onTap: () {},
          ),
          MenuItem(
            key: 'qrWallet',
            icon: Icons.qr_code_rounded,
            title: t.qrWallet,
            subtitle: t.qrWalletSubtitle,
            onTap: () {},
          ),
          MenuItem(
            key: 'vnPay',
            icon: Icons.account_balance_wallet_outlined,
            title: ProfileTexts.of(context).vnaloPayTitle,
            subtitle: ProfileTexts.of(context).vnaloPaySubtitle,
            onTap: () {},
          ),
        ],
      ),
      MenuSection(
        items: [
          MenuItem(
            key: 'security',
            icon: Icons.shield_outlined,
            title: t.accountAndSecurity,
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
            title: t.privacy,
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
                    iconColor: item.iconColor ?? (isDarkMode ? DarkColors.primary : AppColors.primary),
                    title: item.title,
                    subtitle: item.subtitle,
                    trailing: item.trailing,
                    onTap: item.onTap,
                  ),
                  if (index < section.items.length - 1)
                    Divider(
                      height: 1,
                      indent: 70,
                      color: isDarkMode ? DarkColors.divider : AppColors.itemDivider,
                    ),
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
    Widget? trailing,
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
          trailing: trailing ?? Icon(
            Icons.chevron_right,
            size: 20,
            color: Theme.of(context).brightness == Brightness.dark
                ? DarkColors.textHint
                : AppColors.iconSubtle.withValues(alpha: 0.5),
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
    return const SizedBox(height: 8);
  }
}
