import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/group_board_screen.dart';
import 'package:vnalo_mobile/features/chat/widgets/pinned_message_bar.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';

class NoteDetailScreen extends StatelessWidget {
  final Message message;
  final Conversation conversation;

  const NoteDetailScreen({
    super.key,
    required this.message,
    required this.conversation,
  });

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds} giây trước';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? DarkColors.scaffold : Colors.white;
    final textColor = isDark ? DarkColors.textPrimary : LightColors.textPrimary;
    final chatProvider = context.read<ChatProvider>();
    final currentUserId = context.read<AuthProvider>().user?.id;

    // Parse note content
    Map<String, dynamic>? noteData;
    try {
      noteData = jsonDecode(message.content ?? '{}') as Map<String, dynamic>;
    } catch (_) {}
    final noteContent = (noteData?['content'] as String?) ?? message.content ?? '';

    // Resolve sender
    final member = conversation.members.where((m) => m.userId == message.senderId).firstOrNull;
    final senderName = message.senderId == currentUserId
        ? 'Bạn'
        : (member?.nickname ?? member?.user?.displayName ?? message.senderName ?? 'Thành viên');
    final avatarUrl = member?.user?.avatarUrl;
    final timeAgo = _formatTimeAgo(message.createdAt);
    final groupName = conversation.title ?? 'Nhóm';

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? DarkColors.textPrimary : LightColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chi tiết ghi chú',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: isDark ? DarkColors.textPrimary : LightColors.textPrimary,
              ),
            ),
            Text(
              groupName,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: scaffoldBg,
        foregroundColor: isDark ? DarkColors.textPrimary : LightColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: isDark ? DarkColors.textPrimary : LightColors.textPrimary,
            ),
            onPressed: () => _showOptionsSheet(context, chatProvider, currentUserId, noteContent),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
          // ── Header row: avatar + name + time + "Bảng tin nhóm" button ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                SizedBox(
                  width: 42,
                  height: 42,
                  child: ClipOval(
                    child: AvatarWidget(
                      imageUrl: avatarUrl,
                      name: senderName,
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                // "Bảng tin nhóm" button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => GroupBoardScreen(
                        conversation: conversation,
                        initialTabIndex: 2, // Notes tab
                      ),
                    ));
                  },
                  icon: Icon(Icons.dashboard_outlined, size: 16, color: AppColors.primary),
                  label: Text(
                    'Bảng tin nhóm',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
          // ── Note content ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Text(
                noteContent,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  height: 1.55,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsSheet(
    BuildContext context,
    ChatProvider chatProvider,
    String? currentUserId,
    String noteContent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMyNote = message.senderId == currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? DarkColors.surface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.push_pin_outlined, color: AppColors.primary),
              title: const Text('Ghim ghi chú', style: TextStyle(fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
                final pins = chatProvider.getPinnedMessagesForConversation(conversation.id);
                if (pins.length >= 3) {
                  PinnedMessageBar.showPinLimitDialog(context, message);
                } else {
                  chatProvider.pinMessageInConversation(message.id, conversation.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã ghim ghi chú lên đầu trò chuyện'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            if (isMyNote)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Xóa ghi chú',
                    style: TextStyle(fontSize: 15, color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context); // close sheet
                  chatProvider.recallMessage(message.id, conversation.id);
                  Navigator.of(context).pop(); // close detail screen
                },
              ),
            ListTile(
              leading: Icon(Icons.copy_outlined,
                  color: isDark ? Colors.white70 : Colors.grey.shade700),
              title: const Text('Sao chép nội dung', style: TextStyle(fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
                // Flutter clipboard
                debugPrint('[NoteDetail] Copy: $noteContent');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép nội dung'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
