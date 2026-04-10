import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/search/screens/unified_search_screen.dart';

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
    final displayName = auth.user?.displayName ?? 'Người dùng';

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        titleSpacing: 0,
        flexibleSpace: isDarkMode
            ? null
            : Container(decoration: const BoxDecoration(gradient: AppColors.appBarGradient)),
        title: _buildSearchHeader(context, isDarkMode),
        actions: [
          IconButton(
            icon: const Icon(Icons.post_add_outlined, size: 28),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, size: 28),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: appBarBg,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
              tabs: const [
                Tab(text: 'Nhật ký'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Zalo Video'),
                      SizedBox(width: 4),
                      Badge(label: Text('Mới'), backgroundColor: Colors.green),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNhatKyView(context, isDarkMode, auth, displayName),
          const Center(child: Text('Zalo Video Content')),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context, bool isDarkMode) {
    final searchHint = isDarkMode ? DarkColors.textHint : Colors.white.withValues(alpha: 0.8);
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UnifiedSearchScreen(searchTag: 'search_bar_timeline')),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 24, color: searchHint),
            const SizedBox(width: 8),
            Text('Tìm kiếm', style: TextStyle(color: searchHint, fontSize: 18, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  Widget _buildNhatKyView(BuildContext context, bool isDarkMode, AuthProvider auth, String displayName) {
    final containerColor = isDarkMode ? DarkColors.surface : Colors.white;

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
                  AvatarWidget(imageUrl: auth.user?.avatarUrl, name: displayName, size: 45),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Hôm nay bạn thế nào?',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickAction(Icons.image_outlined, 'Ảnh', Colors.green),
                  _buildQuickAction(Icons.videocam_outlined, 'Video', Colors.pink),
                  _buildQuickAction(Icons.collections_outlined, 'Album', Colors.blue),
                  _buildQuickAction(Icons.text_fields, 'Nền chữ', Colors.blueAccent),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 24h Status Row
        Container(
          height: 120,
          color: containerColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _buildStoryItem(auth.user?.avatarUrl, 'Tạo mới', isMe: true),
              _buildStoryItem('https://i.pravatar.cc/150?u=1', 'Mads Mikkelsen'),
              _buildStoryItem('https://i.pravatar.cc/150?u=2', 'Hideo Kojima'),
              _buildStoryItem('https://i.pravatar.cc/150?u=3', 'Hoàng Hiếu'),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Feed Items
        _buildFeedItem(
          isDarkMode,
          'Hoàng Hiếu',
          '3 giờ',
          'Tư vấn tuyển sinh',
          'https://images.unsplash.com/photo-1523050853063-bd42da61709e?w=800',
          'https://i.pravatar.cc/150?u=3',
        ),
        _buildFeedItem(
          isDarkMode,
          'VNALO Team',
          'Vừa xong',
          'Chào mừng bạn đến với mạng xã hội VNALO!',
          null,
          'assets/icons/app_icon.png',
        ),
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

  Widget _buildStoryItem(String? url, String name, {bool isMe = false}) {
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
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: AvatarWidget(imageUrl: url, name: name, size: 60),
              ),
              if (isMe)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
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

  Widget _buildFeedItem(bool isDarkMode, String user, String time, String content, String? imageUrl, String avatarUrl) {
    final cardColor = isDarkMode ? DarkColors.surface : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardColor,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(imageUrl: avatarUrl, name: user, size: 40),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.more_horiz, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: const TextStyle(fontSize: 15)),
          if (imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(imageUrl, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.favorite_border, size: 24, color: Colors.grey),
              SizedBox(width: 4),
              Text('0', style: TextStyle(color: Colors.grey)),
              SizedBox(width: 24),
              Icon(Icons.chat_bubble_outline, size: 24, color: Colors.grey),
              SizedBox(width: 4),
              Text('0', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
