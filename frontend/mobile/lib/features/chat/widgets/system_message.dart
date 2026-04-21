import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';

class SystemMessage extends StatelessWidget {
  final String content;
  final DateTime? timestamp;
  final String? conversationId;

  const SystemMessage({
    super.key,
    required this.content,
    this.timestamp,
    this.conversationId,
  });

  String _getFormattedContent(BuildContext context, ChatProvider provider) {
    if (!content.startsWith('{')) return content;

    try {
      final data = Map<String, dynamic>.from(
        json.decode(content) as Map<String, dynamic>,
      );
      final action = data['action'] as String?;
      final actorId = data['actorId'] as String?;
      
      String actorName = 'Một thành viên';
      if (actorId != null) {
        if (actorId == provider.currentUserId) {
          actorName = 'Bạn';
        } else if (conversationId != null) {
          // Try to find in conversation members
          final convIndex = provider.conversations.indexWhere((c) => c.id == conversationId);
          if (convIndex >= 0) {
            final member = provider.conversations[convIndex].members.firstWhere(
              (m) => m.userId == actorId,
              orElse: () => provider.conversations[convIndex].members.firstWhere((m) => m.userId == 'none', 
                orElse: () => throw Exception('Not found')), // dummy fallback
            );
            actorName = member.user?.displayName ?? actorName;
          }
        }
      }

      switch (action) {
        case 'ADD_MEMBERS':
          return '$actorName đã thêm thành viên vào nhóm';
        case 'LEAVE_GROUP':
          return '$actorName đã rời khỏi nhóm';
        case 'CREATE_GROUP':
          return '$actorName đã tạo nhóm';
        case 'RENAME_GROUP':
        case 'UPDATE_GROUP_INFO':
          final newName = (data['metadata'] as Map?)?['newName'];
          if (newName != null) return '$actorName đã đổi tên nhóm thành "$newName"';
          return '$actorName đã cập nhật thông tin nhóm';
        case 'CHANGE_GROUP_AVATAR':
          return '$actorName đã thay đổi ảnh đại diện nhóm';
        case 'PIN_MESSAGE':
          return '$actorName đã ghim một tin nhắn';
        case 'UNPIN_MESSAGE':
          return '$actorName đã bỏ ghim một tin nhắn';
        case 'REMOVE_MEMBER':
          final targetIds = List<String>.from(data['targetMemberIds'] ?? []);
          String targetName = 'thành viên';
          if (targetIds.isNotEmpty) {
             if (targetIds.first == provider.currentUserId) {
               targetName = 'Bạn';
             } else if (conversationId != null) {
                final convIndex = provider.conversations.indexWhere((c) => c.id == conversationId);
                if (convIndex >= 0) {
                  final member = provider.conversations[convIndex].members.firstWhere(
                    (m) => m.userId == targetIds.first,
                    orElse: () => provider.conversations[convIndex].members.first,
                  );
                  targetName = member.user?.displayName ?? targetName;
                }
             }
          }
          return '$targetName đã bị $actorName mời ra khỏi nhóm';
        case 'PROMOTE_ADMIN':
          return '$actorName đã bổ nhiệm phó nhóm mới';
        case 'TRANSFER_OWNERSHIP':
          return '$actorName đã chuyển quyền trưởng nhóm';
        case 'DISBAND_GROUP':
          return '$actorName đã giải tán nhóm';
        default:
          return 'Thông báo hệ thống';
      }
    } catch (e) {
      return 'Thông báo hệ thống';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final provider = context.read<ChatProvider>();
    final formattedContent = _getFormattedContent(context, provider);
    
    // Hide specialized sync signals that aren't meant for UI
    if (content.contains('UPDATE_MESSAGE_REACTIONS')) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            formattedContent,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode 
                  ? Colors.white.withOpacity(0.7)
                  : Colors.grey.withOpacity(0.8),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
