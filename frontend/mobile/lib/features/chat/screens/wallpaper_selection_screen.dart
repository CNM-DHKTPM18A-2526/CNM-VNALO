import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';

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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lá»—i: $e')));
          setState(() => _isSaving = false);
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.4),
      body: Stack(
        children: [
          // Close on tap outside
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.transparent),
          ),
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Modal Header
                  _buildHeader(),
                  const Divider(height: 1),
                  // Wallpaper Grid
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildGrid(),
                        const SizedBox(height: 16),
                        _buildApplyToBothCheckbox(),
                      ],
                    ),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Change wallpaper',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          TextButton(
            onPressed: (_selectedUrl != null && !_isSaving) ? _save : null,
            child: Text(
              'XONG',
              style: TextStyle(
                color: (_selectedUrl != null && !_isSaving) ? AppColors.primary : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
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
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.camera_alt_outlined, color: Colors.blue, size: 28),
            ),
          );
        }
        final url = _predefinedWallpapers[index - 1];
        final isSelected = _selectedUrl == url;
        return GestureDetector(
          onTap: () => setState(() => _selectedUrl = url),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: isSelected ? Border.all(color: AppColors.primary, width: 3) : null,
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(url),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (isSelected)
                Center(
                  child: Icon(Icons.check_circle, color: AppColors.primary, size: 24),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApplyToBothCheckbox() {
    return GestureDetector(
      onTap: () => setState(() => _applyToBoth = !_applyToBoth),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _applyToBoth ? AppColors.primary : Colors.white,
                border: Border.all(
                  color: _applyToBoth ? AppColors.primary : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: _applyToBoth
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
            ),
            const SizedBox(width: 10),
            const Text(
              'Apply wallpaper for both participants',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
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

      if (mounted) {
        Navigator.pop(context);
        _showSuccessToast();
      }
    } catch (e) {
      if (e is ApiException && e.statusCode == 403 && _applyToBoth) {
        // Fallback to personal wallpaper if global fails due to permissions
        try {
          await context.read<ChatProvider>().updateWallpaperUrl(
            widget.conversation.id,
            _selectedUrl!,
            isGlobal: false,
          );
          if (mounted) {
            Navigator.pop(context);
            _showSuccessToast(isFallback: true);
          }
          return;
        } catch (innerError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $innerError')));
            setState(() => _isSaving = false);
          }
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSuccessToast({bool isFallback = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wallpaper, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isFallback
                  ? 'Wallpaper updated only for you (insufficient permission for both)'
                  : 'Wallpaper updated successfully',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        duration: const Duration(seconds: 3),
        width: isFallback ? 320 : 240,
      ),
    );
  }
}
