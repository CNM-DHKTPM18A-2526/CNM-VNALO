import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/auth/screens/welcome_screen.dart';
import 'package:vnalo_mobile/features/profile/localization/profile_texts.dart';
import 'package:vnalo_mobile/features/profile/screens/account_security_screen.dart';
import 'package:vnalo_mobile/features/profile/screens/appearance_settings_screen.dart';
import 'package:vnalo_mobile/features/profile/screens/personal_info_screen.dart';
import 'package:vnalo_mobile/core/models/menu_item_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final t = ProfileTexts.of(context);

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        title: Text(
          t.settings,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDarkMode ? appBarBg : Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        forceMaterialTransparency: !isDarkMode,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _SettingsSearchDelegate(t: t),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          ..._buildAllSections(context),
          _buildLogoutButton(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<MenuSection> _getSettingsSections(BuildContext context) {
    final t = ProfileTexts.of(context);
    final common = CommonTexts.of(context);
    return [
      MenuSection(
        items: [
          MenuItem(
            key: 'account',
            icon: Icons.shield_outlined,
            title: t.accountAndSecurity,
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const AccountSecurityScreen()),
              );
            },
          ),
          MenuItem(key: 'privacy', icon: Icons.lock_outline, title: t.privacy),
        ],
      ),
      MenuSection(
        items: [
          MenuItem(key: 'storage', icon: Icons.pie_chart_outline, title: t.deviceData),
          MenuItem(key: 'backup', icon: Icons.cloud_sync_outlined, title: _isVi(context) ? 'Sao lưu và khôi phục' : 'Backup & Restore'),
        ],
      ),
      MenuSection(
        items: [
          MenuItem(key: 'notif', icon: Icons.notifications_outlined, title: t.notifications),
          MenuItem(key: 'message', icon: Icons.chat_outlined, title: common.messages),
          MenuItem(key: 'call', icon: Icons.call_outlined, title: _isVi(context) ? 'Cuộc gọi' : 'Calls'),
          MenuItem(key: 'timeline', icon: Icons.access_time, title: common.timeline),
          MenuItem(key: 'contacts', icon: Icons.contacts_outlined, title: common.contacts),
          MenuItem(
            key: 'appearance',
            icon: Icons.color_lens_outlined,
            title: t.appearance,
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const AppearanceSettingsScreen()),
              );
            },
          ),
        ],
      ),
      MenuSection(
        items: [
          MenuItem(
            key: 'about',
            icon: Icons.info_outline,
            title: _isVi(context) ? 'Thông tin về VNALO' : 'About VNALO',
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
              );
            },
          ),
          MenuItem(key: 'help', icon: Icons.help_outline, title: _isVi(context) ? 'Liên hệ hỗ trợ' : 'Help & Support'),
          MenuItem(key: 'switch_account', icon: Icons.swap_horiz, title: _isVi(context) ? 'Chuyển tài khoản' : 'Switch account'),
        ],
      ),
    ];
  }

  bool _isVi(BuildContext context) => ProfileTexts.of(context).language == AppLanguage.vi;

  List<Widget> _buildAllSections(BuildContext context) {
    final sections = _getSettingsSections(context);
    return sections.expand((section) {
      return [
        _buildSection(
          context,
          section.items.map((item) {
            return _item(
              context,
              item.icon,
              item.title,
              onTap: item.onTap,
            );
          }).toList(),
        ),
        const _SectionDivider(),
      ];
    }).toList();
  }

  Widget _buildSection(BuildContext context, List<Widget> items) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final itemBgColor = isDarkMode ? DarkColors.surface : Colors.white;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.sectionDivider;

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
    final itemBgColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;
    final t = ProfileTexts.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: itemBgColor,
          foregroundColor: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () {
          _confirmLogout(context);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, size: 20),
            const SizedBox(width: 8),
            Text(t.logout, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String title, {VoidCallback? onTap}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        highlightColor: AppColors.itemPressBackground,
        splashColor: AppColors.itemPressBackground.withValues(alpha: 0.7),
        onTap: onTap,
        child: ListTile(
          leading: Icon(icon, color: isDarkMode ? DarkColors.primary : AppColors.primary),
          title: Text(
            title,
            style: TextStyle(
              color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Icon(Icons.chevron_right, size: 20, color: isDarkMode ? DarkColors.textHint : const Color(0xFF9CA3AF)),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final t = ProfileTexts.of(context);
    final common = CommonTexts.of(context);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? DarkColors.surface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Icon(Icons.info, color: isDarkMode ? DarkColors.primary : AppColors.primary, size: 30),
                  const SizedBox(height: 12),
                  Text(
                    t.logoutConfirm,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isVi(context) 
                      ? 'Nếu đổi máy mới, hãy sao lưu để tránh mất tin nhắn và ảnh gần đây'
                      : 'If switching to a new device, please backup to avoid losing recent messages and photos',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.red,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isDarkMode ? Colors.red.withValues(alpha: 0.3) : Colors.red.shade100),
                        ),
                      ),
                      child: Text(t.logout, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? DarkColors.divider : Colors.grey.shade100,
                        foregroundColor: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(common.cancel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

class _SettingsSearchDelegate extends SearchDelegate<String> {
  final ProfileTexts t;

  _SettingsSearchDelegate({required this.t});

  List<String> get _settingsKeys => [
    t.accountAndSecurity,
    t.privacy,
    t.deviceData,
    'Sao lưu và khôi phục',
    t.notifications,
    'Tin nhắn',
    'Danh bạ',
    t.appearance,
  ];

  @override
  String get searchFieldLabel => t.language == AppLanguage.vi ? 'Tìm cài đặt...' : 'Search settings...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSuggestionsList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSuggestionsList(context);
  }

  Widget _buildSuggestionsList(BuildContext context) {
    final suggestions = _settingsKeys
        .where((key) => key.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(suggestions[index]),
          leading: const Icon(Icons.settings),
          onTap: () {
            close(context, suggestions[index]);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${ProfileTexts.of(context).language == AppLanguage.vi ? 'Đang phát triển thiết lập' : 'Setting under development'}: ${suggestions[index]}')),
            );
          },
        );
      },
    );
  }
}
