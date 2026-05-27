import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/core/utils/avatar_resolver.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/contacts/providers/contact_provider.dart';
import 'package:vnalo_mobile/features/timeline/providers/post_provider.dart';
import 'package:vnalo_mobile/features/timeline/screens/create_post_screen.dart';
import 'package:vnalo_mobile/features/timeline/screens/story_viewer_screen.dart';
import 'package:vnalo_mobile/features/search/screens/unified_search_screen.dart';
import 'package:vnalo_mobile/features/timeline/screens/create_story_screen.dart';
import 'package:vnalo_mobile/features/timeline/screens/photo_picker_screen.dart';
import 'package:vnalo_mobile/features/timeline/screens/video_picker_screen.dart';
import 'package:vnalo_mobile/features/timeline/screens/text_background_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class HomeWallScreen extends StatefulWidget {
  const HomeWallScreen({super.key});

  @override
  State<HomeWallScreen> createState() => _HomeWallScreenState();
}

class _HomeWallScreenState extends State<HomeWallScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final postProvider = context.read<PostProvider>();
      postProvider.loadStories();
      postProvider.loadTimeline();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final auth = context.watch<AuthProvider>();
    final postProvider = context.watch<PostProvider>();
    final common = CommonTexts.of(context);
    final displayName = auth.user?.displayName ?? common.unknownUser;
    final searchHint = isDarkMode ? DarkColors.textHint : Colors.white.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        backgroundColor: isDarkMode ? appBarBg : Colors.transparent,
        elevation: 0,
        forceMaterialTransparency: !isDarkMode,
        flexibleSpace: isDarkMode
            ? null
            : Container(decoration: BoxDecoration(gradient: AppColors.appBarGradient)),
        title: _buildSearchHeader(context, isDarkMode, searchHint),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 28, color: Colors.white),
            onPressed: () => _openCreatePost(context, PostType.photo),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined, size: 28, color: Colors.white),
                onPressed: () {},
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('1', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: isDarkMode ? DarkColors.surface : Colors.white,
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              labelColor: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
              unselectedLabelColor: isDarkMode ? DarkColors.textSecondary : LightColors.textHint,
              indicatorColor: isDarkMode ? DarkColors.primary : AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              tabs: const [
                Tab(text: 'Quan tâm'),
                Tab(text: 'Khác'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: () => postProvider.refreshTimeline(),
                  child: _buildNhatKyView(context, isDarkMode, auth, postProvider, displayName),
                ),
                const Center(child: Text('Vnalo Video Content')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openCreatePost(BuildContext context, PostType type) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CreatePostScreen(initialType: type)),
    );
  }

  Future<void> _openPhotoPicker(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      
      if (images.isNotEmpty && mounted) {
        final files = images.map((x) => File(x.path)).toList();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CreatePostScreen(
              initialType: PostType.photo,
              initialFiles: files,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[HomeWallScreen] _openPhotoPicker error: $e');
    }
  }

  void _openVideoPicker(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPickerScreen(
          onVideoSelected: (File file) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreatePostScreen(
                  initialType: PostType.video,
                  initialFiles: [file],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openTextBackground(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TextBackgroundScreen(
          onTextCreated: (content) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreatePostScreen(
                  initialType: PostType.textBackground,
                  initialTextContent: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openStoryViewer(BuildContext context, int initialIndex) {
    final postProvider = context.read<PostProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(
          stories: postProvider.stories,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _openCreateStory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
    );
  }

  Widget _buildSearchHeader(BuildContext context, bool isDarkMode, Color searchHint) {
    final common = CommonTexts.of(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const UnifiedSearchScreen(searchTag: 'search_bar_timeline'),
        ),
      ),
      child: Hero(
        tag: 'search_bar_timeline',
        child: Material(
          color: Colors.transparent,
          child: Row(
            children: [
              const Icon(Icons.search, size: 24, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                common.search,
                style: TextStyle(
                  color: searchHint,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNhatKyView(BuildContext context, bool isDarkMode, AuthProvider auth, PostProvider postProvider, String displayName) {
    final containerColor = isDarkMode ? DarkColors.surface : Colors.white;
    final common = CommonTexts.of(context);
    final isVi = common.language == AppLanguage.vi;

    return ListView(
      children: [
        // Post Input Area
        GestureDetector(
          onTap: () => _openCreatePost(context, PostType.photo),
          child: Container(
            color: containerColor,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    AvatarWidget(imageUrl: auth.user?.avatarUrl, name: displayName, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          common.postInputPlaceholder,
                          style: TextStyle(
                            color: isDarkMode ? DarkColors.textHint : LightColors.textHint,
                            fontSize: 16
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Quick action row (pill/chip style)
                Row(
                  children: [
                    Expanded(child: _buildQuickAction(Icons.image_outlined, 'Ảnh', const Color(0xFF4CAF50), () => _openPhotoPicker(context))),
                    const SizedBox(width: 6),
                    Expanded(child: _buildQuickAction(Icons.videocam_outlined, 'Video', const Color(0xFFE91E8C), () => _openVideoPicker(context))),
                    const SizedBox(width: 6),
                    Expanded(child: _buildQuickAction(Icons.collections_outlined, 'Album', const Color(0xFF2196F3), () => _openCreatePost(context, PostType.album))),
                    const SizedBox(width: 6),
                    Expanded(child: _buildQuickAction(Icons.text_fields, 'Nền chữ', const Color(0xFF5C6BC0), () => _openTextBackground(context))),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Story Row (card style)
        Container(
          color: containerColor,
          height: 200,
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: postProvider.stories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: () => _openCreateStory(context),
                  child: _buildStoryCard(
                    isDarkMode,
                    imageUrl: auth.user?.avatarUrl,
                    name: 'Tạo mới',
                    isMe: true,
                  ),
                );
              }
              final story = postProvider.stories[index - 1];
              final contactProvider = context.read<ContactProvider>();
              
              String authorName = story.authorId;
              String? authorAvatar;

              if (story.authorId == auth.user?.id) {
                authorName = auth.user?.displayName ?? story.authorId;
                authorAvatar = auth.user?.avatarUrl;
              } else {
                try {
                  final friend = contactProvider.friends.firstWhere((u) => u.id == story.authorId);
                  authorName = friend.displayName;
                  authorAvatar = friend.avatarUrl;
                } catch (e) {
                  // Fallback
                }
              }

              return GestureDetector(
                onTap: () => _openStoryViewer(context, index - 1),
                child: _buildStoryCard(
                  isDarkMode,
                  imageUrl: authorAvatar,
                  name: authorName,
                  isMe: false,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Feed Items
        if (postProvider.isLoading && postProvider.posts.isEmpty)
           const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (postProvider.posts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                Icon(Icons.feed_outlined, size: 80, color: isDarkMode ? Colors.white12 : Colors.grey.shade200),
                const SizedBox(height: 16),
                Text(
                  isVi ? 'Chưa có kỷ niệm nào được chia sẻ.' : 'No memories shared yet.',
                  style: TextStyle(
                    color: isDarkMode ? DarkColors.textHint : LightColors.textHint,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          )
        else
          ...postProvider.posts.map((post) => _buildFeedItem(context, isDarkMode, post)),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCard(bool isDarkMode, {String? imageUrl, required String name, bool isMe = false}) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dark gradient overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: isMe ? 0.55 : 0.5),
                ],
                stops: const [0.45, 1.0],
              ),
            ),
          ),

          // "Tạo mới" button (blue circle + camera)
          if (isMe)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
                ),
              ),
            ),

          // Story user avatar (small, bottom left)
          if (!isMe)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: ClipOval(
                  child: imageUrl != null
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : Container(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                          child: Icon(Icons.person, size: 18,
                              color: isDarkMode ? Colors.white38 : Colors.grey.shade500),
                        ),
                ),
              ),
            ),

          // Name at bottom
          Positioned(
            bottom: 8,
            left: 6,
            right: 6,
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedItem(BuildContext context, bool isDarkMode, dynamic post) {
    final cardColor = isDarkMode ? DarkColors.surface : Colors.white;
    final timeStr = DateFormat('HH:mm').format(post.createdAt);
    final postProvider = context.read<PostProvider>();
    final auth = context.read<AuthProvider>();
    final contactProvider = context.read<ContactProvider>();

    String authorName = post.authorId;
    String? authorAvatar;

    if (post.authorId == auth.user?.id) {
      authorName = auth.user?.displayName ?? post.authorId;
      authorAvatar = auth.user?.avatarUrl;
    } else {
      try {
        final friend = contactProvider.friends.firstWhere((u) => u.id == post.authorId);
        authorName = friend.displayName;
        authorAvatar = friend.avatarUrl;
      } catch (e) {
        // Fallback to ID if friend not found
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(imageUrl: authorAvatar, name: authorName, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(timeStr, style: TextStyle(color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: isDarkMode ? DarkColors.textHint : AppColors.iconSubtle),
                onSelected: (value) {
                  if (value == 'delete' && post.authorId == context.read<AuthProvider>().user?.id) {
                    _confirmDeletePost(context, post.id, postProvider);
                  }
                },
                itemBuilder: (context) => [
                  if (post.authorId == context.read<AuthProvider>().user?.id)
                    const PopupMenuItem(value: 'delete', child: Text('Xóa bài viết')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(post.content,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
            ),
          ),
          if (post.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                AvatarResolver.resolveUrl(post.mediaUrls[0]) ?? post.mediaUrls[0],
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () => postProvider.toggleLike(post.id),
                child: Row(
                  children: [
                    Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 24,
                      color: post.isLiked ? Colors.red : (isDarkMode ? DarkColors.textHint : AppColors.iconSubtle),
                    ),
                    const SizedBox(width: 4),
                    Text('${post.likeCount}', style: TextStyle(color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () => _openComments(context, post.id),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 24, color: isDarkMode ? DarkColors.textHint : AppColors.iconSubtle),
                    const SizedBox(width: 4),
                    Text('${post.commentCount}', style: TextStyle(color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openComments(BuildContext context, String postId) {
    // TODO: Navigate to comments screen
  }

  void _confirmDeletePost(BuildContext context, String postId, PostProvider postProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bài viết'),
        content: const Text('Bạn có chắc muốn xóa bài viết này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              postProvider.deletePost(postId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
