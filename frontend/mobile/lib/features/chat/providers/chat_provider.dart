import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/socket_service.dart';
import 'package:vnalo_mobile/services/media_service.dart';
import 'package:vnalo_mobile/services/notification_service.dart';
import 'package:vnalo_mobile/core/database/local_database.dart';
import 'dart:io';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;
  final SocketService _socketService;
  final MediaService _mediaService;
  final NotificationService _notificationService;
  final LocalDatabase _db;

  final Map<String, List<Message>> _messages = {};
  final Map<String, Timer> _retryTimers = {};
  final Map<String, int> _retryCounts = {};
  final StreamSubscription<Message> _messageSub;
  final StreamSubscription<Map<String, dynamic>> _readSub;
  final StreamSubscription<Map<String, dynamic>> _deliveredSub;
  final StreamSubscription<Map<String, dynamic>> _recalledSub;
  final Random _random = Random.secure();

  List<Conversation> _conversations = [];
  String? _activeConversationId;
  String? _currentUserId;
  bool _isLoading = false;
  Message? _replyingTo;
  String? _highlightedMessageId;
  Timer? _highlightTimer;

  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get activeConversationId => _activeConversationId;
  Message? get replyingTo => _replyingTo;
  String? get highlightedMessageId => _highlightedMessageId;
  String? get currentUserId => _currentUserId;
  /// Get messages for the currently active conversation.
  /// Use [getMessagesForConversation] for explicit scoping.
  List<Message> get messages =>
      _activeConversationId == null
          ? []
          : (_messages[_activeConversationId!] ?? []);

  List<Message> getMessagesForConversation(String conversationId) =>
      _messages[conversationId] ?? [];

  ChatProvider({
    required ChatService chatService,
    required SocketService socketService,
    required MediaService mediaService,
    required NotificationService notificationService,
    required LocalDatabase db,
  })  : _chatService = chatService,
        _socketService = socketService,
        _mediaService = mediaService,
      _notificationService = notificationService,
        _db = db,
        _messageSub = socketService.onMessage.listen((_) {}),
        _readSub = socketService.onRead.listen((_) {}),
        _deliveredSub = socketService.onDelivered.listen((_) {}),
        _recalledSub = socketService.onRecalled.listen((_) {}) {
    _notificationService.ensureInitialized();
    _messageSub.onData(_handleIncomingMessage);
    _readSub.onData(_handleReadEvent);
    _deliveredSub.onData(_handleDeliveredEvent);
      _recalledSub.onData(_handleRecalledEvent);
  }

  List<Message> getMessages(String conversationId) =>
      _messages[conversationId] ?? [];

  Future<void> loadInbox() async {
    _isLoading = true;
    notifyListeners();

    try {
      _conversations = await _chatService.getInbox();
      await _applyLocalReadStateOverrides();
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
      // 2. Fetch from API to update and sync
      final response = await _chatService.getMessages(
        conversationId,
        before: before,
      );

      if (before == null) {
        _messages[conversationId] = response;
        // Sync API messages to local DB in background
        _db.saveMessagesBatch(response.map(_toLocal).toList());
      } else {
        _messages[conversationId] = [
          ...(_messages[conversationId] ?? []),
          ...response,
        ];
      }
      notifyListeners();
    } catch (e, stack) {
      debugPrint('loadMessages error: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  LocalMessage _toLocal(Message m) {
    return LocalMessage(
      id: m.id,
      conversationId: m.conversationId,
      senderId: m.senderId,
      content: m.content ?? '',
      createdAt: m.createdAt,
      messageType: m.messageType.name,
      mediaUrl: m.mediaUrl,
      mediaMimeType: m.mediaMimeType,
      mediaSizeBytes: m.mediaSizeBytes,
    );
  }

  Message _fromLocal(LocalMessage lm) {
    return Message(
      id: lm.id,
      conversationId: lm.conversationId,
      senderId: lm.senderId,
      content: lm.content,
      createdAt: lm.createdAt,
      messageType: enumFromString(MessageType.values, lm.messageType),
      mediaUrl: lm.mediaUrl,
      mediaMimeType: lm.mediaMimeType,
      mediaSizeBytes: lm.mediaSizeBytes,
      status: MessageStatus.SENT,
    );
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
          _db.upsertConversationReadState(
            conversationId: conversationId,
            lastReadSeq: conv.lastMessage!.serverSeq!,
          );
        }
        notifyListeners();
      }
    }

    // 1. Load from Local Cache FIRST (Optimistic UI)
    final localMsgs = await _db.getMessagesByConversation(conversationId);
    if (_activeConversationId == conversationId) {
      _messages[conversationId] = localMsgs.map(_fromLocal).toList();
      notifyListeners();
    }

    await loadMessages(conversationId);

    // Ensure read state is synced after fresh messages are loaded.
    final latestSeq = _messages[conversationId]
        ?.map((m) => m.serverSeq ?? 0)
        .fold<int>(0, (max, seq) => seq > max ? seq : max) ??
        0;
    if (latestSeq > 0) {
      _socketService.markRead(conversationId, latestSeq);
      _db.upsertConversationReadState(
        conversationId: conversationId,
        lastReadSeq: latestSeq,
      );
    }
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
    _replyingTo = null;
    _highlightedMessageId = null;
    _highlightTimer?.cancel();
  }

  void setReplyTo(Message? message) {
    if (message != null && message.senderName == null) {
      // Try to resolve name if missing
      final resolvedName = _getSenderName(message.conversationId, message.senderId);
      _replyingTo = message.copyWith(senderName: resolvedName);
    } else {
      _replyingTo = message;
    }
    notifyListeners();
  }

  void highlightMessage(String messageId) {
    _highlightedMessageId = messageId;
    _highlightTimer?.cancel();
    notifyListeners();

    // Auto clear highlight after 2 seconds
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      _highlightedMessageId = null;
      notifyListeners();
    });
  }

  void sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'TEXT',
    String? replyToMessageId,
  }) {
    if (content.trim().isEmpty) return;

    final clientMessageId = _generateUuidV4();

    // Auto-resolve reply ID if not provided but we are in reply mode
    final actualReplyId = replyToMessageId ?? _replyingTo?.id;

    // If it's a reply, populate the replyTo fields for optimistic UI
    String? replySenderId;
    String? replySenderName;
    String? replyContent;
    if (actualReplyId != null && _replyingTo != null && _replyingTo!.id == actualReplyId) {
      replySenderId = _replyingTo!.senderId;
      replySenderName = _replyingTo!.senderName;
      replyContent = _replyingTo!.content;
    }

    final optimistic = Message(
      id: 'local-$clientMessageId',
      conversationId: conversationId,
      senderId: _currentUserId ?? '',
      clientMessageId: clientMessageId,
      content: content.trim(),
      messageType: enumFromString(MessageType.values, messageType),
      status: MessageStatus.SENDING,
      createdAt: DateTime.now(),
      replyToMessageId: actualReplyId,
      replyToSenderId: replySenderId,
      replyToSenderName: replySenderName,
      replyToContent: replyContent,
    );

    _messages[conversationId] = [optimistic, ...(getMessagesForConversation(conversationId))];
    _replyingTo = null; // Clear reply state after sending

    // Persist optimistic message locally
    _db.saveMessage(_toLocal(optimistic));

    notifyListeners();
    _sendWithRetry(optimistic);
  }

  Future<void> sendMediaMessage({
    required String conversationId,
    File? file,
    required MessageType type,
    String? mediaUrl,
  }) async {
    final clientMessageId = _generateUuidV4();
    final fileName = file?.path.split('/').last ?? 'media';
    final fileSize = file?.lengthSync() ?? 0;

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
      // Temp local path for preview or remote URL
      mediaUrl: file?.path ?? mediaUrl,
    );

    _messages[conversationId] = [optimistic, ...(getMessagesForConversation(conversationId))];
    notifyListeners();

    if (file == null && mediaUrl != null) {
      _sendWithRetry(optimistic);
      return;
    }

    try {
      final category = _mapMessageTypeToCategory(type);
      final mediaId = await _mediaService.uploadFile(file!, category);
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

  void sendGif({
    required String conversationId,
    required String gifUrl,
  }) {
    sendMediaMessage(
      conversationId: conversationId,
      mediaUrl: gifUrl,
      type: MessageType.IMAGE,
    );
  }

  void sendImage({required String conversationId, required String imagePath}) {
    sendMediaMessage(
      conversationId: conversationId,
      file: File(imagePath),
      type: MessageType.IMAGE,
    );
  }

  void sendVideo({required String conversationId, required String videoPath}) {
    sendMediaMessage(
      conversationId: conversationId,
      file: File(videoPath),
      type: MessageType.VIDEO,
    );
  }

  void sendFile({required String conversationId, required String filePath}) {
    sendMediaMessage(
      conversationId: conversationId,
      file: File(filePath),
      type: MessageType.FILE,
    );
  }

  void deleteMessage(String messageId) {
    if (_activeConversationId == null) return;
    final cid = _activeConversationId!;
    final list = _messages[cid] ?? [];
    final updated = list.where((m) => m.id != messageId).toList();
    _messages[cid] = updated;
    notifyListeners();
  }

  // Forward one or more source messages to multiple target conversations.
  Future<void> sendForwardBatch({
    required List<String> conversationIds,
    required List<Message> sourceMessages,
    String? additionalText,
  }) async {
    if (conversationIds.isEmpty || sourceMessages.isEmpty) return;

    final extra = additionalText?.trim();
    for (final conversationId in conversationIds) {
      if (extra != null && extra.isNotEmpty) {
        sendMessage(conversationId: conversationId, content: extra);
      }

      for (final source in sourceMessages) {
        if (source.messageType == MessageType.TEXT) {
          final content = (source.content ?? '').trim();
          if (content.isEmpty) continue;
          sendMessage(
            conversationId: conversationId,
            content: content,
            messageType: source.messageType.name,
          );
          continue;
        }

        final hasRemoteMedia = (source.mediaUrl ?? '').trim().isNotEmpty;
        if (hasRemoteMedia) {
          await sendMediaMessage(
            conversationId: conversationId,
            type: source.messageType,
            mediaUrl: source.mediaUrl,
          );
          continue;
        }

        final fallback = (source.content ?? '').trim();
        if (fallback.isNotEmpty) {
          sendMessage(
            conversationId: conversationId,
            content: fallback,
            messageType: source.messageType.name,
          );
        }
      }
    }
  }

  // Recall a message for everyone and update UI immediately.
  void recallMessage(String messageId, String conversationId) {
    _socketService.recallMessage(messageId, conversationId);
    final list = _messages[conversationId];
    if (list == null) return;

    final index = list.indexWhere((m) => m.id == messageId);
    if (index < 0) return;

    _replaceMessage(
      conversationId,
      messageId,
      list[index].copyWith(status: MessageStatus.RECALLED, content: ''),
    );
  }

  // Delete a message only for current user.
  Future<void> deleteForMe(String messageId, String conversationId) async {
    await _chatService.deleteForMe(messageId);
    final list = _messages[conversationId];
    if (list == null) return;

    _messages[conversationId] = list.where((m) => m.id != messageId).toList();
    notifyListeners();
  }

  // Reset in-memory chat state on logout.
  void reset() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _retryCounts.clear();
    _messages.clear();
    _conversations = [];
    _activeConversationId = null;
    _currentUserId = null;
    _replyingTo = null;
    _highlightedMessageId = null;
    _highlightTimer?.cancel();
    notifyListeners();
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

    // Resolve reply sender name if missing but ID is present
    if (resolvedMessage.replyToMessageId != null && resolvedMessage.replyToSenderName == null && resolvedMessage.replyToSenderId != null) {
      final resolvedReplyName = _getSenderName(conversationId, resolvedMessage.replyToSenderId!);
      resolvedMessage = resolvedMessage.copyWith(replyToSenderName: resolvedReplyName);
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
        final oldMessage = updated[optimisticIndex];

        // MERGE metadata: Keep reply info if already present in optimistic but missing in resolved
        Message merged = resolvedMessage;
        if (oldMessage.replyToMessageId != null && merged.replyToMessageId == null) {
          merged = merged.copyWith(
            replyToMessageId: oldMessage.replyToMessageId,
            replyToSenderId: oldMessage.replyToSenderId,
            replyToSenderName: oldMessage.replyToSenderName,
            replyToContent: oldMessage.replyToContent,
          );
        } else if (merged.replyToMessageId != null && merged.replyToSenderName == null) {
           // If server returned ID but no name, try to use old name
           merged = merged.copyWith(replyToSenderName: oldMessage.replyToSenderName);
        }

        updated[optimisticIndex] = merged;
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
    final isActiveConversation = conversationId == _activeConversationId;
    final isMine = message.senderId == _currentUserId;
    Conversation? resolvedConversation;
    if (index >= 0) {
      final conversation = _conversations[index];
      final updatedConversation = conversation.copyWith(
        lastMessage: message,
        unreadCount: (isActiveConversation || isMine)
            ? 0
            : conversation.unreadCount + 1,
      );
      _conversations[index] = updatedConversation;
      resolvedConversation = updatedConversation;
      _sortConversations();
    } else {
      // If the conversation is not in the current inbox, reload the inbox to show the new conversation
      loadInbox();
    }

    // Emit delivered indicator if it's not our message
    if (!isMine) {
      _socketService.markDelivered(message.id, conversationId);

      final isMuted = resolvedConversation?.isMuted ?? false;
      if (!isMuted) {
        _playIncomingMessageSound();
      }

      if (!isActiveConversation && !isMuted && !message.isSystemMessage) {
        _notifyIncomingMessage(resolvedMessage, resolvedConversation);
      }
    }

    // Auto-read messages in active conversation and persist local read state.
    if (isActiveConversation && !isMine && message.serverSeq != null) {
      _socketService.markRead(conversationId, message.serverSeq!);
      _db.upsertConversationReadState(
        conversationId: conversationId,
        lastReadSeq: message.serverSeq!,
      );
    }

    // Persist newly received message to local DB
    _db.saveMessage(_toLocal(resolvedMessage));

    notifyListeners();
  }

  void _playIncomingMessageSound() {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Best effort only.
    }
  }

  void _notifyIncomingMessage(Message message, Conversation? conversation) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    final title = conversation?.getDisplayName(currentUserId) ??
        message.senderName ??
        'Tin nhắn mới';
    final body = _buildNotificationBody(message);

    _notificationService.showChatNotification(
      conversationId: message.conversationId,
      title: title,
      body: body,
      senderId: message.senderId,
    );
  }

  String _buildNotificationBody(Message message) {
    switch (message.messageType) {
      case MessageType.TEXT:
        final text = (message.content ?? '').trim();
        return text.isEmpty ? 'Tin nhắn mới' : text;
      case MessageType.IMAGE:
        return 'Đã gửi hình ảnh';
      case MessageType.VIDEO:
        return 'Đã gửi video';
      case MessageType.AUDIO:
        return 'Đã gửi tin nhắn thoại';
      case MessageType.FILE:
        return 'Đã gửi tệp tin';
      case MessageType.STICKER:
        return 'Đã gửi sticker';
      default:
        return 'Tin nhắn mới';
    }
  }

  void _handleReadEvent(Map<String, dynamic> data) {
    final String conversationId = data['conversationId'];
    final String userId = data['userId'];
    final int lastReadSeq = data['lastReadSeq'];

    _db.upsertConversationReadState(
      conversationId: conversationId,
      lastReadSeq: lastReadSeq,
    );

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

  Future<void> _applyLocalReadStateOverrides() async {
    if (_conversations.isEmpty) return;

    final ids = _conversations.map((c) => c.id).toList();
    final localReadState = await _db.getConversationReadStateMap(ids);
    if (localReadState.isEmpty) return;

    bool changed = false;
    final updated = <Conversation>[];
    for (final conv in _conversations) {
      final lastReadSeq = localReadState[conv.id] ?? 0;
      final lastMessageSeq = conv.lastMessage?.serverSeq ?? 0;
      if (conv.unreadCount > 0 && lastReadSeq > 0 && lastMessageSeq > 0 && lastReadSeq >= lastMessageSeq) {
        updated.add(conv.copyWith(unreadCount: 0));
        changed = true;
      } else {
        updated.add(conv);
      }
    }

    if (changed) {
      _conversations = updated;
    }
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

  void _handleRecalledEvent(Map<String, dynamic> data) {
    final conversationId = data['conversationId']?.toString();
    final messageId = data['messageId']?.toString();
    if (conversationId == null || messageId == null) return;

    final msgs = _messages[conversationId];
    if (msgs == null) return;

    final index = msgs.indexWhere((m) => m.id == messageId);
    if (index < 0) return;

    final updated = List<Message>.from(msgs);
    updated[index] = updated[index].copyWith(
      status: MessageStatus.RECALLED,
      content: '',
    );
    _messages[conversationId] = updated;
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
      mediaUrl: message.mediaUrl,
      mediaThumbnailUrl: message.mediaThumbnailUrl,
      mediaSizeBytes: message.mediaSizeBytes,
      replyToMessageId: message.replyToMessageId,
      replyToSenderName: message.replyToSenderName,
      replyToContent: message.replyToContent,
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
    _recalledSub.cancel();
    _highlightTimer?.cancel();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  // Settings and management helpers.

  Future<void> updateConversationSettings({
    required String conversationId,
    bool? isPinned,
    bool? isMuted,
    bool? isHidden,
    bool? isFavorite,
    int? autoDeleteSeconds,
    bool? notifyCall,
  }) async {
    try {
      await _chatService.updateInboxSettings(
        conversationId,
        isPinned: isPinned,
        isMuted: isMuted,
        isHidden: isHidden,
        isFavorite: isFavorite,
        autoDeleteSeconds: autoDeleteSeconds,
        notifyCall: notifyCall,
      );

      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index >= 0) {
        _conversations[index] = _conversations[index].copyWith(
          isPinned: isPinned ?? _conversations[index].isPinned,
          isMuted: isMuted ?? _conversations[index].isMuted,
          isHidden: isHidden ?? _conversations[index].isHidden,
          isFavorite: isFavorite ?? _conversations[index].isFavorite,
          autoDeleteSeconds: autoDeleteSeconds ?? _conversations[index].autoDeleteSeconds,
          notifyCall: notifyCall ?? _conversations[index].notifyCall,
        );
        _sortConversations();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('updateConversationSettings error: $e');
      rethrow;
    }
  }

  Future<void> deleteChatHistory(String conversationId) async {
    try {
      await _chatService.deleteChatHistory(conversationId);
      _messages[conversationId] = [];

      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index >= 0) {
        _conversations[index] = _conversations[index].copyWith(
          lastMessage: null,
          unreadCount: 0,
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('deleteChatHistory error: $e');
      rethrow;
    }
  }

  Future<void> updateMemberNickname(String conversationId, String userId, String nickname) async {
    try {
      await _chatService.updateMemberNickname(conversationId, userId, nickname);

      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index >= 0) {
        final conv = _conversations[index];
        final memberIndex = conv.members.indexWhere((m) => m.userId == userId);
        if (memberIndex >= 0) {
          final updatedMember = conv.members[memberIndex].copyWith(nickname: nickname);
          final updatedMembers = List<ConversationMember>.from(conv.members);
          updatedMembers[memberIndex] = updatedMember;
          _conversations[index] = conv.copyWith(members: updatedMembers);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('updateMemberNickname error: $e');
      rethrow;
    }
  }

  Future<void> updateWallpaper(String conversationId, File file, {bool isGlobal = true}) async {
    try {
      final mediaId = await _mediaService.uploadFile(file, MediaCategory.CHAT_IMAGE);
      final wallpaperUrl = _mediaService.getPublicUrl(mediaId);

      await _chatService.updateWallpaper(conversationId, wallpaperUrl, isGlobal: isGlobal);

      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index >= 0) {
        if (isGlobal) {
          _conversations[index] = _conversations[index].copyWith(wallpaperUrl: wallpaperUrl);
        } else {
          _conversations[index] = _conversations[index].copyWith(personalWallpaperUrl: wallpaperUrl);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('updateWallpaper error: $e');
      rethrow;
    }
  }

  Future<void> updateWallpaperUrl(String conversationId, String wallpaperUrl, {bool isGlobal = true}) async {
    try {
      await _chatService.updateWallpaper(conversationId, wallpaperUrl, isGlobal: isGlobal);

      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index >= 0) {
        if (isGlobal) {
          _conversations[index] = _conversations[index].copyWith(wallpaperUrl: wallpaperUrl);
        } else {
          _conversations[index] = _conversations[index].copyWith(personalWallpaperUrl: wallpaperUrl);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('updateWallpaperUrl error: $e');
      rethrow;
    }
  }

  Future<List<Message>> getSharedMedia(String conversationId, {String? type}) async {
    try {
      return await _chatService.searchMedia(conversationId, messageType: type, limit: 10);
    } catch (e) {
      debugPrint('getSharedMedia error: $e');
      return [];
    }
  }

  String _getSenderName(String conversationId, String senderId) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      final conv = _conversations[index];
      final memberIndex = conv.members.indexWhere((m) => m.userId == senderId);
      if (memberIndex >= 0) {
        final member = conv.members[memberIndex];
        return member.nickname ?? member.user?.displayName ?? 'User';
      }
    }
    return 'User';
  }

  void updateUserProfileInConversations(User updatedUser) {
    bool changed = false;
    final updatedConversations = _conversations.map((conv) {
      if (conv.members.isEmpty) return conv;

      final newMembers = conv.members.map((member) {
        if (member.userId != updatedUser.id) return member;
        changed = true;
        final mergedUser = member.user?.copyWith(
              displayName: updatedUser.displayName,
              avatarUrl: updatedUser.avatarUrl,
              coverUrl: updatedUser.coverUrl,
              isOnline: updatedUser.isOnline,
            ) ??
            updatedUser;
        return member.copyWith(user: mergedUser);
      }).toList();

      return conv.copyWith(members: newMembers);
    }).toList();

    if (changed) {
      _conversations = updatedConversations;
      notifyListeners();
    }
  }
}
