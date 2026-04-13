import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
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
    final common = CommonTexts.of(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(common.featureUnderDev(feature)),
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
    final common = CommonTexts.of(context, listen: false);

    final newNickname = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(common.editNicknameAction),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: common.nicknamePlaceholder,
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

    if (newNickname != null && mounted) {
      await context.read<ChatProvider>().updateMemberNickname(widget.conversation.id, otherMember.userId, newNickname);
    }
  }

  Future<void> _showAutoDeletePicker() async {
    final common = CommonTexts.of(context, listen: false);
    final durations = {
      0: common.off,
      60: '1 ${common.minute}',
      3600: '1 ${common.hour}',
      86400: '24 ${common.hour}',
      604800: '7 ${common.day}',
    };

    final result = await showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(common.autoDeleteMessages),
        message: Text(common.autoDeleteNote),
        actions: durations.entries.map<Widget>((e) => CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context, e.key),
          child: Text(e.value),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: Text(common.cancel),
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
    final common = CommonTexts.of(context, listen: false);
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(common.deleteHistoryTitleMsg),
        content: Text(common.deleteHistoryWarning),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: Text(common.cancel)),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, true),
            isDestructiveAction: true,
            child: Text(common.delete),
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
    final common = CommonTexts.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F2F4),
      appBar: AppBar(
        title: Text(common.options, style: const TextStyle(fontSize: 18, color: Colors.white)),
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
    final common = CommonTexts.of(context);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickBtn(CupertinoIcons.search, common.searchMessagesAction, () => _showComingSoon('Tìm kiếm')),
          _buildQuickBtn(CupertinoIcons.person, common.viewProfileQuickAction, () => _showComingSoon('Trang cá nhân')),
          _buildQuickBtn(CupertinoIcons.paintbrush, common.changeWallpaperQuickAction, _openWallpaperSelection),
          _buildQuickBtn(
            conv.isMuted ? CupertinoIcons.bell_slash : CupertinoIcons.bell,
            common.muteNotifsQuickAction,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDarkMode ? DarkColors.surfaceLight : LightColors.scaffold,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isDarkMode ? DarkColors.textPrimary : Colors.black87, size: 22),
          ),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, height: 1.2)),
        ],
      ),
    );
  }

  Widget _buildPrimarySettings(String name, Conversation conv) {
    final common = CommonTexts.of(context);
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildTile(CupertinoIcons.pencil, common.editNicknameAction, onTap: _editNickname),
          _buildDivider(),
          _buildTile(CupertinoIcons.star, common.markAsFavoriteAction,
            trailing: CupertinoSwitch(
              value: conv.isFavorite,
              onChanged: (v) => context.read<ChatProvider>().updateConversationSettings(
                conversationId: conv.id,
                isFavorite: v,
              ),
              activeTrackColor: AppColors.primary,
            ),
          ),
          _buildDivider(),
          _buildTile(CupertinoIcons.clock, common.sharedTimelineAction, onTap: () => _showComingSoon('Nhật ký chung')),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    final common = CommonTexts.of(context);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTile(CupertinoIcons.photo, common.mediaDocsLinksAction, onTap: () => _showComingSoon('Kho tư liệu')),
          if (_isLoadingMedia)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 56), child: CupertinoActivityIndicator())
          else if (_recentMedia.isEmpty)
            Padding(padding: const EdgeInsets.only(left: 56, top: 4), child: Text(common.noSharedMediaNote, style: const TextStyle(color: Colors.grey, fontSize: 13)))
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
    final common = CommonTexts.of(context);
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildTile(CupertinoIcons.group, common.createGroupWithLabel(name)),
          _buildDivider(),
          _buildTile(CupertinoIcons.person_add, common.addToGroupLabel(name)),
          _buildDivider(),
          _buildTile(CupertinoIcons.person_3, common.viewSharedGroupsAction, trailing: const Text('24', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildConversationSettings(Conversation conv) {
    final common = CommonTexts.of(context);
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildTile(CupertinoIcons.pin, common.pinConversationAction,
            trailing: CupertinoSwitch(
              value: conv.isPinned,
              onChanged: (v) => context.read<ChatProvider>().updateConversationSettings(conversationId: conv.id, isPinned: v),
              activeTrackColor: AppColors.primary,
            )
          ),
          _buildDivider(),
          _buildTile(CupertinoIcons.eye_slash, common.hideConversationAction,
            trailing: CupertinoSwitch(
              value: conv.isHidden,
              onChanged: (v) => context.read<ChatProvider>().updateConversationSettings(conversationId: conv.id, isHidden: v),
              activeTrackColor: AppColors.primary,
            )
          ),
          _buildDivider(),
          _buildTile(CupertinoIcons.phone, common.notifyCallsAction,
            trailing: CupertinoSwitch(
              value: conv.notifyCall,
              onChanged: (v) => context.read<ChatProvider>().updateConversationSettings(conversationId: conv.id, notifyCall: v),
              activeTrackColor: AppColors.primary,
            )
          ),
          _buildZaloDivider(),
          _buildTile(CupertinoIcons.timer, common.autoDeleteMessages,
            onTap: _showAutoDeletePicker,
            trailing: Text(
              _formatAutoDelete(context, conv.autoDeleteSeconds),
              style: const TextStyle(color: Colors.grey, fontSize: 13)
            )
          ),
          _buildZaloDivider(),
          _buildTile(CupertinoIcons.settings, common.personalSettingsAction),
        ],
      ),
    );
  }

  Widget _buildSecurityActions() {
    final common = CommonTexts.of(context);
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildTile(CupertinoIcons.exclamationmark_triangle, common.reportUserAction),
          _buildDivider(),
          _buildTile(CupertinoIcons.slash_circle, common.blockMgmtAction),
          _buildDivider(),
          _buildTile(CupertinoIcons.chart_pie, common.chatStorageAction),
          _buildDivider(),
          _buildTile(CupertinoIcons.trash, common.deleteHistoryAction, textColor: Colors.red, iconColor: Colors.red, onTap: _deleteHistory),
        ],
      ),
    );
  }

  Widget _buildTile(IconData icon, String title, {Widget? trailing, VoidCallback? onTap, Color? textColor, Color? iconColor}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      onTap: onTap,
      dense: true,
      leading: Icon(icon, color: iconColor ?? (isDarkMode ? DarkColors.textSecondary : Colors.black54), size: 22),
      title: Text(title, style: TextStyle(fontSize: 15, color: textColor ?? (isDarkMode ? DarkColors.textPrimary : Colors.black87))),
      trailing: trailing ?? const Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.black26),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minLeadingWidth: 24,
    );
  }

  Widget _buildDivider() => const Divider(height: 0.5, thickness: 0.5, indent: 56);
  Widget _buildZaloDivider() => const Divider(height: 0.5, thickness: 0.5, indent: 56);

  String _formatAutoDelete(BuildContext context, int seconds) {
    final common = CommonTexts.of(context, listen: false);
    if (seconds == 0) return common.off;
    if (seconds < 3600) return '${seconds ~/ 60} ${common.minute}';
    if (seconds < 86400) return '${seconds ~/ 3600} ${common.hour}';
    if (seconds < 604800) return '${seconds ~/ 86400} ${common.day}';
    return '${seconds ~/ 604800} ${common.week}';
  }
}
