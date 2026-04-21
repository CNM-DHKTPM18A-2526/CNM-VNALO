import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/add_group_members_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/group_join_requests_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/group_members_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/group_settings_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/wallpaper_selection_screen.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/navigation/main_shell.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class GroupChatOptionsScreen extends StatefulWidget {
  final Conversation conversation;

  const GroupChatOptionsScreen({super.key, required this.conversation});

  @override
  State<GroupChatOptionsScreen> createState() => _GroupChatOptionsScreenState();
}

class _GroupChatOptionsScreenState extends State<GroupChatOptionsScreen> {
  bool _isLoadingMedia = true;
  bool _isUpdatingAvatar = false;
  List<dynamic> _recentMedia = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final media = await context.read<ChatProvider>().getSharedMedia(widget.conversation.id, type: 'IMAGE');
    if (mounted) {
      setState(() {
        _recentMedia = media;
        _isLoadingMedia = false;
      });
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tính năng $feature đang được phát triển')),
    );
  }

  Future<void> _editGroupName() async {
    final controller = TextEditingController(text: widget.conversation.title ?? '');
    final common = CommonTexts.of(context, listen: false);

    final newName = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Đổi tên nhóm'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Nhập tên nhóm mới',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: Text(common.cancel)),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(common.save),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty && mounted) {
      await context.read<ChatProvider>().updateGroupInfo(widget.conversation.id, title: newName.trim());
    }
  }

  Future<void> _changeGroupAvatar() async {
    final common = CommonTexts.of(context, listen: false);
    final picker = ImagePicker();

    final source = await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Đổi ảnh nhóm'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Chụp ảnh mới'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Chọn từ thư viện'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: Text(common.cancel),
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null && mounted) {
      setState(() => _isUpdatingAvatar = true);
      try {
        await context.read<ChatProvider>().updateGroupAvatarFile(
          widget.conversation.id,
          File(pickedFile.path),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể cập nhật ảnh nhóm')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUpdatingAvatar = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final conv = provider.conversations.firstWhere((c) => c.id == widget.conversation.id, orElse: () => widget.conversation);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);
    final userId = context.read<AuthProvider>().user?.id;
    // Safety check: if members list is empty (e.g. after disband), use a dummy to avoid crash
    final myMember = conv.members.isEmpty 
        ? ConversationMember(conversationId: conv.id, userId: 'none', joinedAt: DateTime.now())
        : conv.members.firstWhere((m) => m.userId == userId, orElse: () => conv.members.first);

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: Text(common.options, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
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
          _buildHeader(conv),
          _buildQuickActions(conv),
          const SizedBox(height: 8),
          _buildSection([
            _buildTile(CupertinoIcons.info, 'Thêm mô tả nhóm', 
              subtitle: conv.description,
              onTap: () => _showComingSoon('Mô tả nhóm')),
          ]),
          const SizedBox(height: 8),
          _buildMediaSection(),
          const SizedBox(height: 8),
          _buildSection([
            _buildTile(CupertinoIcons.calendar, 'Lịch nhóm', onTap: () => _showComingSoon('Lịch nhóm')),
            _buildDivider(),
            _buildTile(CupertinoIcons.pin, 'Tin nhắn đã ghim', onTap: () => _showComingSoon('Ghim tin nhắn')),
            _buildDivider(),
            _buildTile(CupertinoIcons.chart_bar, 'Bình chọn', onTap: () => _showComingSoon('Bình chọn')),
          ]),
          const SizedBox(height: 8),
          _buildSection([
            _buildTile(CupertinoIcons.settings, 'Cài đặt nhóm', 
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => GroupSettingsScreen(conversation: conv),
              )),
            ),
            _buildDivider(),
            _buildTile(CupertinoIcons.person_2, 'Xem thành viên (${conv.activeMemberCount})', 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupMembersScreen(conversation: conv)))),
            _buildDivider(),
            _buildTile(CupertinoIcons.person_badge_plus, 'Duyệt thành viên', 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupJoinRequestsScreen(conversation: conv)))),
            _buildDivider(),
            _buildTile(CupertinoIcons.link, 'Link nhóm', 
              subtitle: conv.joinMode == JoinMode.APPROVAL ? 'Cần phê duyệt' : 'Đã tắt',
              onTap: () => _showComingSoon('Link nhóm')),
          ]),
          if (_isAdminOrOwner(conv, context.read<AuthProvider>().user?.id)) ...[
            const SizedBox(height: 8),
            _buildSection([
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('QUYỀN CỦA THÀNH VIÊN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
              _buildTile(CupertinoIcons.person_badge_plus, 'Cho phép mời người mới', 
                trailing: CupertinoSwitch(
                  value: conv.allowMemberInvite, 
                  onChanged: (v) => provider.updateGroupInfo(conv.id, allowMemberInvite: v),
                  activeTrackColor: AppColors.primary,
                )),
              _buildDivider(),
              _buildTile(CupertinoIcons.pin, 'Cho phép ghim tin nhắn', 
                trailing: CupertinoSwitch(
                  value: conv.allowMemberPin, 
                  onChanged: (v) => provider.updateGroupInfo(conv.id, allowMemberPin: v),
                  activeTrackColor: AppColors.primary,
                )),
              _buildDivider(),
              _buildTile(CupertinoIcons.pencil, 'Cho phép sửa thông tin nhóm', 
                trailing: CupertinoSwitch(
                  value: conv.allowMemberEditInfo, 
                  onChanged: (v) => provider.updateGroupInfo(conv.id, allowMemberEditInfo: v),
                  activeTrackColor: AppColors.primary,
                )),
            ]),
          ],
          const SizedBox(height: 8),
          _buildSection([
            _buildTile(CupertinoIcons.pin_fill, 'Ghim trò chuyện', 
              trailing: CupertinoSwitch(
                value: conv.isPinned, 
                onChanged: (v) => provider.updateConversationSettings(conversationId: conv.id, isPinned: v),
                activeTrackColor: AppColors.primary,
              )),
            _buildDivider(),
            _buildTile(CupertinoIcons.eye_slash, 'Ẩn trò chuyện', 
              trailing: CupertinoSwitch(
                value: conv.isHidden, 
                onChanged: (v) => provider.updateConversationSettings(conversationId: conv.id, isHidden: v),
                activeTrackColor: AppColors.primary,
              )),
            _buildDivider(),
            _buildTile(CupertinoIcons.time, 'Tin nhắn tự xóa', 
              subtitle: 'Không tự xóa',
              onTap: () => _showComingSoon('Tự xóa')),
            _buildDivider(),
            _buildTile(CupertinoIcons.person_crop_circle, 'Cài đặt cá nhân', onTap: () => _showComingSoon('Cài đặt cá nhân')),
          ]),
          const SizedBox(height: 8),
          _buildSection([
            _buildTile(CupertinoIcons.exclamationmark_triangle, 'Báo xấu', onTap: () => _showComingSoon('Báo xấu')),
            _buildDivider(),
            _buildTile(CupertinoIcons.person_2_square_stack, 'Chuyển quyền trưởng nhóm', 
               onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupMembersScreen(conversation: conv, selectionMode: true)))),
            _buildDivider(),
            _buildTile(CupertinoIcons.cloud, 'Dung lượng trò chuyện', onTap: () => _showComingSoon('Dung lượng')),
            _buildDivider(),
            _buildTile(CupertinoIcons.trash, 'Xóa lịch sử trò chuyện', 
              textColor: Colors.red,
              onTap: () => _confirmDeleteHistory(conv)),
          ]),
          const SizedBox(height: 8),
          _buildSection([
            _buildTile(CupertinoIcons.arrow_right_square, 'Rời nhóm', 
              textColor: Colors.red,
              onTap: () => _confirmLeaveGroup(conv)),
            if (myMember.role == MemberRole.OWNER) ...[
              _buildDivider(),
              _buildTile(CupertinoIcons.delete, 'Giải tán nhóm', 
                textColor: Colors.red,
                onTap: () => _confirmDisbandGroup(conv)),
            ],
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  bool _isAdminOrOwner(Conversation conv, String? userId) {
    if (userId == null) return false;
    if (conv.createdBy == userId) return true;
    if (conv.members.isEmpty) return false;
    final member = conv.members.firstWhere((m) => m.userId == userId, orElse: () => conv.members.first);
    return member.role == MemberRole.ADMIN || member.role == MemberRole.OWNER;
  }

  Widget _buildHeader(Conversation conv) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Stack(
            children: [
              (conv.avatarUrl != null && conv.avatarUrl!.isNotEmpty)
                  ? AvatarWidget(
                      imageUrl: conv.avatarUrl,
                      name: conv.title ?? 'Group',
                      size: 100,
                    )
                  : AvatarWidget(
                      imageUrl: null,
                      name: conv.title ?? 'Group',
                      size: 100,
                    ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUpdatingAvatar ? null : _changeGroupAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: _isUpdatingAvatar
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt, size: 18, color: Colors.blue),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  conv.title ?? 'Nhóm',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _editGroupName,
                child: Icon(Icons.edit_outlined, size: 20, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(Conversation conv) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickAction(CupertinoIcons.search, 'Tìm\ntin nhắn', () => _showComingSoon('Tìm kiếm')),
          _buildQuickAction(CupertinoIcons.person_badge_plus, 'Thêm\nthành viên', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AddGroupMembersScreen(conversation: conv)));
          }),
          _buildQuickAction(CupertinoIcons.paintbrush, 'Đổi\nhình nền', () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => WallpaperSelectionScreen(conversation: conv)));
          }),
          _buildQuickAction(
            conv.isMuted ? CupertinoIcons.bell_slash : CupertinoIcons.bell, 
            conv.isMuted ? 'Bật\nthông báo' : 'Tắt\nthông báo', 
            () => context.read<ChatProvider>().updateConversationSettings(conversationId: conv.id, isMuted: !conv.isMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildTile(CupertinoIcons.photo, 'Ảnh, file, link', onTap: () => _showComingSoon('Kho tài liệu')),
          if (_recentMedia.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recentMedia.length.clamp(0, 5),
                itemBuilder: (context, index) {
                  final m = _recentMedia[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade200,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(
                      imageUrl: m.mediaUrl ?? '',
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            )
          else if (!_isLoadingMedia)
             Padding(
               padding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
               child: Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                 child: Text('Hình mới nhất của trò chuyện sẽ xuất hiện tại đây', 
                   style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
               ),
             ),
        ],
      ),
    );
  }

  Widget _buildSection(List<Widget> children) {
    return Container(
      color: Colors.white,
      child: Column(children: children),
    );
  }

  Widget _buildTile(IconData icon, String title, {String? subtitle, Widget? trailing, VoidCallback? onTap, Color? textColor}) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.grey.shade700, size: 22),
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: textColor)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)) : null,
      trailing: trailing ?? Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildDivider() => const Divider(height: 1, thickness: 0.5, indent: 56);

  void _confirmDeleteHistory(Conversation conv) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Xóa lịch sử trò chuyện?'),
        content: const Text('Toàn bộ tin nhắn sẽ bị xóa. Bạn không thể hoàn tác thao tác này.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          CupertinoDialogAction(
            onPressed: () {
              context.read<ChatProvider>().deleteChatHistory(conv.id);
              Navigator.pop(context);
            },
            isDestructiveAction: true,
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveGroup(Conversation conv) {
    final userId = context.read<AuthProvider>().user?.id;
    if (conv.members.isEmpty) return;
    final member = conv.members.firstWhere((m) => m.userId == userId, orElse: () => conv.members.first);
    
    if (member.role == MemberRole.OWNER || member.role == MemberRole.ADMIN) {
      // Rule: Leaders must transfer UNLESS they are the last person in the group
      if (conv.members.length > 1) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Rời nhóm?'),
            content: const Text('Bạn phải chuyển quyền trưởng nhóm cho thành viên khác trước khi rời.'),
            actions: [
              CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
            ],
          ),
        );
        return;
      }
      // If 1 member and is leader (Owner), they can leave (effectively disbanding)
      if (member.role == MemberRole.OWNER) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Rời và Giải tán nhóm?'),
            content: const Text('Bạn là thành viên cuối cùng. Rời nhóm sẽ đồng nghĩa với việc giải tán nhóm này.'),
            actions: [
              CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
              CupertinoDialogAction(
                onPressed: () async {
                  // Dismiss dialog first
                  Navigator.pop(context);
                  
                  final chatProvider = context.read<ChatProvider>();
                  // Don't await here to allow immediate navigation
                  chatProvider.disbandGroup(conv.id);
                  
                  // Navigate to chat tab immediately
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  MainShellState.globalKey.currentState?.setTabIndex(0);
                },
                isDestructiveAction: true,
                child: const Text('Giải tán & Rời đi'),
              ),
            ],
          ),
        );
        return;
      }
    }

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Rời nhóm?'),
        content: const Text('Bạn sẽ không còn nhận được tin nhắn từ nhóm này nữa.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          CupertinoDialogAction(
            onPressed: () {
              // Dismiss dialog first
              Navigator.pop(context);
              
              final chatProvider = context.read<ChatProvider>();
              // Don't await here to allow immediate navigation
              chatProvider.leaveGroup(conv.id);
              
              // Navigate to chat tab immediately
              Navigator.of(context).popUntil((route) => route.isFirst);
              MainShellState.globalKey.currentState?.setTabIndex(0);
            },
            isDestructiveAction: true,
            child: const Text('Rời nhóm'),
          ),
        ],
      ),
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
            onPressed: () {
              // Dismiss dialog first
              Navigator.pop(context);
              
              final chatProvider = context.read<ChatProvider>();
              // Don't await here to allow immediate navigation
              chatProvider.disbandGroup(conv.id);
              
              // Navigate to chat tab immediately
              Navigator.of(context).popUntil((route) => route.isFirst);
              MainShellState.globalKey.currentState?.setTabIndex(0);
            },
            isDestructiveAction: true,
            child: const Text('Giải tán'),
          ),
        ],
      ),
    );
  }
}
