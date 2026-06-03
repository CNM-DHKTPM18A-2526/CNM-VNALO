import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

/// An enhanced system message widget with icons and animations.
class SystemMessage extends StatefulWidget {
  final String content;
  final DateTime? timestamp;
  final String? conversationId;

  const SystemMessage({
    super.key,
    required this.content,
    this.timestamp,
    this.conversationId,
  });

  @override
  State<SystemMessage> createState() => _SystemMessageState();
}

class _SystemMessageState extends State<SystemMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  _SystemEvent _parseEvent(Map<String, dynamic> data, String? action) {
    final actorId = data['actorId'] as String?;
    final metadata = data['metadata'] as Map?;
    final targetIds = data['targetMemberIds'] as List?;

    IconData icon = Icons.info_outline;
    Color iconColor = Colors.blue;
    String text = 'Thông báo hệ thống';

    switch (action) {
      case 'ADD_MEMBERS':
        icon = Icons.person_add;
        iconColor = Colors.green;
        text = 'đã thêm thành viên vào nhóm';
        break;
      case 'LEAVE_GROUP':
        icon = Icons.exit_to_app;
        iconColor = Colors.grey;
        text = 'đã rời khỏi nhóm';
        break;
      case 'CREATE_GROUP':
        icon = Icons.group_add;
        iconColor = Colors.blue;
        text = 'đã tạo nhóm';
        break;
      case 'RENAME_GROUP':
      case 'UPDATE_GROUP_INFO':
        final newName = metadata?['newName'] as String?;
        if (newName != null) {
          text = 'đã đổi tên nhóm thành "$newName"';
        } else {
          text = 'đã cập nhật thông tin nhóm';
        }
        icon = Icons.edit;
        iconColor = Colors.orange;
        break;
      case 'CHANGE_GROUP_AVATAR':
        icon = Icons.photo_camera;
        iconColor = Colors.purple;
        text = 'đã thay đổi ảnh đại diện nhóm';
        break;
      case 'PIN_MESSAGE':
        icon = Icons.push_pin;
        iconColor = AppColors.pinIcon;
        text = 'đã ghim một tin nhắn';
        break;
      case 'UNPIN_MESSAGE':
        icon = Icons.push_pin_outlined;
        iconColor = Colors.grey;
        text = 'đã bỏ ghim một tin nhắn';
        break;
      case 'REMOVE_MEMBER':
        icon = Icons.person_remove;
        iconColor = Colors.red;
        text = 'đã mời một thành viên ra khỏi nhóm';
        break;
      case 'PROMOTE_ADMIN':
        icon = Icons.star;
        iconColor = Colors.amber;
        text = 'đã bổ nhiệm phó nhóm mới';
        break;
      case 'TRANSFER_OWNERSHIP':
        icon = Icons.swap_horiz;
        iconColor = Colors.blue;
        text = 'đã chuyển quyền trưởng nhóm';
        break;
      case 'DISBAND_GROUP':
        icon = Icons.delete_forever;
        iconColor = Colors.red;
        text = 'đã giải tán nhóm';
        break;
      default:
        text = 'Thông báo hệ thống';
    }

    return _SystemEvent(
      icon: icon,
      iconColor: iconColor,
      text: text,
      actorId: actorId,
      targetIds: targetIds?.cast<String>(),
    );
  }

  String _resolveActorName(String? actorId, ChatProvider provider) {
    if (actorId == null) return 'Một thành viên';
    if (actorId == provider.currentUserId) return 'Bạn';

    if (widget.conversationId != null) {
      final convIndex = provider.conversations.indexWhere(
        (c) => c.id == widget.conversationId,
      );
      if (convIndex >= 0) {
        final members = provider.conversations[convIndex].members;
        for (final m in members) {
          if (m.userId == actorId) {
            return m.nickname ?? m.user?.displayName ?? 'Một thành viên';
          }
        }
      }
    }
    return 'Một thành viên';
  }

  String _resolveTargetName(String? targetId, ChatProvider provider) {
    if (targetId == null) return 'thành viên';
    if (targetId == provider.currentUserId) return 'Bạn';

    if (widget.conversationId != null) {
      final convIndex = provider.conversations.indexWhere(
        (c) => c.id == widget.conversationId,
      );
      if (convIndex >= 0) {
        final members = provider.conversations[convIndex].members;
        for (final m in members) {
          if (m.userId == targetId) {
            return m.nickname ?? m.user?.displayName ?? 'thành viên';
          }
        }
      }
    }
    return 'thành viên';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final provider = context.read<ChatProvider>();

    if (widget.content.contains('UPDATE_MESSAGE_REACTIONS')) {
      return const SizedBox.shrink();
    }

    _SystemEvent? parsedEvent;
    final trimmedContent = widget.content.trim();
    
    if (trimmedContent.startsWith('{')) {
      try {
        final data = Map<String, dynamic>.from(
          json.decode(trimmedContent) as Map<String, dynamic>,
        );
        final action = data['action'] as String?;
        parsedEvent = _parseEvent(data, action);
      } catch (e) {
        debugPrint('SystemMessage JSON parse error: $e for content: $trimmedContent');
        parsedEvent = null;
      }
    }

    final actorName = parsedEvent != null
        ? _resolveActorName(parsedEvent.actorId, provider)
        : '';

    String displayText;
    IconData icon;
    Color iconColor;

    if (parsedEvent != null) {
      final targetIds = parsedEvent.targetIds;
      if (targetIds != null && targetIds.isNotEmpty && parsedEvent.icon == Icons.person_remove) {
        final targetName = _resolveTargetName(targetIds.first, provider);
        displayText = '$targetName đã bị $actorName mời ra khỏi nhóm';
      } else {
        displayText = '$actorName ${parsedEvent.text}';
      }
      icon = parsedEvent.icon;
      iconColor = parsedEvent.iconColor;
    } else {
      displayText = widget.content;
      
      // Ẩn các tin nhắn hệ thống cũ (chữ trơn) bị lặp lại do đã có tin nhắn JSON mới
      // Đồng thời ẩn luôn các tin nhắn bị lỗi font chữ (chứa ký tự Ä')
      final lowerText = displayText.toLowerCase();
      if (lowerText.contains('ä\'') ||
          lowerText.contains('đã đổi tên nhóm') ||
          lowerText.contains('đã cập nhật thông tin nhóm') ||
          lowerText.contains('đã thêm thành viên') ||
          lowerText.contains('đã rời khỏi nhóm') ||
          lowerText.contains('đã xóa một thành viên') ||
          lowerText.contains('đã ghim một tin nhắn') ||
          lowerText.contains('đã bỏ ghim một tin nhắn') ||
          lowerText.contains('đã thay đổi ảnh đại diện') ||
          lowerText.contains('đã được thăng cấp') ||
          lowerText.contains('đã chuyển quyền') ||
          lowerText.contains('đã giải tán') ||
          lowerText.contains('đã bị hủy quyền')) {
        return const SizedBox.shrink();
      }

      icon = Icons.info_outline;
      iconColor = Colors.grey;
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 14,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.72)
                            : Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemEvent {
  final IconData icon;
  final Color iconColor;
  final String text;
  final String? actorId;
  final List<String>? targetIds;

  _SystemEvent({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.actorId,
    this.targetIds,
  });
}
