import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class PhotoPickerScreen extends StatefulWidget {
  final List<File> initialFiles;
  final Function(List<File>) onPhotosSelected;
  final int maxPhotos;

  const PhotoPickerScreen({
    super.key,
    this.initialFiles = const [],
    required this.onPhotosSelected,
    this.maxPhotos = 20,
  });

  @override
  State<PhotoPickerScreen> createState() => _PhotoPickerScreenState();
}

class _PhotoPickerScreenState extends State<PhotoPickerScreen> {
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedFiles = [];
  List<XFile> _galleryImages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedFiles = List.from(widget.initialFiles);
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    try {
      // Load images from gallery using pickMultiImage for preview purposes
      // We store all images in state
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openGallery() async {
    try {
      final images = await _picker.pickMultiImage(limit: widget.maxPhotos);
      if (images.isNotEmpty && mounted) {
        setState(() {
          _galleryImages = images;
        });
      }
    } catch (e) {
      debugPrint('[PhotoPickerScreen] openGallery error: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null && mounted) {
        setState(() {
          _selectedFiles.insert(0, File(image.path));
        });
      }
    } catch (e) {
      debugPrint('[PhotoPickerScreen] takePhoto error: $e');
    }
  }

  void _toggleImage(XFile xfile) {
    final file = File(xfile.path);
    final existingIndex = _selectedFiles.indexWhere((f) => f.path == file.path);
    setState(() {
      if (existingIndex >= 0) {
        _selectedFiles.removeAt(existingIndex);
      } else if (_selectedFiles.length < widget.maxPhotos) {
        _selectedFiles.add(file);
      }
    });
  }

  bool _isSelected(XFile xfile) {
    return _selectedFiles.any((f) => f.path == xfile.path);
  }

  int _getSelectionIndex(XFile xfile) {
    return _selectedFiles.indexWhere((f) => f.path == xfile.path) + 1;
  }

  void _confirm() {
    widget.onPhotosSelected(_selectedFiles);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? DarkColors.scaffold : Colors.white;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;

    return Scaffold(
      backgroundColor: bgColor,
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
        actions: [
          if (_selectedFiles.isNotEmpty)
            TextButton(
              onPressed: _confirm,
              child: Text(
                'Tiếp theo (${_selectedFiles.length})',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Gallery content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _galleryImages.isEmpty
                    ? _buildEmptyState(isDarkMode)
                    : _buildImageGrid(isDarkMode),
          ),

          // Bottom confirm bar
          if (_selectedFiles.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDarkMode ? DarkColors.surface : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Đã chọn ${_selectedFiles.length} ảnh',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Tiếp theo', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Camera button at top (simulates "Chụp ảnh" in ảnh 2)
          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt_outlined,
                size: 36,
                color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chụp ảnh',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _openGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Mở thư viện ảnh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Nhấn để chọn ảnh từ thư viện',
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(bool isDarkMode) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _galleryImages.length + 1,
      itemBuilder: (context, index) {
        // First cell = camera
        if (index == 0) {
          return GestureDetector(
            onTap: _takePhoto,
            child: Container(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt,
                    size: 32,
                    color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chụp ảnh',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final xfile = _galleryImages[index - 1];
        final selected = _isSelected(xfile);
        final selectionIndex = selected ? _getSelectionIndex(xfile) : 0;

        return GestureDetector(
          onTap: () => _toggleImage(xfile),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(xfile.path),
                fit: BoxFit.cover,
              ),
              // Dark overlay when selected
              if (selected)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              // Selection badge (top right)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.white,
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: selected
                      ? Center(
                          child: Text(
                            '$selectionIndex',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
