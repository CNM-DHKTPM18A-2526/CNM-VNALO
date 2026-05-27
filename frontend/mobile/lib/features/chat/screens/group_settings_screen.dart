import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/group_join_requests_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/group_members_screen.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/core/widgets/skeleton_loading.dart';

class GroupSettingsScreen extends StatefulWidget {
  final Conversation conversation;

  const GroupSettingsScreen({super.key, required this.conversation});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  bool _isLoading = true;
  bool _isUpdating = false;

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Update a group setting, show feedback, and guard against double-tap
  Future<void> _updateSetting(Future<void> Function() action) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã cập nhật thiết lập nhóm'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cập nhật thất bại. Vui lòng thử lại.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
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
      orElse: () => ConversationMember(
        conversationId: conv.id,
        userId: userId ?? '',
        role: MemberRole.MEMBER,
        joinedAt: DateTime.now(),
      ),
    );

    final isAdmin = myMember.role == MemberRole.ADMIN || myMember.role == MemberRole.DEPUTY;
    final isOwner = myMember.role == MemberRole.ADMIN;

    final sectionTitleColor = isDarkMode
        ? AppColors.primary.withValues(alpha: 0.9)
        : AppColors.primary;
    final bgColor = isDarkMode ? DarkColors.surface : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;

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
        actions: [
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const ShimmerLoading(isLoading: true, child: GroupSettingsSkeleton())
          : ListView(
              children: [
                // ─── Section: Thiết lập tin nhắn ──────────────────────────
                if (isAdmin) ...[
                  _buildSectionTitle('Thiết lập tin nhắn', sectionTitleColor),
                  Container(
                    color: bgColor,
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          'Làm nổi tin nhắn từ trưởng và phó nhóm',
                          conv.highlightAdminMessages,
                          isAdmin
                              ? (val) => _updateSetting(() async {
                                    await provider.updateGroupInfo(conv.id, highlightAdminMessages: val);
                                  })
                              : null,
                          textColor,
                        ),
                        Divider(height: 1, color: dividerColor, indent: 16),
                        _buildSwitchTile(
                          'Thành viên mới xem được tin gửi gần đây',
                          conv.showHistoryToNewMembers,
                          isAdmin
                              ? (val) => _updateSetting(() async {
                                    await provider.updateGroupInfo(conv.id, showHistoryToNewMembers: val);
                                  })
                              : null,
                          textColor,
                        ),
                        Divider(height: 1, color: dividerColor, indent: 16),
                        _buildSwitchTile(
                          'Cho phép thành viên mời người khác',
                          conv.allowMemberInvite,
                          isAdmin
                              ? (val) => _updateSetting(() async {
                                    await provider.updateGroupInfo(conv.id, allowMemberInvite: val);
                                  })
                              : null,
                          textColor,
                        ),
                      ],
                    ),
                  ),
                ],

                // ─── Section: Thành viên ───────────────────────────────────
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
                      // ── Duyệt thành viên ──────────────────────────────
                      if (isAdmin) ...[
                        _buildNavTile(
                          'Duyệt thành viên',
                          conv.joinMode == JoinMode.APPROVAL ? 'Đang bật' : 'Đang tắt',
                          textColor,
                          trailingColor: conv.joinMode == JoinMode.APPROVAL
                              ? Colors.green.shade500
                              : subtitleColor,
                          onTap: () => _showJoinModeSheet(conv, provider, isDarkMode),
                        ),
                        // Sub-row: shortcut to pending requests when APPROVAL is on
                        if (conv.joinMode == JoinMode.APPROVAL) ...[
                          Divider(height: 1, color: dividerColor, indent: 16),
                          InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupJoinRequestsScreen(conversation: conv),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.pending_actions, size: 18, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Xem yêu cầu tham gia',
                                      style: TextStyle(fontSize: 15, color: textColor),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, size: 20, color: subtitleColor),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                      ] else ...[
                        Divider(height: 1, color: dividerColor, indent: 16),
                        _buildNavTile(
                          'Duyệt thành viên',
                          conv.joinMode == JoinMode.APPROVAL ? 'Đang bật' : 'Đang tắt',
                          textColor,
                          trailingColor: subtitleColor,
                          onTap: null, // non-admin: read-only
                        ),
                      ],
                    ],
                  ),
                ),

                // ─── Section: Quyền của thành viên ────────────────────────
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
                          onChanged: (val) => _updateSetting(() async {
                            await provider.updateGroupInfo(conv.id, allowMemberCreateNote: val);
                          }),
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
                          onChanged: (val) => _updateSetting(() async {
                            await provider.updateGroupInfo(conv.id, allowMemberCreatePoll: val);
                          }),
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
                          onChanged: (val) => _updateSetting(() async {
                            await provider.updateGroupInfo(conv.id, allowMemberEditInfo: val);
                          }),
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
                          onChanged: (val) => _updateSetting(() async {
                            await provider.updateGroupInfo(conv.id, allowMemberPin: val);
                          }),
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
                          currentValue: !conv.onlyAdminCanPost,
                          reverseLogic: true,
                          onChanged: (val) => _updateSetting(() async {
                            await provider.updateGroupInfo(conv.id, onlyAdminCanPost: !val);
                          }),
                          isDarkMode: isDarkMode,
                          isAdmin: isAdmin,
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Giải tán nhóm (Owner only) ───────────────────────────
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

  // ─── Builders ──────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool>? onChanged,
    Color textColor,
  ) {
    final isDisabled = onChanged == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: isDisabled ? textColor.withValues(alpha: 0.5) : textColor,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: isDisabled ? null : onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile(
    String title,
    String? trailing,
    Color textColor, {
    Color? trailingColor,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = isDark ? DarkColors.textHint : Colors.grey;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 15, color: textColor)),
            ),
            if (trailing != null)
              Text(trailing, style: TextStyle(fontSize: 14, color: trailingColor ?? Colors.grey)),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 20, color: hintColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile(
    String title,
    String subtitle,
    Color textColor,
    Color subtitleColor, {
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = isDark ? DarkColors.textHint : Colors.grey;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
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
      ),
    );
  }

  // ─── Dialogs / Sheets ──────────────────────────────────────────

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
        const SnackBar(
          content: Text('Bạn không có quyền thay đổi cài đặt này'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? DarkColors.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final textColor = isDarkMode ? Colors.white : Colors.black;
        // For "Quyền gửi tin nhắn" with reverseLogic:
        // currentValue=true means "Tất cả mọi người" selected
        final bool everyoneSelected = reverseLogic ? currentValue : currentValue;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListTile(
                title: Text('Tất cả mọi người', style: TextStyle(color: textColor, fontSize: 16)),
                trailing: everyoneSelected
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () {
                  onChanged(true);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text('Chỉ trưởng và phó nhóm', style: TextStyle(color: textColor, fontSize: 16)),
                trailing: !everyoneSelected
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
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

  void _showJoinModeSheet(Conversation conv, ChatProvider provider, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? DarkColors.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final textColor = isDarkMode ? Colors.white : Colors.black;
        final isApproval = conv.joinMode == JoinMode.APPROVAL;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Chế độ phê duyệt thành viên',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text('Duyệt thành viên mới', style: TextStyle(color: textColor, fontSize: 16)),
                subtitle: const Text('Thành viên mới cần được Admin phê duyệt'),
                trailing: isApproval ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                onTap: () {
                  _updateSetting(() async {
                    await provider.updateGroupInfo(conv.id, joinMode: 'APPROVAL');
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text('Mở tự do', style: TextStyle(color: textColor, fontSize: 16)),
                subtitle: const Text('Bất kỳ ai có link đều có thể tham gia ngay'),
                trailing: !isApproval ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                onTap: () {
                  _updateSetting(() async {
                    await provider.updateGroupInfo(conv.id, joinMode: 'OPEN');
                  });
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
        content: const Text(
          'Tất cả thành viên sẽ bị mời ra khỏi nhóm và cuộc trò chuyện sẽ kết thúc.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              final chatProvider = context.read<ChatProvider>();
              final nav = Navigator.of(context);
              await chatProvider.disbandGroup(conv.id);
              await chatProvider.loadInbox();
              if (mounted) {
                nav.popUntil((route) => route.isFirst);
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
