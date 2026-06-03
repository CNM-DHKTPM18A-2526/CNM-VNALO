import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/contacts/providers/contact_provider.dart';
import 'package:vnalo_mobile/features/timeline/providers/post_provider.dart';
import 'package:vnalo_mobile/models/comment_model.dart';
import 'package:vnalo_mobile/services/content_service.dart';
import 'package:vnalo_mobile/services/media_service.dart';

class CommentBottomSheet extends StatefulWidget {
  final String postId;
  final int initialLikeCount;
  final bool isLiked;
  final String? myReactionType;
  final String? topLikerEmoji;

  const CommentBottomSheet({
    super.key,
    required this.postId,
    this.initialLikeCount = 0,
    this.isLiked = false,
    this.myReactionType,
    this.topLikerEmoji,
  });

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Comment> _comments = [];
  bool _loading = true;
  bool _sending = false;

  final FocusNode _focusNode = FocusNode();
  bool _showEmoji = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _controller.addListener(() {
      setState(() {});
    });
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _showEmoji = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    
    setState(() => _sending = true);
    try {
      final mediaService = context.read<MediaService>();
      final url = await mediaService.uploadFile(File(picked.path), MediaCategory.CHAT_IMAGE);
      final contentService = context.read<ContentService>();
      final comment = await contentService.createComment(
        postId: widget.postId,
        content: '[IMAGE]$url',
      );
      if (comment != null && mounted) {
        setState(() {
          _comments.insert(0, comment);
          _totalCommentCount++;
        });
        context.read<PostProvider>().incrementCommentCount(widget.postId);
      }
    } catch (e) {
      debugPrint('Upload image error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  int _totalCommentCount = 0;

  Future<void> _loadComments() async {
    final contentService = context.read<ContentService>();
    final result = await contentService.getComments(widget.postId);
    if (mounted) {
      final auth = context.read<AuthProvider>();
      final friends = context.read<ContactProvider>().friends.map((e) => e.id).toSet();

      final filteredComments = result.comments.where((c) {
        return c.authorId == auth.user?.id || friends.contains(c.authorId);
      }).toList();

      setState(() {
        _totalCommentCount = result.total;
        _comments = filteredComments;
        _loading = false;
      });
    }
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final contentService = context.read<ContentService>();
    final comment = await contentService.createComment(
      postId: widget.postId,
      content: text,
    );
    if (comment != null && mounted) {
      setState(() {
        _comments.insert(0, comment);
        _sending = false;
      });
      _controller.clear();
      // Update comment count in provider
      context.read<PostProvider>().incrementCommentCount(widget.postId);
    } else if (mounted) {
      setState(() => _sending = false);
    }
  }

  String _resolveAuthorName(String authorId) {
    final auth = context.read<AuthProvider>();
    if (authorId == auth.user?.id) return auth.user?.displayName ?? authorId;
    final user = context.read<ContactProvider>().getUserById(authorId);
    return user?.displayName ?? authorId;
  }

  String? _resolveAuthorAvatar(String authorId) {
    final auth = context.read<AuthProvider>();
    if (authorId == auth.user?.id) return auth.user?.avatarUrl;
    final user = context.read<ContactProvider>().getUserById(authorId);
    return user?.avatarUrl;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white38 : Colors.grey.shade500;
    final dividerColor = isDark ? Colors.white12 : Colors.grey.shade200;

    final viewInsets = MediaQuery.of(context).viewInsets;
    final isKeyboardOpen = viewInsets.bottom > 0;
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      height: isKeyboardOpen || _showEmoji ? screenHeight * 0.95 : screenHeight * 0.6,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Top likes row
          if (widget.initialLikeCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    widget.topLikerEmoji ?? '❤️',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    (() {
                      if (widget.isLiked) {
                        if (widget.initialLikeCount > 1) {
                          return 'Bạn và ${widget.initialLikeCount - 1} người khác';
                        } else {
                          return 'Bạn';
                        }
                      } else {
                        return '${widget.initialLikeCount} bạn';
                      }
                    })(),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          Divider(height: 1, color: dividerColor),

          // Comments list
          Expanded(
            child: _loading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ))
                : _comments.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_totalCommentCount > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                'Có $_totalCommentCount bình luận. Bạn chỉ xem được bình luận của bạn bè Zalo.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Center(child: _buildEmptyState(isDark)),
                          ),
                        ],
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _comments.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                'Có $_totalCommentCount bình luận. Bạn chỉ xem được bình luận của bạn bè Zalo.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ),
                            );
                          }
                          return _buildCommentItem(_comments[index - 1], isDark, textColor);
                        },
                      ),
          ),

          Divider(height: 1, color: dividerColor),

          // Input bar
          _buildInputBar(isDark, textColor, hintColor),

          if (_showEmoji) _buildEmojiPicker(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Tham gia bình luận hoạt động này',
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Thả sticker cho bài đăng này.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              _controller.text = '👍';
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
            },
            child: Text(
              'Thử ngay',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment, bool isDark, Color textColor) {
    final name = _resolveAuthorName(comment.authorId);
    final avatar = _resolveAuthorAvatar(comment.authorId);
    final timeStr = DateFormat('HH:mm').format(comment.createdAt);

    final isImage = comment.content.startsWith('[IMAGE]');
    final imageUrl = isImage ? comment.content.substring(7) : null;
    final isEmojiOnly = !isImage && comment.content.trim().runes.length <= 3 && !RegExp(r'[a-zA-Z0-9]').hasMatch(comment.content);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarWidget(imageUrl: avatar, name: name, size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isImage) ...[
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl!,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 200, height: 200,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ] else if (isEmojiOnly) ...[
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.content,
                    style: const TextStyle(fontSize: 36),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          comment.content,
                          style: TextStyle(fontSize: 14, color: textColor),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.favorite_border,
            size: 18,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark, Color textColor, Color hintColor) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 4,
          right: 4,
          top: 8,
          bottom: 12,
        ),
        child: Row(
          children: [
            // Emoji icon
            IconButton(
              icon: Icon(Icons.sentiment_satisfied_alt_outlined),
              color: isDark ? Colors.white38 : Colors.grey.shade600,
              iconSize: 26,
              onPressed: () {
                if (!_showEmoji) {
                  _focusNode.unfocus();
                } else {
                  _focusNode.requestFocus();
                }
                setState(() => _showEmoji = !_showEmoji);
              },
            ),
            const SizedBox(width: 8),
            // Text input
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: 4,
                  minLines: 1,
                  style: TextStyle(color: textColor, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Nhập bình luận',
                    hintStyle: TextStyle(color: hintColor, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendComment(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Photo icon
            IconButton(
              icon: Icon(Icons.image_outlined),
              color: isDark ? Colors.white38 : Colors.grey.shade600,
              iconSize: 26,
              onPressed: _pickImage,
            ),
            const SizedBox(width: 4),
            // Send icon
            _sending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.send),
                    iconSize: 26,
                    color: _controller.text.trim().isNotEmpty
                        ? AppColors.primary
                        : (isDark ? Colors.white24 : Colors.grey.shade400),
                    onPressed: _sendComment,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return SizedBox(
      height: 250,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          _controller.text += emoji.emoji;
        },
      ),
    );
  }
}
