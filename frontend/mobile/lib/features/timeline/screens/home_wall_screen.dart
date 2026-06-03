import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:vnalo_mobile/features/search/screens/unified_search_screen.dart';
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
    final contactProvider = context.watch<ContactProvider>(); // watch ContactProvider
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
            icon: const Icon(Icons.post_add_outlined, size: 28, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, size: 28, color: Colors.white),
            onPressed: () {},
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
              tabs: [
                Tab(text: common.diaryTab),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Vnalo Video'),
                      const SizedBox(width: 4),
                      Badge(
                        label: Text(common.language == AppLanguage.vi ? 'Mới' : 'New'),
                         backgroundColor: Colors.orange
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: () => postProvider.refreshTimeline(),
                  child: _buildNhatKyView(context, isDarkMode, auth, postProvider, context.watch<ContactProvider>(), displayName),
                ),
                const Center(child: Text('Vnalo Video Content')),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildNhatKyView(BuildContext context, bool isDarkMode, AuthProvider auth, PostProvider postProvider, ContactProvider contactProvider, String displayName) {
    final containerColor = isDarkMode ? DarkColors.surface : Colors.white;
    final common = CommonTexts.of(context);
    final isVi = common.language == AppLanguage.vi;

    return ListView(
      children: [
        // Post Input Area
        Container(
          color: containerColor,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  AvatarWidget(imageUrl: auth.user?.avatarUrl, name: displayName, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      common.postInputPlaceholder,
                      style: TextStyle(
                        color: isDarkMode ? DarkColors.textHint : LightColors.textHint,
                        fontSize: 16
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickAction(Icons.image_outlined, common.photoAction, Colors.green),
                  _buildQuickAction(Icons.videocam_outlined, common.videoAction, Colors.pink),
                  _buildQuickAction(Icons.collections_outlined, common.albumAction, Colors.blue),
                  _buildQuickAction(Icons.text_fields, isVi ? 'Nền chữ' : 'Text background', Colors.blueAccent),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 24h Status Row
        if (postProvider.stories.isNotEmpty || true) // Keep row layout even when empty
        Container(
          height: 120,
          color: containerColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: postProvider.stories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildStoryItem(isDarkMode, auth.user?.avatarUrl, common.createNewStory, isMe: true);
              }
              final story = postProvider.stories[index - 1];
              return _buildStoryItem(isDarkMode, story.mediaUrl, story.authorId, isMe: false);
            },
          ),
        ),

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
          ...postProvider.posts.map((post) => _buildFeedItem(isDarkMode, post)),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildStoryItem(bool isDarkMode, String? url, String name, {bool isMe = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDarkMode ? DarkColors.primary : AppColors.primary,
                    width: 2,
                  ),
                ),
                child: AvatarWidget(imageUrl: url, name: name, size: 60),
              ),
              if (isMe)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDarkMode ? DarkColors.primary : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam, color: Colors.white, size: 16),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(width: 70, child: Text(name, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildFeedItem(bool isDarkMode, dynamic post) {
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
      final user = contactProvider.getUserById(post.authorId);
      if (user != null) {
        authorName = user.displayName;
        authorAvatar = user.avatarUrl;
      }
    }

    // Determine if post has video
    final bool hasVideo = post.mediaUrls.isNotEmpty &&
        (() {
          final url = (post.mediaUrls[0] as String).toLowerCase();
          return url.endsWith('.mp4') || url.endsWith('.mov') || url.endsWith('.webm') || url.contains('type=video');
        })();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardColor,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(imageUrl: post.author.avatarUrl, name: post.author.displayName, size: 48),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.author.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(timeStr, style: TextStyle(color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Icon(Icons.more_horiz, color: isDarkMode ? DarkColors.textHint : AppColors.iconSubtle),
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
              child: Builder(
                builder: (context) {
                  final token = context.read<AuthProvider>().accessToken;
                  final resolvedUrl = AvatarResolver.resolveUrl(post.mediaUrls[0]) ?? post.mediaUrls[0];
                  return CachedNetworkImage(
                    imageUrl: resolvedUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    httpHeaders: token != null && AvatarResolver.isInternalUrl(resolvedUrl)
                        ? {'Authorization': 'Bearer $token'}
                        : const {},
                    placeholder: (_, __) => Container(
                      height: 180,
                      width: double.infinity,
                      color: isDarkMode ? DarkColors.surface : LightColors.surface,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 180,
                      width: double.infinity,
                      color: isDarkMode ? DarkColors.surface : LightColors.surface,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: isDarkMode ? DarkColors.textHint : LightColors.textHint,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.favorite_border, size: 24, color: isDarkMode ? DarkColors.textHint : AppColors.iconSubtle),
              const SizedBox(width: 4),
              Text('${post.likeCount}', style: TextStyle(color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary)),
              const SizedBox(width: 24),
              Icon(Icons.chat_bubble_outline, size: 24, color: isDarkMode ? DarkColors.textHint : AppColors.iconSubtle),
              const SizedBox(width: 4),
              Text('${post.commentCount}', style: TextStyle(color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}




