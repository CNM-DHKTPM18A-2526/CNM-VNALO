import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';

class WallpaperSelectionScreen extends StatefulWidget {
  final Conversation conversation;

  const WallpaperSelectionScreen({super.key, required this.conversation});

  @override
  State<WallpaperSelectionScreen> createState() => _WallpaperSelectionScreenState();
}

class _WallpaperSelectionScreenState extends State<WallpaperSelectionScreen> {
  bool _applyToBoth = true;
  String? _selectedUrl;
  bool _isSaving = false;

  final List<String> _predefinedWallpapers = [
    'https://images.unsplash.com/photo-1557683316-973673baf926?q=80&w=500', // Blue
    'https://images.unsplash.com/photo-1506744038136-46273834b3fb?q=80&w=500', // Landscape
    'https://images.unsplash.com/photo-1533038590840-1cde6e668a91?q=80&w=500', // Minimal
    'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?q=80&w=500', // Sunset
    'https://images.unsplash.com/photo-1501854140801-50d01698950b?q=80&w=500', // Nature
    'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?q=80&w=500', // Forest
    'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?q=80&w=500', // Mist
    'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?q=80&w=500', // River
    'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?q=80&w=500', // Mountains
    'https://images.unsplash.com/photo-1500622345696-2424ef7e3b1f?q=80&w=500', // Hills
    'https://images.unsplash.com/photo-1518173946687-a4c8892bbd9f?q=80&w=500', // Rain
    'https://images.unsplash.com/photo-1502082553048-f009c37129b9?q=80&w=500', // Tree
    'https://images.unsplash.com/photo-1426604966848-d7adac402bff?q=80&w=500', // Waterfall
    'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?q=80&w=500', // Valley
    'https://images.unsplash.com/photo-1475924156734-496f6cac6ec1?q=80&w=500', // Beach
  ];

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() => _isSaving = true);
      try {
        await context.read<ChatProvider>().updateWallpaper(
          widget.conversation.id,
          File(image.path),
          isGlobal: _applyToBoth,
        );
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
          setState(() => _isSaving = false);
        }
      }
    }
  }

  Future<void> _save() async {
    if (_selectedUrl == null) return;
    setState(() => _isSaving = true);
    try {
      await context.read<ChatProvider>().updateWallpaperUrl(
        widget.conversation.id,
        _selectedUrl!,
        isGlobal: _applyToBoth,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Đổi hình nền', style: TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: (_selectedUrl != null && !_isSaving) ? _save : null,
            child: Text(
              'XONG',
              style: TextStyle(
                color: (_selectedUrl != null && !_isSaving) ? Colors.white : Colors.white38,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Semi-transparent background to show chat preview if needed
          // For now just focus on the modal-like UI from Pic 3
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Wallpaper Grid
                  SliverGrid.count(
                    crossAxisCount: 3,
                    children: [],
                  ), // Wait, can't use SliverGrid in a Column like this easily
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _predefinedWallpapers.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return GestureDetector(
                          onTap: _pickFromGallery,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.blue),
                          ),
                        );
                      }
                      final url = _predefinedWallpapers[index - 1];
                      final isSelected = _selectedUrl == url;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedUrl = url),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                            border: isSelected ? Border.all(color: Colors.blue, width: 3) : null,
                          ),
                          child: isSelected ? const Center(child: Icon(Icons.check_circle, color: Colors.blue)) : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Checkbox
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _applyToBoth,
                          onChanged: (v) => setState(() => _applyToBoth = v ?? true),
                          shape: const CircleBorder(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Đổi hình nền cho cả hai bên', style: TextStyle(fontSize: 14, color: Colors.black87)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
