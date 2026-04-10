import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/theme/theme_provider.dart';
import 'package:vnalo_mobile/features/auth/localization/auth_texts.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final searchHint = isDarkMode ? DarkColors.textHint : Colors.white.withValues(alpha: 0.8);
    final cardBorder = isDarkMode ? DarkColors.divider : AppColors.sectionDivider;
    final sectionLabel = isDarkMode ? AppColors.primaryLight : AppColors.primary;
    final pageBg = isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Giao diện và ngôn ngữ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: appBarBg,
        surfaceTintColor: appBarBg,
        elevation: 0,
        iconTheme: IconThemeData(color: searchHint),
        flexibleSpace: isDarkMode
            ? null
            : Container(decoration: const BoxDecoration(gradient: AppColors.appBarGradient)),
      ),
      body: Consumer<ThemeProvider>(
        builder: (_, themeProvider, __) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // ─── Giao diện ───
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Giao diện',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: sectionLabel,
                  ),
                ),
              ),
              // Theme preview cards
              Row(
                children: [
                  _ThemeCard(
                    label: 'Sáng',
                    selected: themeProvider.themeMode == ThemeMode.light,
                    isDark: false,
                    borderColor: cardBorder,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                  ),
                  const SizedBox(width: 12),
                  _ThemeCard(
                    label: 'Tối',
                    selected: themeProvider.themeMode == ThemeMode.dark,
                    isDark: true,
                    borderColor: cardBorder,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                  ),
                  const SizedBox(width: 12),
                  _ThemeCard(
                    label: 'Hệ thống',
                    selected: themeProvider.themeMode == ThemeMode.system,
                    isDark: null,
                    borderColor: cardBorder,
                    onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Font options
              Column(
                children: [
                   _SettingsRow(
                    title: 'Đổi phông chữ',
                    trailing: 'Phông chữ Zalo',
                    isDarkMode: isDarkMode,
                  ),
                  Divider(height: 1, color: isDarkMode ? DarkColors.divider : AppColors.sectionDivider),
                   _SettingsRow(title: 'Đổi cỡ chữ', isDarkMode: isDarkMode),
                ],
              ),
              const SizedBox(height: 18),
              // ─── Ngôn ngữ ───
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Ngôn ngữ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: sectionLabel,
                  ),
                ),
              ),
              Consumer<LanguageProvider>(
                builder: (_, langProvider, __) {
                  final isVi = langProvider.language == AppLanguage.vi;
                  return _SettingsRow(
                    title: 'Đổi ngôn ngữ',
                    trailing: isVi ? '🇻🇳 Tiếng Việt' : '🇺🇸 English',
                    onTap: () => _showLanguagePicker(context, langProvider),
                    isDarkMode: isDarkMode,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, LanguageProvider provider) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? DarkColors.surface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white10 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AuthTexts.of(context, listen: false).languageTitle,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Text('🇻🇳', style: TextStyle(fontSize: 28)),
                    title: Text('Tiếng Việt',
                        style: TextStyle(fontSize: 17, color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary)),
                    trailing: provider.language == AppLanguage.vi
                        ? const Icon(Icons.check,
                            color: AppColors.primary, size: 24)
                        : null,
                    onTap: () {
                      provider.setLanguage(AppLanguage.vi);
                      Navigator.pop(sheetCtx);
                    },
                  ),
                  ListTile(
                    leading: const Text('🇻🇳', style: TextStyle(fontSize: 28)),
                    title:
                         Text('English', style: TextStyle(fontSize: 17, color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary)),
                    trailing: provider.language == AppLanguage.en
                        ? const Icon(Icons.check,
                            color: AppColors.primary, size: 24)
                        : null,
                    onTap: () {
                      provider.setLanguage(AppLanguage.en);
                      Navigator.pop(sheetCtx);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Theme preview card widget ───

class _ThemeCard extends StatelessWidget {
  final String label;
  final bool selected;
  final bool? isDark; // null = system/mixed
  final Color borderColor;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark == true
        ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : const Color(0xFF2D2D2D))
        : isDark == false
            ? const Color(0xFFE8F0FE)
            : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF33334D) : const Color(0xFF4A4A6A));
    final innerBar = isDark == true
        ? AppColors.primary
        : isDark == false
            ? AppColors.primary
            : AppColors.primary;
    final innerBg = isDark == true
        ? const Color(0xFF333333)
        : isDark == false
            ? Colors.white
            : const Color(0xFF444466);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 86,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.primary : borderColor,
                  width: selected ? 2.5 : 1,
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: innerBar,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: innerBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: innerBg,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 50,
                    decoration: BoxDecoration(
                      color: innerBar,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? AppColors.primary : Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? AppColors.primary
                        : (Theme.of(context).brightness == Brightness.dark ? DarkColors.textSecondary : LightColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  final bool isDarkMode;

  const _SettingsRow({required this.title, this.trailing, this.onTap, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? DarkColors.surface : Colors.white;
    return Material(
      color: bgColor,
      child: InkWell(
        highlightColor: AppColors.itemPressBackground,
        splashColor: AppColors.itemPressBackground.withValues(alpha: 0.7),
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(title, style: TextStyle(fontSize: 16, color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null) ...[
                Text(
                  trailing!,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(Icons.chevron_right, size: 20, color: isDarkMode ? DarkColors.textHint : LightColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
