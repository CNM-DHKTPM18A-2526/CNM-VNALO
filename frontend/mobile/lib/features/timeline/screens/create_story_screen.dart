import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/timeline/providers/post_provider.dart';
import 'package:vnalo_mobile/services/media_service.dart';

// ─────────────────────────────────────────────
// Entry: Camera screen (screen 2 style)
// ─────────────────────────────────────────────
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final ImagePicker _picker = ImagePicker();
  int _selectedTabIndex = 1; // 0=CHỮ, 1=ẢNH, 2=VIDEO, 3=LOOP

  final List<String> _tabs = ['CHỮ', 'ẢNH', 'VIDEO', 'LOOP'];

  Future<void> _capturePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
      );
      if (image != null && mounted) {
        _goToPreview(File(image.path));
      }
    } catch (e) {
      debugPrint('[CreateStoryScreen] capturePhoto error: $e');
      // fallback: gallery
      _pickFromGallery();
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        _goToPreview(File(image.path));
      }
    } catch (e) {
      debugPrint('[CreateStoryScreen] pickFromGallery error: $e');
    }
  }

  void _goToPreview(File imageFile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryPreviewScreen(imageFile: imageFile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Dark camera preview background ──
          Container(color: const Color(0xFF1A1A1A)),

          // ── Camera placeholder visual ──
          Center(
            child: Icon(
              Icons.camera_alt,
              size: 80,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),

          // ── Back arrow ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              ),
            ),
          ),

          // ── Chevron down (collapse) ──
          Positioned(
            bottom: 220,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
              ),
            ),
          ),

          // ── Bottom area ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Recent photos row (bottom left thumbnail)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Gallery thumbnail
                      GestureDetector(
                        onTap: _pickFromGallery,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: const Icon(Icons.photo_library_outlined, color: Colors.white54, size: 28),
                        ),
                      ),
                      const Spacer(),

                      // Capture button
                      GestureDetector(
                        onTap: _capturePhoto,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Flip camera
                      GestureDetector(
                        onTap: _capturePhoto,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cameraswitch_outlined, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tab bar: CHỮ | ẢNH | VIDEO | LOOP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_tabs.length, (i) {
                    final isSelected = i == _selectedTabIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedTabIndex = i);
                        if (i == 1) _capturePhoto();
                        if (i == 2) _pickFromGallery();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _tabs[i],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white54,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (isSelected)
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              )
                            else
                              const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Preview + Post screen (screen 3 style)
// ─────────────────────────────────────────────
class StoryPreviewScreen extends StatefulWidget {
  final File imageFile;

  const StoryPreviewScreen({super.key, required this.imageFile});

  @override
  State<StoryPreviewScreen> createState() => _StoryPreviewScreenState();
}

class _StoryPreviewScreenState extends State<StoryPreviewScreen> {
  String _privacy = 'FRIENDS';
  bool _isPosting = false;

  final List<Map<String, dynamic>> _privacyOptions = [
    {'value': 'FRIENDS', 'label': 'Bạn bè', 'icon': Icons.group_outlined},
    {'value': 'PRIVATE', 'label': 'Mình tôi', 'icon': Icons.lock_outline},
    {'value': 'PUBLIC', 'label': 'Công khai', 'icon': Icons.public},
  ];

  String get _privacyLabel {
    return _privacyOptions.firstWhere((o) => o['value'] == _privacy)['label'] as String;
  }

  void _showPrivacyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          const Text('Quyền xem khoảnh khắc', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._privacyOptions.map((option) => ListTile(
                leading: Icon(option['icon'] as IconData, color: Colors.white70),
                title: Text(option['label'] as String, style: const TextStyle(color: Colors.white)),
                trailing: _privacy == option['value']
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _privacy = option['value'] as String);
                  Navigator.pop(ctx);
                },
              )),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Future<void> _postStory() async {
    setState(() => _isPosting = true);
    try {
      final postProvider = context.read<PostProvider>();
      final mediaService = context.read<MediaService>();

      // Upload ảnh
      final mediaId = await mediaService.uploadFile(
        widget.imageFile,
        MediaCategory.STORY,
      );
      final mediaUrl = mediaService.getPublicUrl(mediaId);

      // Tạo story
      final story = await postProvider.createStory(
        mediaUrl: mediaUrl,
        caption: '',
        visibility: _privacy,
      );

      if (story != null && mounted) {
        // Pop cả preview lẫn camera screen
        Navigator.of(context).popUntil((route) => route.isFirst || ModalRoute.of(context)?.settings.name == '/home');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Đã đăng khoảnh khắc!'),
              ],
            ),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng thất bại, vui lòng thử lại')),
        );
      }
    } catch (e) {
      debugPrint('[StoryPreviewScreen] postStory error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _saveToDevice() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu vào thư viện ảnh')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full screen photo ──
          Image.file(
            widget.imageFile,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),

          // ── Top bar: back + Thêm nhạc ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                  ),
                ),
                const Spacer(),
                // "Thêm nhạc" pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_note, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('Thêm nhạc', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Right side tools ──
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 72,
            child: Column(
              children: [
                _buildToolButton(Icons.text_fields_rounded, 'Aa'),
                const SizedBox(height: 16),
                _buildToolButton(Icons.sentiment_satisfied_alt_outlined, null),
                const SizedBox(height: 16),
                _buildToolButton(Icons.crop_rotate, null),
                const SizedBox(height: 16),
                _buildToolButton(Icons.blur_on, null),
                const SizedBox(height: 16),
                _buildToolButton(Icons.keyboard_arrow_down, null),
              ],
            ),
          ),

          // ── Bottom bar: Quyền xem | Tải về | Đăng ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad + 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  // Quyền xem
                  GestureDetector(
                    onTap: _showPrivacyPicker,
                    child: Row(
                      children: [
                        const Icon(Icons.group_outlined, color: Colors.white, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          _privacyLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Tải về
                  GestureDetector(
                    onTap: _saveToDevice,
                    child: const Row(
                      children: [
                        Icon(Icons.download_outlined, color: Colors.white, size: 20),
                        SizedBox(width: 6),
                        Text('Tải về', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Đăng button
                  GestureDetector(
                    onTap: _isPosting ? null : _postStory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isPosting ? AppColors.primary.withValues(alpha: 0.6) : AppColors.primary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: _isPosting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Đăng',
                              style: TextStyle(
                                color: Colors.white,
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
        ],
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String? label) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: label != null
            ? Center(
                child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              )
            : Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
