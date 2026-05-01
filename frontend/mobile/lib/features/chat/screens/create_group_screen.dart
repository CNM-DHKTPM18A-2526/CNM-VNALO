import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/features/profile/providers/avatar_cache_provider.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/friend_service.dart';
import 'package:vnalo_mobile/services/media_service.dart';
import 'package:vnalo_mobile/services/api_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  List<User> _friends = [];
  List<User> _filteredFriends = [];
  final Set<String> _selectedUserIds = {};
  bool _isLoading = true;
  File? _selectedAvatar;
  int? _selectedQuickIconIndex; // Track selected quick icon
  final ImagePicker _picker = ImagePicker();

  // Preset quick icons for group avatar
  static const List<IconData> _quickIcons = [
    Icons.calendar_today,
    Icons.campaign,
    Icons.assignment,
    Icons.image,
  ];
  static const List<Color> _quickIconColors = [
    Color(0xFFE56353),
    Color(0xFFF4B400),
    Color(0xFF4A89DF),
    Color(0xFF34A853),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFriends();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await context.read<FriendService>().getFriends();
      if (mounted) {
        setState(() {
          _friends = friends;
          _filteredFriends = friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _friends;
      } else {
        _filteredFriends = _friends.where((f) {
          final q = query.toLowerCase();
          return f.displayName.toLowerCase().contains(q) || 
                 (f.phone?.contains(q) ?? false);
        }).toList();
      }
    });
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _selectedAvatar = File(image.path);
        _selectedQuickIconIndex = null; // Clear quick icon when photo is picked
      });
    }
  }

  void _showAvatarOptions() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? DarkColors.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Cập nhật hình đại diện',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            // Custom Icons as per Image 3
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(4, (index) =>
                  _buildAvatarQuickIcon(
                    _quickIcons[index], 
                    _quickIconColors[index],
                    index,
                  ),
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Chụp ảnh mới'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Chọn ảnh từ điện thoại'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarQuickIcon(IconData icon, Color color, int index) {
    final isSelected = _selectedQuickIconIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedQuickIconIndex = index;
          _selectedAvatar = null; // Clear photo when quick icon is chosen
        });
        Navigator.pop(context); // Close bottom sheet
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.3) : color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: color, width: 2.5) : null,
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  /// Render a Material icon with colored background to a PNG file for upload
  Future<File> _renderIconToFile(IconData icon, Color color) async {
    const double size = 256;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // Draw colored circle background
    final bgPaint = Paint()..color = color.withValues(alpha: 0.15);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, bgPaint);

    // Draw the icon using TextPainter
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.45,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/group_icon_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(byteData!.buffer.asUint8List());

    return file;
  }

  Future<void> _createGroup() async {
    if (_selectedUserIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 2 thành viên để tạo nhóm')),
      );
      return;
    }

    // Prepare title
    String title = _nameController.text.trim();
    if (title.isEmpty) {
      final List<String> selectedNames = _friends
          .where((f) => _selectedUserIds.contains(f.id))
          .map((f) => f.displayName)
          .toList();
      
      if (selectedNames.length <= 3) {
        title = selectedNames.join(', ');
      } else {
        title = '${selectedNames.take(3).join(', ')}...';
      }
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      String? avatarUrl;

      // Get avatar file: either from picker or render quick icon to file
      File? avatarFile = _selectedAvatar;
      if (avatarFile == null && _selectedQuickIconIndex != null) {
        avatarFile = await _renderIconToFile(
          _quickIcons[_selectedQuickIconIndex!],
          _quickIconColors[_selectedQuickIconIndex!],
        );
      }

      // Upload avatar if available
      if (avatarFile != null) {
        try {
          final mediaService = context.read<MediaService>();
          final mediaId = await mediaService.uploadFile(avatarFile, MediaCategory.AVATAR);
          avatarUrl = mediaService.getPublicUrl(mediaId);
        } catch (e) {
          debugPrint('Avatar upload failed: $e');
        }
      }

      final conversation = await context.read<ChatProvider>().createGroupConversation(
        title: title,
        memberIds: _selectedUserIds.toList(),
        avatarUrl: avatarUrl,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context); // Close screen
        
        if (conversation != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatDetailScreen(conversation: conversation),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tạo nhóm: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        forceMaterialTransparency: !isDarkMode,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhóm mới',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              'Đã chọn: ${_selectedUserIds.length}',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          if (_selectedUserIds.length >= 2)
            TextButton(
              onPressed: _createGroup,
              child: const Text('TẠO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Top Input section
          Container(
            color: isDarkMode ? DarkColors.surface : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showAvatarOptions,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: _selectedAvatar != null 
                      ? ClipOval(child: Image.file(_selectedAvatar!, fit: BoxFit.cover, width: 50, height: 50))
                      : _selectedQuickIconIndex != null
                        ? Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _quickIconColors[_selectedQuickIconIndex!].withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _quickIcons[_selectedQuickIconIndex!], 
                              color: _quickIconColors[_selectedQuickIconIndex!], 
                              size: 26,
                            ),
                          )
                        : Icon(Icons.camera_alt, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Đặt tên nhóm',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDarkMode ? DarkColors.surface : Colors.white,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Tìm tên hoặc số điện thoại',
                  hintStyle: TextStyle(color: isDarkMode ? Colors.white38 : Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
          // Tabs
          Container(
            color: isDarkMode ? DarkColors.surface : Colors.white,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'GẦN ĐÂY'),
                Tab(text: 'DANH BẠ'),
              ],
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2,
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildFriendsList(isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList(bool isDarkMode) {
    if (_filteredFriends.isEmpty) {
      return Center(
        child: Text('Không tìm thấy liên hệ', style: TextStyle(color: Colors.grey.shade500)),
      );
    }

    return ListView.builder(
      itemCount: _filteredFriends.length,
      itemBuilder: (context, index) {
        final user = _filteredFriends[index];
        final isSelected = _selectedUserIds.contains(user.id);
        
        return CheckboxListTile(
          value: isSelected,
          onChanged: (_) => _toggleSelection(user.id),
          title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
          secondary: AvatarWidget(
            imageUrl: user.avatarUrl,
            name: user.displayName,
            size: 48,
          ),
          controlAffinity: ListTileControlAffinity.trailing,
          activeColor: AppColors.primary,
          checkColor: Colors.white,
          checkboxShape: const CircleBorder(),
        );
      },
    );
  }
}
