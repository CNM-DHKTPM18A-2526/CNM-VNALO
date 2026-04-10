import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/wallpaper_selection_screen.dart';

class ChatOptionsScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatOptionsScreen({super.key, required this.conversation});

  @override
  State<ChatOptionsScreen> createState() => _ChatOptionsScreenState();
}

class _ChatOptionsScreenState extends State<ChatOptionsScreen> {
  List<Message> _recentMedia = [];
  bool _isLoadingMedia = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
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
      SnackBar(
        content: Text('Tính năng $feature đang được phát triển, vui lòng quay lại sau'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openWallpaperSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WallpaperSelectionScreen(conversation: widget.conversation),
      ),
    );
  }

  Future<void> _editNickname() async {
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    final otherMember = widget.conversation.members.firstWhere(
      (m) => m.userId != currentUserId, 
      orElse: () => widget.conversation.members.first
    );
    
    final controller = TextEditingController(text: otherMember.nickname ?? '');
    
    final newNickname = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Đổi tên gợi nhớ'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Nhập tên gợi nhớ',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (newNickname != null && mounted) {
      await context.read<ChatProvider>().updateMemberNickname(widget.conversation.id, otherMember.userId, newNickname);
    }
  }

  Future<void> _showAutoDeletePicker() async {
    final durations = {
      0: 'Không tự xóa',
      60: '1 phút',
      3600: '1 giờ',
      86400: '24 giờ',
      604800: '7 ngày',
    };

    final result = await showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Tin nhắn tự xóa'),
        message: const Text('Tin nhắn sẽ tự động biến mất sau khoảng thời gian được chọn.'),
        actions: durations.entries.map<Widget>((e) => CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context, e.key),
          child: Text(e.value),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: const Text('Hủy'),
        ),
      ),
    );

    if (result != null && mounted) {
      await context.read<ChatProvider>().updateConversationSettings(
        conversationId: widget.conversation.id,
        autoDeleteSeconds: result,
      );
    }
  }

  Future<void> _deleteHistory() async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Xóa lịch sử trò chuyện?'),
        content: const Text('Toàn bộ tin nhắn sẽ bị ẩn đi. Bạn không thể hoàn tác thao tác này.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, true),
            isDestructiveAction: true,
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<ChatProvider>().deleteChatHistory(widget.conversation.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final currentConv = provider.conversations.firstWhere((c) => c.id == widget.conversation.id, orElse: () => widget.conversation);
    final currentUserId = context.watch<AuthProvider>().user?.id ?? '';
    final displayName = currentConv.getDisplayName(currentUserId);
    final avatarUrl = currentConv.getDisplayAvatarUrl(currentUserId);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F2F4),
      appBar: AppBar(
        title: const Text('Tùy chọn', style: TextStyle(fontSize: 18, color: Colors.white)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          _buildHeader(displayName, avatarUrl),
          const SizedBox(height: 1),
          _buildQuickActions(currentConv),
          const SizedBox(height: 8),
          _buildPrimarySettings(displayName, currentConv),
          const SizedBox(height: 8),
          _buildMediaSection(),
          const SizedBox(height: 8),
          _buildInteractionSettings(displayName),
          const SizedBox(height: 8),
          _buildConversationSettings(currentConv),
          const SizedBox(height: 8),
          _buildSecurityActions(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildHeader(String name, String? avatarUrl) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          AvatarWidget(imageUrl: avatarUrl, name: name, size: 80),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(Conversation conv) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickBtn(CupertinoIcons.search, 'Tìm\ntin nhắn', () => _showComingSoon('Tìm kiếm')),
          _buildQuickBtn(CupertinoIcons.person, 'Trang\ncá nhân', () => _showComingSoon('Trang cá nhân')),
          _buildQuickBtn(CupertinoIcons.paintbrush, 'Đổi\nhình nền', _openWallpaperSelection),
          _buildQuickBtn(
            conv.isMuted ? CupertinoIcons.bell_slash : CupertinoIcons.bell, 
            'Tắt\nthông báo', 
            () => context.read<ChatProvider>().updateConversationSettings(
              conversationId: conv.id,
              isMuted: !conv.isMuted,
            )
          ),
        ],
      ),
    );
  }

  Widget _buildQuickBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Color(0xFFF4F5F7), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.black87, size: 22),
          ),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, height: 1.2)),
        ],
      ),
    );
  }

  Widget _buildPrimarySettings(String name, Conversation conv) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildTile(CupertinoIcons.pencil, 'Đổi tên gợi nhớ', onTap: _editNickname),
          _buildDivider(),
          _buildTile(CupertinoIcons.star, 'Đánh dấu bạn thân', 
            trailing: CupertinoSwitch(
              value: conv.isFavorite, 
              onChanged: (v) => context.read<ChatProvider>().updateConversationSettings(
                conversationId: conv.id,
                isFavorite: v,
              ),
              activeColor: AppColors.primary,
            ),
          ),
          _buildDivider(),
          _buildTile(CupertinoIcons.clock, 'Nhật ký chung', onTap: () => _showComingSoon('Nhật ký chung')),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTile(CupertinoIcons.photo, 'Ảnh, file, link', onTap: () => _showComingSoon('Kho tư liệu')),
          if (_isLoadingMedia)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 56), child: CupertinoActivityIndicator())
          else if (_recentMedia.isEmpty)
            const Padding(padding: EdgeInsets.only(left: 56, top: 4), child: Text('Chưa có phương tiện nào được chia sẻ', style: TextStyle(color: Colors.grey, fontSize: 13)))
          else
            SizedBox(
              height: 70,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                scrollDirection: Axis.horizontal,
                itemCount: _recentMedia.length,
                itemBuilder: (context, index) {
                  final m = _recentMedia[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 70,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: Colors.grey.shade200),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(imageUrl: m.mediaUrl ?? '', fit: BoxFit.cover),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInteractionSettings(String name) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildTile(CupertinoIcons.group, 'Tạo nhóm với $name'),
          _buildDivider(),
          _buildTile(CupertinoIcons.person_add, 'Thêm $name vào nhóm'),
          _buildDivider(),
          _buildTile(CupertinoIcons.person_3, 'Xem nhóm chung', trailing: const Text('24', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildConversationSettings(Conversation conv) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildTile(CupertinoIcons.pin, 'Ghim trò chuyện', 
            trailing: CupertinoSwitch(
              value: conv.isPinned, 
              onChanged: (v) => context.read<ChatProvider>().updateConversationSettings(conversationId: conv.id, isPinned: v),
              activeColor: AppColors.primary,
            )
          ),
          _buildDivider(),
          _buildTile(CupertinoIcons.eye_slash, 'Ẩn trò chuyện', 
            trailing: CupertinoSwitch(
              value: conv.isHidden, 
              onChanged: (v) => context.read<ChatProvider>().updateConversationSettings(conversationId: conv.id, isHidden: v),
              activeColor: AppColors.primary,
            )
          ),
          _buildDivider(),
          _buildTile(CupertinoIcons.phone, 'Báo cuộc gọi đến', 
            trailing: CupertinoSwitch(
              value: conv.notifyCall, 
              onChanged: (v) => context.read<ChatProvider>().updateConversationSettings(conversationId: conv.id, notifyCall: v),
              activeColor: AppColors.primary,
            )
          ),
          _buildZaloDivider(),
          _buildTile(CupertinoIcons.timer, 'Tin nhắn tự xóa', 
            onTap: _showAutoDeletePicker,
            trailing: Text(
              _formatAutoDelete(conv.autoDeleteSeconds), 
              style: const TextStyle(color: Colors.grey, fontSize: 13)
            )
          ),
          _buildZaloDivider(),
          _buildTile(CupertinoIcons.settings, 'Cài đặt cá nhân'),
        ],
      ),
    );
  }

  Widget _buildSecurityActions() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildTile(CupertinoIcons.exclamationmark_triangle, 'Báo xấu'),
          _buildDivider(),
          _buildTile(CupertinoIcons.slash_circle, 'Quản lý chặn'),
          _buildDivider(),
          _buildTile(CupertinoIcons.chart_pie, 'Dung lượng trò chuyện'),
          _buildDivider(),
          _buildTile(CupertinoIcons.trash, 'Xóa lịch sử trò chuyện', textColor: Colors.red, iconColor: Colors.red, onTap: _deleteHistory),
        ],
      ),
    );
  }

  Widget _buildTile(IconData icon, String title, {Widget? trailing, VoidCallback? onTap, Color? textColor, Color? iconColor}) {
    return ListTile(
      onTap: onTap,
      dense: true,
      leading: Icon(icon, color: iconColor ?? Colors.black54, size: 22),
      title: Text(title, style: TextStyle(fontSize: 15, color: textColor ?? Colors.black87)),
      trailing: trailing ?? const Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.black26),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minLeadingWidth: 24,
    );
  }

  Widget _buildDivider() => const Divider(height: 0.5, thickness: 0.5, indent: 56);
  Widget _buildZaloDivider() => const Divider(height: 0.5, thickness: 0.5, indent: 56);

  String _formatAutoDelete(int seconds) {
    if (seconds == 0) return 'Không tự xóa';
    if (seconds < 3600) return '${seconds ~/ 60} phút';
    if (seconds < 86400) return '${seconds ~/ 3600} giờ';
    if (seconds < 604800) return '${seconds ~/ 86400} ngày';
    return '${seconds ~/ 604800} tuần';
  }
}
