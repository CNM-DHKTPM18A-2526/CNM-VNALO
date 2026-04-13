import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/localization/auth_texts.dart';
import 'package:vnalo_mobile/features/auth/screens/login_screen.dart';
import 'package:vnalo_mobile/features/auth/screens/register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showLanguageSheet(AuthTexts t) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final selected = Provider.of<LanguageProvider>(bottomSheetContext, listen: true).language;

        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? DarkColors.surface : LightColors.surface,
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
                      color: isDarkMode ? DarkColors.divider : LightColors.divider,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t.languageTitle,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _LanguageOptionTile(
                    label: t.vietnamese,
                    selected: selected == AppLanguage.vi,
                    onTap: () {
                      bottomSheetContext.read<LanguageProvider>().setLanguage(
                        AppLanguage.vi,
                      );
                      Navigator.pop(bottomSheetContext);
                    },
                  ),
                  _LanguageOptionTile(
                    label: t.english,
                    selected: selected == AppLanguage.en,
                    onTap: () {
                      bottomSheetContext.read<LanguageProvider>().setLanguage(
                        AppLanguage.en,
                      );
                      Navigator.pop(bottomSheetContext);
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final t = AuthTexts.of(context);
    final carouselImages = AuthTexts.carouselImages;
    final language = context.watch<LanguageProvider>().label;
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: isDarkMode ? DarkColors.scaffold : LightColors.scaffold,
        body: Column(
          children: [
            SizedBox(height: topInset + 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // Language selector
              child: Row(
                children: [
                  const Spacer(),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () => _showLanguageSheet(t),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 40),
                        side: BorderSide(
                          color: isDarkMode ? DarkColors.divider : LightColors.divider,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        foregroundColor: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            language,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // App logo and name
            Text(
              t.appName,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? DarkColors.primary : AppColors.primary,
              ),
            ),
            // Carousel area uses Expanded to take all remaining vertical space
            Expanded(
              child: Column(
                children: [
                  // Image + text area
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: carouselImages.length,
                      onPageChanged:
                          (value) => setState(() => _currentPage = value),
                      itemBuilder: (_, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 26),
                          child: Column(
                            children: [
                              // Image fills available space
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Image.asset(
                                    carouselImages[index],
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              // Title
                              Text(
                                t.welcomeTitles[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Subtitle
                              Text(
                                t.welcomeSubtitles[index],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                  color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Dots
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16, top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        carouselImages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          height: 10,
                          width: 10,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? (isDarkMode ? DarkColors.primary : AppColors.primary)
                                : (isDarkMode ? DarkColors.divider : LightColors.divider),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              backgroundColor: isDarkMode ? DarkColors.primary : AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(
                              t.login,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              backgroundColor: isDarkMode ? DarkColors.surface : LightColors.surfaceLight,
                              foregroundColor: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(
                              t.createAccount,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: bottomInset > 0 ? bottomInset + 8 : 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 18,
          color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
        ),
      ),
      trailing:
          selected
              ? Icon(Icons.check, color: isDarkMode ? DarkColors.primary : AppColors.primary, size: 24)
              : null,
    );
  }
}
