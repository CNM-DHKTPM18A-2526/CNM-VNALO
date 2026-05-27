import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/theme/app_typography.dart';
import 'package:vnalo_mobile/features/ai_assistant/models/mascot_metadata.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/theme/ai_assistant_tokens.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_robot_avatar.dart';

class MascotGalleryScreen extends StatefulWidget {
  const MascotGalleryScreen({super.key});

  @override
  State<MascotGalleryScreen> createState() => _MascotGalleryScreenState();
}

class _MascotGalleryScreenState extends State<MascotGalleryScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiAssistantProvider>();
    final mascots = MascotMetadata.defaultMascots;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary;
    final textSecondary =
        isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary;
    final hasMultipleMascots = mascots.length > 1;

    return Scaffold(
      backgroundColor:
          isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        title: const Text('Chọn trợ lý AI'),
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        elevation: 0,
        forceMaterialTransparency: !isDarkMode,
        flexibleSpace:
            isDarkMode
                ? null
                : Container(
                  decoration: BoxDecoration(gradient: AppColors.appBarGradient),
                ),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: AppTypography.titleMedium.copyWith(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cá nhân hóa trợ lý của bạn',
                    style: AppTypography.titleLarge.copyWith(
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chọn mascot mặc định để đồng bộ giao diện trợ lý ảo trên mobile.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                key: const ValueKey('mascot_gallery_pager'),
                controller: _pageController,
                itemCount: mascots.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final mascot = mascots[index];
                  final isSelected = provider.currentMascot.id == mascot.id;
                  final scale = _currentPage == index ? 1.0 : 0.96;

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: scale, end: scale),
                    duration: const Duration(milliseconds: 260),
                    builder: (context, value, child) {
                      return Transform.scale(scale: value, child: child);
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isDarkMode ? DarkColors.surface : Colors.white,
                          borderRadius: BorderRadius.circular(
                            AiAssistantTokens.sheetRadius,
                          ),
                          border: Border.all(
                            color:
                                isSelected
                                    ? AppColors.primary
                                    : (isDarkMode
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : AppColors.itemDivider),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? AppColors.primary.withValues(
                                              alpha: 0.12,
                                            )
                                            : (isDarkMode
                                                ? Colors.white.withValues(
                                                  alpha: 0.06,
                                                )
                                                : AppColors
                                                    .itemPressBackground),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    isSelected
                                        ? 'Đang sử dụng'
                                        : 'Sẵn sàng áp dụng',
                                    style: AppTypography.labelSmall.copyWith(
                                      color:
                                          isSelected
                                              ? AppColors.primary
                                              : textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: Center(
                                  child: AiRobotAvatar(
                                    state: provider.state,
                                    emotion: provider.currentEmotion,
                                    size: 180,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                mascot.name,
                                textAlign: TextAlign.center,
                                style: AppTypography.titleLarge.copyWith(
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                mascot.description,
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: textSecondary,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  key: const ValueKey(
                                    'mascot_gallery_primary_button',
                                  ),
                                  onPressed:
                                      isSelected
                                          ? null
                                          : () => provider.setMascot(mascot),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        isSelected
                                            ? (isDarkMode
                                                ? DarkColors.surfaceLight
                                                : AppColors.itemPressBackground)
                                            : AppColors.primary,
                                    foregroundColor:
                                        isSelected
                                            ? textSecondary
                                            : Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AiAssistantTokens.pillRadius,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    isSelected
                                        ? 'Mascot hiện tại'
                                        : 'Dùng mascot này',
                                    style: AppTypography.labelLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (hasMultipleMascots)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:
                      mascots.asMap().entries.map((entry) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                _currentPage == entry.key
                                    ? AppColors.primary
                                    : (isDarkMode
                                        ? Colors.white24
                                        : Colors.grey.shade300),
                          ),
                        );
                      }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
