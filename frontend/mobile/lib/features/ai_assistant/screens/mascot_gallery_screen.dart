import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/ai_assistant/models/mascot_metadata.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_robot_avatar.dart';

class MascotGalleryScreen extends StatefulWidget {
  const MascotGalleryScreen({super.key});

  @override
  State<MascotGalleryScreen> createState() => _MascotGalleryScreenState();
}

class _MascotGalleryScreenState extends State<MascotGalleryScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.8);
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

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        title: const Text('Mascot Gallery'),
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        elevation: 0,
        forceMaterialTransparency: !isDarkMode,
        flexibleSpace: isDarkMode 
          ? null 
          : Container(decoration: BoxDecoration(gradient: AppColors.appBarGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Chọn trợ lý Mascot của bạn',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: mascots.length,
              itemBuilder: (context, index) {
                final mascot = mascots[index];
                final isSelected = provider.currentMascot.id == mascot.id;
                final scale = _currentPage == index ? 1.0 : 0.85;

                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: scale, end: scale),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Card(
                    elevation: isSelected ? 8 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    color: isDarkMode ? DarkColors.surface : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: AiRobotAvatar(
                              state: provider.state,
                              emotion: provider.currentEmotion,
                              size: 180,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            mascot.name,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            mascot.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isSelected
                                  ? null
                                  : () {
                                      provider.setMascot(mascot);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected
                                    ? Colors.grey
                                    : AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                isSelected ? 'Đang sử dụng' : 'Sử dụng Mascot này',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: mascots.asMap().entries.map((entry) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == entry.key
                        ? AppColors.primary
                        : (isDarkMode ? Colors.white24 : Colors.grey.shade300),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
