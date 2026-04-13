import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/models/message_model.dart';

class MessageActionMenu extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Function(String action) onAction;

  const MessageActionMenu({
    super.key,
    required this.message,
    required this.isMine,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? DarkColors.surface : Colors.white;
    final common = CommonTexts.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Emoji Bar
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildEmoji('❤️'),
              _buildEmoji('👍'),
              _buildEmoji('🤣'),
              _buildEmoji('😲'),
              _buildEmoji('😭'),
              _buildEmoji('😡'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 2. Action Grid Box
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                crossAxisSpacing: 0,
                mainAxisSpacing: 24,
                childAspectRatio: 0.9,
                children: [
                  _buildActionItem(context, 'reply', common.replyAction, Icons.reply_outlined, const Color(0xFF9C27B0)),
                  _buildActionItem(context, 'forward', common.forwardAction, Icons.forward_rounded, const Color(0xFF2196F3)),
                  _buildActionItem(context, 'save', common.saveToDocsAction, Icons.snippet_folder_outlined, const Color(0xFF03A9F4)),
                  _buildActionItem(context, 'copy', common.copyAction, Icons.copy_all_outlined, const Color(0xFF1E88E5)),
                  
                  _buildActionItem(context, 'pin', common.pinActionTag, Icons.push_pin_outlined, const Color(0xFFFF9800)),
                  _buildActionItem(context, 'reminder', common.reminderAction, Icons.access_time_rounded, const Color(0xFFE65100)),
                  _buildActionItem(context, 'multi', common.selectMultiAction, Icons.check_circle_outline_rounded, const Color(0xFF1976D2)),
                  _buildActionItem(context, 'quick', common.quickReplyAction, Icons.bolt_rounded, const Color(0xFF1976D2)),
                  
                  _buildActionItem(context, 'translate', common.translateAction, Icons.translate_rounded, const Color(0xFF4CAF50), labelExtra: common.newTagLabel),
                  _buildActionItem(context, 'tts', common.speakAction, Icons.volume_up_outlined, const Color(0xFF9C27B0), labelExtra: common.newTagLabel),
                  _buildActionItem(context, 'info', common.detailsAction, Icons.info_outline_rounded, Colors.blueGrey),
                  _buildActionItem(context, 'delete', common.delete, Icons.delete_outline_rounded, Colors.redAccent),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmoji(String emoji) {
    return GestureDetector(
      onTap: () => onAction('emoji_$emoji'),
      child: Text(emoji, style: const TextStyle(fontSize: 28)),
    );
  }

  Widget _buildActionItem(
    BuildContext context, 
    String actionId, 
    String label, 
    IconData icon, 
    Color color,
    {String? labelExtra}
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onAction(actionId);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 28),
              if (labelExtra != null)
                Positioned(
                  top: -6,
                  right: -14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      labelExtra,
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
