import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/features/contacts/screens/add_friend_screen.dart';
import 'package:vnalo_mobile/features/contacts/screens/friend_requests_screen.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/friend_service.dart';
import 'package:vnalo_mobile/features/chat/screens/create_group_screen.dart';
import 'package:vnalo_mobile/features/search/screens/unified_search_screen.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/features/contacts/providers/contact_provider.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<ContactProvider>();
        provider.fetchFriends();
        provider.fetchPendingRequestCount();
      }
    });
  }

  Future<void> _openChat(User user) async {
    try {
      final conversation = await context.read<ChatService>().getOrCreateDirect(user.id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            conversation: conversation,
            friendUser: user,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        final common = CommonTexts.of(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${common.cannotOpenChat}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: isDarkMode ? appBarBg : Colors.transparent,
          elevation: 0,
          forceMaterialTransparency: !isDarkMode,
          flexibleSpace: isDarkMode
              ? null
              : Container(
                  decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
                ),
          title: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UnifiedSearchScreen()),
              );
            },
            child: Row(
              children: [
                const Icon(Icons.search, size: 24, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  CommonTexts.of(context).search,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_outlined, color: Colors.white),
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
              color: isDarkMode ? DarkColors.surface : Colors.white,
              child: TabBar(
                dividerColor: Colors.transparent,
                labelColor: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                unselectedLabelColor: isDarkMode ? DarkColors.textSecondary : Colors.grey.shade400,
                indicatorColor: isDarkMode ? DarkColors.primary : AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                tabs: [
                  Tab(text: CommonTexts.of(context).friends),
                  Tab(text: CommonTexts.of(context).groups),
                  Tab(text: CommonTexts.of(context).officialAccount),
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
    return Consumer<ContactProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.friends.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final friends = provider.friends;
        final Map<String, List<User>> grouped = {};
        for (var user in friends) {
          final String firstLetter = user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '#';
          final letter = RegExp(r'[A-Z]').hasMatch(firstLetter) ? firstLetter : '#';
          if (!grouped.containsKey(letter)) {
            grouped[letter] = [];
          }
          grouped[letter]!.add(user);
        }

        final sortedKeys = grouped.keys.toList()..sort();
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDarkMode ? DarkColors.scaffold : LightColors.scaffold;
        final sectionColor = isDarkMode ? DarkColors.surface : Colors.white;

        return RefreshIndicator(
          onRefresh: () => provider.fetchFriends(),
          child: Container(
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
                            color: (isDarkMode ? DarkColors.primary : AppColors.primary).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.person_add_outlined, color: isDarkMode ? DarkColors.primary : AppColors.primary),
                        ),
                        title: Text(
                          CommonTexts.of(context).friendRequests,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                        ),
                        trailing: provider.pendingRequestCount > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${provider.pendingRequestCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              )
                            : null,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const FriendRequestsScreen()),
                          );
                          provider.onFriendshipUpdated();
                        },
                      ),
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (isDarkMode ? DarkColors.primary : AppColors.primary).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.cake, color: isDarkMode ? DarkColors.primary : AppColors.primary),
                        ),
                        title: Text(
                          CommonTexts.of(context).birthday,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                        ),
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
                            _buildFilterChip('${CommonTexts.of(context).filterAll} ${friends.length}', true),
                            const SizedBox(width: 8),
                            _buildFilterChip(CommonTexts.of(context).recentlyActive, false),
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
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                  onTap: () => _openChat(user),
                                )),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, bool isActive) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? (isDarkMode ? const Color(0xFF333333) : const Color(0xFFE5E7EB)) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: isActive ? null : Border.all(color: Colors.grey.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? (isDarkMode ? Colors.white : Colors.black87) : Colors.grey,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildGroupsTab(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final sectionColor = isDarkMode ? DarkColors.surface : Colors.white;
    final bgColor = isDarkMode ? DarkColors.scaffold : LightColors.scaffold;

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
                  color: (isDarkMode ? DarkColors.primary : AppColors.primary).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.group_add, color: isDarkMode ? DarkColors.primary : AppColors.primary),
              ),
              title: Text(CommonTexts.of(context).createNewGroup, style: TextStyle(color: isDarkMode ? DarkColors.primary : AppColors.primary, fontWeight: FontWeight.normal)),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                );
              },
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
                      Text(CommonTexts.of(context).joinedGroups(groups.length), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          const Icon(Icons.swap_vert, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(CommonTexts.of(context).sort, style: const TextStyle(color: Colors.grey)),
                        ],
                      )
                    ],
                  ),
                ),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(CommonTexts.of(context).noGroupsJoined, style: const TextStyle(color: Colors.grey)),
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
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(conversation: group),
                          ),
                        );
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
    final sectionColor = isDarkMode ? DarkColors.surface : Colors.white;
    final bgColor = isDarkMode ? DarkColors.scaffold : LightColors.scaffold;
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
              title: Text(CommonTexts.of(context).findMoreOA),
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
                  child: Text(CommonTexts.of(context).followedOA(0), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(CommonTexts.of(context).noOAFollowed, style: const TextStyle(color: Colors.grey)),
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
