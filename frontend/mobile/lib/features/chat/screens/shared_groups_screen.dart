import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';

class SharedGroupsScreen extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;

  const SharedGroupsScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  State<SharedGroupsScreen> createState() => _SharedGroupsScreenState();
}

class _SharedGroupsScreenState extends State<SharedGroupsScreen> {
  List<Conversation> _sharedGroups = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSharedGroups();
  }

  Future<void> _loadSharedGroups() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final chatProvider = context.read<ChatProvider>();
      final myUserId = context.read<AuthProvider>().currentUser?.id ?? '';

      // Get all conversations from the provider (already loaded in inbox)
      final allConversations = chatProvider.conversations;

      // Filter to GROUP conversations that both users are members of
      final shared = allConversations.where((conv) {
        if (conv.type != ConversationType.GROUP) return false;
        final hasMe = conv.members.any((m) => m.userId == myUserId);
        final hasTarget = conv.members.any((m) => m.userId == widget.targetUserId);
        return hasMe && hasTarget;
      }).toList();

      // Sort by last message time
      shared.sort((a, b) {
        final aTime = a.lastMessage?.createdAt ?? DateTime(1970);
        final bTime = b.lastMessage?.createdAt ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _sharedGroups = shared;
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);
    final bgColor = isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        elevation: 0,
        forceMaterialTransparency: !isDarkMode,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.white),
        title: Text(
          common.sharedGroupsWith(widget.targetUserName),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(isDarkMode)
              : _sharedGroups.isEmpty
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
            onPressed: _loadSharedGroups,
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
          Icon(Icons.group_off, size: 64, color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(common.noSharedGroups, style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white54 : Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildGroupList(bool isDarkMode) {
    return RefreshIndicator(
      onRefresh: _loadSharedGroups,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _sharedGroups.length,
        itemBuilder: (context, index) {
          final group = _sharedGroups[index];
          return _GroupListItem(
            conversation: group,
            isDarkMode: isDarkMode,
            onTap: () => _openGroup(group),
          );
        },
      ),
    );
  }

  void _openGroup(Conversation group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(conversation: group),
      ),
    );
  }
}

class _GroupListItem extends StatelessWidget {
  final Conversation conversation;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _GroupListItem({
    required this.conversation,
    required this.isDarkMode,
    required this.onTap,
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
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AvatarWidget(
                  imageUrl: conversation.avatarUrl,
                  name: conversation.title ?? 'Nhóm',
                  size: 48,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.title ?? 'Nhóm',
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
                        '${conversation.members.length} thành viên',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? DarkColors.textSecondary : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDarkMode ? DarkColors.textHint : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
