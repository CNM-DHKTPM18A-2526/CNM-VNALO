import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/widgets/chat_input_bar.dart';
import 'package:vnalo_mobile/features/chat/widgets/message_bubble.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';

class ChatDetailScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatDetailScreen({super.key, required this.conversation});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatProvider>().openConversation(widget.conversation.id);
    });
  }

  @override
  void dispose() {
    context.read<ChatProvider>().closeConversation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    final displayName = widget.conversation.getDisplayName(currentUserId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            AvatarWidget(
              name: displayName,
              imageUrl: widget.conversation.getDisplayAvatarUrl(currentUserId),
              size: 36,
            ),
            const SizedBox(width: 10),
            Text(displayName, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (_, chat, __) {
                final items = chat.messages;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final message = items[index];
                    return MessageBubble(
                      message: message,
                      isMine: message.isMine(currentUserId),
                    );
                  },
                );
              },
            ),
          ),
          ChatInputBar(
            onSend: (text) => context.read<ChatProvider>().sendMessage(text),
          ),
        ],
      ),
    );
  }
}
