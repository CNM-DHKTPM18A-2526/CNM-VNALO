import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/timeline/providers/post_provider.dart';
import 'package:vnalo_mobile/features/timeline/screens/album_privacy_sheet.dart';
import 'package:vnalo_mobile/features/timeline/screens/theme_decoration_screen.dart';
import 'package:vnalo_mobile/features/timeline/screens/text_background_screen.dart';
import 'package:vnalo_mobile/models/post_model.dart';
import 'package:vnalo_mobile/services/media_service.dart';

enum PostType { photo, video, album, textBackground }

class CreatePostScreen extends StatefulWidget {
  final PostType initialType;
  final List<File> initialFiles;
  final String? initialTextContent;

  const CreatePostScreen({
    super.key,
    this.initialType = PostType.photo,
    this.initialFiles = const [],
    this.initialTextContent,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  PostType _currentType = PostType.photo;
  List<File> _selectedFiles = [];
  bool _isPosting = false;

  // Album specific
  final TextEditingController _albumNameController = TextEditingController();
  String _privacy = 'FRIENDS';
  List<String> _includedFriendIds = [];
  List<String> _excludedFriendIds = [];
  String? _selectedTheme;
  bool _isAlbumMode = false;

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
    _isAlbumMode = _currentType == PostType.album;
    if (widget.initialFiles.isNotEmpty) {
      _selectedFiles = List.from(widget.initialFiles);
    }
    if (widget.initialTextContent != null) {
      _contentController.text = widget.initialTextContent!;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _albumNameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    try {
      final images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(images.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      debugPrint('[CreatePostScreen] pickPhotos error: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _selectedFiles.add(File(image.path));
        });
      }
    } catch (e) {
      debugPrint('[CreatePostScreen] takePhoto error: $e');
    }
  }

  Future<void> _pickVideos() async {
    try {
      final videos = await _picker.pickMultipleMedia(
        requestFullMetadata: true,
      );
      if (videos.isNotEmpty) {
        setState(() {
          for (final v in videos) {
            // Check by file extension
            final path = v.path.toLowerCase();
            if (path.endsWith('.mp4') || path.endsWith('.mov') || 
                path.endsWith('.avi') || path.endsWith('.mkv') ||
                path.endsWith('.webm') || path.contains('video')) {
              _selectedFiles.add(File(v.path));
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[CreatePostScreen] pickVideos error: $e');
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2),
            )),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: const Text('Chụp ảnh mới'),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library, color: Colors.purple),
              ),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhotos();
              },
            ),
            if (_isAlbumMode)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.video_library, color: Colors.orange),
                ),
                title: const Text('Chọn video'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVideos();
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AlbumPrivacySheet(
        currentPrivacy: _privacy,
        includedFriendIds: _includedFriendIds,
        excludedFriendIds: _excludedFriendIds,
        onPrivacyChanged: (privacy, included, excluded) {
          setState(() {
            _privacy = privacy;
            _includedFriendIds = included;
            _excludedFriendIds = excluded;
          });
        },
      ),
    );
  }

  void _showThemePicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThemeDecorationScreen(
          selectedTheme: _selectedTheme,
          albumPhotos: _selectedFiles,
          albumPrivacy: _privacy,
          onThemeSelected: (theme) {
            setState(() {
              _selectedTheme = theme;
            });
          },
        ),
      ),
    );
  }

  void _openTextBackground() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TextBackgroundScreen(
          onTextCreated: (content) {
            setState(() {
              _contentController.text = content;
              _currentType = PostType.textBackground;
            });
          },
        ),
      ),
    );
  }

  void _switchToAlbumMode() {
    setState(() {
      _isAlbumMode = true;
      _currentType = PostType.album;
    });
  }

  Future<void> _createPost() async {
    if (_isAlbumMode) {
      if (_albumNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập tên album')),
        );
        return;
      }
      if (_selectedFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn ít nhất 1 ảnh')),
        );
        return;
      }
    }

    setState(() => _isPosting = true);

    try {
      final postProvider = context.read<PostProvider>();
      final mediaService = context.read<MediaService>();

      List<String>? mediaUrls;
      if (_selectedFiles.isNotEmpty) {
        mediaUrls = [];
        for (final file in _selectedFiles) {
          final mediaId = await mediaService.uploadFile(
            file,
            MediaCategory.TIMELINE,
          );
          final mediaUrl = mediaService.getPublicUrl(mediaId);
          mediaUrls.add(mediaUrl);
        }
      }

      Post? post;
        if (_isAlbumMode) {
          // Create as album post
          final description = _contentController.text.trim();
          post = await postProvider.createPost(
            contentText: '${_albumNameController.text.trim()}${description.isNotEmpty ? '\n\n$description' : ''}',
            mediaUrls: mediaUrls,
            visibility: _privacy,
            includedIds: _privacy == 'SOME_FRIENDS' ? _includedFriendIds : [],
            excludedIds: _privacy == 'EXCEPT' ? _excludedFriendIds : [],
          );
        } else {
          post = await postProvider.createPost(
            contentText: _contentController.text.trim(),
            mediaUrls: mediaUrls,
            visibility: _privacy,
            includedIds: _privacy == 'SOME_FRIENDS' ? _includedFriendIds : [],
            excludedIds: _privacy == 'EXCEPT' ? _excludedFriendIds : [],
          );
        }

      if (post != null && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng thành công')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng thất bại')),
        );
      }
    } catch (e) {
      debugPrint('[CreatePostScreen] createPost error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _isAlbumMode 
            ? Text(
                'Tạo album mới',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              )
            : GestureDetector(
                onTap: _showPrivacyPicker,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _privacy == 'FRIENDS' ? Icons.group : 
                      _privacy == 'PRIVATE' ? Icons.lock : 
                      _privacy == 'SOME_FRIENDS' ? Icons.person_add : Icons.person_remove,
                      color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _getPrivacyDisplayTitle(),
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down, color: isDarkMode ? Colors.white : Colors.black, size: 18),
                            ],
                          ),
                          Text(
                            _getPrivacyDisplaySubtitle(),
                            style: TextStyle(
                              color: isDarkMode ? Colors.white54 : Colors.grey.shade500,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        actions: [
          if (_isAlbumMode)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TextButton(
                  onPressed: _isPosting ? null : _createPost,
                  child: _isPosting
                      ? SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : Text(
                          'LƯU',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "Aa / Brush" mock toggle button
                Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white12 : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white24 : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Aa',
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.brush, size: 16, color: isDarkMode ? Colors.white54 : Colors.blue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: TextButton(
                      onPressed: _isPosting ? null : _createPost,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                      ),
                      child: _isPosting
                          ? SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : Text(
                              'Đăng', 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 16, 
                                color: (_contentController.text.trim().isNotEmpty || _selectedFiles.isNotEmpty) 
                                    ? AppColors.primary 
                                    : (isDarkMode ? Colors.white38 : Colors.grey),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isAlbumMode ? _buildAlbumMode(context) : _buildNormalMode(context),
    );
  }

  Widget _buildNormalMode(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Content input
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: _currentType == PostType.textBackground 
                          ? 'Nội dung đã được tạo với nền chữ...' 
                          : 'Bạn đang nghĩ gì?',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: isDarkMode ? Colors.white38 : Colors.grey, fontSize: 16),
                    ),
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16),
                  ),
                ),

                // Outline action buttons row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildOutlineButton(Icons.music_note, 'Thêm nhạc', Colors.purple.shade300),
                      const SizedBox(width: 8),
                      _buildOutlineButton(Icons.collections, 'Thêm vào album', Colors.green),
                      const SizedBox(width: 8),
                      _buildOutlineButton(Icons.local_offer, 'Với bạn bè', Colors.grey.shade700),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),

                // Selected files preview
                if (_selectedFiles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        ...List.generate(_selectedFiles.length, (index) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: FileImage(_selectedFiles[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                            // Set a fixed height or aspect ratio for the image
                            height: MediaQuery.of(context).size.width * 1.2, 
                            child: Stack(
                              children: [
                                // Sửa ảnh button
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit, color: Colors.white, size: 14),
                                        SizedBox(width: 6),
                                        Text('Sửa ảnh', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ),
                                // Close button
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: () => _removeFile(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white24, width: 1),
                                      ),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        
                        // + Thêm ảnh button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showPhotoOptions,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Thêm ảnh', style: TextStyle(fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                              foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Bottom Toolbar
        _buildBottomToolbar(isDarkMode),
      ],
    );
  }

  Widget _buildOutlineButton(IconData icon, String label, Color iconColor) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? DarkColors.appBarBg : Colors.white,
        border: Border(top: BorderSide(color: isDarkMode ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Text background circle
                Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text('Aa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDarkMode ? Colors.white : Colors.black87)),
                      const Positioned(
                        right: 2,
                        bottom: 2,
                        child: Icon(Icons.color_lens, size: 12, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.face, color: isDarkMode ? Colors.white60 : Colors.grey.shade600, size: 28),
                GestureDetector(
                  onTap: _showPhotoOptions,
                  child: Icon(Icons.photo_outlined, color: isDarkMode ? Colors.white60 : Colors.grey.shade600, size: 28),
                ),
                Icon(Icons.play_circle_outline, color: isDarkMode ? Colors.white60 : Colors.grey.shade600, size: 28),
                Icon(Icons.link, color: isDarkMode ? Colors.white60 : Colors.grey.shade600, size: 28),
                Icon(Icons.location_on_outlined, color: isDarkMode ? Colors.white60 : Colors.grey.shade600, size: 28),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumMode(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDarkMode ? Colors.white : Colors.black;
    final textHint = isDarkMode ? Colors.white38 : Colors.grey.shade400;
    final dividerColor = isDarkMode ? Colors.white12 : Colors.grey.shade200;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album name input (large, bold placeholder)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: TextField(
              controller: _albumNameController,
              decoration: InputDecoration(
                hintText: 'Nhập tên album',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.white30 : Colors.grey.shade300,
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                color: textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Description input (smaller, not required)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _contentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Thêm mô tả (không bắt buộc)',
                hintStyle: TextStyle(color: textHint, fontSize: 15),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(color: textPrimary, fontSize: 15),
            ),
          ),

          Divider(color: dividerColor, thickness: 1, height: 1),
          const SizedBox(height: 8),

          // Privacy setting tile - Bạn bè VNALO
          InkWell(
            onTap: _showPrivacyPicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.group_outlined, size: 20, color: isDarkMode ? Colors.white60 : Colors.black54),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getPrivacyDisplayTitle(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary)),
                        Text(_getPrivacyDisplaySubtitle(), style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white38 : Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Divider(color: dividerColor, thickness: 1, height: 1, indent: 66),

          // Theme decoration tile
          InkWell(
            onTap: _showThemePicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_awesome_outlined, size: 20, color: isDarkMode ? Colors.pinkAccent.shade100 : Colors.pinkAccent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chọn chủ đề trang trí',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary),
                        ),
                        Text(
                          _selectedTheme != null ? 'Đã chọn: $_selectedTheme' : 'Làm đẹp album với các yếu tố trang trí',
                          style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white38 : Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Divider(color: dividerColor, thickness: 1, height: 1),
          const SizedBox(height: 12),

          // Photos section label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Ảnh',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),

          // Photo grid or empty state
          _buildPhotoGrid(),

          // Add more button (when photos exist)
          if (_selectedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showPhotoOptions,
                  icon: const Icon(Icons.add),
                  label: const Text('+ Thêm ảnh'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                    foregroundColor: isDarkMode ? Colors.white70 : Colors.black54,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (_selectedFiles.isEmpty) {
      return GestureDetector(
        onTap: _showPhotoOptions,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 36),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDarkMode ? Colors.white12 : Colors.grey.shade300,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white10 : const Color(0xFFF0F4FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  size: 36,
                  color: isDarkMode ? Colors.white30 : const Color(0xFFB0BEC5),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Chưa có ảnh nào',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Thêm ảnh tại đây để xem trước cùng với\nchủ đề trang trí.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _showPhotoOptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                ),
                child: const Text(
                  'THÊM ẢNH',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: _selectedFiles.length + 1,
        itemBuilder: (context, index) {
          if (index == _selectedFiles.length) {
            return GestureDetector(
              onTap: _showPhotoOptions,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(Icons.add, color: Colors.grey),
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_selectedFiles[index], fit: BoxFit.cover),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeFile(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }



  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          )),
        ],
      ),
    );
  }

  Widget _buildGalleryPreview() {
    return GestureDetector(
      onTap: _pickPhotos,
      child: Container(
        height: 100,
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.photo_library, color: Colors.grey.shade400, size: 32),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Chọn từ thư viện',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đăng ảnh, video lên nhật ký',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  String _getPrivacyDisplayTitle() {
    switch (_privacy) {
      case 'FRIENDS':
        return 'Bạn bè VNALO';
      case 'PRIVATE':
        return 'Chỉ mình tôi';
      case 'SOME_FRIENDS':
        return 'Một số bạn bè';
      case 'EXCEPT':
        return 'Bạn bè ngoại trừ...';
      default:
        return 'Bạn bè VNALO';
    }
  }

  String _getPrivacyDisplaySubtitle() {
    switch (_privacy) {
      case 'FRIENDS':
        return 'Tất cả bạn bè trên VNALO';
      case 'PRIVATE':
        return 'Chỉ mình bạn được xem';
      case 'SOME_FRIENDS':
        return _includedFriendIds.isEmpty 
          ? 'Chọn những bạn bè được xem' 
          : '${_includedFriendIds.length} người được chọn';
      case 'EXCEPT':
        return _excludedFriendIds.isEmpty 
          ? 'Chọn những bạn bè không được xem'
          : '${_excludedFriendIds.length} người bị loại trừ';
      default:
        return 'Tất cả bạn bè trên VNALO';
    }
  }


}
