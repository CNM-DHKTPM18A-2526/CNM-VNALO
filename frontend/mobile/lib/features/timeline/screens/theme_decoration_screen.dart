import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class ThemeDecorationScreen extends StatefulWidget {
  final String? selectedTheme;
  final List<File> albumPhotos;
  final String albumPrivacy;
  final Function(String?) onThemeSelected;

  const ThemeDecorationScreen({
    super.key,
    this.selectedTheme,
    this.albumPhotos = const [],
    this.albumPrivacy = 'FRIENDS',
    required this.onThemeSelected,
  });

  @override
  State<ThemeDecorationScreen> createState() => _ThemeDecorationScreenState();
}

class _ThemeDecorationScreenState extends State<ThemeDecorationScreen> {
  late String? _selectedTheme;

  final List<Map<String, dynamic>> _themes = [
    {
      'id': 'family',
      'name': 'Gia đình',
      'bgColor': const Color(0xFFFFF3E0),
      'accentColor': const Color(0xFFFF8A65),
      'icon': Icons.family_restroom,
      'gradient': [const Color(0xFFFF8A65), const Color(0xFFFFCC02)],
    },
    {
      'id': 'travel',
      'name': 'Du lịch',
      'bgColor': const Color(0xFFE3F2FD),
      'accentColor': const Color(0xFF42A5F5),
      'icon': Icons.flight_takeoff,
      'gradient': [const Color(0xFF42A5F5), const Color(0xFF26C6DA)],
    },
    {
      'id': 'childhood',
      'name': 'Tuổi thơ',
      'bgColor': const Color(0xFFF3E5F5),
      'accentColor': const Color(0xFFAB47BC),
      'icon': Icons.child_care,
      'gradient': [const Color(0xFFAB47BC), const Color(0xFFFF80AB)],
    },
    {
      'id': 'couple',
      'name': 'Đôi lứa',
      'bgColor': const Color(0xFFFCE4EC),
      'accentColor': const Color(0xFFEC407A),
      'icon': Icons.favorite,
      'gradient': [const Color(0xFFEC407A), const Color(0xFFF06292)],
    },
    {
      'id': 'feminine',
      'name': 'Nữ tính',
      'bgColor': const Color(0xFFFCE4EC),
      'accentColor': const Color(0xFFF48FB1),
      'icon': Icons.local_florist,
      'gradient': [const Color(0xFFF8BBD0), const Color(0xFFE91E63)],
      'isFloral': true,
    },
    {
      'id': 'nature',
      'name': 'Thiên nhiên',
      'bgColor': const Color(0xFFE8F5E9),
      'accentColor': const Color(0xFF66BB6A),
      'icon': Icons.park,
      'gradient': [const Color(0xFF66BB6A), const Color(0xFF26A69A)],
    },
    {
      'id': 'birthday',
      'name': 'Sinh nhật',
      'bgColor': const Color(0xFFFFF9C4),
      'accentColor': const Color(0xFFFFD600),
      'icon': Icons.cake,
      'gradient': [const Color(0xFFFFD600), const Color(0xFFFF6F00)],
    },
    {
      'id': 'graduation',
      'name': 'Tốt nghiệp',
      'bgColor': const Color(0xFFE8EAF6),
      'accentColor': const Color(0xFF5C6BC0),
      'icon': Icons.school,
      'gradient': [const Color(0xFF5C6BC0), const Color(0xFF7986CB)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.selectedTheme;
  }

  Map<String, dynamic>? get _selectedThemeData {
    if (_selectedTheme == null) return null;
    try {
      return _themes.firstWhere((t) => t['id'] == _selectedTheme);
    } catch (_) {
      return null;
    }
  }

  String _getPrivacyLabel() {
    switch (widget.albumPrivacy) {
      case 'FRIENDS': return 'Bạn bè VNALO';
      case 'PRIVATE': return 'Mình tôi';
      case 'CONTACTS': return 'Bạn bè từ danh bạ';
      case 'GROUP': return 'Bạn bè trong nhóm';
      case 'FRIENDS_EXCEPT': return 'Bạn bè ngoại trừ';
      default: return 'Bạn bè VNALO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeData = _selectedThemeData;

    // Background color of the preview based on theme
    final previewBg = themeData != null
        ? (themeData['bgColor'] as Color)
        : (isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF8F8F8));

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chủ đề trang trí',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      body: Column(
        children: [
          // ====== PREVIEW AREA ======
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              color: previewBg,
              child: Stack(
                children: [
                  // Decorative corner elements (floral for feminine theme)
                  if (themeData?['isFloral'] == true) ...[
                    Positioned(
                      top: -10,
                      left: -10,
                      child: _buildFloralDecoration(120, 0.6),
                    ),
                    Positioned(
                      top: -10,
                      right: -10,
                      child: Transform.flip(
                        flipX: true,
                        child: _buildFloralDecoration(120, 0.6),
                      ),
                    ),
                  ],

                  // Center content
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Photo count & privacy
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${widget.albumPhotos.length} ảnh',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.white38 : Colors.black38,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.group_outlined,
                                size: 16,
                                color: isDarkMode ? Colors.white54 : Colors.black45,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getPrivacyLabel(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Photo preview area
                        if (widget.albumPhotos.isNotEmpty)
                          _buildPhotoPreview(themeData)
                        else
                          _buildEmptyPhotoPreview(isDarkMode, themeData),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ====== BOTTOM PANEL: THEME SELECTION ======
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? DarkColors.surface : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Text(
                    'Chọn chủ đề',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),

                // Horizontal theme scroll
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _themes.length,
                    itemBuilder: (context, index) {
                      final theme = _themes[index];
                      final isSelected = _selectedTheme == theme['id'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTheme = isSelected ? null : theme['id'] as String;
                          });
                        },
                        child: _buildThemeItem(theme, isSelected, isDarkMode),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Apply button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onThemeSelected(_selectedTheme);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text(
                        'ÁP DỤNG CHỦ ĐỀ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeItem(Map<String, dynamic> theme, bool isSelected, bool isDarkMode) {
    final gradient = theme['gradient'] as List<Color>;
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 12, bottom: 4),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(color: AppColors.primary, width: 3)
                  : Border.all(color: Colors.transparent, width: 3),
              boxShadow: [
                BoxShadow(
                  color: (gradient.first).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 28)
                : Icon(
                    theme['icon'] as IconData,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 28,
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            theme['name'] as String,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? AppColors.primary
                  : (isDarkMode ? Colors.white60 : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPhotoPreview(bool isDarkMode, Map<String, dynamic>? themeData) {
    return Container(
      width: 260,
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white10 : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeData != null
              ? (themeData['accentColor'] as Color).withValues(alpha: 0.3)
              : (isDarkMode ? Colors.white12 : Colors.grey.shade200),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : const Color(0xFFE8EDF5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.photo_library_outlined,
              size: 34,
              color: isDarkMode ? Colors.white30 : const Color(0xFFB0BEC5),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Album chưa có ảnh',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Lấp đầy album bằng những khoảnh khắc đáng nhớ.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview(Map<String, dynamic>? themeData) {
    final photos = widget.albumPhotos.take(4).toList();
    return Container(
      width: 260,
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: photos.length == 1
            ? Image.file(photos[0], fit: BoxFit.cover, width: 260, height: 200)
            : GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: photos.map((f) => Image.file(f, fit: BoxFit.cover)).toList(),
              ),
      ),
    );
  }

  Widget _buildFloralDecoration(double size, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.pink.shade100,
              Colors.pink.shade50.withValues(alpha: 0),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 10,
              left: 10,
              child: Icon(Icons.local_florist, size: 40, color: Colors.pink.shade200),
            ),
            Positioned(
              top: 30,
              left: 40,
              child: Icon(Icons.local_florist, size: 28, color: Colors.pink.shade100),
            ),
          ],
        ),
      ),
    );
  }
}
