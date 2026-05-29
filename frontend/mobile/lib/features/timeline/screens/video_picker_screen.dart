import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

import 'package:vnalo_mobile/features/timeline/screens/video_preview_screen.dart';
import 'package:vnalo_mobile/features/timeline/screens/create_post_screen.dart';

class VideoPickerScreen extends StatefulWidget {
  const VideoPickerScreen({super.key});

  @override
  State<VideoPickerScreen> createState() => _VideoPickerScreenState();
}

class _VideoPickerScreenState extends State<VideoPickerScreen> {
  final ImagePicker _picker = ImagePicker();


  Future<void> _recordVideo() async {
    try {
      final video = await _picker.pickVideo(source: ImageSource.camera);
      if (video != null && mounted) {
        _goToPreview(File(video.path));
      }
    } catch (e) {
      debugPrint('[VideoPickerScreen] recordVideo error: $e');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null && mounted) {
        _goToPreview(File(video.path));
      }
    } catch (e) {
      debugPrint('[VideoPickerScreen] pickVideo error: $e');
    }
  }

  void _goToPreview(File file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPreviewScreen(
          videoFile: file,
          onConfirm: (File confirmedFile, bool isMuted) {
            // Push CreatePostScreen with video
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => CreatePostScreen(
                  initialType: PostType.video,
                  initialFiles: [confirmedFile],
                  // Future: Handle isMuted here if CreatePostScreen supports it
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : Colors.white,
      appBar: AppBar(
        backgroundColor: appBarBg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tất cả',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _buildEmptyState(isDarkMode),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Video/image placeholder icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : const Color(0xFFF0F4FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.image_outlined,
              size: 52,
              color: isDarkMode ? Colors.white30 : const Color(0xFFB0BEC5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Hiện tại bạn chưa có video nào.',
            style: TextStyle(
              fontSize: 15,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _recordVideo,
            child: Text(
              'Bấm để quay video',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Button to open gallery picker
          OutlinedButton.icon(
            onPressed: _pickVideoFromGallery,
            icon: Icon(Icons.video_library_outlined, color: AppColors.primary),
            label: Text(
              'Chọn video từ thư viện',
              style: TextStyle(color: AppColors.primary),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

}
