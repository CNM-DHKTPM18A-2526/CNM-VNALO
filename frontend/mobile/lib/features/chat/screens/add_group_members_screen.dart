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
  List<User> _filteredFriends = [];
  final Set<String> _selectedUserIds = {};
  bool _isLoading = true;

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
      // Filter out people already in conversation
      final existingMemberIds = widget.conversation.members.map((m) => m.userId).toSet();
      final availableFriends = friends.where((f) => !existingMemberIds.contains(f.id)).toList();
      
      if (mounted) {
        setState(() {
          _friends = availableFriends;
          _filteredFriends = availableFriends;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _friends;
      } else {
        _filteredFriends = _friends.where((f) {
          final q = query.toLowerCase();
          return f.displayName.toLowerCase().contains(q) || (f.phone?.contains(q) ?? false);
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

  Future<void> _addMembers() async {
    if (_selectedUserIds.isEmpty) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await context.read<ChatProvider>().addMembersToGroup(
        widget.conversation.id,
        _selectedUserIds.toList(),
      );

      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context); // Close screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm thành viên vào nhóm')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi thêm thành viên: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thêm thành viên', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Đã chọn: ${_selectedUserIds.length}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          if (_selectedUserIds.isNotEmpty)
            TextButton(
              onPressed: _addMembers,
              child: const Text('THÊM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDarkMode ? null : AppColors.appBarGradient,
            color: isDarkMode ? DarkColors.appBarBg : null,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: isDarkMode ? DarkColors.surface : Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm bạn bè',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFriends.isEmpty
                    ? const Center(child: Text('Không có bạn bè khả dụng'))
                    : ListView.builder(
                        itemCount: _filteredFriends.length,
                        itemBuilder: (context, index) {
                          final user = _filteredFriends[index];
                          final isSelected = _selectedUserIds.contains(user.id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(user.id),
                            title: Text(user.displayName),
                            secondary: AvatarWidget(
                              imageUrl: user.avatarUrl,
                              name: user.displayName,
                              size: 40,
                            ),
                            controlAffinity: ListTileControlAffinity.trailing,
                            activeColor: AppColors.primary,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
