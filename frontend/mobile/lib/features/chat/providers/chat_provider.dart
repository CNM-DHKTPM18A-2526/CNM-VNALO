import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;
  final SocketService _socketService;

  final Map<String, List<Message>> _messages = {};
  final StreamSubscription<Message> _messageSub;

  List<Conversation> _conversations = [];
  String? _activeConversationId;
  bool _isLoading = false;

  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get activeConversationId => _activeConversationId;
  List<Message> get messages =>
      _activeConversationId == null
          ? []
          : (_messages[_activeConversationId!] ?? []);

  ChatProvider(this._chatService, this._socketService)
    : _messageSub = _socketService.onMessage.listen((_) {}) {
    _messageSub.onData(_handleIncomingMessage);
  }

  List<Message> getMessages(String conversationId) =>
      _messages[conversationId] ?? [];

  Future<void> loadInbox() async {
    _isLoading = true;
    notifyListeners();

    try {
      _conversations = await _chatService.getInbox();
    } catch (e) {
      debugPrint('loadInbox error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(String conversationId, {String? before}) async {
    try {
      final response = await _chatService.getMessages(
        conversationId,
        before: before,
      );
      if (before == null) {
        _messages[conversationId] = response;
      } else {
        _messages[conversationId] = [
          ...(_messages[conversationId] ?? []),
          ...response,
        ];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('loadMessages error: $e');
    }
  }

  Future<void> openConversation(String conversationId) async {
    _activeConversationId = conversationId;
    _socketService.joinConversation(conversationId);
    await loadMessages(conversationId);
  }

  void closeConversation() {
    final id = _activeConversationId;
    if (id != null) {
      _socketService.leaveConversation(id);
    }
    _activeConversationId = null;
  }

  void sendMessage(String content, {String messageType = 'TEXT'}) {
    final id = _activeConversationId;
    if (id == null || content.trim().isEmpty) return;

    _socketService.sendMessage(
      conversationId: id,
      content: content.trim(),
      messageType: messageType,
    );
  }

  void _handleIncomingMessage(Message message) {
    final conversationId = message.conversationId;

    final existing = _messages[conversationId] ?? [];
    final alreadyPresent = existing.any((m) => m.id == message.id);
    if (!alreadyPresent) {
      _messages[conversationId] = [message, ...existing];
    }

    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index > 0) {
      final conversation = _conversations.removeAt(index);
      _conversations.insert(0, conversation);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _messageSub.cancel();
    super.dispose();
  }
}
