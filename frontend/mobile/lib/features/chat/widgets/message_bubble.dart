import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        isMine ? LightColors.chatBubbleSent : LightColors.chatBubbleReceived;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMine ? 60 : 0,
          right: isMine ? 0 : 60,
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
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content ?? '',
              style: TextStyle(
                fontSize: 15,
                color: isMine ? Colors.white : LightColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormatter.time(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isMine ? Colors.white70 : LightColors.textSecondary,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  if (message.status == MessageStatus.SENDING) ...[
                    const Icon(Icons.schedule, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    const Text(
                      'Đang gửi...',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]
                  else if (message.status == MessageStatus.FAILED)
                    GestureDetector(
                      onTap: onRetry,
                      child: const Icon(Icons.error_outline, size: 14, color: Colors.orangeAccent),
                    )
                  else
                    Icon(
                      message.status == MessageStatus.DELIVERED
                          ? Icons.done_all
                          : Icons.done,
                      size: 14,
                      color:
                          message.status == MessageStatus.DELIVERED
                              ? Colors.lightBlueAccent
                              : Colors.white70,
                    ),
                ],
              ],
            ),
            if (isMine && message.status == MessageStatus.FAILED)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: GestureDetector(
                  onTap: onRetry,
                  child: const Text(
                    'Gửi lại',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
