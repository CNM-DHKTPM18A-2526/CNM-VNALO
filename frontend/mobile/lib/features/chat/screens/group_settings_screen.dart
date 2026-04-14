import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/group_members_screen.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';

class GroupSettingsScreen extends StatefulWidget {
  final Conversation conversation;

  const GroupSettingsScreen({super.key, required this.conversation});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  bool _highlightLeaderMessages = true;
  bool _newMemberCanSeeHistory = true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final conv = provider.conversations.firstWhere(
      (c) => c.id == widget.conversation.id,
      orElse: () => widget.conversation,
    );
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final userId = context.read<AuthProvider>().user?.id;
    final myMember = conv.members.firstWhere(
      (m) => m.userId == userId,
      orElse: () => conv.members.first,
    );
    final isOwner = myMember.role == MemberRole.OWNER;

    final sectionTitleColor = isDarkMode 
        ? AppColors.primary.withValues(alpha: 0.9) 
        : AppColors.primary;
    final bgColor = isDarkMode ? DarkColors.surface : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    final dividerColor = isDarkMode ? Colors.white10 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text(
          'Cài đặt nhóm',
          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDarkMode ? null : AppColors.appBarGradient,
            color: isDarkMode ? DarkColors.appBarBg : null,
          ),
        ),
      ),
      body: ListView(
        children: [
          // === Section: Thiết lập tin nhắn ===
          _buildSectionTitle('Thiết lập tin nhắn', sectionTitleColor),
          Container(
            color: bgColor,
            child: Column(
              children: [
                _buildSwitchTile(
                  'Làm nổi tin nhắn từ trưởng và phó nhóm',
                  _highlightLeaderMessages,
                  (val) => setState(() => _highlightLeaderMessages = val),
                  textColor,
                ),
                Divider(height: 1, color: dividerColor, indent: 16),
                _buildSwitchTile(
                  'Thành viên mới xem được tin gửi gần đây',
                  _newMemberCanSeeHistory,
                  (val) => setState(() => _newMemberCanSeeHistory = val),
                  textColor,
                ),
              ],
            ),
          ),

          // === Section: Thành viên ===
          _buildSectionTitle('Thành viên', sectionTitleColor),
          Container(
            color: bgColor,
            child: Column(
              children: [
                _buildNavTile(
                  'Quản lý thành viên',
                  null,
                  textColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GroupMembersScreen(conversation: conv)),
                  ),
                ),
                Divider(height: 1, color: dividerColor, indent: 16),
                _buildNavTile(
                  'Duyệt thành viên',
                  'Đã tắt',
                  textColor,
                  trailingColor: subtitleColor,
                  onTap: () {},
                ),
                Divider(height: 1, color: dividerColor, indent: 16),
                if (isOwner)
                  _buildNavTile(
                    'Chuyển quyền trưởng nhóm',
                    null,
                    textColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupMembersScreen(
                          conversation: conv,
                          selectionMode: true,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // === Section: Quyền của thành viên ===
          _buildSectionTitle('Quyền của thành viên', sectionTitleColor),
          Container(
            color: bgColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPermissionTile('Quyền sửa thông tin nhóm', 'Tất cả mọi người', textColor, subtitleColor),
                Divider(height: 1, color: dividerColor, indent: 16),
                _buildPermissionTile('Quyền tạo ghi chú, nhắc hẹn', 'Tất cả mọi người', textColor, subtitleColor),
                Divider(height: 1, color: dividerColor, indent: 16),
                _buildPermissionTile('Quyền tạo bình chọn', 'Tất cả mọi người', textColor, subtitleColor),
                Divider(height: 1, color: dividerColor, indent: 16),
                _buildPermissionTile('Quyền ghim tin nhắn', 'Tất cả mọi người', textColor, subtitleColor),
                Divider(height: 1, color: dividerColor, indent: 16),
                _buildPermissionTile(
                  'Quyền gửi tin nhắn', 
                  provider.isReadOnlyForMembers(conv.id) ? 'Chỉ trưởng và phó nhóm' : 'Tất cả mọi người', 
                  textColor, 
                  subtitleColor,
                  onTap: () => _showSendPermissionSheet(conv.id, provider, isDarkMode, isOwner),
                ),
              ],
            ),
          ),

          // === Giải tán nhóm (Owner only, no section header - just a red tile) ===
          if (isOwner) ...[
            const SizedBox(height: 12),
            Container(
              color: bgColor,
              child: InkWell(
                onTap: () => _confirmDisbandGroup(conv),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Text(
                    'Giải tán nhóm',
                    style: TextStyle(fontSize: 15, color: Colors.red, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 15, color: textColor),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile(String title, String? trailing, Color textColor, {Color? trailingColor, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 15, color: textColor),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: TextStyle(fontSize: 14, color: trailingColor ?? Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile(String title, String subtitle, Color textColor, Color subtitleColor, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 15, color: textColor)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 13, color: subtitleColor)),
          ],
        ),
      ),
    );
  }

  void _showSendPermissionSheet(String convId, ChatProvider provider, bool isDarkMode, bool isOwner) {
    if (!isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ trưởng nhóm mới có thể thay đổi quyền này')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? DarkColors.surface : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        final textColor = isDarkMode ? Colors.white : Colors.black;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Quyền gửi tin nhắn',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text('Tất cả mọi người', style: TextStyle(color: textColor, fontSize: 16)),
                trailing: !provider.isReadOnlyForMembers(convId) 
                  ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  provider.setReadOnlyForMembers(convId, false);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text('Chỉ trưởng và phó nhóm', style: TextStyle(color: textColor, fontSize: 16)),
                trailing: provider.isReadOnlyForMembers(convId) 
                  ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  provider.setReadOnlyForMembers(convId, true);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDisbandGroup(Conversation conv) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Giải tán nhóm?'),
        content: const Text('Tất cả thành viên sẽ bị mời ra khỏi nhóm và cuộc trò chuyện sẽ kết thúc.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          CupertinoDialogAction(
            onPressed: () async {
              final chatProvider = context.read<ChatProvider>();
              await chatProvider.disbandGroup(conv.id);
              await chatProvider.loadInbox();
              if (mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
            isDestructiveAction: true,
            child: const Text('Giải tán'),
          ),
        ],
      ),
    );
  }
}
