import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final VoidCallback? onRetry;
  final bool showTime;
  final bool showStatus;
  final String? milestoneText;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onRetry,
    this.showTime = true,
    this.showStatus = false,
    this.milestoneText,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isMine
        ? (isDarkMode ? DarkColors.chatBubbleSent : LightColors.chatBubbleSent)
        : (isDarkMode ? DarkColors.chatBubbleReceived : LightColors.chatBubbleReceived);

    return Column(
      children: [
        if (milestoneText != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              milestoneText!,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? DarkColors.textHint : Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                margin: EdgeInsets.only(
                  top: showTime ? 8 : 2,
                  bottom: 2,
                  left: isMine ? 60 : 12,
                  right: isMine ? 12 : 60,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMine ? 16 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 16),
                  ),
                  boxShadow: [
                    if (!isDarkMode && !isMine)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ),
                child: Text(
                  message.content ?? '',
                  style: TextStyle(
                    fontSize: 15,
                    color: isMine
                        ? (isDarkMode ? Colors.white : const Color(0xFF1F2937))
                        : (isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary),
                  ),
                ),
              ),
              if (showTime || showStatus)
                Padding(
                  padding: EdgeInsets.only(
                    top: 2,
                    bottom: 8,
                    left: isMine ? 0 : 16,
                    right: isMine ? 16 : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showTime)
                        Text(
                          DateFormatter.time(message.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode ? DarkColors.textHint : Colors.grey.shade500,
                          ),
                        ),
                      if (isMine && showStatus && message.status == MessageStatus.DELIVERED) ...[
                        if (showTime) const SizedBox(width: 6),
                        const Icon(Icons.done_all, size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        const Text(
                          'Đã nhận',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
