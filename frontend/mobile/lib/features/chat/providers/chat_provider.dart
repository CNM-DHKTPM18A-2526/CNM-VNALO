import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;
  final SocketService _socketService;

  final Map<String, List<Message>> _messages = {};
  final Map<String, Timer> _retryTimers = {};
  final Map<String, int> _retryCounts = {};
  final StreamSubscription<Message> _messageSub;
  final Random _random = Random.secure();

  List<Conversation> _conversations = [];
  String? _activeConversationId;
  String? _currentUserId;
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

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
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

    final clientMessageId = _generateUuidV4();
    final optimistic = Message(
      id: 'local-$clientMessageId',
      conversationId: id,
      senderId: _currentUserId ?? '',
      clientMessageId: clientMessageId,
      content: content.trim(),
      messageType: enumFromString(MessageType.values, messageType),
      status: MessageStatus.SENDING,
      createdAt: DateTime.now(),
    );

    _messages[id] = [optimistic, ...(_messages[id] ?? [])];
    notifyListeners();
    _sendWithRetry(optimistic);
  }

  void retryMessage(Message message) {
    final clientMessageId = message.clientMessageId;
    if (clientMessageId == null || message.status != MessageStatus.FAILED) {
      return;
    }

    _retryCounts[clientMessageId] = 0;
    _replaceMessage(
      message.conversationId,
      message.id,
      message.copyWith(status: MessageStatus.SENDING),
    );
    _sendWithRetry(message.copyWith(status: MessageStatus.SENDING));
  }

  void _handleIncomingMessage(Message message) {
    final conversationId = message.conversationId;

    final existing = _messages[conversationId] ?? [];
    final clientMessageId = message.clientMessageId;
    if (clientMessageId != null) {
      _clearRetry(clientMessageId);
      final optimisticIndex = existing.indexWhere(
        (m) => m.clientMessageId == clientMessageId,
      );
      if (optimisticIndex >= 0) {
        final updated = List<Message>.from(existing);
        updated[optimisticIndex] = message;
        _messages[conversationId] = updated;
      } else {
        final alreadyPresent = existing.any((m) => m.id == message.id);
        if (!alreadyPresent) {
          _messages[conversationId] = [message, ...existing];
        }
      }
    } else {
      final alreadyPresent = existing.any((m) => m.id == message.id);
      if (!alreadyPresent) {
        _messages[conversationId] = [message, ...existing];
      }
    }

    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      final conversation = _conversations[index];
      final updatedConversation = conversation.copyWith(lastMessage: message);
      _conversations.removeAt(index);
      _conversations.insert(0, updatedConversation);
    }

    notifyListeners();
  }

  Future<void> _sendWithRetry(Message message) async {
    final clientMessageId = message.clientMessageId;
    if (clientMessageId == null) {
      return;
    }

    final ack = await _socketService.sendMessage(
      conversationId: message.conversationId,
      content: message.content ?? '',
      messageType: message.messageType.name,
      clientMessageId: clientMessageId,
    );

    if (ack != null && ack['event'] == 'message.error') {
      _scheduleRetry(message);
      return;
    }

    if (ack != null && ack['event'] == 'message.sent' && ack['data'] is Map) {
      final serverMessage = Message.fromJson(Map<String, dynamic>.from(ack['data']));
      _handleIncomingMessage(serverMessage);
      return;
    }

    final delaySeconds = 3 + ((_retryCounts[clientMessageId] ?? 0) * 2);
    _retryTimers[clientMessageId]?.cancel();
    _retryTimers[clientMessageId] = Timer(Duration(seconds: delaySeconds), () {
      final pending = _findByClientMessageId(
        message.conversationId,
        clientMessageId,
      );
      if (pending == null) {
        return;
      }
      if (pending.status == MessageStatus.SENDING) {
        _scheduleRetry(pending);
      }
    });
  }

  void _scheduleRetry(Message message) {
    final clientMessageId = message.clientMessageId;
    if (clientMessageId == null) {
      return;
    }

    final retryCount = (_retryCounts[clientMessageId] ?? 0) + 1;
    _retryCounts[clientMessageId] = retryCount;
    if (retryCount > 3) {
      _replaceMessage(
        message.conversationId,
        message.id,
        message.copyWith(status: MessageStatus.FAILED),
      );
      HapticFeedback.heavyImpact();
      _clearRetry(clientMessageId, keepCount: true);
      return;
    }

    final backoffSeconds = min(2 * retryCount, 6);
    _retryTimers[clientMessageId]?.cancel();
    _retryTimers[clientMessageId] = Timer(Duration(seconds: backoffSeconds), () {
      final current = _findByClientMessageId(
        message.conversationId,
        clientMessageId,
      );
      if (current == null) {
        _clearRetry(clientMessageId);
        return;
      }
      _replaceMessage(
        message.conversationId,
        current.id,
        current.copyWith(status: MessageStatus.SENDING),
      );
      _sendWithRetry(current.copyWith(status: MessageStatus.SENDING));
    });
  }

  Message? _findByClientMessageId(String conversationId, String clientMessageId) {
    final list = _messages[conversationId] ?? const [];
    for (final message in list) {
      if (message.clientMessageId == clientMessageId) {
        return message;
      }
    }
    return null;
  }

  void _replaceMessage(String conversationId, String messageId, Message updated) {
    final list = _messages[conversationId] ?? const [];
    final index = list.indexWhere((m) => m.id == messageId);
    if (index < 0) {
      return;
    }
    final copied = List<Message>.from(list);
    copied[index] = updated;
    _messages[conversationId] = copied;
    notifyListeners();
  }

  void _clearRetry(String clientMessageId, {bool keepCount = false}) {
    _retryTimers.remove(clientMessageId)?.cancel();
    if (!keepCount) {
      _retryCounts.remove(clientMessageId);
    }
  }

  String _generateUuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String toHex(int byte) => byte.toRadixString(16).padLeft(2, '0');

    return '${toHex(bytes[0])}${toHex(bytes[1])}${toHex(bytes[2])}${toHex(bytes[3])}'
        '-${toHex(bytes[4])}${toHex(bytes[5])}'
        '-${toHex(bytes[6])}${toHex(bytes[7])}'
        '-${toHex(bytes[8])}${toHex(bytes[9])}'
        '-${toHex(bytes[10])}${toHex(bytes[11])}${toHex(bytes[12])}${toHex(bytes[13])}${toHex(bytes[14])}${toHex(bytes[15])}';
  }

  @override
  void dispose() {
    _messageSub.cancel();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
