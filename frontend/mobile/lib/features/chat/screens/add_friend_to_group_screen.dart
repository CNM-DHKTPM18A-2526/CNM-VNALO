import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/friend_service.dart';

class AddFriendToGroupScreen extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;

  const AddFriendToGroupScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  State<AddFriendToGroupScreen> createState() => _AddFriendToGroupScreenState();
}

class _AddFriendToGroupScreenState extends State<AddFriendToGroupScreen> {
  List<_GroupItem> _groups = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final chatProvider = context.read<ChatProvider>();
      final myUserId = context.read<AuthProvider>().user?.id ?? '';

      // Get all group conversations where I am a member
      final allConversations = chatProvider.conversations;

      // Filter: GROUP conversations I'm in, but target user is NOT in
      final eligible = <_GroupItem>[];

      for (final conv in allConversations) {
        if (conv.type != ConversationType.GROUP) continue;

        final hasMe = conv.members.any((m) => m.userId == myUserId);
        final hasTarget = conv.members.any((m) => m.userId == widget.targetUserId);

        // Only include groups I'm in but they are not
        if (hasMe && !hasTarget) {
          eligible.add(_GroupItem(conversation: conv, isAdding: false, isLoading: false));
        }
      }

      // Sort by last message time
      eligible.sort((a, b) {
        final aTime = a.conversation.lastMessage?.createdAt ?? DateTime(1970);
        final bTime = b.conversation.lastMessage?.createdAt ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _groups = eligible;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addToGroup(_GroupItem item) async {
    // Find index and set loading
    final idx = _groups.indexWhere((g) => g.conversation.id == item.conversation.id);
    if (idx < 0) return;

    setState(() {
      _groups[idx] = item.copyWith(isLoading: true);
    });

    try {
      // Need to fetch the user object to pass to addMembersToGroup
      final friendService = context.read<FriendService>();
      User? targetUser;
      try {
        final friends = await friendService.getFriends();
        targetUser = friends.firstWhere((u) => u.id == widget.targetUserId);
      } catch (_) {
        targetUser = User(id: widget.targetUserId, displayName: widget.targetUserName);
      }

      await context.read<ChatProvider>().addMembersToGroup(
        item.conversation.id,
        [targetUser!],
      );

      if (mounted) {
        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm ${widget.targetUserName} vào nhóm'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Remove from list since they're now added
        setState(() {
          _groups.removeAt(idx);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi thêm: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );

        // Reset loading state
        final currentIdx = _groups.indexWhere((g) => g.conversation.id == item.conversation.id);
        if (currentIdx >= 0) {
          setState(() {
            _groups[currentIdx] = _groups[currentIdx].copyWith(isLoading: false);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);
    final bgColor = isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDarkMode ? DarkColors.appBarBg : AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          common.addToGroupTitle(widget.targetUserName),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(isDarkMode)
              : _groups.isEmpty
                  ? _buildEmptyState(isDarkMode, common)
                  : _buildGroupList(isDarkMode),
    );
  }

  Widget _buildErrorState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Không thể tải dữ liệu', style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white54 : Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(_error ?? '', style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white38 : Colors.grey.shade500), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadGroups,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? Colors.white12 : Colors.grey.shade200,
              foregroundColor: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, CommonTexts common) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_add_outlined, size: 64, color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(common.noGroupsToAdd(widget.targetUserName), style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white54 : Colors.grey.shade600)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Bạn không có nhóm nào để thêm ${widget.targetUserName}',
              style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white38 : Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList(bool isDarkMode) {
    return RefreshIndicator(
      onRefresh: _loadGroups,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _groups.length,
        itemBuilder: (context, index) {
          final item = _groups[index];
          return _GroupItemWidget(
            item: item,
            isDarkMode: isDarkMode,
            onAdd: () => _addToGroup(item),
          );
        },
      ),
    );
  }
}

class _GroupItem {
  final Conversation conversation;
  final bool isAdding;
  final bool isLoading;

  const _GroupItem({
    required this.conversation,
    required this.isAdding,
    required this.isLoading,
  });

  _GroupItem copyWith({Conversation? conversation, bool? isAdding, bool? isLoading}) {
    return _GroupItem(
      conversation: conversation ?? this.conversation,
      isAdding: isAdding ?? this.isAdding,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class _GroupItemWidget extends StatelessWidget {
  final _GroupItem item;
  final bool isDarkMode;
  final VoidCallback onAdd;

  const _GroupItemWidget({
    required this.item,
    required this.isDarkMode,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? DarkColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AvatarWidget(
                imageUrl: item.conversation.avatarUrl,
                name: item.conversation.title ?? 'Nhóm',
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.conversation.title ?? 'Nhóm',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.conversation.members.length} thành viên',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? DarkColors.textSecondary : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.isLoading)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                ElevatedButton(
                  onPressed: onAdd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Thêm', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
