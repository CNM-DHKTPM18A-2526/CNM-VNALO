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

  // ========================= BUILD =========================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final currentConv = provider.conversations.firstWhere((c) => c.id == widget.conversation.id, orElse: () => widget.conversation);
    final currentUserId = context.watch<AuthProvider>().user?.id ?? '';
    final displayName = currentConv.getDisplayName(currentUserId);
    final avatarUrl = currentConv.getDisplayAvatarUrl(currentUserId);
    final common = CommonTexts.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        title: Text(common.options, style: const TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDarkMode ? null : AppColors.appBarGradient,
            color: isDarkMode ? DarkColors.appBarBg : null,
          ),
        ),
      ),
      body: ListView(
        children: [
          // ── Header ──
          _buildHeader(displayName, avatarUrl),
          // ── Quick Actions (no gap, same white card) ──
          _buildQuickActions(currentConv),
          const SizedBox(height: 8),
          // ── Primary Settings ──
          _buildPrimarySettings(displayName, currentConv),
          const SizedBox(height: 8),
          // ── Media Section ──
          _buildMediaSection(),
          const SizedBox(height: 8),
          // ── Interaction Settings ──
          _buildInteractionSettings(displayName),
          const SizedBox(height: 8),
          // ── Conversation Settings ──
          _buildConversationSettings(currentConv),
          const SizedBox(height: 8),
          // ── Security / Danger Zone ──
          _buildSecurityActions(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ========================= HEADER =========================

  Widget _buildHeader(String name, String? avatarUrl) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 28, bottom: 20),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AvatarWidget(
            imageUrl: avatarUrl,
            name: name,
            size: 80,
            borderWidth: 0,
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  // ========================= QUICK ACTIONS =========================

  Widget _buildQuickActions(Conversation conv) {
    final common = CommonTexts.of(context);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickBtn(CupertinoIcons.search, common.searchMessagesAction, () => _showComingSoon('Tìm kiếm')),
          _buildQuickBtn(CupertinoIcons.person, common.viewProfileQuickAction, () => _showComingSoon('Trang cá nhân')),
          _buildQuickBtn(CupertinoIcons.paintbrush, common.changeWallpaperQuickAction, _openWallpaperSelection),
          _buildQuickBtn(
            conv.isMuted ? CupertinoIcons.bell_slash_fill : CupertinoIcons.bell,
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
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
              ),
              child: Icon(icon, color: const Color(0xFF555555), size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================= PRIMARY SETTINGS =========================

  Widget _buildPrimarySettings(String name, Conversation conv) {
    final common = CommonTexts.of(context);
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildTile(CupertinoIcons.pencil, common.editNicknameAction, onTap: _editNickname, showChevron: true),
          _buildDivider(),
          _buildTile(CupertinoIcons.star, common.markAsFavoriteAction,
            trailing: CupertinoSwitch(
              value: conv.isFavorite,
              onChanged: (v) => context.read<ChatProvider>().updateConversationSettings(
                conversationId: conv.id,
                isFavorite: v,
              ),
              activeTrackColor: const Color(0xFF0068FF),
            ),
          ),
          _buildDivider(),
          _buildTile(CupertinoIcons.clock, common.sharedTimelineAction, onTap: () => _showComingSoon('Nhật ký chung'), showChevron: true),
        ],
      ),
    );
  }

  // ========================= MEDIA SECTION =========================

  Widget _buildMediaSection() {
    final common = CommonTexts.of(context);
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTile(CupertinoIcons.photo_on_rectangle, common.mediaDocsLinksAction, showChevron: false),
          if (_isLoadingMedia)
            const Padding(
              padding: EdgeInsets.only(left: 56, bottom: 16),
              child: CupertinoActivityIndicator(),
            )
          else if (_recentMedia.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 56, bottom: 16, top: 2),
              child: Text(
                common.noSharedMediaNote,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else
            Container(
              height: 72,
              padding: const EdgeInsets.only(left: 56, bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recentMedia.length.clamp(0, 4),
                      itemBuilder: (context, index) {
                        final m = _recentMedia[index];
                        return Container(
                          margin: const EdgeInsets.only(right: 4),
                          width: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.grey.shade200,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CachedNetworkImage(
                            imageUrl: m.mediaUrl ?? '',
                            fit: BoxFit.cover,
                            placeholder: (ctx, url) => Container(color: Colors.grey.shade200),
                            errorWidget: (ctx, url, err) => const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showComingSoon('Kho tư liệu'),
                    child: Container(
                      width: 44,
                      height: 72,
                      margin: const EdgeInsets.only(left: 4, right: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.arrow_forward, color: Color(0xFF0068FF), size: 22),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ========================= INTERACTION SETTINGS =========================

  Widget _buildInteractionSettings(String name) {
    final common = CommonTexts.of(context);
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildTile(CupertinoIcons.person_2, common.createGroupWithLabel(name), showChevron: false),
          _buildDivider(),
          _buildTile(CupertinoIcons.person_badge_plus, common.addToGroupLabel(name), showChevron: false),
          _buildDivider(),
          _buildTile(CupertinoIcons.person_2_fill, common.viewSharedGroupsAction, showChevron: false),
        ],
      ),
    );
  }

  // ========================= CONVERSATION SETTINGS =========================

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
              activeTrackColor: const Color(0xFF0068FF),
            ),
          ),
          _buildDivider(),
          _buildTile(CupertinoIcons.eye_slash, common.hideConversationAction,
            trailing: CupertinoSwitch(
              value: conv.isHidden,
              onChanged: (v) => context.read<ChatProvider>().updateConversationSettings(conversationId: conv.id, isHidden: v),
              activeTrackColor: const Color(0xFF0068FF),
            ),
          ),
          _buildDivider(),
          _buildTile(CupertinoIcons.phone, common.notifyCallsAction,
            trailing: CupertinoSwitch(
              value: conv.notifyCall,
              onChanged: (v) => context.read<ChatProvider>().updateConversationSettings(conversationId: conv.id, notifyCall: v),
              activeTrackColor: const Color(0xFF0068FF),
            ),
          ),
          _buildDivider(),
          _buildTile(CupertinoIcons.time, common.autoDeleteMessages,
            onTap: _showAutoDeletePicker,
            subtitle: _formatAutoDelete(context, conv.autoDeleteSeconds),
            showChevron: false,
          ),
          _buildDivider(),
          _buildTile(CupertinoIcons.person_crop_circle, common.personalSettingsAction, showChevron: false),
        ],
      ),
    );
  }

  // ========================= SECURITY / DANGER ZONE =========================

  Widget _buildSecurityActions() {
    final common = CommonTexts.of(context);
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildTile(CupertinoIcons.exclamationmark_triangle, common.reportUserAction, showChevron: false),
          _buildDivider(),
          _buildTile(CupertinoIcons.nosign, common.blockMgmtAction, showChevron: true),
          _buildDivider(),
          _buildTile(CupertinoIcons.clock, common.chatStorageAction, showChevron: false),
          _buildDivider(),
          _buildTile(CupertinoIcons.trash, common.deleteHistoryAction,
            textColor: const Color(0xFFE04040),
            iconColor: const Color(0xFFE04040),
            onTap: _deleteHistory,
            showChevron: false,
          ),
        ],
      ),
    );
  }

  // ========================= SHARED WIDGETS =========================

  Widget _buildTile(
    IconData icon,
    String title, {
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
    Color? iconColor,
    String? subtitle,
    bool showChevron = false,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Widget? trailingWidget;
    if (trailing != null) {
      trailingWidget = trailing;
    } else if (showChevron) {
      trailingWidget = Icon(CupertinoIcons.chevron_right, size: 15, color: Colors.grey.shade400);
    } else {
      trailingWidget = null;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isDarkMode ? DarkColors.surface : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? (isDarkMode ? DarkColors.textSecondary : const Color(0xFF666666)), size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      color: textColor ?? (isDarkMode ? DarkColors.textPrimary : const Color(0xFF1A1A1A)),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ],
              ),
            ),
            if (trailingWidget != null) trailingWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() => Divider(
    height: 0.5,
    thickness: 0.5,
    indent: 54,
    color: Colors.grey.shade200,
  );

  String _formatAutoDelete(BuildContext context, int seconds) {
    final common = CommonTexts.of(context, listen: false);
    if (seconds == 0) return common.off;
    if (seconds < 3600) return '${seconds ~/ 60} ${common.minute}';
    if (seconds < 86400) return '${seconds ~/ 3600} ${common.hour}';
    if (seconds < 604800) return '${seconds ~/ 86400} ${common.day}';
    return '${seconds ~/ 604800} ${common.week}';
  }
}
