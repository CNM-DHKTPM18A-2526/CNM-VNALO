import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/contacts/screens/add_friend_screen.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/friend_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<User> _friends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      _friends = await context.read<FriendService>().getFriends();
    } catch (_) {
      _friends = [];
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final searchHint = isDarkMode ? DarkColors.textHint : Colors.white.withValues(alpha: 0.8);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: appBarBg,
          elevation: 0,
          flexibleSpace: isDarkMode
              ? null
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0068FF), Color(0xFF00A2ED)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
          title: Row(
            children: [
              Icon(Icons.search, size: 24, color: searchHint),
              const SizedBox(width: 8),
              Text(
                'Tìm kiếm',
                style: TextStyle(color: searchHint, fontSize: 16, fontWeight: FontWeight.w400),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.person_add_outlined, color: searchHint),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddFriendScreen()),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
              child: TabBar(
                dividerColor: Colors.transparent,
                labelColor: isDarkMode ? Colors.white : Colors.black,
                unselectedLabelColor: const Color(0xFF9CA3AF),
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                tabs: const [
                  Tab(text: 'Bạn bè'),
                  Tab(text: 'Nhóm'),
                  Tab(text: 'OA'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildFriendsTab(),
                  _buildGroupsTab(context),
                  _buildOATab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    _friends.sort((a, b) => a.displayName.compareTo(b.displayName));
    
    final Map<String, List<User>> grouped = {};
    for (var user in _friends) {
      final String firstLetter = user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '#';
      final letter = RegExp(r'[A-Z]').hasMatch(firstLetter) ? firstLetter : '#';
      if (!grouped.containsKey(letter)) {
        grouped[letter] = [];
      }
      grouped[letter]!.add(user);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.black : const Color(0xFFF4F5F7);
    final sectionColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      color: bgColor,
      child: ListView(
        children: [
          Container(
            color: sectionColor,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.group_add, color: AppColors.primary),
                  ),
                  title: const Text('Lời mời kết bạn'),
                  onTap: () {},
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cake, color: AppColors.primary),
                  ),
                  title: const Text('Sinh nhật'),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: sectionColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      _buildFilterChip('Tất cả ${_friends.length}', true),
                      const SizedBox(width: 8),
                      _buildFilterChip('Mới truy cập', false),
                    ],
                  ),
                ),
                ...sortedKeys.map((letter) {
                   return Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Padding(
                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                         child: Text(letter, style: const TextStyle(fontWeight: FontWeight.bold)),
                       ),
                       ...grouped[letter]!.map((user) => ListTile(
                         leading: AvatarWidget(
                           imageUrl: user.avatarUrl,
                           name: user.displayName,
                           size: 44,
                           showOnline: user.isOnline,
                         ),
                         title: Text(user.displayName),
                         trailing: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
                             IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () {}),
                           ],
                         ),
                       )),
                     ],
                   );
                }).expand((e) => [e]), // flatten
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isActive) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive 
            ? (isDarkMode ? const Color(0xFF333333) : const Color(0xFFE5E7EB))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: isActive ? null : Border.all(color: Colors.grey.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive 
              ? (isDarkMode ? Colors.white : Colors.black87)
              : Colors.grey,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildGroupsTab(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final sectionColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final bgColor = isDarkMode ? Colors.black : const Color(0xFFF4F5F7);

    final chatProvider = context.watch<ChatProvider>();
    final groups = chatProvider.conversations.where((c) => c.type == ConversationType.GROUP).toList();

    return Container(
      color: bgColor,
      child: ListView(
        children: [
          Container(
            color: sectionColor,
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_add, color: AppColors.primary),
              ),
              title: const Text('Tạo nhóm mới', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.normal)),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: sectionColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Nhóm đang tham gia (${groups.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Row(
                        children: [
                          Icon(Icons.swap_vert, size: 16, color: Colors.grey),
                          SizedBox(width: 4),
                          Text('Sắp xếp', style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    ],
                  ),
                ),
                if (groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text('Bạn chưa tham gia nhóm nào', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ...groups.map((group) {
                    final isOnline = group.members.any((m) => m.user?.isOnline == true && m.userId != chatProvider.activeConversationId);
                    return ListTile(
                      leading: AvatarWidget(
                        imageUrl: group.avatarUrl,
                        name: group.title ?? 'Nhóm',
                        size: 48,
                        showOnline: isOnline,
                      ),
                      title: Text(group.title ?? 'Nhóm', style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(group.lastMessage?.content ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        // TODO: Navigate to group chat
                      },
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOATab(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final sectionColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final bgColor = isDarkMode ? Colors.black : const Color(0xFFF4F5F7);
    return Container(
      color: bgColor,
      child: ListView(
        children: [
          Container(
            color: sectionColor,
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.deepPurpleAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_tethering, color: Colors.white),
              ),
              title: const Text('Tìm thêm Official Account'),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: sectionColor,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Official Account đã quan tâm (0)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text('Bạn chưa quan tâm Official Account nào', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
