import 'package:flutter/material.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_options_screen.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';

class DirectChatOptionsScreen extends StatelessWidget {
  final Conversation conversation;

  const DirectChatOptionsScreen({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    // Redirect to the main ChatOptionsScreen which now has the premium UI.
    return ChatOptionsScreen(conversation: conversation);
  }
}
