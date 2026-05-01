import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/friend_service.dart';

class AddGroupMembersScreen extends StatefulWidget {
  final Conversation conversation;

  const AddGroupMembersScreen({super.key, required this.conversation});

  @override
  State<AddGroupMembersScreen> createState() => _AddGroupMembersScreenState();
}

class _AddGroupMembersScreenState extends State<AddGroupMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<User> _friends = [];
  Map<String, List<User>> _groupedFriends = {};
  List<User> _selectedUsers = [];
  bool _isLoading = true;
  bool _seeRecentHistory = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await context.read<FriendService>().getFriends();
      // Filter out people who are ALREADY ACTIVE in conversation
      final activeMemberIds = widget.conversation.members
          .where((m) => m.leftAt == null)
          .map((m) => m.userId).toSet();
      final availableFriends = friends.where((f) => !activeMemberIds.contains(f.id)).toList();
      
      if (mounted) {
        setState(() {
          _friends = availableFriends;
          _groupFriends(availableFriends);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _groupFriends(List<User> friends) {
    // Sort friends by display name
    friends.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    
    final grouped = <String, List<User>>{};
    for (final friend in friends) {
      final firstLetter = friend.displayName.isNotEmpty 
          ? friend.displayName[0].toUpperCase()
          : '#';
      if (!grouped.containsKey(firstLetter)) {
        grouped[firstLetter] = [];
      }
      grouped[firstLetter]!.add(friend);
    }
    
    _groupedFriends = Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _groupFriends(_friends);
      } else {
        final filtered = _friends.where((f) {
          final q = query.toLowerCase();
          return f.displayName.toLowerCase().contains(q) || (f.phone?.contains(q) ?? false);
        }).toList();
        _groupFriends(filtered);
      }
    });
  }

  void _toggleSelection(User user) {
    setState(() {
      final index = _selectedUsers.indexWhere((u) => u.id == user.id);
      if (index >= 0) {
        _selectedUsers.removeAt(index);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  Future<void> _addMembers() async {
    if (_selectedUsers.isEmpty) return;

    // Fire and forget (Optimistic UI)
    context.read<ChatProvider>().addMembersToGroup(
      widget.conversation.id,
      _selectedUsers,
    );

    if (mounted) {
      Navigator.pop(context); // Close screen immediately
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang thêm thành viên vào nhóm...')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        forceMaterialTransparency: !isDarkMode,
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: isDarkMode 
          ? null 
          : Container(decoration: const BoxDecoration(gradient: AppColors.appBarGradient)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             const Text('Thêm vào nhóm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
             Text('Đã chọn: ${_selectedUsers.length}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDarkMode ? DarkColors.surface : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Tìm tên hoặc số điện thoại',
                      prefixIcon: Icon(Icons.search, size: 20, color: isDarkMode ? DarkColors.textHint : LightColors.textHint),
                      filled: true,
                      fillColor: isDarkMode ? DarkColors.scaffold : Colors.grey.shade100,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      hintStyle: TextStyle(color: isDarkMode ? DarkColors.textHint : LightColors.textHint),
                    ),
                    style: TextStyle(color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: isDarkMode ? DarkColors.surface : Colors.white,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDarkMode ? DarkColors.primary : AppColors.primary).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.link, color: isDarkMode ? DarkColors.primary : AppColors.primary, size: 24),
              ),
              title: const Text('Mời vào nhóm bằng link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              onTap: () {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Tính năng mời bằng link đang được phát triển')),
                 );
              },
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _friends.isEmpty
                    ? const Center(child: Text('Không có bạn bè khả dụng'))
                    : ListView(
                        children: _groupedFriends.entries.expand((entry) {
                          return [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              color: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
                              width: double.infinity,
                              child: Text(entry.key, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary)),
                            ),
                            ...entry.value.map((user) {
                              final isSelected = _selectedUsers.any((u) => u.id == user.id);
                              return Container(
                                color: isDarkMode ? DarkColors.surface : Colors.white,
                                child: InkWell(
                                  onTap: () => _toggleSelection(user),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Row(
                                      children: [
                                        AvatarWidget(imageUrl: user.avatarUrl, name: user.displayName, size: 48),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(user.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                        ),
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: isSelected ? null : Border.all(color: isDarkMode ? DarkColors.divider : AppColors.itemDivider, width: 1.5),
                                            color: isSelected ? (isDarkMode ? DarkColors.primary : AppColors.primary) : Colors.transparent,
                                          ),
                                          child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ];
                        }).toList(),
                      ),
          ),
          if (_selectedUsers.isNotEmpty)
            Container(
            decoration: BoxDecoration(
                color: isDarkMode ? DarkColors.surface : Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.05), blurRadius: 4, offset: const Offset(0, -2))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedUsers.length,
                            itemBuilder: (context, index) {
                              final user = _selectedUsers[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AvatarWidget(imageUrl: user.avatarUrl, name: user.displayName, size: 50),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _toggleSelection(user),
                                        child: Container(
                                          decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 16, left: 8),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: FloatingActionButton(
                              onPressed: _addMembers,
                              backgroundColor: Colors.blue,
                              elevation: 2,
                              child: const Icon(Icons.arrow_forward, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                    const Divider(height: 1, thickness: 0.5, color: AppColors.itemDivider),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Thành viên mới xem được tin gửi gần đây', style: TextStyle(fontSize: 14))),
                        Switch.adaptive(
                          value: _seeRecentHistory,
                          onChanged: (v) => setState(() => _seeRecentHistory = v),
                          activeColor: isDarkMode ? DarkColors.primary : AppColors.primary,
                        ),
                      ],
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
