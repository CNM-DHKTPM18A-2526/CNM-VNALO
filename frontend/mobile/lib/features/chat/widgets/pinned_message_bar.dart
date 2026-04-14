import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';

class PinnedMessageBar extends StatefulWidget {
  final String conversationId;
  final Function(String messageId) onMessageTap;

  const PinnedMessageBar({
    super.key,
    required this.conversationId,
    required this.onMessageTap,
  });

  @override
  State<PinnedMessageBar> createState() => _PinnedMessageBarState();
}

class _PinnedMessageBarState extends State<PinnedMessageBar> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _getMessagePreview(Message message, CommonTexts common) {
    if (message.status == MessageStatus.RECALLED) {
      return common.msgRecalled;
    }
    
    switch (message.messageType) {
      case MessageType.IMAGE:
        return '[${common.imageLabel}]';
      case MessageType.VIDEO:
        return '[${common.videoAction}]';
      case MessageType.FILE:
        return '[${common.documentLabel}] ${message.content ?? ""}';
      case MessageType.AUDIO:
        return '[${common.audioAction}]';
      case MessageType.STICKER:
        return '[Sticker]';
      default:
        return message.content ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);
    
    return Consumer<ChatProvider>(
      builder: (context, chat, child) {
        final pins = chat.getPinnedMessagesForConversation(widget.conversationId);
        if (pins.isEmpty) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => widget.onMessageTap(pins[_currentPage].id),
          child: Container(
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? DarkColors.surface : Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 1. Blue Icon Circle
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.textsms_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 2. Text Content (Title & Subtitle)
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pins.length,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemBuilder: (context, index) {
                      final msg = pins[index];
                      final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.id;
                      
                      // Resolve sender name from members
                      final conversation = chat.conversations.where((c) => c.id == widget.conversationId).firstOrNull;
                      final member = conversation?.members.where((m) => m.userId == msg.senderId).firstOrNull;
                      
                      final senderName = msg.senderId == currentUserId
                          ? common.you
                          : (member?.nickname ?? member?.user?.displayName ?? msg.senderName ?? common.unknownUser);
                      
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getMessagePreview(msg, common),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            '${common.messagesTab} ${common.language == AppLanguage.vi ? "của" : "from"} $senderName',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDarkMode ? Colors.white54 : Colors.black45,
                              height: 1.2,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // 3. Right Action with Divider
                Container(
                  height: 24,
                  width: 1,
                  color: isDarkMode ? Colors.white10 : Colors.black12,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 1),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  onPressed: () => _showAllPins(context, pins),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAllPins(BuildContext context, List<Message> pins) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);
    final chat = context.read<ChatProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDarkMode ? DarkColors.surface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${common.pinActionTag} (${pins.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: pins.length,
                itemBuilder: (context, index) {
                  final msg = pins[index];
                  return ListTile(
                    leading: const Icon(Icons.push_pin_outlined, size: 20),
                    title: Text(
                      _getMessagePreview(msg, common),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${msg.senderName ?? common.unknownUser} • ${_formatDate(msg.createdAt)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        chat.unpinMessage(msg.id);
                        if (pins.length <= 1) Navigator.pop(context);
                      },
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onMessageTap(msg.id);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
