import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/services/chat_service.dart';

class FriendOptionsScreen extends StatefulWidget {
  final String friendName;
  final String? friendAvatarUrl;
  final String? friendUserId;
  final Conversation? conversation;

  const FriendOptionsScreen({
    super.key,
    required this.friendName,
    this.friendAvatarUrl,
    this.friendUserId,
    this.conversation,
  });

  @override
  State<FriendOptionsScreen> createState() => _FriendOptionsScreenState();
}

class _FriendOptionsScreenState extends State<FriendOptionsScreen> {
  bool _blockActivity = false;
  late String _displayName;

  @override
  void initState() {
    super.initState();
    _displayName = widget.friendName;
  }

  void _editNickname() {
    final common = CommonTexts.of(context, listen: false);
    final controller = TextEditingController(text: _displayName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(common.editNicknameAction),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: common.nicknamePlaceholder,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(common.cancelActionLabel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _displayName = controller.text.trim());
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(common.nicknameUpdatedLocal)),
              );
            },
            child: Text(common.saveActionLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _onDone() async {
    if (widget.conversation != null) {
      context.read<ChatProvider>().loadInbox();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(conversation: widget.conversation!),
        ),
        (route) => route.isFirst,
      );
    } else if (widget.friendUserId != null && widget.friendUserId!.isNotEmpty) {
      try {
        final conversation = await context.read<ChatService>().getOrCreateDirect(widget.friendUserId!);
        if (!mounted) return;
        context.read<ChatProvider>().loadInbox();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(conversation: conversation),
          ),
          (route) => route.isFirst,
        );
      } catch (_) {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg,
        title: Text(common.friendOptionsHeader, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                AvatarWidget(
                  imageUrl: widget.friendAvatarUrl,
                  name: widget.friendName,
                  size: 52,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _editNickname,
                            child: Icon(Icons.edit, size: 18, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        common.recentlyFriended,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            child: SwitchListTile(
              title: Text(common.blockActivityFromMe),
              value: _blockActivity,
              onChanged: (val) {
                setState(() => _blockActivity = val);
              },
              activeThumbColor: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text(common.doneLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
