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

  /// Show the pin-limit dialog when 3 pins are already reached.
  /// Called from message_bubble.dart when user tries to pin a 4th message.
  static void showPinLimitDialog(BuildContext context, Message newMessage) {
    final chat = context.read<ChatProvider>();
    final pins = chat.getPinnedMessagesForConversation(newMessage.conversationId);
    final common = CommonTexts.of(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PinLimitDialog(
        pins: pins,
        newMessage: newMessage,
        common: common,
        isDarkMode: isDarkMode,
      ),
    );
  }
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

        // Clamp _currentPage to valid range
        if (_currentPage >= pins.length) {
          _currentPage = pins.length - 1;
        }

        return Container(
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
                // 1. Tappable area: icon + text (navigate to message)
                Expanded(
                  child: InkWell(
                    onTap: () => widget.onMessageTap(pins[_currentPage].id),
                    child: Row(
                      children: [
                        // Blue Icon Circle
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
                        // Text Content (Title & Subtitle)
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: pins.length,
                            onPageChanged: (index) => setState(() => _currentPage = index),
                            itemBuilder: (context, index) {
                              final msg = pins[index];
                              final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.id;
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
                        // Thumbnail preview (if image)
                        if (pins[_currentPage].messageType == MessageType.IMAGE && pins[_currentPage].mediaUrl != null)
                          Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              image: DecorationImage(
                                image: NetworkImage(pins[_currentPage].mediaUrl!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // 2. Tappable area: arrow button (show all pins)
                Container(
                  height: 24,
                  width: 1,
                  color: isDarkMode ? Colors.white10 : Colors.black12,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                InkWell(
                  onTap: () => _showAllPins(context, pins),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pins.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              '+${pins.length - 1}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 1),
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
      },
    );
  }

  void _showAllPins(BuildContext context, List<Message> pins) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context, listen: false);
    final chat = context.read<ChatProvider>();
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.id;
    final conversation = chat.conversations.where((c) => c.id == widget.conversationId).firstOrNull;

    String resolveSenderName(Message msg) {
      final member = conversation?.members.where((m) => m.userId == msg.senderId).firstOrNull;
      return msg.senderId == currentUserId
          ? common.you
          : (member?.nickname ?? member?.user?.displayName ?? msg.senderName ?? common.unknownUser);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? DarkColors.surface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    common.pinnedListTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Pinned list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: pins.length,
                itemBuilder: (_, index) {
                  final msg = pins[index];
                  final senderName = resolveSenderName(msg);

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.textsms_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      _getMessagePreview(msg, common),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      '${common.messagesTab} ${common.language == AppLanguage.vi ? "của" : "from"} $senderName',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: _buildThumbnail(msg),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      widget.onMessageTap(msg.id);
                    },
                  );
                },
              ),
            ),
            // Bottom bar: Edit + Collapse
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: isDarkMode ? Colors.white10 : Colors.black12),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(sheetContext);
                    },
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: isDarkMode ? Colors.white70 : Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          common.editAction,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetContext),
                    child: Row(
                      children: [
                        Text(
                          common.collapseAction,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_up_rounded, size: 18, color: isDarkMode ? Colors.white70 : Colors.black54),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildThumbnail(Message msg) {
    if (msg.messageType == MessageType.IMAGE && msg.mediaUrl != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          image: DecorationImage(
            image: NetworkImage(msg.mediaUrl!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Pin Limit Dialog (shown when user tries to pin a 4th message) ───

class _PinLimitDialog extends StatefulWidget {
  final List<Message> pins;
  final Message newMessage;
  final CommonTexts common;
  final bool isDarkMode;

  const _PinLimitDialog({
    required this.pins,
    required this.newMessage,
    required this.common,
    required this.isDarkMode,
  });

  @override
  State<_PinLimitDialog> createState() => _PinLimitDialogState();
}

class _PinLimitDialogState extends State<_PinLimitDialog> {
  late List<Message> _currentPins;

  @override
  void initState() {
    super.initState();
    _currentPins = List.from(widget.pins);
  }

  String _getPreview(Message msg) {
    if (msg.status == MessageStatus.RECALLED) return widget.common.msgRecalled;
    switch (msg.messageType) {
      case MessageType.IMAGE:
        return '[${widget.common.imageLabel}]';
      case MessageType.VIDEO:
        return '[${widget.common.videoAction}]';
      case MessageType.FILE:
        return '[${widget.common.documentLabel}] ${msg.content ?? ""}';
      case MessageType.AUDIO:
        return '[${widget.common.audioAction}]';
      case MessageType.STICKER:
        return '[Sticker]';
      default:
        return msg.content ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.read<ChatProvider>();
    final canAddNew = _currentPins.length < 3;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: widget.isDarkMode ? DarkColors.surface : Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          // Pin icon
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.push_pin_rounded,
              color: Color(0xFFFF9800),
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          // Title text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.common.pinLimitTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: widget.isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Pinned messages list
          Flexible(
            child: Consumer<ChatProvider>(
              builder: (context, chatConsumer, _) {
                _currentPins = chatConsumer.getPinnedMessagesForConversation(widget.newMessage.conversationId);
                
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _currentPins.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final msg = _currentPins[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.textsms_outlined, size: 16, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          // Preview text
                          Expanded(
                            child: Text(
                              _getPreview(msg),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: widget.isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                              ),
                            ),
                          ),
                          // Thumbnail (if image)
                          if (msg.messageType == MessageType.IMAGE && msg.mediaUrl != null)
                            Container(
                              width: 36,
                              height: 36,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                image: DecorationImage(
                                  image: NetworkImage(msg.mediaUrl!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          // Remove button
                          GestureDetector(
                            onTap: () {
                              chat.unpinMessage(msg.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade400, width: 1.5),
                              ),
                              child: Icon(
                                Icons.remove,
                                size: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // New message to pin (preview)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (widget.isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.textsms_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getPreview(widget.newMessage),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Consumer<ChatProvider>(
              builder: (context, chatConsumer, _) {
                final livePins = chatConsumer.getPinnedMessagesForConversation(widget.newMessage.conversationId);
                final canAdd = livePins.length < 3;

                return Row(
                  children: [
                    // Close button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          widget.common.closeAction,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Add new pin button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: canAdd
                            ? () {
                                chat.pinMessage(widget.newMessage.id);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(widget.common.pinActionTag)),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: canAdd ? AppColors.primary : Colors.grey.shade300,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Text(
                          widget.common.addNewPin,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
