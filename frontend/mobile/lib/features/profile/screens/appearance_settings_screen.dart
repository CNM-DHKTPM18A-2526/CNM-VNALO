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
    final cardBorder = isDarkMode
        ? const Color(0xFF3A3A3A)
        : AppColors.sectionDivider;
    final sectionLabel = isDarkMode
        ? const Color(0xFF60A5FA)
        : AppColors.primary;
    final pageBg = isDarkMode ? Colors.black : AppColors.sectionBackground;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Giao diện và ngôn ngữ'),
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
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
              Container(
                color: Colors.white,
                child: const Column(
                  children: [
                    _SettingsRow(
                      title: 'Đổi phông chữ',
                      trailing: 'Phông chữ Zalo',
                    ),
                    Divider(height: 1, color: AppColors.sectionDivider),
                    _SettingsRow(title: 'Đổi cỡ chữ'),
                  ],
                ),
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
                  return Container(
                    color: Colors.white,
                    child: _SettingsRow(
                      title: 'Đổi ngôn ngữ',
                      trailing: isVi ? '🇻🇳 Tiếng Việt' : '🇺🇸 English',
                      onTap: () => _showLanguagePicker(context, langProvider),
                    ),
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AuthTexts.of(context, listen: false).languageTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF141414),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Text('🇻🇳', style: TextStyle(fontSize: 28)),
                    title: const Text('Tiếng Việt',
                        style: TextStyle(fontSize: 17)),
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
                    leading: const Text('🇺🇸', style: TextStyle(fontSize: 28)),
                    title:
                        const Text('English', style: TextStyle(fontSize: 17)),
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
        ? const Color(0xFF2D2D2D)
        : isDark == false
            ? const Color(0xFFE8F0FE)
            : const Color(0xFF4A4A6A);
    final innerBar = isDark == true
        ? AppColors.primary
        : isDark == false
            ? AppColors.primary
            : AppColors.primary;
    final innerBg = isDark == true
        ? const Color(0xFF404040)
        : isDark == false
            ? Colors.white
            : const Color(0xFF5A5A7A);

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
                  color: selected ? AppColors.primary : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? AppColors.primary
                        : null,
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

  const _SettingsRow({required this.title, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        highlightColor: AppColors.itemPressBackground,
        splashColor: AppColors.itemPressBackground.withValues(alpha: 0.7),
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(title, style: const TextStyle(fontSize: 16)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null) ...[
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFFD1D5DB)),
            ],
          ),
        ),
      ),
    );
  }
}
