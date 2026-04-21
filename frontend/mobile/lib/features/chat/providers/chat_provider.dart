import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/models/message_reaction_model.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/socket_service.dart';
import 'package:vnalo_mobile/services/media_service.dart';
import 'package:vnalo_mobile/services/notification_service.dart';
import 'package:vnalo_mobile/core/database/local_database.dart';
import 'dart:io';
import 'dart:convert';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;
  final SocketService _socketService;
  final MediaService _mediaService;
  final NotificationService _notificationService;
  final LocalDatabase _db;

  final Map<String, List<Message>> _messages = {};
  final Map<String, Timer> _retryTimers = {};
  final Map<String, int> _retryCounts = {};
  final Map<String, List<Message>> _pinnedMessages = {};
  final Map<String, List<MessageReaction>> _reactions = {};
  final StreamSubscription<Message> _messageSub;
  final StreamSubscription<Map<String, dynamic>> _readSub;
  final StreamSubscription<Map<String, dynamic>> _deliveredSub;
  final StreamSubscription<Map<String, dynamic>> _recalledSub;
  final StreamSubscription<Map<String, dynamic>> _pinnedSub;
  final StreamSubscription<Map<String, dynamic>> _unpinnedSub;
  final StreamSubscription<Map<String, dynamic>> _reactionAddedSub;
  final StreamSubscription<Map<String, dynamic>> _reactionRemovedSub;
  final Random _random = Random.secure();

  List<Conversation> _conversations = [];
  String? _activeConversationId;
  String? _currentUserId;
  bool _isLoading = false;
  Message? _replyingTo;
  String? _highlightedMessageId;
  Timer? _highlightTimer;
  Message? _lastCloudMessage;

  List<Conversation> get conversations => _conversations;
  Message? get lastCloudMessage => _lastCloudMessage;
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
          : (_messages[_activeConversationId!] ?? [])
              .where((m) => m.content?.startsWith('[ACTION:') != true)
              .toList();

  List<Message> getMessagesForConversation(String conversationId) =>
      (_messages[conversationId] ?? [])
          .where((m) => m.content?.startsWith('[ACTION:') != true)
          .toList();

  List<Message> getPinnedMessagesForConversation(String conversationId) =>
      _pinnedMessages[conversationId] ?? [];

  List<MessageReaction> getReactionsForMessage(String messageId) =>
      _reactions[messageId] ?? [];

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
        _recalledSub = socketService.onRecalled.listen((_) {}),
        _pinnedSub = socketService.onPinned.listen((_) {}),
        _unpinnedSub = socketService.onUnpinned.listen((_) {}),
        _reactionAddedSub = socketService.onReactionAdded.listen((_) {}),
        _reactionRemovedSub = socketService.onReactionRemoved.listen((_) {}) {
    _notificationService.ensureInitialized();
    _messageSub.onData(_handleIncomingMessage);
    _readSub.onData(_handleReadEvent);
    _deliveredSub.onData(_handleDeliveredEvent);
    _recalledSub.onData(_handleRecalledEvent);
    _pinnedSub.onData(_handlePinnedEvent);
    _unpinnedSub.onData(_handleUnpinnedEvent);
    _reactionAddedSub.onData(_handleReactionAddedEvent);
    _reactionRemovedSub.onData(_handleReactionRemovedEvent);
  }

  List<Message> getMessages(String conversationId) =>
      _messages[conversationId] ?? [];

  // Mock frontend-only state for "Quyền gửi tin nhắn" (Only Owners/Admins can send)
  final Map<String, bool> _readOnlyForMembers = {};
  bool isReadOnlyForMembers(String convId) => _readOnlyForMembers[convId] ?? false;
  void setReadOnlyForMembers(String convId, bool value) {
    _readOnlyForMembers[convId] = value;
    notifyListeners();
  }

  Future<void> loadInbox() async {
    _isLoading = true;
    notifyListeners();

    try {
      final raw = await _chatService.getInbox();
      
      // Load last cloud message (Harden to prevent inbox blocking)
      try {
        if (_currentUserId != null) {
          final cloudMsgs = await _db.getMessagesByConversation('MY_DOCUMENTS', _currentUserId!);
          if (cloudMsgs.isNotEmpty) {
            _lastCloudMessage = _fromLocal(cloudMsgs.first);
          }
        }
      } catch (e) {
        debugPrint('Cloud preview loading failed: $e');
      }
      
      final backendIds = raw.map((c) => c.id).toSet();
      
      // Preserve locally created groups that are not yet in the backend inbox
      // (Backend only puts them in inbox after first message is sent)
      final localEmptyGroups = _conversations.where((localConv) {
         return !backendIds.contains(localConv.id) &&
                localConv.type == ConversationType.GROUP &&
                localConv.lastMessage == null &&
                localConv.members.any((m) => m.userId == _currentUserId && m.leftAt == null);
      }).toList();

      final combined = [...raw, ...localEmptyGroups];

      _conversations = combined.map((remoteConv) {
        final localConv = _conversations.firstWhere((c) => c.id == remoteConv.id, orElse: () => remoteConv);
        // Use the remoteConv as base, but merge members from localConv if it exists and is different
        return _mergeAndSanitize(remoteConv, local: localConv == remoteConv ? null : localConv);
      })
      .whereType<Conversation>()
      // FILTER: Only keep groups where I am currently an active member
      // This solves the database persistence issue where old groups stay in the server inbox
      .where((c) {
        if (c.type == ConversationType.DIRECT) return true;
        return c.members.any((m) => m.userId == _currentUserId && m.leftAt == null);
      })
      .toList();
      await _applyLocalReadStateOverrides();
      _sortConversations();
    } catch (e) {
      debugPrint('loadInbox error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void refreshCloudPreview() async {
    try {
      if (_currentUserId != null) {
        final cloudMsgs = await _db.getMessagesByConversation('MY_DOCUMENTS', _currentUserId!);
        if (cloudMsgs.isNotEmpty) {
          _lastCloudMessage = _fromLocal(cloudMsgs.first);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('refreshCloudPreview failure: $e');
    }
  }

  /// Combined helper to merge local optimistic members with remote server data
  /// and then apply standard sanitization (Dual Owner fix, membership check, etc.)
  Conversation? _mergeAndSanitize(Conversation remote, {Conversation? local}) {
    if (local == null) {
      return _sanitizeConversation(remote);
    }

    // 1. Merge Members: Protect optimistic updates from being overwritten by stale server data
    final remoteMembers = remote.members;
    final mergedMembers = List<ConversationMember>.from(remoteMembers);
    
    // Check for members that exist locally but are missing from the server's current view
    for (final localM in local.members) {
      final isMissingInRemote = !remoteMembers.any((rm) => rm.userId == localM.userId);
      // Protection period: 60 seconds
      final isVeryRecent = localM.joinedAt.isAfter(DateTime.now().subtract(const Duration(seconds: 60)));
      
      if (isMissingInRemote && isVeryRecent && localM.leftAt == null) {
        mergedMembers.add(localM);
        debugPrint('Sync protection: Preserved optimistic member ${localM.userId} in ${remote.id}');
      }
    }

    final mergedConv = remote.copyWith(members: mergedMembers);
    
    // 2. Sanitize: Resolve conflicts (like multiple owners) and check active status
    return _sanitizeConversation(mergedConv);
  }

  Conversation? _sanitizeConversation(Conversation conv) {
    final myId = _currentUserId;
    if (myId == null) return conv;

    // 1. Hide groups where the user is no longer an active member (Bypass Backend Bug)
    // NOTE: If members list is empty, it's likely still loading (enriching). 
    // Do NOT filter out yet to prevent groups from "disappearing" from the inbox temporarily.
    if (conv.members.isEmpty) return conv;

    final myMembership = conv.members.firstWhere(
      (m) => m.userId == myId,
      orElse: () => ConversationMember(
        conversationId: conv.id,
        userId: 'not_found',
        joinedAt: DateTime.now(),
        leftAt: DateTime.now(), // Assume left if not found in member list
      ),
    );

    if (myMembership.userId == 'not_found' || myMembership.leftAt != null) {
      return null;
    }

    // 2. Enforce exactly 1 Owner (Fix Two Owners display bug)
    final owners = conv.members.where((m) => m.role == MemberRole.OWNER).toList();
    if (owners.length > 1) {
      // Logic: If there are multiple owners and I am one of them, prefer the OTHER person
      // as the primary owner to support smooth self-demotion during transfer.
      final otherOwners = owners.where((o) => o.userId != myId).toList();
      String primaryOwnerId;
      
      if (otherOwners.isNotEmpty) {
        // Pick the earliest joined owner among THE OTHERS
        otherOwners.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
        primaryOwnerId = otherOwners.first.userId;
      } else {
        // Fallback to earliest joined overall
        owners.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
        primaryOwnerId = owners.first.userId;
      }

      final sanitizedMembers = conv.members.map((m) {
        if (m.role == MemberRole.OWNER && m.userId != primaryOwnerId) {
          // Locally demote secondary owners to MEMBER
          return m.copyWith(role: MemberRole.MEMBER);
        }
        return m;
      }).toList();

      return conv.copyWith(members: sanitizedMembers);
    }

    return conv;
  }

  Future<Conversation?> createGroupConversation({
    required String title,
    required List<String> memberIds,
    String? avatarUrl,
  }) async {
    try {
      final conversation = await _chatService.createGroup(
        title: title,
        memberIds: memberIds,
        avatarUrl: avatarUrl,
      );

      if (conversation != null) {
        final sanitized = _sanitizeConversation(conversation);
        if (sanitized != null) {
          _conversations = [sanitized, ..._conversations];
          notifyListeners();
          
          // Send system notification for group creation
          final currentUser = _currentUserId;
          String userName = 'Một thành viên';
          if (currentUser != null) {
            final memberIndex = sanitized.members.indexWhere((m) => m.userId == currentUser);
            if (memberIndex >= 0) {
              userName = sanitized.members[memberIndex].user?.displayName ?? userName;
            }
          }
          await _sendSystemNotification(sanitized.id, '$userName đã tạo nhóm "$title"');

          // BROADCAST to other platforms/members via Socket 
          // 1. Join room first
          _socketService.joinConversation(sanitized.id);

          // 2. Emit identical SYSTEM message as Web does, so Web can 'discover' it
          final syncPayload = '{"action":"CREATE_GROUP","actorId":"$currentUser"}';
          _socketService.sendMessage(
            conversationId: sanitized.id,
            content: syncPayload,
            messageType: 'SYSTEM',
          );
          
          return sanitized;
        }
      }
      return conversation;
    } catch (e) {
      debugPrint('createGroupConversation error: $e');
      rethrow;
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
        
        // Load reactions for all messages
        for (final message in response) {
          loadReactions(message.id);
        }
      } else {
        _messages[conversationId] = [
          ...(_messages[conversationId] ?? []),
          ...response,
        ];
        
        // Load reactions for newly loaded messages
        for (final message in response) {
          loadReactions(message.id);
        }
      }
      notifyListeners();
    } catch (e, stack) {
      debugPrint('loadMessages error: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  LocalMessage _toLocal(Message m) {
    if (_currentUserId == null) {
      throw StateError('Cannot map to local message without active currentUserId');
    }
    return LocalMessage(
      id: m.id,
      ownerId: _currentUserId!,
      conversationId: m.conversationId,
      senderId: m.senderId,
      content: m.content ?? '',
      createdAt: m.createdAt,
      messageType: m.messageType.name,
      mediaUrl: m.mediaUrl,
      mediaMimeType: m.mediaMimeType,
      mediaSizeBytes: m.mediaSizeBytes,
      replyToId: m.replyToMessageId,
      replyToSenderId: m.replyToSenderId,
      replyToSenderName: m.replyToSenderName,
      replyToContent: m.replyToContent,
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
      replyToMessageId: lm.replyToId,
      replyToSenderId: lm.replyToSenderId,
      replyToSenderName: lm.replyToSenderName,
      replyToContent: lm.replyToContent,
      status: MessageStatus.SENT,
    );
  }

  Future<void> openConversation(String conversationId) async {
    _activeConversationId = conversationId;
    _socketService.joinConversation(conversationId);
    loadPinnedMessages(conversationId);

    // Load reactions for messages in this conversation
    final messages = _messages[conversationId] ?? [];
    for (final message in messages) {
      loadReactions(message.id);
    }

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
    if (_currentUserId != null) {
      final localMsgs = await _db.getMessagesByConversation(conversationId, _currentUserId!);
      if (_activeConversationId == conversationId) {
        _messages[conversationId] = localMsgs.map(_fromLocal).toList();
        notifyListeners();
      }
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
      final resolvedName = getSenderName(message.conversationId, message.senderId);
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
    String? content,
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
      content: content ?? (type == MessageType.AUDIO ? '' : fileName),
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
        content: content ?? (type == MessageType.AUDIO ? (content ?? '') : (optimistic.content ?? fileName)),
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

  void sendVoiceMessage({
    required String conversationId,
    required String audioPath,
    String? transcription,
  }) {
    sendMediaMessage(
      conversationId: conversationId,
      file: File(audioPath),
      type: MessageType.AUDIO,
      content: transcription,
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

  Future<void> downloadFile(Message message) async {
    // Basic implementation: for now, we just open the URL if possible, 
    // or provide a placeholder for actual background downloading in the future.
    if (message.mediaUrl == null || message.mediaUrl!.isEmpty) return;
    
    // In a real app, this would involve a background download task.
    // For now, satisfy the compiler and provide a hook.
    debugPrint('Download requested for: ${message.mediaUrl}');
  }

  // Delete a message only for current user.
  Future<void> deleteForMe(String messageId, String conversationId) async {
    // Step 1: Surgical Local Update for immediate feedback
    final list = _messages[conversationId];
    if (list != null) {
      _messages[conversationId] = list.where((m) => m.id != messageId).toList();
      notifyListeners();
    }
    
    // Step 2: Background tasks
    try {
      await _chatService.deleteForMe(messageId);
      if (_currentUserId != null) {
        _db.deleteMessage(messageId, _currentUserId!);
      }
    } catch (e) {
      debugPrint('deleteForMe error: $e');
      // In a more robust implementation, we could revert if the API fails,
      // but usually standard sync handles this.
    }
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
    // 1. SIGNAL MESSAGE HANDLING (Real-time Sync for Disband/Remove)
    // Since backend doesn't emit dedicated socket events, we use hidden "Signal Messages"
    // that are broadcasted as normal messages but intercepted here.
    if (message.messageType == MessageType.SYSTEM || message.content?.startsWith('[ACTION:') == true) {
      final content = message.content ?? '';
      if (content == '[ACTION:DISBAND]') {
        debugPrint('SIGNAL: Group ${message.conversationId} disbanded. Removing...');
        _removeConversationLocally(message.conversationId);
        return;
      }
      if (content.startsWith('[ACTION:REMOVE:')) {
        // Extract userId: [ACTION:REMOVE:user-uuid-here]
        final targetUserId = content.replaceFirst('[ACTION:REMOVE:', '').replaceFirst(']', '');
        if (targetUserId == _currentUserId) {
          debugPrint('SIGNAL: I was removed from ${message.conversationId}. Removing...');
          _removeConversationLocally(message.conversationId);
          return;
        }
      }

      // Handle JSON-based system signals
      if (content.contains('"action":')) {
        try {
          final data = jsonDecode(content);
          final action = data['action'];
          final actorId = data['actorId'];

          if (action == 'CREATE_GROUP') {
            debugPrint('SIGNAL: New group created. Refreshing inbox...');
            loadInbox();
          }

          if (action == 'LEAVE_GROUP' || action == 'REMOVE_MEMBER') {
            final targetIds = List<String>.from(data['targetMemberIds'] ?? [actorId]);
            debugPrint('SIGNAL: Membership update received for ${message.conversationId}. Targets: $targetIds');

            if (targetIds.contains(_currentUserId)) {
              debugPrint('SIGNAL: I was removed from or left ${message.conversationId}. Removing locally.');
              _removeConversationLocally(message.conversationId);
            } else {
              // Someone else left/removed
              bool changed = false;
              for (int i = 0; i < _conversations.length; i++) {
                if (_conversations[i].id == message.conversationId) {
                  final conv = _conversations[i];
                  final updatedMembers = conv.members.where((m) => !targetIds.contains(m.userId)).toList();
                  
                  if (updatedMembers.length != conv.members.length) {
                    _conversations[i] = conv.copyWith(members: updatedMembers);
                    changed = true;
                  }
                  break;
                }
              }
              if (changed) notifyListeners();
            }
          }

          if (action == 'DISBAND_GROUP') {
            debugPrint('SIGNAL: Group disbanded: ${message.conversationId}. Removing locally.');
            _removeConversationLocally(message.conversationId);
          }

          if (action == 'UPDATE_GROUP_INFO' || action == 'CHANGE_GROUP_AVATAR') {
             final metadata = data['metadata'] ?? {};
             final newName = metadata['newName'];
             final newAvatarUrl = metadata['newAvatarUrl'];
             
             debugPrint('SIGNAL: Group metadata update received for ${message.conversationId}.');
             
             bool changed = false;
             for (int i = 0; i < _conversations.length; i++) {
               if (_conversations[i].id == message.conversationId) {
                 var updated = _conversations[i];
                 if (newName != null) {
                   updated = updated.copyWith(title: newName);
                   changed = true;
                 }
                 if (newAvatarUrl != null) {
                   updated = updated.copyWith(avatarUrl: newAvatarUrl);
                   changed = true;
                 }
                 if (changed) {
                   _conversations[i] = updated;
                 }
                 break;
               }
             }
             if (changed) {
               notifyListeners();
             } else {
               // Fallback to refresh if we didn't find it in local list 
               // (might be a new conversation for us)
               loadInbox();
             }
          }

          if (content.contains('"action":"UPDATE_MESSAGE_REACTIONS"')) {
            final data = jsonDecode(content);
            final msgId = data['messageId'];
            final actionType = data['type']; // 'ADD' or 'REMOVE'
            final emoji = data['emoji'];
            final actorId = data['actorId'];

            if (msgId != null) {
              debugPrint('SIGNAL: Reaction update signal received for $msgId.');
              
              // Optimistic local update if we have enough info
              if (actionType != null && emoji != null && actorId != null) {
                final currentReactions = _reactions[msgId] ?? [];
                if (actionType == 'ADD') {
                  final newReaction = MessageReaction(
                    id: 'signal_${DateTime.now().millisecondsSinceEpoch}',
                    conversationId: message.conversationId,
                    messageId: msgId,
                    serverSeq: 0,
                    userId: actorId,
                    emoji: emoji,
                    createdAt: DateTime.now(),
                  );
                  // Replace existing if from same user
                  final filtered = currentReactions.where((r) => r.userId != actorId).toList();
                  filtered.add(newReaction);
                  _reactions[msgId] = filtered;
                } else if (actionType == 'REMOVE') {
                  _reactions[msgId] = currentReactions.where((r) => r.userId != actorId).toList();
                }
                notifyListeners();
              }
              
              // Background sync to ensure data integrity
              loadReactions(msgId);
            }
          }
        } catch (e) {
          debugPrint('Error parsing system signal: $e');
        }
      }
    }

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
    if (resolvedMessage.replyToSenderId != null && resolvedMessage.replyToSenderName == null) {
      final resolvedReplyName = getSenderName(conversationId, resolvedMessage.replyToSenderId!);
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

  Future<void> _removeConversationLocally(String conversationId) async {
    debugPrint('[ChatProvider] Removing conversation locally: $conversationId');
    
    // 1. In-memory update
    _conversations.removeWhere((c) => c.id == conversationId);
    if (_activeConversationId == conversationId) {
      _activeConversationId = null;
    }
    _messages.remove(conversationId);
    _pinnedMessages.remove(conversationId);
    notifyListeners();

    // 2. Database cleanup
    if (_currentUserId != null) {
      try {
        await _db.deleteConversation(conversationId, _currentUserId!);
        debugPrint('[ChatProvider] Database cleanup successful for $conversationId');
      } catch (e) {
        debugPrint('[ChatProvider] Database cleanup failed for $conversationId: $e');
      }
    }
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
            m.status != MessageStatus.RECALLED &&
            m.status != MessageStatus.FAILED &&
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
    final recalledMessage = updated[index].copyWith(
      status: MessageStatus.RECALLED,
      content: '',
    );
    updated[index] = recalledMessage;
    _messages[conversationId] = updated;
    
    // Persist recalled state to local database
    _db.saveMessage(_toLocal(recalledMessage));

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
    _pinnedSub.cancel();
    _unpinnedSub.cancel();
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



  Future<List<Message>> getSharedMedia(String conversationId, {String? type}) async {
    try {
      return await _chatService.searchMedia(conversationId, messageType: type, limit: 10);
    } catch (e) {
      debugPrint('getSharedMedia error: $e');
      return [];
    }
  }

  String getSenderName(String conversationId, String senderId) {
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

  Future<void> refreshConversation(String conversationId) async {
    try {
      final updated = await _chatService.getConversationById(conversationId);
      if (updated != null) {
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        
        if (index >= 0) {
          final localConv = _conversations[index];
          final sanitized = _mergeAndSanitize(updated, local: localConv);
          
          if (sanitized == null) {
            _conversations.removeAt(index);
          } else {
            _conversations[index] = sanitized;
          }
        } else {
          // If not in local list yet, use standard sanitization
          final sanitized = _sanitizeConversation(updated);
          if (sanitized != null) {
            _conversations.insert(0, sanitized);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('refreshConversation error: $e');
    }
  }

  // --- Group Management ---

  Future<void> _sendSystemNotification(String conversationId, String content) async {
    try {
      debugPrint('Adding system notification to local state for $conversationId: $content');
      
      // Create system message locally and add to messages list
      final systemMessage = Message(
        id: 'system-${DateTime.now().millisecondsSinceEpoch}',
        conversationId: conversationId,
        senderId: _currentUserId ?? '',
        messageType: MessageType.SYSTEM,
        content: content,
        status: MessageStatus.SENT,
        createdAt: DateTime.now(),
      );
      
      // Add to local messages
      if (_messages[conversationId] == null) {
        _messages[conversationId] = [];
      }
      _messages[conversationId]!.insert(0, systemMessage);
      notifyListeners();
      
      debugPrint('System notification added to local state successfully');
    } catch (e) {
      debugPrint('Failed to add system notification: $e');
    }
  }

  Future<void> updateGroupInfo(String conversationId, {
    String? title, 
    String? description, 
    String? avatarUrl, 
    String? joinMode,
    bool? allowMemberInvite,
    bool? allowMemberPin,
    bool? allowMemberEditInfo,
  }) async {
    final currentUser = _currentUserId;
    String userName = 'Một thành viên';
    if (currentUser != null) {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index >= 0) {
        final memberIndex = _conversations[index].members.indexWhere((m) => m.userId == currentUser);
        if (memberIndex >= 0) {
          userName = _conversations[index].members[memberIndex].user?.displayName ?? userName;
        }
      }
    }

    // Step 1: Optimistic UI Update
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      _conversations[index] = _conversations[index].copyWith(
        title: title ?? _conversations[index].title,
        description: description ?? _conversations[index].description,
        avatarUrl: avatarUrl ?? _conversations[index].avatarUrl,
        joinMode: joinMode != null ? enumFromString(JoinMode.values, joinMode) : _conversations[index].joinMode,
        allowMemberInvite: allowMemberInvite ?? _conversations[index].allowMemberInvite,
        allowMemberPin: allowMemberPin ?? _conversations[index].allowMemberPin,
        allowMemberEditInfo: allowMemberEditInfo ?? _conversations[index].allowMemberEditInfo,
      );
      notifyListeners();
    }

    try {
      final Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
      if (joinMode != null) body['joinMode'] = joinMode;
      if (allowMemberInvite != null) body['allowMemberInvite'] = allowMemberInvite;
      if (allowMemberPin != null) body['allowMemberPin'] = allowMemberPin;
      if (allowMemberEditInfo != null) body['allowMemberEditInfo'] = allowMemberEditInfo;

      await _chatService.updateGroup(conversationId, body);
      
      // Send system actions via socket for real-time sync across platforms
      if (title != null || avatarUrl != null) {
        final syncPayload = '{"action":"UPDATE_GROUP_INFO","actorId":"$currentUser"}';
        _socketService.sendMessage(
          conversationId: conversationId,
          content: syncPayload,
          messageType: 'SYSTEM'
        );
      }
      
      // No need to update local state again since we did it optimistically.
    } catch (e) {
      debugPrint('updateGroupInfo error: $e');
      rethrow;
    }
  }

  Future<void> updateWallpaperUrl(String conversationId, String imageUrl, {bool isGlobal = true}) async {
    try {
      await _chatService.updateWallpaper(conversationId, imageUrl, isGlobal: isGlobal);

      // Update local state immediately — refreshConversation only returns conversation-level data
      // and does NOT include personalWallpaperUrl (inbox-level personal setting per user).
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index >= 0) {
        if (isGlobal) {
          _conversations[index] = _conversations[index].copyWith(wallpaperUrl: imageUrl);
        } else {
          _conversations[index] = _conversations[index].copyWith(personalWallpaperUrl: imageUrl);
        }
        notifyListeners();
      }
      
      // Send system notification for wallpaper change (only for global wallpaper)
      if (isGlobal) {
        final currentUser = _currentUserId;
        String userName = 'Một thành viên';
        if (currentUser != null) {
          final convIndex = _conversations.indexWhere((c) => c.id == conversationId);
          if (convIndex >= 0) {
            final memberIndex = _conversations[convIndex].members.indexWhere((m) => m.userId == currentUser);
            if (memberIndex >= 0) {
              userName = _conversations[convIndex].members[memberIndex].user?.displayName ?? userName;
            }
          }
        }
        await _sendSystemNotification(conversationId, '$userName đã đổi hình nền nhóm');
      }
    } catch (e) {
      debugPrint('updateWallpaperUrl error: $e');
      rethrow;
    }
  }

  Future<void> updateGroupAvatarFile(String conversationId, File file) async {
    try {
      final mediaId = await _mediaService.uploadFile(file, MediaCategory.CHAT_IMAGE);
      final imageUrl = _mediaService.getPublicUrl(mediaId);
      await updateGroupInfo(conversationId, avatarUrl: imageUrl);
    } catch (e) {
      debugPrint('updateGroupAvatarFile error: $e');
      rethrow;
    }
  }

  Future<void> updateWallpaperFile(String conversationId, File file, {bool isGlobal = true}) async {
    try {
      final mediaId = await _mediaService.uploadFile(file, MediaCategory.CHAT_IMAGE);
      final imageUrl = _mediaService.getPublicUrl(mediaId);
      await updateWallpaperUrl(conversationId, imageUrl, isGlobal: isGlobal);
    } catch (e) {
      debugPrint('updateWallpaperFile error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> requestJoinGroup(String conversationId) async {
    try {
      final result = await _chatService.requestJoin(conversationId);
      await loadInbox(); // Refresh list to show new group if joined
      return result;
    } catch (e) {
      debugPrint('requestJoinGroup error: $e');
      rethrow;
    }
  }

  Future<void> transferOwnership(String conversationId, String targetUserId) async {
    final myId = _currentUserId;
    if (myId == null) return;

    // Get user names for notification
    String myName = 'Một thành viên';
    String targetName = 'Một thành viên';
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      final myMemberIndex = _conversations[index].members.indexWhere((m) => m.userId == myId);
      if (myMemberIndex >= 0) {
        myName = _conversations[index].members[myMemberIndex].user?.displayName ?? myName;
      }
      final targetMemberIndex = _conversations[index].members.indexWhere((m) => m.userId == targetUserId);
      if (targetMemberIndex >= 0) {
        targetName = _conversations[index].members[targetMemberIndex].user?.displayName ?? targetName;
      }
    }

    // Step 1: Surgical Local Update for immediate feedback (Optimistic UI)
    if (index >= 0) {
      final conv = _conversations[index];
      final updatedMembers = conv.members.map((m) {
        if (m.userId == targetUserId) {
          return m.copyWith(role: MemberRole.OWNER);
        } else if (m.userId == myId) {
          return m.copyWith(role: MemberRole.MEMBER);
        }
        return m;
      }).toList();
      
      _conversations[index] = conv.copyWith(members: updatedMembers);
      notifyListeners();
    }

    try {
      // Step 2: API Update
      await _chatService.updateMemberRole(conversationId, targetUserId, 'OWNER');
      
      // Send system notification for ownership transfer
      await _sendSystemNotification(conversationId, '$myName đã chuyển quyền trưởng nhóm cho $targetName');
      
      // Step 3: Unified Sync
      await refreshConversation(conversationId);
    } catch (e) {
      debugPrint('transferOwnership error: $e');
      // ROLLBACK: Sync back to server truth if API fails
      await refreshConversation(conversationId);
      rethrow;
    }
  }

  Future<void> addMembersToGroup(String conversationId, List<User> newUsers) async {
    // Get current user name for notification
    final currentUser = _currentUserId;
    String userName = 'Một thành viên';
    if (currentUser != null) {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index >= 0) {
        final memberIndex = _conversations[index].members.indexWhere((m) => m.userId == currentUser);
        if (memberIndex >= 0) {
          userName = _conversations[index].members[memberIndex].user?.displayName ?? userName;
        }
      }
    }

    // Step 1: Surgical Local Update for immediate visual feedback (TRUE Optimistic UI)
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      final conv = _conversations[index];
      final currentMembers = List<ConversationMember>.from(conv.members);
      
      for (final user in newUsers) {
        final existingIndex = currentMembers.indexWhere((m) => m.userId == user.id);
        if (existingIndex >= 0) {
          // Update existing entry (handle re-invites correctly)
          currentMembers[existingIndex] = currentMembers[existingIndex].copyWith(
            leftAt: null,
            joinedAt: DateTime.now(),
            role: MemberRole.MEMBER,
            user: user,
          );
        } else {
          // Add new entry
          currentMembers.add(ConversationMember(
            conversationId: conversationId,
            userId: user.id,
            joinedAt: DateTime.now(),
            role: MemberRole.MEMBER,
            user: user,
          ));
        }
      }
      
      _conversations[index] = conv.copyWith(members: currentMembers);
      notifyListeners();
      debugPrint('addMembersToGroup (Optimistic): Added/Updated ${newUsers.length} members. New total: ${currentMembers.length}');
    }

    try {
      final memberIds = newUsers.map((u) => u.id).toList();
      await _chatService.addMembers(conversationId, memberIds);
      
      // Send system notification for adding members
      if (newUsers.length == 1) {
        final memberName = newUsers.first.displayName ?? 'Một thành viên';
        await _sendSystemNotification(conversationId, '$userName đã thêm $memberName vào nhóm');
      } else {
        await _sendSystemNotification(conversationId, '$userName đã thêm ${newUsers.length} thành viên vào nhóm');
      }
      
      // Step 2: Synchronization Delay
      // Allow the backend some time to process the addition before we refresh the state.
      await Future.delayed(const Duration(seconds: 2));
      
      // Step 3: Server Refresh
      await refreshConversation(conversationId);
      debugPrint('addMembersToGroup: Successfully synced with server for $conversationId');
    } catch (e) {
      debugPrint('addMembersToGroup API error: $e');
      // ROLLBACK: If the API fails, sync back to server truth immediately.
      // This will remove the optimistic members that weren't actually added.
      await refreshConversation(conversationId);
      rethrow;
    }
  }

  Future<void> removeMember(String conversationId, String userId) async {
    // Get current user name and removed user name for notification
    final currentUser = _currentUserId;
    String userName = 'Một thành viên';
    String removedUserName = 'Một thành viên';
    
    if (currentUser != null) {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index >= 0) {
        final memberIndex = _conversations[index].members.indexWhere((m) => m.userId == currentUser);
        if (memberIndex >= 0) {
          userName = _conversations[index].members[memberIndex].user?.displayName ?? userName;
        }
        final removedMemberIndex = _conversations[index].members.indexWhere((m) => m.userId == userId);
        if (removedMemberIndex >= 0) {
          removedUserName = _conversations[index].members[removedMemberIndex].user?.displayName ?? removedUserName;
        }
      }
    }

    // Step 1: Surgical Local Update for immediate feedback
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      final members = _conversations[index].members.where((m) => m.userId != userId).toList();
      _conversations[index] = _conversations[index].copyWith(members: members);
      notifyListeners();
    }

    try {
      // NOTIFY: Send signal message so others know about the removal
      final removeSignal = {
        'action': 'REMOVE_MEMBER',
        'actorId': _currentUserId,
        'targetMemberIds': [userId]
      };
      
      await _socketService.sendMessage(
        conversationId: conversationId,
        content: jsonEncode(removeSignal),
        messageType: 'SYSTEM',
      );
      
      await _chatService.removeMember(conversationId, userId);
      
      // Send system notification for removing member
      await _sendSystemNotification(conversationId, '$userName đã loại $removedUserName khỏi nhóm');
    } catch (e) {
      debugPrint('removeMember error: $e');
      rethrow;
    }
  }

  Future<void> leaveGroup(String conversationId) async {
    final userId = _currentUserId;
    if (userId == null) return;
    
    // Check if current user is the owner
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      final conv = _conversations[index];
      final member = conv.members.firstWhere(
        (m) => m.userId == userId,
        orElse: () => throw Exception('Member not found'),
      );
      
      // If user is owner, check if there are other members to transfer ownership to
      if (member.role == MemberRole.OWNER) {
        final activeMembers = conv.members.where((m) => m.leftAt == null).toList();
        if (activeMembers.length > 1) {
          throw Exception('Bạn phải chuyển quyền trưởng nhóm cho thành viên khác trước khi rời nhóm');
        }
      }
    }
    
    // Step 1: Remove conversation immediately from UI and DB
    await _removeConversationLocally(conversationId);

    try {
      await removeMember(conversationId, userId);
    } catch (e) {
      debugPrint('leaveGroup error: $e');
      // If error, maybe we should reload inbox, but usually user wants to get out anyway.
    }
  }

  Future<void> disbandGroup(String conversationId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Current user is not available');
    }

    // Get current user name for notification
    String userName = 'Một thành viên';
    final convToRemove = _conversations.firstWhere((c) => c.id == conversationId, 
      orElse: () => throw Exception('Conversation not found'));
    final memberIndex = convToRemove.members.indexWhere((m) => m.userId == currentUserId);
    if (memberIndex >= 0) {
      userName = convToRemove.members[memberIndex].user?.displayName ?? userName;
    }
    
    final memberIdsToNotify = convToRemove.members
        .where((m) => m.leftAt == null)
        .map((m) => m.userId)
        .toList();

    try {
      // Send system notification for disbanding group
      await _sendSystemNotification(conversationId, '$userName đã giải tán nhóm');
      
      // NOTIFY: Send signal message so everyone's app knows the group is disbanded in real-time
      final disbandSignal = {
        'action': 'DISBAND_GROUP',
        'actorId': _currentUserId
      };
      
      await _socketService.sendMessage(
        conversationId: conversationId,
        content: jsonEncode(disbandSignal),
        messageType: 'SYSTEM',
      );
      
      await _removeConversationLocally(conversationId);
      
      await _chatService.disbandGroup(
        conversationId: conversationId,
        currentUserId: currentUserId,
        memberIds: memberIdsToNotify,
      );
      debugPrint('disbandGroup: Successfully signaled and started disband cleanup');
    } catch (e) {
      debugPrint('disbandGroup error: $e');
    }
  }

  Future<List<dynamic>> getJoinRequests(String conversationId) async {
    try {
      return await _chatService.getJoinRequests(conversationId);
    } catch (e) {
      debugPrint('getJoinRequests error: $e');
      return [];
    }
  }

  Future<void> approveJoinRequest(String conversationId, String userId) async {
    try {
      await _chatService.approveJoinRequest(conversationId, userId);
      // We might need to refresh the conversation members list here
      final updated = await _chatService.getConversationById(conversationId);
      if (updated != null) {
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index >= 0) {
          _conversations[index] = updated;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('approveJoinRequest error: $e');
      rethrow;
    }
  }

  Future<void> rejectJoinRequest(String conversationId, String userId) async {
    try {
      await _chatService.rejectJoinRequest(conversationId, userId);
    } catch (e) {
      debugPrint('rejectJoinRequest error: $e');
      rethrow;
    }
  }

  Future<void> updateMemberRole(String conversationId, String userId, String role) async {
    final memberRole = enumFromString(MemberRole.values, role);
    final myId = _currentUserId;

    // Get user names for notification
    String myName = 'Một thành viên';
    String targetName = 'Một thành viên';
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0 && myId != null) {
      final myMemberIndex = _conversations[index].members.indexWhere((m) => m.userId == myId);
      if (myMemberIndex >= 0) {
        myName = _conversations[index].members[myMemberIndex].user?.displayName ?? myName;
      }
      final targetMemberIndex = _conversations[index].members.indexWhere((m) => m.userId == userId);
      if (targetMemberIndex >= 0) {
        targetName = _conversations[index].members[targetMemberIndex].user?.displayName ?? targetName;
      }
    }

    // Step 1: Surgical Local Update for immediate feedback (Optimistic UI)
    if (index >= 0) {
      final conv = _conversations[index];
      
      final updatedMembers = conv.members.map((m) {
        if (m.userId == userId) {
          return m.copyWith(role: memberRole);
        }
        // Enforce exactly 1 owner if someone is being promoted to OWNER
        if (memberRole == MemberRole.OWNER && m.role == MemberRole.OWNER) {
          return m.copyWith(role: MemberRole.MEMBER);
        }
        return m;
      }).toList();
      
      _conversations[index] = conv.copyWith(members: updatedMembers);
      notifyListeners();
      debugPrint('updateMemberRole (Optimistic): Updated user $userId to $role');
    }

    try {
      // Step 2: API Update
      await _chatService.updateMemberRole(conversationId, userId, role);
      
      // Send system notification for role change
      if (memberRole == MemberRole.ADMIN) {
        await _sendSystemNotification(conversationId, '$myName đã bổ nhiệm $targetName làm phó nhóm');
      } else if (memberRole == MemberRole.MEMBER) {
        await _sendSystemNotification(conversationId, '$myName đã hạ cấp $targetName thành thành viên');
      }
      
      // Step 3: Unified Sync
      await refreshConversation(conversationId);
    } catch (e) {
      debugPrint('updateMemberRole error: $e');
      // ROLLBACK: Sync back to server truth if API fails (e.g., 404 Member Not Found)
      await refreshConversation(conversationId);
      rethrow;
    }
  }

  Future<void> loadPinnedMessages(String conversationId) async {
    try {
      final pins = await _chatService.getPinnedMessages(conversationId);
      final List<Message> messages = [];
      for (final p in (pins as List)) {
        if (p['message'] != null) {
          messages.add(Message.fromJson(p['message']));
        }
      }
      _pinnedMessages[conversationId] = messages;
      notifyListeners();
    } catch (e) {
      debugPrint('loadPinnedMessages error: $e');
    }
  }

  /// Find a conversation by name (Friend name or Group title) for AI resolution.
  Conversation? findConversationByName(String name) {
    if (name.isEmpty) return null;
    final search = name.toLowerCase().trim();

    String getLabel(Conversation conversation) {
      if (conversation.type == ConversationType.GROUP) {
        return (conversation.title ?? '').toLowerCase();
      }

      if (_currentUserId == null) {
        return (conversation.title ?? '').toLowerCase();
      }

      ConversationMember? peer;
      for (final member in conversation.members) {
        if (member.userId != _currentUserId) {
          peer = member;
          break;
        }
      }

      return (peer?.nickname ??
              peer?.user?.displayName ??
              conversation.title ??
              '')
          .toLowerCase();
    }

    for (final conversation in _conversations) {
      if (getLabel(conversation) == search) {
        return conversation;
      }
    }

    for (final conversation in _conversations) {
      if (getLabel(conversation).contains(search)) {
        return conversation;
      }
    }

    return null;
  }

  void pinMessage(String messageId) {
    if (_activeConversationId == null) return;
    _socketService.pinMessage(messageId, _activeConversationId!);
  }

  void unpinMessage(String messageId) {
    if (_activeConversationId == null) return;
    _socketService.unpinMessage(messageId, _activeConversationId!);
  }

  bool isMessagePinned(String conversationId, String messageId) {
    final pins = _pinnedMessages[conversationId];
    if (pins == null) return false;
    return pins.any((m) => m.id == messageId);
  }

  void _handlePinnedEvent(Map<String, dynamic> data) {
    debugPrint('[ChatProvider] 📌 Received message.pinned event: $data');
    final pin = data['pin'];
    if (pin != null && pin['message'] != null) {
      final conversationId = pin['conversationId'] ?? _activeConversationId;
      if (conversationId == null) {
        debugPrint('[ChatProvider] ⚠️ Skip pin: No conversationId found');
        return;
      }

      final message = Message.fromJson(pin['message']);
      final currentPins = _pinnedMessages[conversationId] ?? [];
      
      // Avoid duplicates
      if (!currentPins.any((m) => m.id == message.id)) {
        _pinnedMessages[conversationId] = [message, ...currentPins];
        notifyListeners();
      }
    }
  }

  void _handleUnpinnedEvent(Map<String, dynamic> data) {
    final messageId = data['messageId'];
    final conversationId = data['conversationId'] ?? _activeConversationId;
    if (messageId == null || conversationId == null) return;

    final currentPins = _pinnedMessages[conversationId] ?? [];
    final updatedPins = currentPins.where((m) => m.id != messageId).toList();
    
    if (updatedPins.length != currentPins.length) {
      _pinnedMessages[conversationId] = updatedPins;
      notifyListeners();
    }
  }

  void _handleReactionAddedEvent(Map<String, dynamic> data) {
    final messageId = data['messageId'];
    if (messageId == null) return;

    final reaction = MessageReaction.fromJson(data);
    final currentReactions = _reactions[messageId] ?? [];
    
    // Remove existing reaction from the same user (if any)
    final filteredReactions = currentReactions.where((r) => r.userId != reaction.userId).toList();
    filteredReactions.add(reaction);
    
    _reactions[messageId] = filteredReactions;
    notifyListeners();
  }

  void _handleReactionRemovedEvent(Map<String, dynamic> data) {
    final messageId = data['messageId'];
    final userId = data['userId'];
    if (messageId == null || userId == null) return;

    final currentReactions = _reactions[messageId] ?? [];
    final filteredReactions = currentReactions.where((r) => r.userId != userId).toList();
    
    _reactions[messageId] = filteredReactions;
    notifyListeners();
  }

  // ─── Reactions Methods ─────────────────────────────────────

  Future<void> addReaction(String messageId, String emoji) async {
    try {
      // Optimistic update
      final currentReactions = _reactions[messageId] ?? [];
      final userReactionIndex = currentReactions.indexWhere((r) => r.userId == _currentUserId);
      
      final optimisticReaction = MessageReaction(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: '',
        messageId: messageId,
        serverSeq: 0,
        userId: _currentUserId ?? '',
        emoji: emoji,
        createdAt: DateTime.now(),
      );
      
      final updatedReactions = List<MessageReaction>.from(currentReactions);
      if (userReactionIndex >= 0) {
        updatedReactions[userReactionIndex] = optimisticReaction;
      } else {
        updatedReactions.add(optimisticReaction);
      }
      
      _reactions[messageId] = updatedReactions;
      notifyListeners();
      
      // Only use REST API for now (WebSocket events not implemented on backend)
      await _chatService.addReaction(messageId, emoji);
      // _socketService.addReaction(messageId, emoji); // Disabled until backend implements WebSocket events

      // Broadcast signal for real-time sync with other clients (Web/Mobile)
      if (_activeConversationId != null) {
        final signal = {
          'action': 'UPDATE_MESSAGE_REACTIONS',
          'messageId': messageId,
          'conversationId': _activeConversationId,
          'actorId': _currentUserId,
          'type': 'ADD',
          'emoji': emoji,
        };
        _socketService.sendMessage(
          conversationId: _activeConversationId!,
          content: jsonEncode(signal),
          messageType: 'SYSTEM',
        );
      }
    } catch (e) {
      debugPrint('Error adding reaction: $e');
      // Revert on error - reload reactions
      await loadReactions(messageId);
    }
  }

  Future<void> removeReaction(String messageId) async {
    try {
      // Find what emoji we are removing for the signal
      final currentReactions = _reactions[messageId] ?? [];
      final myReaction = currentReactions.firstWhere((r) => r.userId == _currentUserId, 
        orElse: () => MessageReaction(id: '', conversationId: '', messageId: '', serverSeq: 0, userId: '', emoji: '', createdAt: DateTime.now())
      );
      final removedEmoji = myReaction.emoji;

      // Optimistic update
      final updatedReactions = currentReactions.where((r) => r.userId != _currentUserId).toList();
      
      _reactions[messageId] = updatedReactions;
      notifyListeners();
      
      // Only use REST API for now (WebSocket events not implemented on backend)
      await _chatService.removeReaction(messageId);
      // _socketService.removeReaction(messageId); // Disabled until backend implements WebSocket events

      // Broadcast signal for real-time sync with other clients (Web/Mobile)
      if (_activeConversationId != null && removedEmoji.isNotEmpty) {
        final signal = {
          'action': 'UPDATE_MESSAGE_REACTIONS',
          'messageId': messageId,
          'conversationId': _activeConversationId,
          'actorId': _currentUserId,
          'type': 'REMOVE',
          'emoji': removedEmoji,
        };
        _socketService.sendMessage(
          conversationId: _activeConversationId!,
          content: jsonEncode(signal),
          messageType: 'SYSTEM',
        );
      }
    } catch (e) {
      debugPrint('Error removing reaction: $e');
      // Revert on error - reload reactions
      await loadReactions(messageId);
    }
  }

  Future<void> loadReactions(String messageId) async {
    try {
      final reactions = await _chatService.getReactions(messageId);
      _reactions[messageId] = reactions;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading reactions: $e');
    }
  }

  void toggleReaction(String messageId, String emoji) async {
    debugPrint('toggleReaction called: messageId=$messageId, emoji=$emoji, userId=$_currentUserId');
    await addReaction(messageId, emoji);
  }
}
