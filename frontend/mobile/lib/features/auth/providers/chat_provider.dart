import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;
  final SocketService _socketService;

  List<Conversation> _conversations = [];
  final Map<String, List<Message>> _messages = {};
  bool _isLoading = false;
  StreamSubscription? _messageSubscription;

  List<Conversation> get conversations => _conversations;

  bool get isLoading => _isLoading;

  List<Message> getMessages(String conversationId) =>
      _messages[conversationId] ?? [];

  ChatProvider(this._chatService, this._socketService) {
    _messageSubscription = _socketService.onMessage.listen(_handleMessage);
  }

  // Load the inbox conversations and their last messages
  Future<void> loadInbox() async {
    _isLoading = true;
    notifyListeners();

    try {
      _conversations = await _chatService.getInbox();
    } catch (e) {
      debugPrint('Error loading inbox: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load messages for a specific conversation, with optional pagination support
  Future<void> loadMessages(String conversationId, {String? before}) async {
    try {
      final response = await _chatService.getMessages(
        conversationId,
        before: before,
      );

      // If 'before' is null, this is the initial load, so replace the existing messages
      if (before == null) {
        _messages[conversationId] = response;
      } else {
        // Append older messages to the existing list for pagination
        _messages[conversationId] = [
          ...(_messages[conversationId] ?? []),
          ...response,
        ];
      }
    } catch (e) {
      debugPrint('Error loading messages for conversation $conversationId: $e');
    }
  }

  void sendMessage(
    String conversationId,
    String content, {
    String messageType = 'TEXT',
  }) async {
    _socketService.sendMessage(
      conversationId: conversationId,
      content: content,
      messageType: messageType,
    );
  }

  // Handle incoming messages from the socket and update the corresponding conversation's message list
  void _handleMessage(Message message) {
    final conversationId = message.conversationId;
    // Add the new message to the beginning of the list for the corresponding conversation
    _messages[conversationId] = [message, ...(_messages[conversationId] ?? [])];
    final index = _conversations.indexWhere((c) => c.id == conversationId);

    // If the conversation is not already at the top of the list, move it to the top
    if (index > 0) {
      final conversation = _conversations.removeAt(index);
      _conversations.insert(0, conversation);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
