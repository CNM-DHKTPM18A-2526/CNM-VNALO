import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/socket_service.dart';
import 'package:vnalo_mobile/services/media_service.dart';
import 'dart:io';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;
  final SocketService _socketService;
  final MediaService _mediaService;

  final Map<String, List<Message>> _messages = {};
  final Map<String, Timer> _retryTimers = {};
  final Map<String, int> _retryCounts = {};
  final StreamSubscription<Message> _messageSub;
  final StreamSubscription<Map<String, dynamic>> _readSub;
  final StreamSubscription<Map<String, dynamic>> _deliveredSub;
  final Random _random = Random.secure();

  List<Conversation> _conversations = [];
  String? _activeConversationId;
  String? _currentUserId;
  bool _isLoading = false;

  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get activeConversationId => _activeConversationId;
  /// Get messages for the currently active conversation.
  /// Use [getMessagesForConversation] for explicit scoping.
  List<Message> get messages =>
      _activeConversationId == null
          ? []
          : (_messages[_activeConversationId!] ?? []);

  List<Message> getMessagesForConversation(String conversationId) =>
      _messages[conversationId] ?? [];

  ChatProvider(this._chatService, this._socketService, this._mediaService)
    : _messageSub = _socketService.onMessage.listen((_) {}),
      _readSub = _socketService.onRead.listen((_) {}),
      _deliveredSub = _socketService.onDelivered.listen((_) {}) {
    _messageSub.onData(_handleIncomingMessage);
    _readSub.onData(_handleReadEvent);
    _deliveredSub.onData(_handleDeliveredEvent);
  }

  List<Message> getMessages(String conversationId) =>
      _messages[conversationId] ?? [];

  Future<void> loadInbox() async {
    _isLoading = true;
    notifyListeners();

    try {
      _conversations = await _chatService.getInbox();
      _sortConversations();
    } catch (e) {
      debugPrint('loadInbox error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _sortConversations() {
    _conversations.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final timeA = a.lastMessage?.createdAt ?? a.updatedAt ?? DateTime(0);
      final timeB = b.lastMessage?.createdAt ?? b.updatedAt ?? DateTime(0);
      return timeB.compareTo(timeA);
    });
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

    // Clear unread count locally
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      final conv = _conversations[index];
      if (conv.unreadCount > 0) {
        _conversations[index] = conv.copyWith(unreadCount: 0);
        // Mark as read on server
        if (conv.lastMessage != null && conv.lastMessage!.serverSeq != null) {
          _socketService.markRead(conversationId, conv.lastMessage!.serverSeq!);
        }
        notifyListeners();
      }
    }

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

  void sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'TEXT',
  }) {
    if (content.trim().isEmpty) return;

    final clientMessageId = _generateUuidV4();
    final optimistic = Message(
      id: 'local-$clientMessageId',
      conversationId: conversationId,
      senderId: _currentUserId ?? '',
      clientMessageId: clientMessageId,
      content: content.trim(),
      messageType: enumFromString(MessageType.values, messageType),
      status: MessageStatus.SENDING,
      createdAt: DateTime.now(),
    );

    _messages[conversationId] = [optimistic, ...(getMessagesForConversation(conversationId))];
    notifyListeners();
    _sendWithRetry(optimistic);
  }

  Future<void> sendMediaMessage({
    required String conversationId,
    required File file,
    required MessageType type,
  }) async {
    final clientMessageId = _generateUuidV4();
    final fileName = file.path.split('/').last;
    final fileSize = file.lengthSync();
    
    final optimistic = Message(
      id: 'local-$clientMessageId',
      conversationId: conversationId,
      senderId: _currentUserId ?? '',
      clientMessageId: clientMessageId,
      messageType: type,
      content: fileName,
      mediaSizeBytes: fileSize,
      status: MessageStatus.SENDING,
      createdAt: DateTime.now(),
      // Temp local path for preview
      mediaUrl: file.path, 
    );

    _messages[conversationId] = [optimistic, ...(getMessagesForConversation(conversationId))];
    notifyListeners();

    try {
      final category = _mapMessageTypeToCategory(type);
      final mediaId = await _mediaService.uploadFile(file, category);
      final publicUrl = _mediaService.getPublicUrl(mediaId);
      
      final updated = optimistic.copyWith(
        mediaUrl: publicUrl,
        content: fileName,
        mediaSizeBytes: fileSize,
      );
      _replaceMessage(conversationId, optimistic.id, updated);
      _sendWithRetry(updated);
    } catch (e) {
      debugPrint('sendMediaMessage error: $e');
      _replaceMessage(
        conversationId,
        optimistic.id,
        optimistic.copyWith(status: MessageStatus.FAILED),
      );
    }
  }

  void sendSticker({
    required String conversationId,
    required String stickerId,
    required String stickerUrl,
  }) {
    final clientMessageId = _generateUuidV4();
    final message = Message(
      id: 'local-$clientMessageId',
      conversationId: conversationId,
      senderId: _currentUserId ?? '',
      clientMessageId: clientMessageId,
      content: stickerId,
      mediaUrl: stickerUrl,
      messageType: MessageType.STICKER,
      status: MessageStatus.SENDING,
      createdAt: DateTime.now(),
    );

    _messages[conversationId] = [message, ...(getMessagesForConversation(conversationId))];
    notifyListeners();
    _sendWithRetry(message);
  }

  MediaCategory _mapMessageTypeToCategory(MessageType type) {
    switch (type) {
      case MessageType.IMAGE:
        return MediaCategory.CHAT_IMAGE;
      case MessageType.VIDEO:
        return MediaCategory.CHAT_VIDEO;
      case MessageType.AUDIO:
        return MediaCategory.CHAT_VOICE;
      case MessageType.FILE:
        return MediaCategory.CHAT_FILE;
      case MessageType.STICKER:
        return MediaCategory.STICKER;
      default:
        return MediaCategory.CHAT_FILE;
    }
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

    // Resolve mediaId to URL if it's just an ID
    Message resolvedMessage = message;
    if (message.mediaUrl != null &&
        !message.mediaUrl!.startsWith('http') &&
        !message.mediaUrl!.startsWith('/')) {
      resolvedMessage = message.copyWith(
        mediaUrl: _mediaService.getPublicUrl(message.mediaUrl!),
      );
    }

    final existing = _messages[conversationId] ?? [];
    final clientMessageId = resolvedMessage.clientMessageId;
    if (clientMessageId != null) {
      _clearRetry(clientMessageId);
      final optimisticIndex = existing.indexWhere(
        (m) => m.clientMessageId == clientMessageId,
      );
      if (optimisticIndex >= 0) {
        final updated = List<Message>.from(existing);
        updated[optimisticIndex] = resolvedMessage;
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
      final updatedConversation = conversation.copyWith(
        lastMessage: message,
        unreadCount: (conversation.id == _activeConversationId || message.senderId == _currentUserId)
            ? 0
            : conversation.unreadCount + 1,
      );
      _conversations[index] = updatedConversation;
      _sortConversations();
    }

    // Emit delivered indicator if it's not our message
    if (message.senderId != _currentUserId) {
      _socketService.markDelivered(message.id, conversationId);
    }

    notifyListeners();
  }

  void _handleReadEvent(Map<String, dynamic> data) {
    final String conversationId = data['conversationId'];
    final String userId = data['userId'];
    final int lastReadSeq = data['lastReadSeq'];

    // Update member's lastReadSeq in the conversation object
    final convIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convIndex >= 0) {
      final conv = _conversations[convIndex];
      final memberIndex = conv.members.indexWhere((m) => m.userId == userId);
      if (memberIndex >= 0) {
        final member = conv.members[memberIndex];
        if (lastReadSeq > member.lastReadSeq) {
          final updatedMember = member.copyWith(lastReadSeq: lastReadSeq);
          final updatedMembers = List<ConversationMember>.from(conv.members);
          updatedMembers[memberIndex] = updatedMember;
          _conversations[convIndex] = conv.copyWith(members: updatedMembers);
        }
      }
    }

    // Update message statuses to READ if applicable
    final msgs = _messages[conversationId];
    if (msgs != null && msgs.isNotEmpty) {
      bool changed = false;
      final updatedMsgs = msgs.map((m) {
        if (m.senderId == _currentUserId && 
            m.status != MessageStatus.READ && 
            m.serverSeq != null && 
            m.serverSeq! <= lastReadSeq) {
          changed = true;
          return m.copyWith(status: MessageStatus.READ);
        }
        return m;
      }).toList();

      if (changed) {
        _messages[conversationId] = updatedMsgs;
      }
    }

    notifyListeners();
  }

  void _handleDeliveredEvent(Map<String, dynamic> data) {
    final String conversationId = data['conversationId'];
    final String messageId = data['messageId'];

    final msgs = _messages[conversationId];
    if (msgs != null) {
      final index = msgs.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        final msg = msgs[index];
        if (msg.status == MessageStatus.SENT) {
          final updated = List<Message>.from(msgs);
          updated[index] = msg.copyWith(status: MessageStatus.DELIVERED);
          _messages[conversationId] = updated;
          notifyListeners();
        }
      }
    }
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
      mediaUrl: message.mediaUrl,
      mediaThumbnailUrl: message.mediaThumbnailUrl,
      mediaMimeType: message.mediaMimeType,
      mediaSizeBytes: message.mediaSizeBytes,
      replyToMessageId: message.replyToMessageId,
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
    _readSub.cancel();
    _deliveredSub.cancel();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
