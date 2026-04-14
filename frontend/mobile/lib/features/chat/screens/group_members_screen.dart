import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';

class GroupMembersScreen extends StatelessWidget {
  final Conversation conversation;
  final bool selectionMode;

  const GroupMembersScreen({
    super.key, 
    required this.conversation,
    this.selectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final conv = provider.conversations.firstWhere(
      (c) => c.id == conversation.id, 
      orElse: () => conversation
    );
    final currentUserId = context.watch<AuthProvider>().user?.id ?? '';
    final isOwnerOrAdmin = conv.members.any((m) => 
      m.userId == currentUserId && (m.role == MemberRole.OWNER || m.role == MemberRole.ADMIN)
    );
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Sort members: OWNER first, then ADMIN, then by name
    final sortedMembers = List<ConversationMember>.from(conv.members)
      ..sort((a, b) {
        if (a.role == MemberRole.OWNER) return -1;
        if (b.role == MemberRole.OWNER) return 1;
        if (a.role == MemberRole.ADMIN) return -1;
        if (b.role == MemberRole.ADMIN) return 1;
        return (a.user?.displayName ?? '').compareTo(b.user?.displayName ?? '');
      });

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: Text('Thành viên (${conv.members.length})', 
          style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDarkMode ? null : AppColors.appBarGradient,
            color: isDarkMode ? DarkColors.appBarBg : null,
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: sortedMembers.length,
        itemBuilder: (context, index) {
          final member = sortedMembers[index];
          final isSelf = member.userId == currentUserId;
          
          return Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: AvatarWidget(
                    imageUrl: member.user?.avatarUrl,
                    name: member.user?.displayName ?? member.nickname ?? 'User',
                    size: 44,
                  ),
                  title: Text(
                    isSelf ? '${member.user?.displayName ?? 'Bạn'} (Bạn)' : (member.user?.displayName ?? 'Người dùng'),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(_getRoleLabel(member.role), 
                    style: TextStyle(color: _getRoleColor(member.role), fontSize: 12, fontWeight: FontWeight.bold)),
                  trailing: selectionMode
                    ? (isSelf || member.role == MemberRole.OWNER ? null : const Icon(Icons.chevron_right))
                    : isOwnerOrAdmin && !isSelf && member.role != MemberRole.OWNER
                      ? IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () => _showMemberActions(context, conv, member),
                        )
                      : null,
                  onTap: selectionMode && !isSelf && member.role != MemberRole.OWNER
                    ? () => _confirmTransferOwnership(context, conv, member)
                    : null,
                ),
                if (index < sortedMembers.length - 1)
                  const Divider(height: 1, thickness: 0.5, indent: 72),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getRoleLabel(MemberRole role) {
    switch (role) {
      case MemberRole.OWNER: return 'Trưởng nhóm';
      case MemberRole.ADMIN: return 'Phó nhóm';
      case MemberRole.MEMBER: return 'Thành viên';
    }
  }

  Color _getRoleColor(MemberRole role) {
    switch (role) {
      case MemberRole.OWNER: return Colors.orange.shade800;
      case MemberRole.ADMIN: return Colors.blue.shade700;
      case MemberRole.MEMBER: return Colors.grey;
    }
  }

  void _showMemberActions(BuildContext context, Conversation conv, ConversationMember member) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Quản lý ${member.user?.displayName ?? 'thành viên'}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _confirmRemoveMember(context, conv, member);
            },
            isDestructiveAction: true,
            child: const Text('Mời ra khỏi nhóm'),
          ),
          if (member.role == MemberRole.MEMBER)
            CupertinoActionSheetAction(
              onPressed: () {
                 Navigator.pop(context);
                 context.read<ChatProvider>().updateMemberRole(conv.id, member.userId, 'ADMIN');
              },
              child: const Text('Bổ nhiệm làm Phó nhóm'),
            )
          else if (member.role == MemberRole.ADMIN)
            CupertinoActionSheetAction(
              onPressed: () {
                 Navigator.pop(context);
                 context.read<ChatProvider>().updateMemberRole(conv.id, member.userId, 'MEMBER');
              },
              child: const Text('Gỡ vai trò Phó nhóm'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
               Navigator.pop(context);
               context.read<ChatProvider>().updateMemberRole(conv.id, member.userId, 'OWNER');
            },
            child: const Text('Chuyển quyền Trưởng nhóm'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  void _confirmRemoveMember(BuildContext context, Conversation conv, ConversationMember member) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Mời ra khỏi nhóm?'),
        content: Text('Bạn có chắc chắn muốn mời ${member.user?.displayName ?? 'thành viên này'} ra khỏi nhóm?'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          CupertinoDialogAction(
            onPressed: () {
              context.read<ChatProvider>().removeMember(conv.id, member.userId);
              Navigator.pop(context);
            },
            isDestructiveAction: true,
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
  }
  void _confirmTransferOwnership(BuildContext context, Conversation conv, ConversationMember member) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Chuyển quyền Trưởng nhóm?'),
        content: Text('Bạn có chắc chắn muốn chuyển quyền Trưởng nhóm cho ${member.user?.displayName ?? 'thành viên này'}?\n\nSau khi chuyển, bạn sẽ trở thành thành viên bình thường.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              context.read<ChatProvider>().transferOwnership(conv.id, member.userId);
              Navigator.pop(context); // Close screen
            },
            isDestructiveAction: true,
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
  }
}
