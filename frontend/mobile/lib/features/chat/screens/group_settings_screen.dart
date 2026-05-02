import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/group_members_screen.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/core/widgets/skeleton_loading.dart';

class GroupSettingsScreen extends StatefulWidget {
  final Conversation conversation;

  const GroupSettingsScreen({super.key, required this.conversation});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await context.read<ChatProvider>().refreshConversation(widget.conversation.id);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
    
    // Group Admin (Trưởng nhóm) has full control. 
    // Deputy (Phó nhóm) has partial control in some features.
    final isAdmin = myMember.role == MemberRole.ADMIN || myMember.role == MemberRole.DEPUTY;
    final isOwner = myMember.role == MemberRole.ADMIN;

    final sectionTitleColor = isDarkMode 
        ? AppColors.primary.withValues(alpha: 0.9) 
        : AppColors.primary;
    final bgColor = isDarkMode ? DarkColors.surface : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;
    final hintColor = isDarkMode ? DarkColors.textHint : Colors.grey;

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        title: const Text(
          'Cài đặt nhóm',
          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        forceMaterialTransparency: !isDarkMode,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: BoxDecoration(gradient: AppColors.appBarGradient),
              ),
      ),
      body: _isLoading 
        ? const ShimmerLoading(isLoading: true, child: GroupSettingsSkeleton())
        : ListView(
          children: [
            // === Section: Thiết lập tin nhắn ===
          _buildSectionTitle('Thiết lập tin nhắn', sectionTitleColor),
          Container(
            color: bgColor,
            child: Column(
              children: [
                _buildSwitchTile(
                  'Làm nổi tin nhắn từ trưởng và phó nhóm',
                  conv.highlightAdminMessages,
                  (val) => provider.updateGroupInfo(conv.id, highlightAdminMessages: val),
                  textColor,
                ),
                Divider(height: 1, color: dividerColor, indent: 16),
                _buildSwitchTile(
                  'Thành viên mới xem được tin gửi gần đây',
                  conv.showHistoryToNewMembers,
                  (val) => provider.updateGroupInfo(conv.id, showHistoryToNewMembers: val),
                  textColor,
                ),
                Divider(height: 1, color: dividerColor, indent: 16),
                _buildSwitchTile(
                  'Cho phép thành viên mời người khác',
                  conv.allowMemberInvite,
                  (val) => provider.updateGroupInfo(conv.id, allowMemberInvite: val),
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
                  '${conv.members.length} thành viên',
                  textColor,
                  trailingColor: subtitleColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GroupMembersScreen(conversation: conv)),
                  ),
                ),
                Divider(height: 1, color: dividerColor, indent: 16),
                _buildNavTile(
                  'Duyệt thành viên',
                  conv.joinMode == JoinMode.APPROVAL ? 'Đang bật' : 'Đang tắt',
                  textColor,
                  trailingColor: subtitleColor,
                  onTap: () => _showJoinModeSheet(conv.id, provider, isDarkMode, isAdmin),
                ),
                Divider(height: 1, color: dividerColor, indent: 16),
                if (isAdmin)
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
                _buildPermissionTile(
                  'Quyền tạo ghi chú, nhắc hẹn', 
                  conv.allowMemberCreateNote ? 'Tất cả mọi người' : 'Chỉ trưởng và phó nhóm', 
                  textColor, 
                  subtitleColor,
                  onTap: () => _showSimplePermissionSheet(
                    context: context,
                    title: 'Quyền tạo ghi chú, nhắc hẹn',
                    currentValue: conv.allowMemberCreateNote,
                    onChanged: (val) => provider.updateGroupInfo(conv.id, allowMemberCreateNote: val),
                    isDarkMode: isDarkMode,
                    isAdmin: isAdmin,
                  ),
                ),
                Divider(height: 1, color: dividerColor, indent: 16),
                _buildPermissionTile(
                  'Quyền tạo bình chọn', 
                  conv.allowMemberCreatePoll ? 'Tất cả mọi người' : 'Chỉ trưởng và phó nhóm', 
                  textColor, 
                  subtitleColor,
                  onTap: () => _showSimplePermissionSheet(
                    context: context,
                    title: 'Quyền tạo bình chọn',
                    currentValue: conv.allowMemberCreatePoll,
                    onChanged: (val) => provider.updateGroupInfo(conv.id, allowMemberCreatePoll: val),
                    isDarkMode: isDarkMode,
                    isAdmin: isAdmin,
                  ),
                ),
                Divider(height: 1, color: dividerColor, indent: 16),
                _buildPermissionTile(
                  'Quyền sửa thông tin nhóm', 
                  conv.allowMemberEditInfo ? 'Tất cả mọi người' : 'Chỉ trưởng và phó nhóm', 
                  textColor, 
                  subtitleColor,
                  onTap: () => _showSimplePermissionSheet(
                    context: context,
                    title: 'Quyền sửa thông tin nhóm',
                    currentValue: conv.allowMemberEditInfo,
                    onChanged: (val) => provider.updateGroupInfo(conv.id, allowMemberEditInfo: val),
                    isDarkMode: isDarkMode,
                    isAdmin: isAdmin,
                  ),
                ),
                Divider(height: 1, color: dividerColor, indent: 16),
                _buildPermissionTile(
                  'Quyền ghim tin nhắn', 
                  conv.allowMemberPin ? 'Tất cả mọi người' : 'Chỉ trưởng và phó nhóm', 
                  textColor, 
                  subtitleColor,
                  onTap: () => _showSimplePermissionSheet(
                    context: context,
                    title: 'Quyền ghim tin nhắn',
                    currentValue: conv.allowMemberPin,
                    onChanged: (val) => provider.updateGroupInfo(conv.id, allowMemberPin: val),
                    isDarkMode: isDarkMode,
                    isAdmin: isAdmin,
                  ),
                ),
                Divider(height: 1, color: dividerColor, indent: 16),
                _buildPermissionTile(
                  'Quyền gửi tin nhắn', 
                  conv.onlyAdminCanPost ? 'Chỉ trưởng và phó nhóm' : 'Tất cả mọi người', 
                  textColor, 
                  subtitleColor,
                  onTap: () => _showSimplePermissionSheet(
                    context: context,
                    title: 'Quyền gửi tin nhắn',
                    currentValue: !conv.onlyAdminCanPost, // Note: onlyAdminCanPost=true means MemberPost=false
                    reverseLogic: true,
                    onChanged: (val) => provider.updateGroupInfo(conv.id, onlyAdminCanPost: !val),
                    isDarkMode: isDarkMode,
                    isAdmin: isAdmin,
                  ),
                ),
              ],
            ),
          ),

          // === Giải tán nhóm (Admin only) ===
          if (isAdmin) ...[
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
    final hintColor = Theme.of(context).brightness == Brightness.dark ? DarkColors.textHint : Colors.grey;
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
            Icon(Icons.chevron_right, size: 20, color: hintColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile(String title, String subtitle, Color textColor, Color subtitleColor, {VoidCallback? onTap}) {
    final hintColor = Theme.of(context).brightness == Brightness.dark ? DarkColors.textHint : Colors.grey;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 15, color: textColor)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: subtitleColor)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: hintColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSimplePermissionSheet({
    required BuildContext context,
    required String title,
    required bool currentValue,
    required Function(bool) onChanged,
    required bool isDarkMode,
    required bool isAdmin,
    bool reverseLogic = false,
  }) {
    if (!isAdmin) {
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
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text('Tất cả mọi người', style: TextStyle(color: textColor, fontSize: 16)),
                trailing: currentValue ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  onChanged(true);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text('Chỉ trưởng và phó nhóm', style: TextStyle(color: textColor, fontSize: 16)),
                trailing: !currentValue ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  onChanged(false);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showJoinModeSheet(String convId, ChatProvider provider, bool isDarkMode, bool isAdmin) {
    if (!isAdmin) {
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
                'Chế độ phê duyệt thành viên',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text('Duyệt thành viên mới', style: TextStyle(color: textColor, fontSize: 16)),
                subtitle: const Text('Thành viên mới cần được Admin phê duyệt để tham gia'),
                onTap: () {
                  provider.updateGroupInfo(convId, joinMode: 'APPROVAL');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text('Mở tự do', style: TextStyle(color: textColor, fontSize: 16)),
                subtitle: const Text('Bất kỳ ai có link đều có thể tham gia ngay'),
                onTap: () {
                  provider.updateGroupInfo(convId, joinMode: 'OPEN');
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
