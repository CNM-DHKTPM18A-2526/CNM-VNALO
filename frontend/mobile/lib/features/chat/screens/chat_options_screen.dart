import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/wallpaper_selection_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/media_viewer_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/create_group_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/add_friend_to_group_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/shared_groups_screen.dart';
import 'package:vnalo_mobile/services/block_service.dart';

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
    if (widget.conversation.members.isEmpty) return;
    
    final otherMember = widget.conversation.members.firstWhere(
      (m) => m.userId != currentUserId,
      orElse: () => widget.conversation.members.first,
    );

    final controller = TextEditingController(text: otherMember.nickname ?? '');
    final common = CommonTexts.of(context, listen: false);

    final newNickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(common.editNicknameAction),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: common.nicknamePlaceholder,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(common.cancel, style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(common.save),
          ),
        ],
      ),
    );

    if (newNickname != null) {
      try {
        await context.read<ChatProvider>().updateMemberNickname(widget.conversation.id, otherMember.userId, newNickname);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đổi tên gợi nhớ thành công')));
        }
      } catch (e) {
        debugPrint('Failed to update nickname: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể đổi tên. Vui lòng thử lại.')));
        }
      }
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
    final otherMember = currentConv.members.firstWhere(
      (m) => m.userId != currentUserId,
      orElse: () => currentConv.members.isNotEmpty ? currentConv.members.first : ConversationMember(conversationId: currentConv.id, userId: 'unknown', joinedAt: DateTime.now()),
    );
    final displayName = currentConv.getDisplayName(currentUserId);
    final avatarUrl = currentConv.getDisplayAvatarUrl(currentUserId);
    final common = CommonTexts.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        title: Text(common.options, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        forceMaterialTransparency: !isDarkMode,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: false,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
              ),
      ),
      body: ListView(
        children: [
          // ── Header ──
          _buildHeader(displayName, avatarUrl, isDarkMode),
          // ── Quick Actions (no gap, same white card) ──
          _buildQuickActions(currentConv, isDarkMode),
          const SizedBox(height: 8),
          // ── Primary Settings ──
          _buildPrimarySettings(displayName, currentConv, isDarkMode),
          const SizedBox(height: 8),
          // ── Media Section ──
          _buildMediaSection(isDarkMode),
          const SizedBox(height: 8),
          // ── Interaction Settings ──
          _buildInteractionSettings(displayName, otherMember.userId, isDarkMode),
          const SizedBox(height: 8),
          // ── Conversation Settings ──
          _buildConversationSettings(currentConv, isDarkMode),
          const SizedBox(height: 8),
          // ── Security / Danger Zone ──
          _buildSecurityActions(isDarkMode),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ========================= HEADER =========================

  Widget _buildHeader(String name, String? avatarUrl, bool isDarkMode) {
    return Container(
      color: isDarkMode ? DarkColors.surface : Colors.white,
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
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  // ========================= QUICK ACTIONS =========================

  Widget _buildQuickActions(Conversation conv, bool isDarkMode) {
    final common = CommonTexts.of(context);

    return Container(
      color: isDarkMode ? DarkColors.surface : Colors.white,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickBtn(CupertinoIcons.search, common.searchMessagesAction, () => _showComingSoon('Tìm kiếm'), isDarkMode),
          _buildQuickBtn(CupertinoIcons.person, common.viewProfileQuickAction, () => _showComingSoon('Trang cá nhân'), isDarkMode),
          _buildQuickBtn(CupertinoIcons.photo, common.changeWallpaperQuickAction, _openWallpaperSelection, isDarkMode),
          _buildQuickBtn(
            conv.isMuted ? CupertinoIcons.bell_slash_fill : CupertinoIcons.bell,
            common.muteNotifsQuickAction,
            () => context.read<ChatProvider>().updateConversationSettings(
              conversationId: conv.id,
              isMuted: !conv.isMuted,
            ),
            isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickBtn(IconData icon, String label, VoidCallback onTap, bool isDarkMode) {
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
                border: Border.all(color: isDarkMode ? DarkColors.divider : const Color(0xFFE0E0E0), width: 1),
              ),
              child: Icon(icon, color: isDarkMode ? DarkColors.textPrimary : const Color(0xFF555555), size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: isDarkMode ? DarkColors.textSecondary : const Color(0xFF333333),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================= PRIMARY SETTINGS =========================

  Widget _buildPrimarySettings(String name, Conversation conv, bool isDarkMode) {
    final common = CommonTexts.of(context);
    return Container(
      color: isDarkMode ? DarkColors.surface : Colors.white,
      child: Column(
        children: [
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
          _buildTile(CupertinoIcons.clock, common.sharedTimelineAction, onTap: () => _showComingSoon('Nhật ký chung'), showChevron: true),
        ],
      ),
    );
  }

  void _openMediaViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaViewerScreen(
          conversationId: widget.conversation.id,
          conversationName: widget.conversation.getDisplayName(context.read<AuthProvider>().user?.id ?? ''),
        ),
      ),
    );
  }

  // ========================= MEDIA SECTION =========================

  Widget _buildMediaSection(bool isDarkMode) {
    final common = CommonTexts.of(context);
    return Container(
      color: isDarkMode ? DarkColors.surface : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTile(CupertinoIcons.photo_on_rectangle, common.mediaDocsLinksAction, showChevron: false, onTap: _openMediaViewer),
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
                style: TextStyle(color: isDarkMode ? DarkColors.textHint : Colors.grey.shade500, fontSize: 13),
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
                        return GestureDetector(
                          onTap: _openMediaViewer,
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            width: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: isDarkMode ? DarkColors.scaffold : Colors.grey.shade200,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: CachedNetworkImage(
                              imageUrl: m.mediaUrl ?? '',
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) => Container(color: isDarkMode ? Colors.white10 : Colors.grey.shade200),
                              errorWidget: (ctx, url, err) => const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: _openMediaViewer,
                    child: Container(
                      width: 44,
                      height: 72,
                      margin: const EdgeInsets.only(left: 4, right: 16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? DarkColors.scaffold : const Color(0xFFF0F6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.arrow_forward, color: isDarkMode ? DarkColors.textPrimary : const Color(0xFF0068FF), size: 22),
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

  Widget _buildInteractionSettings(String name, String otherUserId, bool isDarkMode) {
    final common = CommonTexts.of(context);
    return Container(
      color: isDarkMode ? DarkColors.surface : Colors.white,
      child: Column(
        children: [
          _buildTile(CupertinoIcons.person_2, common.createGroupWithLabel(name),
            onTap: () => _createGroupWith(otherUserId, name)),
          _buildDivider(),
          _buildTile(CupertinoIcons.person_badge_plus, common.addToGroupLabel(name),
            onTap: () => _addToGroup(otherUserId, name)),
          _buildDivider(),
          _buildTile(CupertinoIcons.person_2_fill, common.viewSharedGroupsAction,
            onTap: () => _viewSharedGroups(otherUserId, name)),
        ],
      ),
    );
  }

  void _createGroupWith(String userId, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupScreen(preselectedUserId: userId, preselectedUserName: name),
      ),
    );
  }

  void _addToGroup(String userId, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFriendToGroupScreen(targetUserId: userId, targetUserName: name),
      ),
    );
  }

  void _viewSharedGroups(String userId, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SharedGroupsScreen(targetUserId: userId, targetUserName: name),
      ),
    );
  }

  // ========================= CONVERSATION SETTINGS =========================

  Widget _buildConversationSettings(Conversation conv, bool isDarkMode) {
    final common = CommonTexts.of(context);
    return Container(
      color: isDarkMode ? DarkColors.surface : Colors.white,
      child: Column(
        children: [
          _buildTile(CupertinoIcons.pin, common.pinConversationAction,
            trailing: CupertinoSwitch(
              value: conv.isPinned,
              onChanged: (v) => context.read<ChatProvider>().updateConversationSettings(conversationId: conv.id, isPinned: v),
              activeTrackColor: AppColors.primary,
            ),
          ),
          _buildDivider(),
          _buildTile(CupertinoIcons.eye_slash, common.hideConversationAction,
            trailing: CupertinoSwitch(
              value: conv.isHidden,
              onChanged: (v) => context.read<ChatProvider>().updateConversationSettings(conversationId: conv.id, isHidden: v),
              activeTrackColor: AppColors.primary,
            ),
          ),
          _buildDivider(),
          _buildTile(CupertinoIcons.phone, common.notifyCallsAction,
            trailing: CupertinoSwitch(
              value: conv.notifyCall,
              onChanged: (v) => context.read<ChatProvider>().updateConversationSettings(conversationId: conv.id, notifyCall: v),
              activeTrackColor: AppColors.primary,
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

  Future<void> _openBlockManagement(String otherUserId, String displayName) async {
    final blockService = context.read<BlockService>();

    bool youBlocked = false;
    bool blockedYou = false;

    // Default when currently blocked (backend defaults): messages=true, calls=true
    bool blockMessages = true;
    bool blockCalls = true;

    try {
      final res = await blockService.checkBlockStatus(otherUserId);
      final data = res['data'];
      if (data is Map) {
        youBlocked = data['youBlocked'] == true;
        blockedYou = data['blockedYou'] == true;
      }

      if (youBlocked) {
        // Fetch current flags from /blocks list (best effort)
        final listRes = await blockService.getBlockedUsers(page: 0, size: 50);
        final listData = listRes['data'];
        final content = listData is Map<String, dynamic> ? (listData['content'] as List?) : null;
        final match = (content ?? const [])
            .whereType<Map>()
            .cast<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => e['userId']?.toString() == otherUserId)
            .toList();
        if (match.isNotEmpty) {
          final m = match.first;
          blockMessages = m['blockMessages'] == true;
          blockCalls = m['blockCalls'] == true;
        }
      } else {
        // Not blocked yet: start all off
        blockMessages = false;
        blockCalls = false;
      }
    } catch (e) {
      debugPrint('[ChatOptions] checkBlockStatus error: $e');
    }

    if (!mounted) return;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> applyChange() async {
              final anyOn = blockMessages || blockCalls;
              try {
                if (!anyOn) {
                  if (youBlocked) {
                    await blockService.unblockUser(otherUserId);
                    youBlocked = false;
                  }
                } else {
                  if (!youBlocked) {
                    await blockService.blockUser(
                      otherUserId,
                      blockMessages: blockMessages,
                      blockCalls: blockCalls,
                    );
                    youBlocked = true;
                  } else {
                    await blockService.updateBlock(
                      otherUserId,
                      blockMessages: blockMessages,
                      blockCalls: blockCalls,
                    );
                  }
                }
              } catch (e) {
                debugPrint('[ChatOptions] applyChange error: $e');
              }
            }

            return CupertinoActionSheet(
              title: Text(displayName),
              message: Text(blockedYou ? 'Người này đã chặn bạn' : 'Quản lý quyền chặn cho người dùng này'),
              actions: [
                CupertinoActionSheetAction(
                  onPressed: () {},
                  isDefaultAction: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Chặn tin nhắn'),
                      CupertinoSwitch(
                        value: blockMessages,
                        onChanged: (v) async {
                          setSheetState(() => blockMessages = v);
                          await applyChange();
                        },
                      ),
                    ],
                  ),
                ),
                CupertinoActionSheetAction(
                  onPressed: () {},
                  isDefaultAction: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Chặn cuộc gọi'),
                      CupertinoSwitch(
                        value: blockCalls,
                        onChanged: (v) async {
                          setSheetState(() => blockCalls = v);
                          await applyChange();
                        },
                      ),
                    ],
                  ),
                ),
                if (youBlocked)
                  CupertinoActionSheetAction(
                    isDestructiveAction: true,
                    onPressed: () async {
                      await blockService.unblockUser(otherUserId);
                      setSheetState(() {
                        youBlocked = false;
                        blockMessages = false;
                        blockCalls = false;
                      });
                    },
                    child: const Text('Bỏ chặn'),
                  ),
              ],
              cancelButton: CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSecurityActions(bool isDarkMode) {
    final common = CommonTexts.of(context);
    return Container(
      color: isDarkMode ? DarkColors.surface : Colors.white,
      child: Column(
        children: [
          _buildTile(CupertinoIcons.exclamationmark_triangle, common.reportUserAction, showChevron: false),
          _buildDivider(),
          _buildTile(
            CupertinoIcons.nosign,
            common.blockMgmtAction,
            showChevron: true,
            onTap: () {
              final provider = context.read<ChatProvider>();
              final currentConv = provider.conversations.firstWhere((c) => c.id == widget.conversation.id, orElse: () => widget.conversation);
              final currentUserId = context.read<AuthProvider>().user?.id ?? '';
              final otherMember = currentConv.members.firstWhere(
                (m) => m.userId != currentUserId,
                orElse: () => currentConv.members.isNotEmpty
                    ? currentConv.members.first
                    : ConversationMember(conversationId: currentConv.id, userId: 'unknown', joinedAt: DateTime.now()),
              );
              final displayName = currentConv.getDisplayName(currentUserId);
              _openBlockManagement(otherMember.userId, displayName);
            },
          ),
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
      trailingWidget = Icon(CupertinoIcons.chevron_right, size: 15, color: isDarkMode ? DarkColors.textHint : Colors.grey.shade400);
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
                    Text(subtitle, style: TextStyle(fontSize: 12, color: isDarkMode ? DarkColors.textHint : Colors.grey.shade500)),
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

  Widget _buildDivider() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 70,
      color: isDarkMode ? DarkColors.divider : AppColors.itemDivider,
    );
  }

  String _formatAutoDelete(BuildContext context, int seconds) {
    final common = CommonTexts.of(context, listen: false);
    if (seconds == 0) return common.off;
    if (seconds < 3600) return '${seconds ~/ 60} ${common.minute}';
    if (seconds < 86400) return '${seconds ~/ 3600} ${common.hour}';
    if (seconds < 604800) return '${seconds ~/ 86400} ${common.day}';
    return '${seconds ~/ 604800} ${common.week}';
  }
}
