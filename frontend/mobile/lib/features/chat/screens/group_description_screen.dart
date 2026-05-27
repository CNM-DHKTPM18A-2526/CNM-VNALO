import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/core/widgets/group_avatar.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';

class GroupDescriptionScreen extends StatefulWidget {
  final Conversation conversation;

  const GroupDescriptionScreen({super.key, required this.conversation});

  @override
  State<GroupDescriptionScreen> createState() => _GroupDescriptionScreenState();
}

class _GroupDescriptionScreenState extends State<GroupDescriptionScreen> {
  late TextEditingController _controller;
  bool _isEditing = false;
  bool _isSaving = false;
  late bool _startedEmpty;

  @override
  void initState() {
    super.initState();
    final description = widget.conversation.description ?? '';
    _controller = TextEditingController(text: description);
    _startedEmpty = description.isEmpty;

    final userId = context.read<ChatProvider>().currentUserId;
    final myMember = widget.conversation.members.firstWhere(
      (m) => m.userId == userId,
      orElse: () => widget.conversation.members.isNotEmpty ? widget.conversation.members.first : ConversationMember(conversationId: widget.conversation.id, userId: userId ?? '', joinedAt: DateTime.now()),
    );
    final isAdminOrDeputy = myMember.role == MemberRole.ADMIN || myMember.role == MemberRole.DEPUTY;
    final hasEditPermission = widget.conversation.allowMemberEditInfo || isAdminOrDeputy;

    _isEditing = _startedEmpty && hasEditPermission;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.5 - 25,
        left: MediaQuery.of(context).size.width * 0.15,
        right: MediaQuery.of(context).size.width * 0.15,
        child: Material(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  Future<void> _saveDescription() async {
    final text = _controller.text.trim();
    setState(() => _isSaving = true);

    try {
      await context.read<ChatProvider>().updateGroupInfo(
            widget.conversation.id,
            description: text,
          );

      if (mounted) {
        _showToast(context, 'Đã cập nhật thông tin nhóm');
        setState(() {
          _isSaving = false;
          _isEditing = false;
          _startedEmpty = text.isEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
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
    final appBarBg = isDarkMode ? DarkColors.appBarBg : Colors.transparent;

    final userId = provider.currentUserId;
    final myMember = conv.members.firstWhere(
      (m) => m.userId == userId,
      orElse: () => ConversationMember(
        conversationId: conv.id,
        userId: userId ?? '',
        role: MemberRole.MEMBER,
        joinedAt: DateTime.now(),
      ),
    );
    final isAdminOrDeputy = myMember.role == MemberRole.ADMIN || myMember.role == MemberRole.DEPUTY;
    final hasEditPermission = conv.allowMemberEditInfo || isAdminOrDeputy;

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : Colors.white,
      appBar: AppBar(
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        elevation: 0,
        forceMaterialTransparency: !isDarkMode,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: false,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.appBarGradient,
                ),
              ),
        leading: _isEditing
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  if (_startedEmpty) {
                    Navigator.pop(context);
                  } else {
                    setState(() {
                      _isEditing = false;
                      _controller.text = conv.description ?? '';
                    });
                  }
                },
              )
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text(
          'Mô tả nhóm',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _saveDescription,
              child: const Text(
                'LƯU',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            )
          else if (hasEditPermission)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Group Header Info ----
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      // Avatar
                      (conv.avatarUrl != null && conv.avatarUrl!.isNotEmpty)
                          ? AvatarWidget(
                              imageUrl: conv.avatarUrl,
                              name: conv.title ?? 'Group',
                              size: 44,
                            )
                          : GroupAvatar(
                              members: conv.members
                                  .where((m) =>
                                      m.userId !=
                                      context.read<ChatProvider>().currentUserId)
                                  .take(3)
                                  .map((m) => (
                                        imageUrl: m.user?.avatarUrl,
                                        name: m.user?.displayName ?? 'User'
                                      ))
                                  .toList(),
                              totalMemberCount: conv.members.length,
                              size: 44,
                            ),
                      const SizedBox(width: 14),
                      // Group Name
                      Expanded(
                        child: Text(
                          conv.title ?? 'Nhóm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Divider
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: isDarkMode ? DarkColors.divider : Colors.grey.shade200,
                ),
                
                // ---- Description Body ----
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: _isEditing
                      ? TextField(
                          controller: _controller,
                          maxLines: null,
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          decoration: const InputDecoration(
                            hintText:
                                'Thêm mục đích, nội quy hay chủ đề chính của nhóm',
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                          ),
                        )
                      : Text(
                          (conv.description != null && conv.description!.isNotEmpty)
                              ? conv.description!
                              : 'Chưa có mô tả nhóm',
                          style: TextStyle(
                            fontSize: 15,
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                            height: 1.4,
                            fontStyle: (conv.description == null || conv.description!.isEmpty) ? FontStyle.italic : null,
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
