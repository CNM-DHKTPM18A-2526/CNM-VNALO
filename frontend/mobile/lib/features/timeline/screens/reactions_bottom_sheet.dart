import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/contacts/providers/contact_provider.dart';
import 'package:vnalo_mobile/services/content_service.dart';

const _reactionEmojis = {
  'LOVE': '❤️',
  'HAHA': '😂',
  'WOW': '😮',
  'SAD': '😢',
  'ANGRY': '😡',
  'LIKE': '👍',
};

class ReactionsBottomSheet extends StatefulWidget {
  final String postId;
  final int likeCount;

  const ReactionsBottomSheet({
    super.key,
    required this.postId,
    required this.likeCount,
  });

  @override
  State<ReactionsBottomSheet> createState() => _ReactionsBottomSheetState();
}

class _ReactionsBottomSheetState extends State<ReactionsBottomSheet> {
  List<Map<String, dynamic>> _friendLikers = [];
  int _othersCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLikers();
  }

  Future<void> _loadLikers() async {
    final contentService = context.read<ContentService>();
    final likers = await contentService.getPostLikers(widget.postId);
    if (mounted) {
      final auth = context.read<AuthProvider>();
      final friends = context.read<ContactProvider>().friends.map((e) => e.id).toSet();

      final friendLikers = <Map<String, dynamic>>[];
      int othersCount = 0;

      for (var liker in likers) {
        final userId = liker['userId']?.toString() ?? liker['authorId']?.toString() ?? '';
        if (userId == auth.user?.id || friends.contains(userId)) {
          friendLikers.add(liker);
        } else {
          othersCount++;
        }
      }

      setState(() {
        _friendLikers = friendLikers;
        _othersCount = othersCount;
        _loading = false;
      });
    }
  }

  String _resolveUserName(String userId) {
    final auth = context.read<AuthProvider>();
    if (userId == auth.user?.id) return auth.user?.displayName ?? userId;
    final user = context.read<ContactProvider>().getUserById(userId);
    return user?.displayName ?? userId;
  }

  String? _resolveAvatar(String userId) {
    final auth = context.read<AuthProvider>();
    if (userId == auth.user?.id) return auth.user?.avatarUrl;
    final user = context.read<ContactProvider>().getUserById(userId);
    return user?.avatarUrl;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.grey.shade600;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${widget.likeCount} người bày tỏ cảm xúc',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),

          // Sub-title
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Bạn chỉ xem được cảm xúc của bạn bè Zalo',
              style: TextStyle(fontSize: 12, color: subColor),
            ),
          ),

          // Likers list
          Flexible(
            child: _loading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ))
                : _friendLikers.isEmpty && _othersCount == 0
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'Chưa có ai bày tỏ cảm xúc',
                          style: TextStyle(color: subColor, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _friendLikers.length + (_othersCount > 0 ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _friendLikers.length) {
                            return _buildOthersRow(isDark, textColor, bg);
                          }

                          final liker = _friendLikers[index];
                          final userId = liker['userId']?.toString() ?? liker['authorId']?.toString() ?? '';
                          final reactionType = liker['reactionType']?.toString() ?? 'LOVE';
                          final emoji = _reactionEmojis[reactionType] ?? '❤️';
                          final name = _resolveUserName(userId);
                          final avatar = _resolveAvatar(userId);

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Row(
                              children: [
                                // Avatar with emoji badge
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    AvatarWidget(imageUrl: avatar, name: name, size: 46),
                                    Positioned(
                                      bottom: -4,
                                      right: -4,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: bg,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(emoji, style: const TextStyle(fontSize: 13)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                // Message icon
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 22,
                                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOthersRow(bool isDark, Color textColor, Color bg) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Bạn không thể xem hồ sơ khi chưa kết bạn với người này.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF4A4A4A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.only(bottom: 40, left: 40, right: 40),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Unknown user avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: isDark ? Colors.white12 : const Color(0xFFD6DDE7),
                  child: Icon(Icons.person, color: isDark ? Colors.white54 : Colors.white, size: 36),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Text('?', style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.bold, 
                    color: isDark ? Colors.white70 : Colors.white,
                  )),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '$_othersCount người khác',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
