import 'dart:async';
import 'dart:math';

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
import 'package:vnalo_mobile/core/utils/avatar_resolver.dart';
import 'package:vnalo_mobile/features/ai_assistant/utils/ai_compose_draft_bus.dart';
import 'package:vnalo_mobile/features/ai_assistant/utils/ai_command_routing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'dart:io';
import 'dart:convert';

class ChatTypingState {
  final DateTime startedAt;
  final DateTime lastSeen;
  final String? clientPlatform;

  const ChatTypingState({
    required this.startedAt,
    required this.lastSeen,
    this.clientPlatform,
  });
}

class ChatProvider extends ChangeNotifier with WidgetsBindingObserver {
  final ChatService _chatService;
  SocketService _socketService;
  final MediaService _mediaService;
  final NotificationService _notificationService;
  final LocalDatabase _db;
  final AiComposeDraftBus _aiComposeDraftBus;

  final Map<String, List<Message>> _messages = {};
  final Map<String, Timer> _retryTimers = {};
  final Map<String, int> _retryCounts = {};
  final Map<String, List<Message>> _pinnedMessages = {};
  final Map<String, List<MessageReaction>> _reactions = {};
  StreamSubscription<Message>? _messageSub;
  StreamSubscription<Map<String, dynamic>>? _readSub;
  StreamSubscription<Map<String, dynamic>>? _deliveredSub;
  StreamSubscription<Map<String, dynamic>>? _recalledSub;
  StreamSubscription<Map<String, dynamic>>? _pinnedSub;
  StreamSubscription<Map<String, dynamic>>? _unpinnedSub;
  StreamSubscription<Map<String, dynamic>>? _reactionAddedSub;
  StreamSubscription<Map<String, dynamic>>? _reactionRemovedSub;
  StreamSubscription<Map<String, dynamic>>? _groupDisbandedSub;
  StreamSubscription<Map<String, dynamic>>? _groupSettingsChangedSub;
  StreamSubscription<Map<String, dynamic>>? _groupMemberAddedSub;
  StreamSubscription<Map<String, dynamic>>? _groupMemberRemovedSub;
  StreamSubscription<Map<String, dynamic>>? _groupRoleChangedSub;
  StreamSubscription<Map<String, dynamic>>? _groupAdminTransferredSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  StreamSubscription<Map<String, dynamic>>? _presenceSub;
  StreamSubscription<dynamic>? _presenceListSub;
  StreamSubscription<void>? _connectSub;
  int _lastSocketReinitCount = -1;
  final Random _random = Random.secure();

  // Typing indicator state: conversationId -> { userId -> typing state }
  final Map<String, Map<String, ChatTypingState>> _typingUsers = {};

  List<Conversation> _conversations = [];
  String? _activeConversationId;
  String? _currentUserId;
  bool _isLoading = false;
  Message? _replyingTo;
  String? _highlightedMessageId;
  Timer? _highlightTimer;

  // Deduplication cache for system notifications (ID -> Timestamp)
  final Map<String, DateTime> _processedSystemEvents = {};
  Message? _lastCloudMessage;
  Timer? _openConversationDebounce;
  Timer?
  _inboxPollingTimer; // Polling timer for inbox refresh when socket fails
  static const _inboxPollingInterval = Duration(
    seconds: 3,
  ); // Poll every 5 seconds

  List<Conversation> get conversations => _conversations;
  Message? get lastCloudMessage => _lastCloudMessage;
  bool get isLoading => _isLoading;
  String? get activeConversationId => _activeConversationId;
  Message? get replyingTo => _replyingTo;
  String? get highlightedMessageId => _highlightedMessageId;
  String? get currentUserId => _currentUserId;
  Stream<AiComposeDraftEvent> get aiComposeDraftStream =>
      _aiComposeDraftBus.stream;

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

  /// Returns a map of userId -> typing state for users currently typing in [conversationId].
  Map<String, ChatTypingState> getTypingUsers(String conversationId) =>
      _typingUsers[conversationId] ?? {};

  ChatProvider({
    required ChatService chatService,
    required SocketService socketService,
    required MediaService mediaService,
    required NotificationService notificationService,
    required LocalDatabase db,
    required AiComposeDraftBus aiComposeDraftBus,
  }) : _chatService = chatService,
       _socketService = socketService,
       _mediaService = mediaService,
       _notificationService = notificationService,
       _db = db,
       _aiComposeDraftBus = aiComposeDraftBus {
    _notificationService.ensureInitialized();
    _initSocketListeners();

    // Listen for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  void _initSocketListeners() {
    _cancelSubscriptions();

    debugPrint(
      '🟢 [ChatProvider] Initializing socket listeners (Socket reinit count: ${_socketService.reinitCount})',
    );
    _lastSocketReinitCount = _socketService.reinitCount;

    _messageSub = _socketService.onMessage.listen((msg) {
      debugPrint(
        '[ChatProvider] 📡 SOCKET MESSAGE: id=${msg.id} conv=${msg.conversationId} type=${msg.messageType}',
      );
      _handleIncomingMessage(msg);
    });
    _readSub = _socketService.onRead.listen(_handleReadEvent);
    _deliveredSub = _socketService.onDelivered.listen(_handleDeliveredEvent);
    _recalledSub = _socketService.onRecalled.listen(_handleRecalledEvent);
    _pinnedSub = _socketService.onPinned.listen(_handlePinnedEvent);
    _unpinnedSub = _socketService.onUnpinned.listen(_handleUnpinnedEvent);
    _reactionAddedSub = _socketService.onReactionAdded.listen(
      _handleReactionAddedEvent,
    );
    _reactionRemovedSub = _socketService.onReactionRemoved.listen(
      _handleReactionRemovedEvent,
    );
    _groupDisbandedSub = _socketService.onGroupDisbanded.listen(
      _handleGroupDisbandedEvent,
    );
    _groupSettingsChangedSub = _socketService.onGroupSettingsChanged.listen(
      _handleGroupSettingsChangedEvent,
    );
    _groupMemberAddedSub = _socketService.onGroupMemberAdded.listen(
      _handleGroupMemberAddedEvent,
    );
    _groupMemberRemovedSub = _socketService.onGroupMemberRemoved.listen(
      _handleGroupMemberRemovedEvent,
    );
    _groupRoleChangedSub = _socketService.onGroupRoleChanged.listen(
      _handleGroupRoleChangedEvent,
    );
    _groupAdminTransferredSub = _socketService.onGroupAdminTransferred.listen(
      _handleGroupAdminTransferredEvent,
    );
    _typingSub = _socketService.onTyping.listen(_handleTypingEvent);
    _presenceSub = _socketService.onPresence.listen(_handlePresenceEvent);
    _presenceListSub = _socketService.onPresenceList.listen(
      _handlePresenceListEvent,
    );
    _connectSub = _socketService.onConnectStream.listen((_) {
      _requestBulkPresence();
    });
  }

  void _cancelSubscriptions() {
    _messageSub?.cancel();
    _readSub?.cancel();
    _deliveredSub?.cancel();
    _recalledSub?.cancel();
    _pinnedSub?.cancel();
    _unpinnedSub?.cancel();
    _reactionAddedSub?.cancel();
    _reactionRemovedSub?.cancel();
    _groupDisbandedSub?.cancel();
    _groupSettingsChangedSub?.cancel();
    _groupMemberAddedSub?.cancel();
    _groupMemberRemovedSub?.cancel();
    _groupRoleChangedSub?.cancel();
    _groupAdminTransferredSub?.cancel();
    _typingSub?.cancel();
    _presenceSub?.cancel();
    _presenceListSub?.cancel();
    _connectSub?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[ChatProvider] 📱 App Resumed: Reporting Online');
      _socketService.emitPresence(true);
      loadInbox(); // Refresh to get latest state
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      debugPrint('[ChatProvider] 📱 App Paused/Inactive: Reporting Offline');
      _socketService.emitPresence(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelSubscriptions();
    _inboxPollingTimer?.cancel();
    _highlightTimer?.cancel();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void injectAiComposeDraft({
    required String conversationId,
    required String text,
  }) {
    _aiComposeDraftBus.emit(conversationId: conversationId, text: text);
  }

  List<Message> getMessages(String conversationId) =>
      _messages[conversationId] ?? [];

  // Mock frontend-only state for "Quyền gửi tin nhắn" (Only Owners/Admins can send)
  final Map<String, bool> _readOnlyForMembers = {};
  bool isReadOnlyForMembers(String convId) =>
      _readOnlyForMembers[convId] ?? false;
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
          final cloudMsgs = await _db.getMessagesByConversation(
            'MY_DOCUMENTS',
            _currentUserId!,
          );
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
      final localEmptyGroups =
          _conversations.where((localConv) {
            return !backendIds.contains(localConv.id) &&
                localConv.type == ConversationType.GROUP &&
                localConv.lastMessage == null &&
                localConv.members.any(
                  (m) => m.userId == _currentUserId && m.leftAt == null,
                );
          }).toList();

      final combined = [...raw, ...localEmptyGroups];

      _conversations =
          combined
              .map((remoteConv) {
                final localConv = _conversations.firstWhere(
                  (c) => c.id == remoteConv.id,
                  orElse: () => remoteConv,
                );
                // Use the remoteConv as base, but merge members from localConv if it exists and is different
                return _mergeAndSanitize(
                  remoteConv,
                  local: localConv == remoteConv ? null : localConv,
                );
              })
              .whereType<Conversation>()
              // FILTER: Only keep groups where I am currently an active member
              // This solves the database persistence issue where old groups stay in the server inbox
              .where((c) {
                if (c.type == ConversationType.DIRECT) return true;
                return c.members.any(
                  (m) => m.userId == _currentUserId && m.leftAt == null,
                );
              })
              .toList();
      await _applyLocalReadStateOverrides();
      _sortConversations();
      _syncPresenceFromConversations();

      // Request bulk presence: try immediately, then retry after 2s
      // (handles race condition where socket connects after loadInbox finishes)
      _requestBulkPresence();
      Future.delayed(const Duration(seconds: 2), _requestBulkPresence);

      // Ensure we join all conversation rooms to receive group call signals and other events
      for (final conv in _conversations) {
        _socketService.joinConversation(conv.id);
      }

      // Start inbox polling as fallback for realtime messaging (since socket.broadcast may not work)
      _startInboxPolling();
    } catch (e) {
      debugPrint('loadInbox error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startInboxPolling() {
    _inboxPollingTimer?.cancel();
    _inboxPollingTimer = Timer.periodic(
      _inboxPollingInterval,
      (_) => _pollInbox(),
    );
    debugPrint(
      '[ChatProvider] Started inbox polling every ${_inboxPollingInterval.inSeconds}s',
    );
  }

  Future<void> _pollInbox() async {
    try {
      final newConversations = await _chatService.getInbox();
      bool hasNewMessages = false;

      for (final conv in newConversations) {
        final convId = conv.id;
        final existingIndex = _conversations.indexWhere((c) => c.id == convId);

        if (existingIndex < 0) {
          debugPrint('[SYNC] 🆕 New conversation found in poll: $convId');
          _conversations.add(conv);
          hasNewMessages = true;
          await _reloadMessagesForConversation(convId);
          continue;
        }

        final existingConv = _conversations[existingIndex];
        bool hasChanges = false;

        // --- SYNC GUARD: Detect missed member changes ---
        if (conv.members.length != existingConv.members.length) {
          debugPrint(
            '[SYNC] 👥 Member count change detected for ${conv.id}: ${existingConv.members.length} -> ${conv.members.length}',
          );

          final String eventKey =
              'member_count_${conv.id}_${conv.members.length}';
          final now = DateTime.now();

          // Check if we already processed this change recently via Socket
          if (_processedSystemEvents[eventKey] == null ||
              now.difference(_processedSystemEvents[eventKey]!).inSeconds >
                  10) {
            _processedSystemEvents[eventKey] = now;

            if (conv.members.length > existingConv.members.length) {
              // Someone was added
              final existingIds =
                  existingConv.members.map((m) => m.userId).toSet();
              final added =
                  conv.members
                      .where((m) => !existingIds.contains(m.userId))
                      .toList();
              if (added.isNotEmpty) {
                final names = added
                    .map((m) => m.user?.displayName ?? 'Thành viên mới')
                    .join(', ');
                _sendSystemNotification(
                  conv.id,
                  '$names đã được thêm vào nhóm',
                );
              }
            } else {
              // Someone left/removed
              final newIds = conv.members.map((m) => m.userId).toSet();
              final removed =
                  existingConv.members
                      .where((m) => !newIds.contains(m.userId))
                      .toList();
              if (removed.isNotEmpty) {
                final names = removed
                    .map((m) => m.user?.displayName ?? 'Thành viên')
                    .join(', ');
                _sendSystemNotification(
                  conv.id,
                  '$names đã không còn trong nhóm',
                );
              }
            }
          }
          hasChanges = true;
        }
        // -----------------------------------------------

        final newSeq = conv.lastMessage?.serverSeq?.toString();
        final existingSeq = existingConv.lastMessage?.serverSeq?.toString();

        if (newSeq != null && newSeq != existingSeq) {
          debugPrint(
            '[SYNC] 🔄 Out of sync detected for $convId: existing=$existingSeq, new=$newSeq',
          );
          hasNewMessages = true;
          hasChanges = true;
          await _reloadMessagesForConversation(convId);
        }

        // CRITICAL: Update the in-memory conversation object if ANY change was detected
        // to prevent the next poll from triggering the same notification.
        if (hasChanges) {
          _conversations[existingIndex] = conv;
        }
      }

      if (hasNewMessages) {
        _sortConversations();
        _syncPresenceFromConversations();
        notifyListeners();
        debugPrint('[ChatProvider] _pollInbox: Updated UI with new messages');
      }
    } catch (e) {
      debugPrint('[ChatProvider] _pollInbox error: $e');
    }
  }

  Future<void> _reloadMessagesForConversation(String convId) async {
    try {
      // Fetch latest 50 messages from server to sync state
      final messages = await _chatService.fetchLatestMessages(
        convId,
        limit: 50,
      );

      if (messages.isNotEmpty) {
        debugPrint(
          '[SYNC]   → Got ${messages.length} messages from server for $convId',
        );
        final existing = _messages[convId] ?? [];
        final existingIds = existing.map((m) => m.id).toSet();

        // Find messages that we don't have yet
        final newItems =
            messages.where((m) => !existingIds.contains(m.id)).toList();

        if (newItems.isNotEmpty) {
          // Merge and sort to ensure newest is at index 0 (bottom of reversed list)
          // Also preserve local-only messages (system/pending)
          final localOnly =
              existing
                  .where(
                    (m) => m.id.startsWith('sys_') || m.id.startsWith('local-'),
                  )
                  .toList();

          final merged = [
            ...newItems,
            ...existing.where(
              (m) => !m.id.startsWith('sys_') && !m.id.startsWith('local-'),
            ),
            ...localOnly,
          ];
          merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          _messages[convId] = merged;
          debugPrint(
            '[SYNC]   → Merged ${newItems.length} unique messages. Total: ${merged.length}',
          );

          if (convId == _activeConversationId) {
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatProvider] _reloadMessagesForConversation error: $e');
    }
  }

  void refreshCloudPreview() async {
    try {
      if (_currentUserId != null) {
        final cloudMsgs = await _db.getMessagesByConversation(
          'MY_DOCUMENTS',
          _currentUserId!,
        );
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
      final isMissingInRemote =
          !remoteMembers.any((rm) => rm.userId == localM.userId);
      // Protection period: 60 seconds
      final isVeryRecent = localM.joinedAt.isAfter(
        DateTime.now().subtract(const Duration(seconds: 60)),
      );

      if (isMissingInRemote && isVeryRecent && localM.leftAt == null) {
        mergedMembers.add(localM);
        debugPrint(
          'Sync protection: Preserved optimistic member ${localM.userId} in ${remote.id}',
        );
      } else {
        // ⚡ PRESENCE PROTECTION: If member exists in both, keep the latest online status from local
        final remoteIdx = mergedMembers.indexWhere(
          (rm) => rm.userId == localM.userId,
        );
        if (remoteIdx >= 0 &&
            localM.user != null &&
            mergedMembers[remoteIdx].user != null) {
          final localUser = localM.user!;
          final remoteUser = mergedMembers[remoteIdx].user!;

          // If local knows the user is online but remote says offline, trust local (it's more real-time)
          if (localUser.isOnline && !remoteUser.isOnline) {
            mergedMembers[remoteIdx] = mergedMembers[remoteIdx].copyWith(
              user: remoteUser.copyWith(
                isOnline: true,
                lastSeen: localUser.lastSeen,
              ),
            );
          }
        }
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
      orElse:
          () => ConversationMember(
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
    final owners =
        conv.members.where((m) => m.role == MemberRole.ADMIN).toList();
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

      final sanitizedMembers =
          conv.members.map((m) {
            if (m.role == MemberRole.ADMIN && m.userId != primaryOwnerId) {
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
            final memberIndex = sanitized.members.indexWhere(
              (m) => m.userId == currentUser,
            );
            if (memberIndex >= 0) {
              userName =
                  sanitized.members[memberIndex].user?.displayName ?? userName;
            }
          }
          await _sendSystemNotification(
            sanitized.id,
            '$userName đã tạo nhóm "$title"',
          );

          // BROADCAST to other platforms/members via Socket
          // 1. Join room first
          _socketService.joinConversation(sanitized.id);

          // 2. Emit identical SYSTEM message as Web does, so Web can 'discover' it
          final syncPayload =
              '{"action":"CREATE_GROUP","actorId":"$currentUser"}';
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

  Future<Conversation?> getOrCreateDirectConversation(
    String otherUserId,
  ) async {
    final targetUserId = otherUserId.trim();
    if (targetUserId.isEmpty) return null;

    try {
      final conversation = await _chatService.getOrCreateDirect(targetUserId);
      final sanitized = _sanitizeConversation(conversation);
      if (sanitized == null) return conversation;

      final existingIndex = _conversations.indexWhere(
        (item) => item.id == sanitized.id,
      );
      if (existingIndex >= 0) {
        _conversations[existingIndex] = sanitized;
      } else {
        _conversations = [sanitized, ..._conversations];
      }
      _sortConversations();
      _socketService.joinConversation(sanitized.id);
      notifyListeners();
      return sanitized;
    } catch (error) {
      debugPrint('getOrCreateDirectConversation error: $error');
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

      // Resolve senderName from members for all messages
      for (int i = 0; i < response.length; i++) {
        final msg = response[i];
        if (msg.senderName == null) {
          final resolvedName = getSenderName(conversationId, msg.senderId);
          response[i] = msg.copyWith(senderName: resolvedName);
        }
        // Also resolve reply sender name
        if (msg.replyToSenderId != null && msg.replyToSenderName == null) {
          final replyName = getSenderName(conversationId, msg.replyToSenderId!);
          response[i] = response[i].copyWith(replyToSenderName: replyName);
        }
      }

      if (before == null) {
        // MERGE: Keep existing local system messages or local pending messages
        final existing = _messages[conversationId] ?? [];
        final localOnly =
            existing
                .where(
                  (m) => m.id.startsWith('sys_') || m.id.startsWith('local-'),
                )
                .toList();

        // Deduplicate: If server already confirmed a local message, don't keep the local version
        final serverIds = response.map((m) => m.id).toSet();
        final serverClientIds =
            response.map((m) => m.clientMessageId).whereType<String>().toSet();

        final filteredLocal =
            localOnly.where((m) {
              if (serverIds.contains(m.id)) return false;
              if (m.clientMessageId != null &&
                  serverClientIds.contains(m.clientMessageId))
                return false;
              return true;
            }).toList();

        final merged = [...response, ...filteredLocal];
        // Ensure chronological order (newest first for UI list)
        merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        _messages[conversationId] = merged;

        // Sync API messages to local DB in background
        _db.saveMessagesBatch(response.map(_toLocal).toList());
      } else {
        final existing = _messages[conversationId] ?? [];
        final merged = [...existing, ...response];
        merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _messages[conversationId] = merged;
      }
      notifyListeners();
    } catch (e, stack) {
      debugPrint('loadMessages error: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  LocalMessage _toLocal(Message m) {
    if (_currentUserId == null) {
      throw StateError(
        'Cannot map to local message without active currentUserId',
      );
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
    // Zero latency: open immediately without debounce
    await _openConversationInternal(conversationId);
  }

  Future<void> _openConversationInternal(String conversationId) async {
    // Skip if already in this conversation or if userId not set yet
    if (_activeConversationId == conversationId || _currentUserId == null) {
      return;
    }

    _activeConversationId = conversationId;
    _socketService.joinConversation(conversationId);
    // Load pinned messages in background (non-blocking)
    loadPinnedMessages(conversationId);

    // Clear unread count locally
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      final conv = _conversations[index];
      if (conv.unreadCount > 0) {
        _conversations[index] = conv.copyWith(unreadCount: 0);
        if (conv.lastMessage != null && conv.lastMessage!.serverSeq != null) {
          _socketService.markRead(conversationId, conv.lastMessage!.serverSeq!);
          _db.upsertConversationReadState(
            conversationId: conversationId,
            lastReadSeq: conv.lastMessage!.serverSeq!,
          );
        }
      }
    }

    // Load from Local Cache FIRST (Optimistic UI) — no notifyListeners here
    final localMsgs = await _db.getMessagesByConversation(
      conversationId,
      _currentUserId!,
    );
    if (_activeConversationId == conversationId) {
      _messages[conversationId] = localMsgs.map(_fromLocal).toList();
    }

    // Then fetch fresh data from API
    await loadMessages(conversationId);

    // Ensure read state is synced after fresh messages are loaded.
    final latestSeq =
        _messages[conversationId]
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

    // Single notifyListeners after all data is loaded
    notifyListeners();
  }

  void update(String? userId, SocketService socketService) {
    debugPrint(
      '[ChatProvider] 🔄 update called: userId=$userId, socketConnected=${socketService.isConnected()}',
    );
    bool needsReinit = false;

    if (_socketService != socketService) {
      debugPrint('🟢 [ChatProvider] SocketService instance changed');
      _socketService = socketService;
      needsReinit = true;
    }

    if (_currentUserId != userId) {
      debugPrint('[ChatProvider] 🔑 User changed: $_currentUserId -> $userId');
      _currentUserId = userId;
      if (userId == null || userId.isEmpty) {
        _cancelSubscriptions();
        _messages.clear();
        _conversations = [];
        _activeConversationId = null;
        notifyListeners();
      } else {
        needsReinit = true;
      }
    }

    if (_currentUserId != null &&
        (needsReinit || _lastSocketReinitCount != _socketService.reinitCount)) {
      debugPrint(
        '🟢 [ChatProvider] Re-initializing socket listeners (reinitCount: ${_socketService.reinitCount})',
      );
      _initSocketListeners();
      loadInbox();
    }
  }

  set currentUserId(String? value) {
    if (_currentUserId != value) {
      _currentUserId = value;
      if (value != null && value.isNotEmpty) {
        _syncPresenceFromConversations();
        notifyListeners();
      }
    }
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
      final resolvedName = getSenderName(
        message.conversationId,
        message.senderId,
      );
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
    if (actualReplyId != null &&
        _replyingTo != null &&
        _replyingTo!.id == actualReplyId) {
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

    debugPrint(
      '[ChatProvider] sendMessage ADDING TO UI: conv=$conversationId id=local-$clientMessageId content="$content"',
    );
    _messages[conversationId] = [
      optimistic,
      ...(getMessagesForConversation(conversationId)),
    ];
    _replyingTo = null; // Clear reply state after sending

    // ⚡ ZERO LATENCY: Update Inbox immediately (move to top)
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx >= 0) {
      final conv = _conversations[idx];
      _conversations.removeAt(idx);
      _conversations.insert(
        0,
        conv.copyWith(lastMessage: optimistic, updatedAt: DateTime.now()),
      );
    }

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

    _messages[conversationId] = [
      optimistic,
      ...(getMessagesForConversation(conversationId)),
    ];

    // ⚡ ZERO LATENCY: Update Inbox immediately (move to top)
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx >= 0) {
      final conv = _conversations[idx];
      _conversations.removeAt(idx);
      _conversations.insert(
        0,
        conv.copyWith(lastMessage: optimistic, updatedAt: DateTime.now()),
      );
    }

    notifyListeners();

    if (file == null && mediaUrl != null) {
      _sendWithRetryMedia(optimistic);
      return;
    }

    try {
      final category = _mapMessageTypeToCategory(type);
      final mediaId = await _mediaService.uploadFile(file!, category);
      final publicUrl = _mediaService.getPublicUrl(mediaId);

      final updated = optimistic.copyWith(
        mediaUrl: publicUrl,
        content:
            content ??
            (type == MessageType.AUDIO
                ? (content ?? '')
                : (optimistic.content ?? fileName)),
        mediaSizeBytes: fileSize,
      );
      _replaceMessage(conversationId, optimistic.id, updated);
      _sendWithRetryMedia(updated);
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

    _messages[conversationId] = [
      message,
      ...(getMessagesForConversation(conversationId)),
    ];
    notifyListeners();
    _sendWithRetryMedia(message);
  }

  void sendGif({required String conversationId, required String gifUrl}) {
    debugPrint('[ChatProvider] sendGif: conv=$conversationId url=$gifUrl');
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

    debugPrint(
      '[ChatProvider] sendForwardBatch: ${sourceMessages.length} msgs to ${conversationIds.length} convs',
    );

    final extra = additionalText?.trim();

    for (final conversationId in conversationIds) {
      // Send optional additional text first
      if (extra != null && extra.isNotEmpty) {
        try {
          final msg = await _chatService.sendMessage(
            conversationId: conversationId,
            content: extra,
            messageType: 'TEXT',
          );
          _addMessageToConversation(conversationId, msg);
          debugPrint(
            '[ChatProvider] sendForwardBatch: extra text sent to $conversationId',
          );
        } catch (e) {
          debugPrint(
            '[ChatProvider] sendForwardBatch: failed to send extra text to $conversationId: $e',
          );
        }
      }

      // Send each source message
      for (final source in sourceMessages) {
        try {
          final hasRemoteMedia = (source.mediaUrl ?? '').trim().isNotEmpty;

          if (source.messageType == MessageType.TEXT || !hasRemoteMedia) {
            final content = (source.content ?? '').trim();
            if (content.isEmpty) continue;

            final msg = await _chatService.sendMessage(
              conversationId: conversationId,
              content: content,
              messageType: source.messageType.name,
              mediaUrl: hasRemoteMedia ? source.mediaUrl : null,
              mediaThumbnailUrl: source.mediaThumbnailUrl,
              forwardFromMessageId: source.id,
              forwardFromConversationId: source.conversationId,
            );
            _addMessageToConversation(conversationId, msg);
            debugPrint(
              '[ChatProvider] sendForwardBatch: TEXT/FILE msg sent to $conversationId',
            );
          } else {
            // Media message (IMAGE, VIDEO, AUDIO, STICKER) — forward as media
            final msg = await _chatService.sendMessage(
              conversationId: conversationId,
              content: source.content ?? '',
              messageType: source.messageType.name,
              mediaUrl: source.mediaUrl,
              mediaThumbnailUrl: source.mediaThumbnailUrl,
              mediaMimeType: source.mediaMimeType,
              mediaSizeBytes: source.mediaSizeBytes,
              forwardFromMessageId: source.id,
              forwardFromConversationId: source.conversationId,
            );
            _addMessageToConversation(conversationId, msg);
            debugPrint(
              '[ChatProvider] sendForwardBatch: MEDIA msg sent to $conversationId',
            );
          }
        } catch (e) {
          debugPrint(
            '[ChatProvider] sendForwardBatch: failed to forward msg ${source.id} to $conversationId: $e',
          );
        }
      }
    }
  }

  void _addMessageToConversation(String conversationId, Message message) {
    final list = _messages[conversationId] ?? [];
    debugPrint(
      '[ChatProvider] _addMessageToConversation: conv=$conversationId msgId=${message.id} existingCount=${list.length}',
    );
    if (!list.any((m) => m.id == message.id)) {
      _messages[conversationId] = [message, ...list];
      _db.saveMessage(_toLocal(message));
      notifyListeners();
      debugPrint(
        '[ChatProvider] _addMessageToConversation: ADDED msgId=${message.id} newCount=${list.length + 1}',
      );
    } else {
      debugPrint(
        '[ChatProvider] _addMessageToConversation: SKIPPED (duplicate) msgId=${message.id}',
      );
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

    // Use HTTP fallback for TEXT, socket retry for media
    final isMedia = message.mediaUrl != null;
    if (isMedia) {
      _sendWithRetryMedia(message.copyWith(status: MessageStatus.SENDING));
    } else {
      _sendWithRetry(message.copyWith(status: MessageStatus.SENDING));
    }
  }

  void _syncPresenceToMembers(
    String userId,
    bool isOnline, {
    DateTime? lastSeen,
  }) {
    debugPrint(
      '[ChatProvider] 🔄 _syncPresenceToMembers: $userId -> online=$isOnline',
    );
    int matchCount = 0;
    for (int i = 0; i < _conversations.length; i++) {
      final conv = _conversations[i];
      final memberIdx = conv.members.indexWhere(
        (m) => m.userId.toLowerCase() == userId,
      );
      if (memberIdx >= 0) {
        matchCount++;
        final member = conv.members[memberIdx];
        if (member.user != null &&
            (member.user!.isOnline != isOnline ||
                member.user!.lastSeen != lastSeen)) {
          final updatedUser = member.user!.copyWith(
            isOnline: isOnline,
            lastSeen:
                lastSeen ?? (isOnline ? DateTime.now() : member.user!.lastSeen),
          );
          final updatedMember = member.copyWith(user: updatedUser);
          final updatedMembers = List<ConversationMember>.from(conv.members);
          updatedMembers[memberIdx] = updatedMember;
          _conversations[i] = conv.copyWith(members: updatedMembers);
          debugPrint(
            '[ChatProvider] ✅ Updated member presence in conv ${conv.id}',
          );
        }
      }
    }
    debugPrint(
      '[ChatProvider] 🔄 _syncPresenceToMembers finished. Matches: $matchCount',
    );
  }

  void _handleIncomingMessage(Message message) {
    final String conversationId = message.conversationId;

    // Force sender presence to online if message received (since they must be active to send)
    if (message.senderId != _currentUserId) {
      final String senderId = message.senderId.toLowerCase();
      if (_userPresence[senderId] != true) {
        debugPrint(
          '[PRESENCE] 📡 FORCING Presence ONLINE for $senderId due to incoming message',
        );
        _userPresence[senderId] = true;
        // Also update the member object in conversations if it exists
        _syncPresenceToMembers(senderId, true);
        debugPrint('[PRESENCE] 📡 Presence cache now: $_userPresence');
        notifyListeners();
      }
    }
    debugPrint(
      '[ChatProvider] 📩 _handleIncomingMessage: id=${message.id} conv=$conversationId sender=${message.senderId} type=${message.messageType} clientId=${message.clientMessageId} isMine=${message.senderId == _currentUserId} content=${message.content?.substring(0, min(30, message.content?.length ?? 0))}',
    );
    // #region agent_h2_provider_entry
    debugPrint(
      '[DEBUG][H2] ChatProvider._handleIncomingMessage ENTRY - msgId=${message.id} convId=$conversationId senderId=${message.senderId}',
    );
    // #endregion

    // Early deduplication: skip if a message with the same server ID is already in the list
    final existing = _messages[conversationId] ?? [];
    if (!message.id.startsWith('local-') &&
        existing.any((m) => m.id == message.id)) {
      debugPrint(
        '[ChatProvider] _handleIncomingMessage: SKIPPED duplicate server id=${message.id}',
      );
      return;
    }

    // FILTER: Prevent "Ghost Conversations" from friend requests
    if (message.isSystemMessage) {
      final content = message.content ?? '';
      if (content.contains('lời mời kết bạn') ||
          content.contains('[ACTION:FRIEND_REQUEST]')) {
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index < 0) {
          debugPrint(
            '[ChatProvider] 🚫 Filtering out ghost conversation from friend request: $conversationId',
          );
          _db.saveMessage(_toLocal(message));
          return;
        }
      }

      // Signal handling for reactions etc
      try {
        if (content.contains('"action":"UPDATE_MESSAGE_REACTIONS"')) {
          final data = jsonDecode(content);
          final msgId = data['messageId'];
          final actionType = data['type'];
          final emoji = data['emoji'];
          final actorId = data['actorId'];

          if (msgId != null) {
            debugPrint('SIGNAL: Reaction update signal received for $msgId.');
            if (actionType != null && emoji != null && actorId != null) {
              final currentReactions = _reactions[msgId] ?? [];
              if (actionType == 'ADD') {
                final newReaction = MessageReaction(
                  id: 'signal_${DateTime.now().millisecondsSinceEpoch}',
                  conversationId: conversationId,
                  messageId: msgId,
                  serverSeq: 0,
                  userId: actorId,
                  emoji: emoji,
                  createdAt: DateTime.now(),
                );
                final filtered =
                    currentReactions.where((r) => r.userId != actorId).toList();
                filtered.add(newReaction);
                _reactions[msgId] = filtered;
              } else if (actionType == 'REMOVE') {
                _reactions[msgId] =
                    currentReactions.where((r) => r.userId != actorId).toList();
              }
              notifyListeners();
            }
            loadReactions(msgId);
          }
        }
      } catch (e) {
        debugPrint('Error parsing system signal: $e');
      }
    }

    // Resolve mediaId to URL if it's just an ID
    Message resolvedMessage = message;
    if (message.mediaUrl != null &&
        !message.mediaUrl!.startsWith('http') &&
        !message.mediaUrl!.startsWith('/')) {
      resolvedMessage = message.copyWith(
        mediaUrl: _mediaService.getPublicUrl(message.mediaUrl!),
      );
    }

    // Also resolve via AvatarResolver to ensure proper URL formatting for all cases
    if (resolvedMessage.mediaUrl != null) {
      final resolvedUrl = AvatarResolver.resolveUrl(resolvedMessage.mediaUrl!);
      if (resolvedUrl != null && resolvedUrl != resolvedMessage.mediaUrl) {
        debugPrint(
          '[ChatProvider] _handleIncomingMessage: AvatarResolver mediaUrl ${resolvedMessage.mediaUrl} -> $resolvedUrl',
        );
        resolvedMessage = resolvedMessage.copyWith(mediaUrl: resolvedUrl);
      }
    }

    // Resolve reply sender name if missing but ID is present
    if (resolvedMessage.replyToSenderId != null &&
        resolvedMessage.replyToSenderName == null) {
      final resolvedReplyName = getSenderName(
        conversationId,
        resolvedMessage.replyToSenderId!,
      );
      resolvedMessage = resolvedMessage.copyWith(
        replyToSenderName: resolvedReplyName,
      );
    }

    final msgList = _messages[conversationId] ?? [];
    final clientMessageId = resolvedMessage.clientMessageId;
    if (clientMessageId != null) {
      _clearRetry(clientMessageId);
      final optimisticIndex = msgList.indexWhere(
        (m) => m.clientMessageId == clientMessageId,
      );
      if (optimisticIndex >= 0) {
        debugPrint(
          '[ChatProvider] _handleIncomingMessage: REPLACING optimistic msgId=${message.id} clientId=$clientMessageId',
        );
        final updated = List<Message>.from(msgList);
        final oldMessage = updated[optimisticIndex];

        // MERGE metadata: Keep reply info if already present in optimistic but missing in resolved
        Message merged = resolvedMessage;
        if (oldMessage.replyToMessageId != null &&
            merged.replyToMessageId == null) {
          merged = merged.copyWith(
            replyToMessageId: oldMessage.replyToMessageId,
            replyToSenderId: oldMessage.replyToSenderId,
            replyToSenderName: oldMessage.replyToSenderName,
            replyToContent: oldMessage.replyToContent,
          );
        } else if (merged.replyToMessageId != null &&
            merged.replyToSenderName == null) {
          // If server returned ID but no name, try to use old name
          merged = merged.copyWith(
            replyToSenderName: oldMessage.replyToSenderName,
          );
        }

        // Resolve senderName from optimistic message or member list if missing
        if (merged.senderName == null) {
          final resolvedSenderName =
              oldMessage.senderName ??
              getSenderName(conversationId, merged.senderId);
          merged = merged.copyWith(senderName: resolvedSenderName);
        }

        updated[optimisticIndex] = merged;
        _messages[conversationId] = updated;
      } else {
        // Not an optimistic message (from another device) — resolve senderName from members
        final alreadyPresent = msgList.any((m) => m.id == message.id);
        if (!alreadyPresent) {
          debugPrint(
            '[ChatProvider] _handleIncomingMessage: ADDING new msg (no clientId) msgId=${message.id}',
          );
          Message toAdd = message;
          if (message.senderName == null) {
            toAdd = message.copyWith(
              senderName: getSenderName(conversationId, message.senderId),
            );
          }
          _messages[conversationId] = [toAdd, ...msgList];
        }
      }
    } else {
      // No clientMessageId — resolve senderName from members
      final alreadyPresent = msgList.any((m) => m.id == message.id);
      if (!alreadyPresent) {
        debugPrint(
          '[ChatProvider] _handleIncomingMessage: ADDING new msg (no clientId) msgId=${message.id}',
        );
        Message toAdd = message;
        if (message.senderName == null) {
          toAdd = message.copyWith(
            senderName: getSenderName(conversationId, message.senderId),
          );
        }
        _messages[conversationId] = [toAdd, ...msgList];
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
        unreadCount:
            (isActiveConversation || isMine) ? 0 : conversation.unreadCount + 1,
      );
      _conversations[index] = updatedConversation;
      resolvedConversation = updatedConversation;
      debugPrint(
        '[ChatProvider] ✅ Updated conversation lastMessage: convId=$conversationId msgId=${message.id} isMine=$isMine unread=${updatedConversation.unreadCount}',
      );
      // #region agent_h3_notify
      debugPrint(
        '[DEBUG][H3] About to call notifyListeners - conversation list updated, _activeConversationId=$_activeConversationId',
      );
      // #endregion
      _sortConversations();
    } else {
      debugPrint(
        '[ChatProvider] ⚠️ Conversation NOT FOUND in list, adding message first then reloading inbox',
      );
      // First add message to local list so it displays immediately
      _messages[conversationId] = [
        resolvedMessage.copyWith(
          senderName: getSenderName(conversationId, message.senderId),
        ),
        ...msgList,
      ];
      // Then reload inbox
      loadInbox();
    }

    // Emit delivered indicator if it's not our message
    if (!isMine) {
      _socketService.markDelivered(message.id, conversationId);

      final isMuted = resolvedConversation?.isMuted ?? false;
      if (!isMuted) {
        _playIncomingMessageSound();
      }

      // 2. Real-time Inbox Update (Zero Latency)
      // Move conversation to top and update last message state locally
      final convIndex = _conversations.indexWhere(
        (c) => c.id == conversationId,
      );
      if (convIndex >= 0) {
        final conv = _conversations[convIndex];
        final updatedConv = conv.copyWith(
          lastMessage: resolvedMessage,
          unreadCount: !isActiveConversation ? (conv.unreadCount + 1) : 0,
          updatedAt: DateTime.now(),
        );

        // Move to top: remove from current pos and insert at 0
        _conversations.removeAt(convIndex);
        _conversations.insert(0, updatedConv);

        debugPrint(
          '[ChatProvider] ⚡ Real-time Inbox update: Moved $conversationId to top',
        );
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

    // #region agent_h3_notify_end
    debugPrint('[DEBUG][H3] CALLING notifyListeners now - UI should rebuild');
    // #endregion
    notifyListeners();
    // #region agent_h3_notify_done
    debugPrint(
      '[DEBUG][H3] notifyListeners COMPLETED - UI should have rebuilt',
    );
    // #endregion
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
        debugPrint(
          '[ChatProvider] Database cleanup successful for $conversationId',
        );
      } catch (e) {
        debugPrint(
          '[ChatProvider] Database cleanup failed for $conversationId: $e',
        );
      }
    }
  }

  void _handleGroupDisbandedEvent(Map<String, dynamic> data) {
    final String? conversationId = data['conversationId'];
    if (conversationId != null) {
      debugPrint(
        '[ChatProvider] EVENT: Group disbanded: $conversationId. Purging cache...',
      );
      _removeConversationLocally(conversationId);
    }
  }

  void _handleGroupSettingsChangedEvent(Map<String, dynamic> data) {
    final String? conversationId = data['conversationId'];
    if (conversationId == null) return;
    debugPrint('[ChatProvider] EVENT: Group settings changed: $conversationId');

    // Optional: Show notification if actor info is available
    final String? actorId = data['actorId'];
    if (actorId != null) {
      final actorName = getSenderName(conversationId, actorId);
      _sendSystemNotification(
        conversationId,
        '$actorName đã cập nhật thiết lập nhóm',
      );
    }

    refreshConversation(conversationId);
  }

  void _handleGroupMemberAddedEvent(Map<String, dynamic> data) {
    final String? conversationId = data['conversationId'];
    final String? actorId = data['actorId'];
    final List<dynamic>? memberIds = data['memberIds'];

    if (conversationId == null) return;
    debugPrint('[ChatProvider] EVENT: Member added to group: $conversationId');

    // Deduplication
    if (memberIds != null) {
      for (final id in memberIds) {
        _processedSystemEvents['member_added_${conversationId}_$id'] =
            DateTime.now();
      }
      // Also mark member count event as processed to prevent Polling from firing
      final int idx = _conversations.indexWhere((c) => c.id == conversationId);
      if (idx >= 0) {
        final int newCount =
            _conversations[idx].members.length + memberIds.length;
        _processedSystemEvents['member_count_${conversationId}_$newCount'] =
            DateTime.now();
      }
    }

    // First refresh to get the latest member list (to resolve names)
    refreshConversation(conversationId).then((_) {
      if (actorId != null && memberIds != null && memberIds.isNotEmpty) {
        final actorName = getSenderName(conversationId, actorId);
        // Resolve names for all added members
        final List<String> names =
            memberIds
                .map((id) => getSenderName(conversationId, id.toString()))
                .toList();
        final namesString = names.join(', ');

        _sendSystemNotification(
          conversationId,
          '$actorName đã thêm $namesString vào nhóm',
        );
      }
    });
  }

  void _handleGroupMemberRemovedEvent(Map<String, dynamic> data) {
    final String? conversationId = data['conversationId'];
    final String? removedUserId = data['userId'];
    final String? actorId = data['actorId'];
    if (conversationId == null || removedUserId == null) return;

    if (removedUserId == _currentUserId) {
      debugPrint('[ChatProvider] EVENT: I was removed from $conversationId');
      _removeConversationLocally(conversationId);
    } else {
      debugPrint(
        '[ChatProvider] EVENT: Member $removedUserId removed from $conversationId',
      );

      // Use a consistent event key for deduplication
      final String eventKey = 'member_removed_${conversationId}_$removedUserId';
      _processedSystemEvents[eventKey] = DateTime.now();

      // Refresh first to get accurate names and state
      refreshConversation(conversationId).then((_) {
        final actorName =
            actorId != null ? getSenderName(conversationId, actorId) : null;
        final removedName = getSenderName(conversationId, removedUserId);
        final bool isSilent = data['silent'] == true;

        if (!isSilent) {
          if (actorId == removedUserId) {
            _sendSystemNotification(
              conversationId,
              '$removedName đã rời khỏi nhóm',
            );
          } else if (actorName != null) {
            _sendSystemNotification(
              conversationId,
              '$removedName đã bị $actorName xóa khỏi nhóm',
            );
          } else {
            _sendSystemNotification(
              conversationId,
              '$removedName đã không còn trong nhóm',
            );
          }
        }
      });
    }
  }

  void _handleGroupRoleChangedEvent(Map<String, dynamic> data) {
    final String? conversationId = data['conversationId'];
    if (conversationId == null) return;
    debugPrint('[ChatProvider] EVENT: Role changed in group: $conversationId');
    refreshConversation(conversationId);
  }

  void _handleGroupAdminTransferredEvent(Map<String, dynamic> data) {
    final String? conversationId = data['conversationId'];
    final String? newAdminId = data['newAdminId'];
    final String? oldAdminId = data['oldAdminId'];

    if (conversationId == null) return;
    debugPrint(
      '[ChatProvider] EVENT: Admin transferred in group: $conversationId',
    );

    if (newAdminId != null && oldAdminId != null) {
      final newAdminName = getSenderName(conversationId, newAdminId);
      final oldAdminName = getSenderName(conversationId, oldAdminId);
      _sendSystemNotification(
        conversationId,
        '$oldAdminName đã chuyển quyền trưởng nhóm cho $newAdminName',
      );
    }

    refreshConversation(conversationId);
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

    final rawContent = message.content ?? '';
    final mentionsMe =
        conversation?.type == ConversationType.GROUP &&
        (rawContent.contains('@$currentUserId') || rawContent.contains('@Bạn'));

    final title =
        mentionsMe
            ? 'Bạn được nhắc đến trong ${conversation?.getDisplayName(currentUserId) ?? "nhóm"}'
            : (conversation?.getDisplayName(currentUserId) ??
                message.senderName ??
                'Tin nhắn mới');

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
      final updatedMsgs =
          msgs.map((m) {
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
      if (conv.unreadCount > 0 &&
          lastReadSeq > 0 &&
          lastMessageSeq > 0 &&
          lastReadSeq >= lastMessageSeq) {
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

  void _handleTypingEvent(Map<String, dynamic> data) {
    final conversationId = data['conversationId']?.toString();
    final senderId = data['senderId']?.toString() ?? data['userId']?.toString();
    final isTyping = data['isTyping'] == true;
    final clientPlatform = _normalizeTypingPlatform(
      data['clientPlatform']?.toString(),
    );

    if (conversationId == null || senderId == null) return;
    // Don't show own typing
    if (senderId == _currentUserId) return;

    _typingUsers[conversationId] ??= {};

    if (isTyping) {
      final existing = _typingUsers[conversationId]![senderId];
      final now = DateTime.now();
      _typingUsers[conversationId]![senderId] = ChatTypingState(
        startedAt: existing?.startedAt ?? now,
        lastSeen: now,
        clientPlatform: clientPlatform,
      );
      // Auto-expire after 5 seconds if no stop event
      Future.delayed(const Duration(seconds: 5), () {
        if (_typingUsers[conversationId]?[senderId] != null) {
          final elapsed = DateTime.now().difference(
            _typingUsers[conversationId]![senderId]!.lastSeen,
          );
          if (elapsed.inSeconds >= 5) {
            _typingUsers[conversationId]?.remove(senderId);
            if (_typingUsers[conversationId]?.isEmpty ?? false) {
              _typingUsers.remove(conversationId);
            }
            notifyListeners();
          }
        }
      });
    } else {
      _typingUsers[conversationId]?.remove(senderId);
      if (_typingUsers[conversationId]?.isEmpty ?? false) {
        _typingUsers.remove(conversationId);
      }
    }
    notifyListeners();
  }

  String? _normalizeTypingPlatform(String? rawPlatform) {
    final normalized = rawPlatform?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return switch (normalized) {
      'WEB' ||
      'PC' ||
      'DESKTOP' ||
      'WINDOWS' ||
      'MACOS' ||
      'LINUX' => 'DESKTOP',
      'ANDROID' => 'ANDROID',
      'IOS' || 'IPHONE' || 'IPAD' => 'IOS',
      _ => normalized,
    };
  }

  /// Emit typing indicator to socket.
  void emitTyping(String conversationId) {
    _socketService.sendTyping(conversationId, true);
    // Auto-stop after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      _socketService.sendTyping(conversationId, false);
    });
  }

  // Global cache for user presence to ensure consistency across different conversation objects
  final Map<String, bool> _userPresence = {};
  bool isUserOnline(String userId) {
    final lowerId = userId.toLowerCase();
    return _userPresence[lowerId] ?? false;
  }

  void _syncPresenceFromConversations() {
    // debugPrint('[PRESENCE] 🔄 _syncPresenceFromConversations starting (convs: ${_conversations.length})');
    for (final conv in _conversations) {
      if (conv.type == ConversationType.DIRECT) {
        for (final member in conv.members) {
          if (member.userId != _currentUserId && member.user != null) {
            final uid = member.userId.toLowerCase();
            _userPresence[uid] = member.user!.isOnline;
            // debugPrint('[PRESENCE] 🔄 Synced $uid -> ${member.user!.isOnline} from conv ${conv.id}');
          }
        }
      }
    }
  }

  void _handlePresenceEvent(Map<String, dynamic> data) {
    debugPrint('[PRESENCE] 📡 PRESENCE EVENT: $data');
    final rawUserId = (data['userId'] ?? data['id'] ?? data['uid'])?.toString();
    if (rawUserId == null) {
      debugPrint(
        '[ChatProvider] ⚠️ Presence event ignored: No userId found in $data',
      );
      return;
    }

    final userId = rawUserId.toLowerCase(); // Standardize ID

    // Super safe boolean parsing
    final isOnline =
        data['isOnline'] == true ||
        data['online'] == true ||
        data['isOnline']?.toString().toLowerCase() == 'true' ||
        data['online']?.toString().toLowerCase() == 'true' ||
        data['isOnline'] == 1 ||
        data['online'] == 1;

    final lastSeenRaw = data['lastSeen'] ?? data['last_seen'];
    final lastSeen =
        lastSeenRaw != null
            ? DateTime.tryParse(lastSeenRaw.toString())
            : (isOnline ? DateTime.now() : null);

    // Update global cache and track changes
    final bool presenceChanged = _userPresence[userId] != isOnline;
    _userPresence[userId] = isOnline;

    // Sync to conversation members
    _syncPresenceToMembers(userId, isOnline, lastSeen: lastSeen);

    if (presenceChanged || isOnline) {
      // Always notify if someone goes online to ensure UI catches it
      notifyListeners();
    }
  }

  void _handlePresenceListEvent(dynamic data) {
    debugPrint('[PRESENCE] 📡 PRESENCE LIST EVENT: $data');
    if (data is List) {
      bool changed = false;
      for (final item in data) {
        if (item is Map) {
          final rawUserId =
              (item['userId'] ?? item['id'] ?? item['uid'])?.toString();
          if (rawUserId != null) {
            final String userId = rawUserId.toLowerCase();
            final bool isOnline =
                item['isOnline'] == true ||
                item['online'] == true ||
                item['isOnline']?.toString().toLowerCase() == 'true' ||
                item['online']?.toString().toLowerCase() == 'true';

            final lastSeenRaw = item['lastSeen'] ?? item['last_seen'];
            final lastSeen =
                lastSeenRaw != null
                    ? DateTime.tryParse(lastSeenRaw.toString())
                    : null;

            if (_userPresence[userId] != isOnline) {
              _userPresence[userId] = isOnline;
              _syncPresenceToMembers(userId, isOnline, lastSeen: lastSeen);
              changed = true;
            }
          }
        }
      }
      if (changed) {
        // debugPrint('[PRESENCE] 📡 Cache updated from LIST: $_userPresence');
        notifyListeners();
      }
    }
  }

  void _requestBulkPresence() {
    if (_currentUserId == null) return;
    final Set<String> userIdsToFetch = {};
    for (final conv in _conversations) {
      for (final member in conv.members) {
        if (member.userId != _currentUserId) {
          userIdsToFetch.add(member.userId);
        }
      }
    }
    if (userIdsToFetch.isNotEmpty) {
      debugPrint(
        '[ChatProvider] 📡 Requesting bulk presence for ${userIdsToFetch.length} users',
      );
      _socketService.requestPresence(userIdsToFetch.toList());
    }
  }

  Future<void> _sendWithRetry(Message message) async {
    final clientMessageId = message.clientMessageId;
    if (clientMessageId == null) return;

    // Check if socket is connected
    if (!_socketService.isConnected()) {
      debugPrint('[ChatProvider] Socket not connected, falling back to HTTP');
      await _sendViaHttp(message);
      return;
    }

    // M-TASK: Emit via socket with ACK timeout — retry via HTTP on failure
    _socketService
        .sendMessage(
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
        )
        .catchError((e) {
          debugPrint(
            '[ChatProvider] sendMessage threw (ACK timeout/network): $e — retrying via HTTP',
          );
          _sendViaHttp(message);
        });

    // Check after a short delay if message was confirmed by server
    Timer(const Duration(milliseconds: 800), () async {
      final existing = _messages[message.conversationId] ?? [];
      final wasConfirmed = existing.any(
        (m) =>
            m.clientMessageId == clientMessageId && !m.id.startsWith('local-'),
      );
      if (!wasConfirmed) {
        debugPrint(
          '[ChatProvider] Socket not confirmed in 800ms, falling back to HTTP',
        );
        await _sendViaHttp(message);
      }
    });
  }

  Future<void> _sendViaHttp(Message message) async {
    final clientMessageId = message.clientMessageId;
    if (clientMessageId == null) return;

    try {
      final serverMessage = await _chatService.sendMessage(
        conversationId: message.conversationId,
        content: message.content ?? '',
        messageType: message.messageType.name,
        mediaUrl: message.mediaUrl,
        mediaThumbnailUrl: message.mediaThumbnailUrl,
        replyToMessageId: message.replyToMessageId,
      );

      // Replace optimistic message with server message (match by clientMessageId)
      final existing = _messages[message.conversationId] ?? [];
      final idx = existing.indexWhere(
        (m) => m.clientMessageId == clientMessageId,
      );
      if (idx >= 0) {
        debugPrint(
          '[ChatProvider] _sendViaHttp: REPLACING optimistic id=local-$clientMessageId with server id=${serverMessage.id}',
        );
        final updated = List<Message>.from(existing);
        updated[idx] = serverMessage;
        _messages[message.conversationId] = updated;
        notifyListeners();
      } else {
        debugPrint(
          '[ChatProvider] _sendViaHttp: optimistic not found for clientId=$clientMessageId, adding directly',
        );
        final updatedList = [serverMessage, ...existing];
        _messages[message.conversationId] = updatedList;
        notifyListeners();
      }
      _db.saveMessage(_toLocal(serverMessage));

      // Also notify other devices via socket (fire and forget)
      _socketService.sendMessage(
        conversationId: message.conversationId,
        content: message.content ?? '',
        messageType: message.messageType.name,
        clientMessageId: clientMessageId,
        mediaUrl: message.mediaUrl,
        mediaThumbnailUrl: message.mediaThumbnailUrl,
      );

      debugPrint('[ChatProvider] Message sent via HTTP: ${serverMessage.id}');
    } catch (e) {
      debugPrint('[ChatProvider] HTTP fallback failed: $e');
      _scheduleRetry(message, viaHttp: true);
    }
  }

  void _scheduleRetry(Message message, {required bool viaHttp}) {
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
    _retryTimers[clientMessageId] = Timer(
      Duration(seconds: backoffSeconds),
      () {
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
        if (viaHttp) {
          _sendViaHttp(current.copyWith(status: MessageStatus.SENDING));
        } else {
          _sendWithRetry(current.copyWith(status: MessageStatus.SENDING));
        }
      },
    );
  }

  /// Media message send — always via socket (needs mediaUrl)
  Future<void> _sendWithRetryMedia(Message message) async {
    final clientMessageId = message.clientMessageId;
    if (clientMessageId == null) return;

    // Check if socket is connected
    if (!_socketService.isConnected()) {
      debugPrint(
        '[ChatProvider] Socket not connected, falling back to HTTP for media',
      );
      await _sendMediaViaHttp(message);
      return;
    }

    // Emit via socket immediately (fire-and-forget)
    _socketService.sendMessage(
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

    // Check after a short delay if message was confirmed
    Timer(const Duration(milliseconds: 800), () {
      final existing = _messages[message.conversationId] ?? [];
      final wasConfirmed = existing.any(
        (m) =>
            m.clientMessageId == clientMessageId && !m.id.startsWith('local-'),
      );
      if (!wasConfirmed) {
        debugPrint(
          '[ChatProvider] Media socket not confirmed in 800ms, falling back to HTTP',
        );
        _sendMediaViaHttp(message);
      }
    });
  }

  Future<void> _sendMediaViaHttp(Message message) async {
    final clientMessageId = message.clientMessageId;
    if (clientMessageId == null) return;

    try {
      final serverMessage = await _chatService.sendMessage(
        conversationId: message.conversationId,
        content: message.content ?? '',
        messageType: message.messageType.name,
        mediaUrl: message.mediaUrl,
        mediaThumbnailUrl: message.mediaThumbnailUrl,
        replyToMessageId: message.replyToMessageId,
      );

      final existing = _messages[message.conversationId] ?? [];
      final idx = existing.indexWhere(
        (m) => m.clientMessageId == clientMessageId,
      );
      if (idx >= 0) {
        final updated = List<Message>.from(existing);
        updated[idx] = serverMessage;
        _messages[message.conversationId] = updated;
        notifyListeners();
      }
      _db.saveMessage(_toLocal(serverMessage));
      debugPrint('[ChatProvider] Media sent via HTTP: ${serverMessage.id}');
    } catch (e) {
      debugPrint('[ChatProvider] Media HTTP fallback failed: $e');
      _scheduleRetryMedia(message.copyWith(status: MessageStatus.SENDING));
    }
  }

  void _scheduleRetryMedia(Message message) {
    final clientMessageId = message.clientMessageId;
    if (clientMessageId == null) return;

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
    _retryTimers[clientMessageId] = Timer(
      Duration(seconds: backoffSeconds),
      () {
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
        _sendWithRetryMedia(current.copyWith(status: MessageStatus.SENDING));
      },
    );
  }

  Message? _findByClientMessageId(
    String conversationId,
    String clientMessageId,
  ) {
    final list = _messages[conversationId] ?? const [];
    for (final message in list) {
      if (message.clientMessageId == clientMessageId) {
        return message;
      }
    }
    return null;
  }

  void _replaceMessage(
    String conversationId,
    String messageId,
    Message updated,
  ) {
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
  // Settings and management
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
          autoDeleteSeconds:
              autoDeleteSeconds ?? _conversations[index].autoDeleteSeconds,
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

  Future<void> deleteConversation(String conversationId) async {
    try {
      // 1. Call API to delete for everyone/self on server
      await _chatService.deleteChatHistory(conversationId);

      // 2. Remove locally (Memory + DB)
      await _removeConversationLocally(conversationId);

      debugPrint('deleteConversation success: $conversationId');
    } catch (e) {
      debugPrint('deleteConversation error: $e');
      // Fallback: still remove locally even if API fails to ensure UI responsiveness
      await _removeConversationLocally(conversationId);
    }
  }

  Future<void> updateMemberNickname(
    String conversationId,
    String userId,
    String nickname,
  ) async {
    try {
      await _chatService.updateMemberNickname(conversationId, userId, nickname);

      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index >= 0) {
        final conv = _conversations[index];
        final memberIndex = conv.members.indexWhere((m) => m.userId == userId);
        if (memberIndex >= 0) {
          final updatedMember = conv.members[memberIndex].copyWith(
            nickname: nickname,
          );
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

  Future<void> updateWallpaper(
    String conversationId,
    File file, {
    bool isGlobal = true,
  }) async {
    try {
      final mediaId = await _mediaService.uploadFile(
        file,
        MediaCategory.CHAT_IMAGE,
      );
      final wallpaperUrl = _mediaService.getPublicUrl(mediaId);

      await _chatService.updateWallpaper(
        conversationId,
        wallpaperUrl,
        isGlobal: isGlobal,
      );

      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index >= 0) {
        if (isGlobal) {
          _conversations[index] = _conversations[index].copyWith(
            wallpaperUrl: wallpaperUrl,
          );
        } else {
          _conversations[index] = _conversations[index].copyWith(
            personalWallpaperUrl: wallpaperUrl,
          );
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('updateWallpaper error: $e');
      rethrow;
    }
  }

  Future<List<Message>> getSharedMedia(
    String conversationId, {
    String? type,
  }) async {
    try {
      return await _chatService.searchMedia(
        conversationId,
        messageType: type,
        limit: 10,
      );
    } catch (e) {
      debugPrint('getSharedMedia error: $e');
      return [];
    }
  }

  String getSenderName(String conversationId, String senderId) {
    if (senderId == 'SYSTEM' || senderId == 'SERVER') return 'Hệ thống';

    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      final conv = _conversations[index];
      final memberIndex = conv.members.indexWhere((m) => m.userId == senderId);
      if (memberIndex >= 0) {
        final member = conv.members[memberIndex];
        return member.nickname ??
            member.user?.displayName ??
            'Người dùng ($senderId)';
      }
    }
    return 'Người dùng ($senderId)';
  }

  void updateUserProfileInConversations(User updatedUser) {
    bool changed = false;
    final updatedConversations =
        _conversations.map((conv) {
          if (conv.members.isEmpty) return conv;

          final newMembers =
              conv.members.map((member) {
                if (member.userId != updatedUser.id) return member;
                changed = true;
                final mergedUser =
                    member.user?.copyWith(
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

  Future<void> _sendSystemNotification(
    String conversationId,
    String content, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Use a consistent ID format that can be easily identified as a local system message
      // but still unique enough to avoid collisions.
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String localId = 'sys_${conversationId}_$timestamp';

      final systemMessage = Message(
        id: localId,
        conversationId: conversationId,
        senderId: 'SERVER', // Use 'SERVER' or 'SYSTEM' consistently
        messageType: MessageType.SYSTEM,
        content: content,
        status: MessageStatus.SENT,
        createdAt: DateTime.now(),
        // metadata can store actorId, targetId, or action type for Web to parse
        // content: jsonEncode({'text': content, ...metadata}), // Optional: if Web expects JSON
      );

      // 1. Memory update
      if (_messages[conversationId] == null) {
        _messages[conversationId] = [];
      }

      // Avoid adding duplicate local system messages if they arrive fast
      if (!_messages[conversationId]!.any(
        (m) =>
            m.content == content &&
            DateTime.now().difference(m.createdAt).inSeconds < 2,
      )) {
        _messages[conversationId]!.insert(0, systemMessage);
        notifyListeners();

        // 2. Persist to local database
        await _db.saveMessage(_toLocal(systemMessage));
        debugPrint('[ChatProvider] System notification persisted: $content');
      }
    } catch (e) {
      debugPrint('Failed to persist system notification: $e');
    }
  }

  Future<void> updateGroupInfo(
    String conversationId, {
    String? title,
    String? description,
    String? avatarUrl,
    String? joinMode,
    bool? allowMemberInvite,
    bool? allowMemberPin,
    bool? allowMemberEditInfo,
    bool? onlyAdminCanPost,
    bool? highlightAdminMessages,
    bool? showHistoryToNewMembers,
    bool? allowMemberCreateNote,
    bool? allowMemberCreatePoll,
  }) async {
    final currentUser = _currentUserId;
    String userName = 'Một thành viên';
    if (currentUser != null) {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index >= 0) {
        final memberIndex = _conversations[index].members.indexWhere(
          (m) => m.userId == currentUser,
        );
        if (memberIndex >= 0) {
          userName =
              _conversations[index].members[memberIndex].user?.displayName ??
              userName;
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
        joinMode:
            joinMode != null
                ? enumFromString(JoinMode.values, joinMode)
                : _conversations[index].joinMode,
        allowMemberInvite:
            allowMemberInvite ?? _conversations[index].allowMemberInvite,
        allowMemberPin: allowMemberPin ?? _conversations[index].allowMemberPin,
        allowMemberEditInfo:
            allowMemberEditInfo ?? _conversations[index].allowMemberEditInfo,
        onlyAdminCanPost:
            onlyAdminCanPost ?? _conversations[index].onlyAdminCanPost,
        highlightAdminMessages:
            highlightAdminMessages ??
            _conversations[index].highlightAdminMessages,
        showHistoryToNewMembers:
            showHistoryToNewMembers ??
            _conversations[index].showHistoryToNewMembers,
        allowMemberCreateNote:
            allowMemberCreateNote ??
            _conversations[index].allowMemberCreateNote,
        allowMemberCreatePoll:
            allowMemberCreatePoll ??
            _conversations[index].allowMemberCreatePoll,
      );
      notifyListeners();
    }

    try {
      final Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
      if (joinMode != null) body['joinMode'] = joinMode;
      if (allowMemberInvite != null)
        body['allowMemberInvite'] = allowMemberInvite;
      if (allowMemberPin != null) body['allowMemberPin'] = allowMemberPin;
      if (allowMemberEditInfo != null)
        body['allowMemberEditInfo'] = allowMemberEditInfo;
      if (onlyAdminCanPost != null) body['onlyAdminCanPost'] = onlyAdminCanPost;
      if (highlightAdminMessages != null)
        body['highlightAdminMessages'] = highlightAdminMessages;
      if (showHistoryToNewMembers != null)
        body['showHistoryToNewMembers'] = showHistoryToNewMembers;
      if (allowMemberCreateNote != null)
        body['allowMemberCreateNote'] = allowMemberCreateNote;
      if (allowMemberCreatePoll != null)
        body['allowMemberCreatePoll'] = allowMemberCreatePoll;

      await _chatService.updateGroupInfo(conversationId, body);

      // Restore Optimistic UI Notification
      if (title != null) {
        await _sendSystemNotification(
          conversationId,
          '$userName đã đổi tên nhóm thành "$title"',
        );
      } else if (avatarUrl == null) {
        await _sendSystemNotification(
          conversationId,
          '$userName đã cập nhật thiết lập nhóm',
        );
      }
    } catch (e) {
      debugPrint('updateGroupInfo error: $e');
      rethrow;
    }
  }

  Future<void> updateWallpaperUrl(
    String conversationId,
    String imageUrl, {
    bool isGlobal = true,
  }) async {
    try {
      await _chatService.updateWallpaper(
        conversationId,
        imageUrl,
        isGlobal: isGlobal,
      );

      // Update local state immediately — refreshConversation only returns conversation-level data
      // and does NOT include personalWallpaperUrl (inbox-level personal setting per user).
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index >= 0) {
        if (isGlobal) {
          _conversations[index] = _conversations[index].copyWith(
            wallpaperUrl: imageUrl,
          );
        } else {
          _conversations[index] = _conversations[index].copyWith(
            personalWallpaperUrl: imageUrl,
          );
        }
        notifyListeners();
      }

      // Send system notification for wallpaper change (only for global wallpaper)
      if (isGlobal) {
        final currentUser = _currentUserId;
        String userName = 'Một thành viên';
        if (currentUser != null) {
          final convIndex = _conversations.indexWhere(
            (c) => c.id == conversationId,
          );
          if (convIndex >= 0) {
            final memberIndex = _conversations[convIndex].members.indexWhere(
              (m) => m.userId == currentUser,
            );
            if (memberIndex >= 0) {
              userName =
                  _conversations[convIndex]
                      .members[memberIndex]
                      .user
                      ?.displayName ??
                  userName;
            }
          }
        }
        await _sendSystemNotification(
          conversationId,
          '$userName đã đổi hình nền nhóm',
        );
      }
    } catch (e) {
      debugPrint('updateWallpaperUrl error: $e');
      rethrow;
    }
  }

  Future<void> updateGroupAvatarFile(String conversationId, File file) async {
    try {
      final mediaId = await _mediaService.uploadFile(
        file,
        MediaCategory.CHAT_IMAGE,
      );
      final imageUrl = _mediaService.getPublicUrl(mediaId);
      await updateGroupInfo(conversationId, avatarUrl: imageUrl);
    } catch (e) {
      debugPrint('updateGroupAvatarFile error: $e');
      rethrow;
    }
  }

  Future<void> updateWallpaperFile(
    String conversationId,
    File file, {
    bool isGlobal = true,
  }) async {
    try {
      final mediaId = await _mediaService.uploadFile(
        file,
        MediaCategory.CHAT_IMAGE,
      );
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

  Future<void> transferOwnership(
    String conversationId,
    String targetUserId,
  ) async {
    final myId = _currentUserId;
    if (myId == null) return;

    // Step 1: Surgical Local Update for immediate feedback (Optimistic UI)
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      final conv = _conversations[index];
      final updatedMembers =
          conv.members.map((m) {
            if (m.userId == targetUserId) {
              return m.copyWith(role: MemberRole.ADMIN);
            } else if (m.userId == myId) {
              return m.copyWith(role: MemberRole.MEMBER);
            }
            return m;
          }).toList();

      _conversations[index] = conv.copyWith(members: updatedMembers);
      notifyListeners();
    }

    try {
      // Use updateMemberRole to transfer ownership (set target to ADMIN)
      // The backend should handle demoting the current owner automatically or via separate call
      await _chatService.updateMemberRole(
        conversationId,
        targetUserId,
        'ADMIN',
      );

      final index = _conversations.indexWhere((c) => c.id == conversationId);
      String myName = 'Trưởng nhóm';
      String targetName = 'Thành viên';

      if (index >= 0) {
        final myMemberIndex = _conversations[index].members.indexWhere(
          (m) => m.userId == myId,
        );
        if (myMemberIndex >= 0) {
          myName =
              _conversations[index].members[myMemberIndex].user?.displayName ??
              myName;
        }
        final targetMemberIndex = _conversations[index].members.indexWhere(
          (m) => m.userId == targetUserId,
        );
        if (targetMemberIndex >= 0) {
          targetName =
              _conversations[index]
                  .members[targetMemberIndex]
                  .user
                  ?.displayName ??
              targetName;
        }
      }

      await _sendSystemNotification(
        conversationId,
        '$myName đã chuyển quyền trưởng nhóm cho $targetName',
      );
    } catch (e) {
      debugPrint('transferOwnership error: $e');
      rethrow;
    }
  }

  Future<void> addMembersToGroup(
    String conversationId,
    List<User> newUsers,
  ) async {
    // Step 1: Surgical Local Update for immediate visual feedback (TRUE Optimistic UI)
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      final conv = _conversations[index];
      final currentMembers = List<ConversationMember>.from(conv.members);

      for (final user in newUsers) {
        final existingIndex = currentMembers.indexWhere(
          (m) => m.userId == user.id,
        );
        if (existingIndex >= 0) {
          // Update existing entry (handle re-invites correctly)
          currentMembers[existingIndex] = currentMembers[existingIndex]
              .copyWith(
                leftAt: null,
                joinedAt: DateTime.now(),
                role: MemberRole.MEMBER,
                user: user,
              );
        } else {
          // Add new entry
          currentMembers.add(
            ConversationMember(
              conversationId: conversationId,
              userId: user.id,
              joinedAt: DateTime.now(),
              role: MemberRole.MEMBER,
              user: user,
            ),
          );
        }
      }

      _conversations[index] = conv.copyWith(members: currentMembers);
      notifyListeners();
    }

    try {
      await _chatService.addMembers(
        conversationId,
        newUsers.map((u) => u.id).toList(),
      );

      // Restore Optimistic UI Notification
      final currentUser = _currentUserId;
      String userName = 'Một thành viên';
      if (currentUser != null) {
        final conv = _conversations.firstWhere((c) => c.id == conversationId);
        userName =
            conv.members
                .firstWhere((m) => m.userId == currentUser)
                .user
                ?.displayName ??
            userName;
      }

      if (newUsers.length == 1) {
        final memberName = newUsers.first.displayName;
        await _sendSystemNotification(
          conversationId,
          '$userName đã thêm $memberName vào nhóm',
        );
      } else {
        await _sendSystemNotification(
          conversationId,
          '$userName đã thêm ${newUsers.length} thành viên vào nhóm',
        );
      }
    } catch (e) {
      debugPrint('addMembers error: $e');
      rethrow;
    }
  }

  Future<void> removeMember(String conversationId, String userId) async {
    // Step 1: Surgical Local Update for immediate feedback
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      final members =
          _conversations[index].members
              .where((m) => m.userId != userId)
              .toList();
      _conversations[index] = _conversations[index].copyWith(members: members);
      notifyListeners();
    }

    try {
      await _chatService.removeMember(conversationId, userId);

      // Restore Optimistic UI Notification (Silent Leave - will only be visible locally for the actor)
      final currentUser = _currentUserId;
      String userName = 'Admin';
      String targetName = 'Thành viên';
      if (currentUser != null) {
        final conv = _conversations.firstWhere((c) => c.id == conversationId);
        userName =
            conv.members
                .firstWhere((m) => m.userId == currentUser)
                .user
                ?.displayName ??
            userName;
        targetName =
            conv.members
                .firstWhere((m) => m.userId == userId)
                .user
                ?.displayName ??
            targetName;
      }
      await _sendSystemNotification(
        conversationId,
        '$userName đã mời $targetName rời khỏi nhóm',
      );
    } catch (e) {
      debugPrint('removeMember error: $e');
      rethrow;
    }
  }

  Future<void> leaveGroup(String conversationId, {bool silent = false}) async {
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
      if (member.role == MemberRole.ADMIN) {
        final activeMembers =
            conv.members.where((m) => m.leftAt == null).toList();
        if (activeMembers.length > 1) {
          throw Exception(
            'Bạn phải chuyển quyền trưởng nhóm cho thành viên khác trước khi rời nhóm',
          );
        }
      }
    }

    // Step 1: Remove conversation immediately from UI and DB
    await _removeConversationLocally(conversationId);

    try {
      await _chatService.leaveGroup(conversationId, userId, silent: silent);
      debugPrint('[ChatProvider] leaveGroup: Success (silent=$silent)');
    } catch (e) {
      debugPrint('leaveGroup error: $e');
    }
  }

  Future<void> disbandGroup(String conversationId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Current user is not available');
    }

    // Optimistic UI update
    await _removeConversationLocally(conversationId);

    try {
      final conv = _conversations.firstWhere((c) => c.id == conversationId);
      final memberIds = conv.members.map((m) => m.userId);

      await _chatService.disbandGroup(
        conversationId: conversationId,
        currentUserId: currentUserId,
        memberIds: memberIds,
      );

      // Local notification before removal
      final userName =
          _conversations
              .firstWhere((c) => c.id == conversationId)
              .members
              .firstWhere((m) => m.userId == _currentUserId)
              .user
              ?.displayName ??
          'Admin';
      await _sendSystemNotification(
        conversationId,
        '$userName đã giải tán nhóm',
      );

      debugPrint(
        '[ChatProvider] disbandGroup: Successfully disbanded group $conversationId',
      );
    } catch (e) {
      debugPrint('[ChatProvider] disbandGroup error: $e');
      rethrow;
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

  Future<void> updateMemberRole(
    String conversationId,
    String userId,
    String role,
  ) async {
    final memberRole = enumFromString(MemberRole.values, role);
    final myId = _currentUserId;

    // Get user names for notification
    String myName = 'Một thành viên';
    String targetName = 'Một thành viên';
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0 && myId != null) {
      final myMemberIndex = _conversations[index].members.indexWhere(
        (m) => m.userId == myId,
      );
      if (myMemberIndex >= 0) {
        myName =
            _conversations[index].members[myMemberIndex].user?.displayName ??
            myName;
      }
      final targetMemberIndex = _conversations[index].members.indexWhere(
        (m) => m.userId == userId,
      );
      if (targetMemberIndex >= 0) {
        targetName =
            _conversations[index]
                .members[targetMemberIndex]
                .user
                ?.displayName ??
            targetName;
      }
    }

    // Step 1: Surgical Local Update for immediate feedback (Optimistic UI)
    if (index >= 0) {
      final conv = _conversations[index];

      final updatedMembers =
          conv.members.map((m) {
            if (m.userId == userId) {
              return m.copyWith(role: memberRole);
            }
            // Enforce exactly 1 owner if someone is being promoted to OWNER
            if (memberRole == MemberRole.ADMIN && m.role == MemberRole.ADMIN) {
              return m.copyWith(role: MemberRole.MEMBER);
            }
            return m;
          }).toList();

      _conversations[index] = conv.copyWith(members: updatedMembers);
      notifyListeners();
      debugPrint(
        'updateMemberRole (Optimistic): Updated user $userId to $role',
      );
    }

    try {
      // Step 2: API Update
      await _chatService.updateMemberRole(conversationId, userId, role);

      // Send system notification for role change
      if (memberRole == MemberRole.DEPUTY) {
        await _sendSystemNotification(
          conversationId,
          '$myName đã bổ nhiệm $targetName làm phó nhóm',
        );
      } else if (memberRole == MemberRole.MEMBER) {
        await _sendSystemNotification(
          conversationId,
          '$myName đã hạ cấp $targetName thành thành viên',
        );
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
      debugPrint(
        '[ChatProvider] loadPinnedMessages START conversationId=$conversationId',
      );
      final pins = await _chatService.getPinnedMessages(conversationId);
      debugPrint('[ChatProvider] loadPinnedMessages raw response: $pins');
      final List<Message> messages = [];
      for (final p in pins) {
        debugPrint(
          '[ChatProvider] loadPinnedMessages pin item: $p (type: ${p.runtimeType})',
        );
        // Handle both Map and object with 'message' property
        // The API returns PinnedMessage entity: { id, conversationId, messageId, serverSeq, pinnedBy, pinnedAt, message: {...} }
        Object? messageData;
        if (p is Map) {
          messageData = p['message'];
        } else {
          messageData = (p as dynamic).message;
        }
        if (messageData != null) {
          final Map<String, dynamic> msgJson =
              messageData is Map
                  ? Map<String, dynamic>.from(messageData)
                  : (messageData as dynamic);
          final msg = Message.fromJson(msgJson);
          // Resolve senderName if missing
          if (msg.senderName == null) {
            final resolvedName = getSenderName(conversationId, msg.senderId);
            messages.add(msg.copyWith(senderName: resolvedName));
          } else {
            messages.add(msg);
          }
          debugPrint('[ChatProvider] loadPinnedMessages added: ${msg.id}');
        }
      }
      _pinnedMessages[conversationId] = messages;
      debugPrint('[ChatProvider] loadPinnedMessages total: ${messages.length}');
      notifyListeners();
    } catch (e, st) {
      debugPrint('loadPinnedMessages error: $e\n$st');
    }
  }

  /// Find a conversation by name (Friend name or Group title) for AI resolution.
  Conversation? findConversationByName(String name) {
    final matches = findConversationMatchesByName(name);
    return matches.length == 1 ? matches.first : null;
  }

  /// Find all deterministic conversation matches for AI resolution.
  List<Conversation> findConversationMatchesByName(String name) {
    if (name.isEmpty) return const [];
    final normalizedSearch = AiCommandRouting.normalizeSearchText(name);
    if (normalizedSearch.isEmpty) return const [];

    List<String> getLabels(Conversation conversation) {
      final labels = <String>{};
      void addLabel(String? value) {
        final normalized =
            value == null ? null : AiCommandRouting.normalizeSearchText(value);
        if (normalized != null && normalized.isNotEmpty) {
          labels.add(normalized);
        }
      }

      addLabel(conversation.title);
      if (conversation.type == ConversationType.GROUP) {
        return labels.toList(growable: false);
      }

      if (_currentUserId == null) {
        return labels.toList(growable: false);
      }

      for (final member in conversation.members) {
        if (member.userId != _currentUserId) {
          addLabel(member.nickname);
          addLabel(member.user?.displayName);
          addLabel(member.user?.phone);
        }
      }

      return labels.toList(growable: false);
    }

    final exactMatches = <Conversation>[];
    final scoredMatches = <({Conversation conversation, int score})>[];
    for (final conversation in _conversations) {
      final labels = getLabels(conversation);
      if (labels.any((label) => label == normalizedSearch)) {
        exactMatches.add(conversation);
        continue;
      }

      var bestScore = -1;
      for (final label in labels) {
        final score = AiCommandRouting.computeNameMatchScore(
          label,
          normalizedSearch,
        );
        if (score > bestScore) {
          bestScore = score;
        }
      }

      if (bestScore >= 0) {
        scoredMatches.add((conversation: conversation, score: bestScore));
      }
    }

    if (exactMatches.isNotEmpty) {
      return exactMatches;
    }

    scoredMatches.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;

      final timeA =
          a.conversation.lastMessage?.createdAt ??
          a.conversation.updatedAt ??
          a.conversation.createdAt ??
          DateTime(0);
      final timeB =
          b.conversation.lastMessage?.createdAt ??
          b.conversation.updatedAt ??
          b.conversation.createdAt ??
          DateTime(0);
      return timeB.compareTo(timeA);
    });

    return scoredMatches.map((entry) => entry.conversation).toList();
  }

  void pinMessage(String messageId) {
    debugPrint(
      '[ChatProvider] pinMessage CALLED: messageId=$messageId activeConvId=$_activeConversationId',
    );
    if (_activeConversationId == null) {
      debugPrint('[ChatProvider] pinMessage SKIP: no active conversation');
      return;
    }
    final convId = _activeConversationId!;

    // Use REST API for pin (more reliable than socket)
    _chatService
        .pinMessage(convId, messageId)
        .then((pinData) async {
          debugPrint('[ChatProvider] pinMessage REST SUCCESS: $pinData');
          // Parse the pin data to extract message and update state
          final messageData = pinData['message'];
          if (messageData != null && messageData is Map) {
            final msg = Message.fromJson(
              Map<String, dynamic>.from(messageData),
            );
            final resolvedName = getSenderName(convId, msg.senderId);
            final resolvedMsg = msg.copyWith(senderName: resolvedName);
            final currentPins = _pinnedMessages[convId] ?? [];
            if (!currentPins.any((m) => m.id == resolvedMsg.id)) {
              _pinnedMessages[convId] = [resolvedMsg, ...currentPins];
              debugPrint(
                '[ChatProvider] pinMessage added to state: ${resolvedMsg.id}',
              );
              notifyListeners();
            }
          }
          // Also try socket for real-time broadcast to other clients
          _socketService.pinMessage(messageId, convId);
        })
        .catchError((e) {
          debugPrint('[ChatProvider] pinMessage REST FAILED: $e');
          // Fallback to socket
          _socketService.pinMessage(messageId, convId);
        });
  }

  void pinMessageInConversation(String messageId, String conversationId) {
    final previousActiveConversationId = _activeConversationId;
    _activeConversationId = conversationId;
    pinMessage(messageId);
    _activeConversationId = previousActiveConversationId;
  }

  void unpinMessage(String messageId) {
    debugPrint(
      '[ChatProvider] unpinMessage CALLED: messageId=$messageId activeConvId=$_activeConversationId',
    );
    if (_activeConversationId == null) {
      debugPrint('[ChatProvider] unpinMessage SKIP: no active conversation');
      return;
    }
    final convId = _activeConversationId!;

    // Use REST API for unpin (more reliable than socket)
    _chatService
        .unpinMessage(convId, messageId)
        .then((_) async {
          debugPrint('[ChatProvider] unpinMessage REST SUCCESS');
          // Update local state immediately
          final currentPins = _pinnedMessages[convId] ?? [];
          final updatedPins =
              currentPins.where((m) => m.id != messageId).toList();
          if (updatedPins.length != currentPins.length) {
            _pinnedMessages[convId] = updatedPins;
            debugPrint(
              '[ChatProvider] unpinMessage removed from state: $messageId',
            );
            notifyListeners();
          }
          // Also try socket for real-time broadcast
          _socketService.unpinMessage(messageId, convId);
        })
        .catchError((e) {
          debugPrint('[ChatProvider] unpinMessage REST FAILED: $e');
          // Fallback to socket
          _socketService.unpinMessage(messageId, convId);
        });
  }

  bool isMessagePinned(String conversationId, String messageId) {
    final pins = _pinnedMessages[conversationId];
    if (pins == null) return false;
    return pins.any((m) => m.id == messageId);
  }

  void _handlePinnedEvent(Map<String, dynamic> data) {
    debugPrint('[ChatProvider] Received message.pinned event: $data');

    // Backend sends: { pin: { message: {...}, conversationId: "...", pinnedBy: "..." } }
    Message? message;
    String? conversationId;

    final pin = data['pin'];
    if (pin == null) {
      debugPrint('[ChatProvider] Skip pin: pin data is null');
      return;
    }

    if (pin is Map) {
      // pin = { id, message: {...}, conversationId: "...", ... }
      final messageData = pin['message'];
      if (messageData != null) {
        message = Message.fromJson(Map<String, dynamic>.from(messageData));
      }
      conversationId = pin['conversationId']?.toString();
    } else {
      debugPrint('[ChatProvider] Pin data is not a Map: $pin');
      return;
    }

    if (message == null) {
      debugPrint(
        '[ChatProvider] Skip pin: could not extract message from pin data',
      );
      return;
    }

    // Fallback conversationId to active conversation
    conversationId ??= _activeConversationId;
    if (conversationId == null) {
      debugPrint('[ChatProvider] Skip pin: No conversationId');
      return;
    }

    // Resolve senderName if missing (backend message only has senderId)
    if (message.senderName == null) {
      final resolvedName = getSenderName(conversationId, message.senderId);
      message = message.copyWith(senderName: resolvedName);
    }

    final currentPins = _pinnedMessages[conversationId] ?? [];

    // Avoid duplicates - update existing or add new
    final existingIndex = currentPins.indexWhere((m) => m.id == message!.id);
    if (existingIndex >= 0) {
      // Update existing pin
      final updated = List<Message>.from(currentPins);
      updated[existingIndex] = message!;
      _pinnedMessages[conversationId] = updated;
      debugPrint('[ChatProvider] Updated existing pin: ${message!.id}');
    } else {
      // Add new pin at the beginning
      _pinnedMessages[conversationId] = [message!, ...currentPins];
      debugPrint('[ChatProvider] Added new pin: ${message!.id}');
    }
    notifyListeners();
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
    final filteredReactions =
        currentReactions.where((r) => r.userId != reaction.userId).toList();
    filteredReactions.add(reaction);

    _reactions[messageId] = filteredReactions;
    notifyListeners();
  }

  void _handleReactionRemovedEvent(Map<String, dynamic> data) {
    final messageId = data['messageId'];
    final userId = data['userId'];
    if (messageId == null || userId == null) return;

    final currentReactions = _reactions[messageId] ?? [];
    final filteredReactions =
        currentReactions.where((r) => r.userId != userId).toList();

    _reactions[messageId] = filteredReactions;
    notifyListeners();
  }

  // ─── Reactions Methods ─────────────────────────────────────

  Future<void> addReaction(String messageId, String emoji) async {
    try {
      // Optimistic update
      final currentReactions = _reactions[messageId] ?? [];
      final userReactionIndex = currentReactions.indexWhere(
        (r) => r.userId == _currentUserId,
      );

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
      final myReaction = currentReactions.firstWhere(
        (r) => r.userId == _currentUserId,
        orElse:
            () => MessageReaction(
              id: '',
              conversationId: '',
              messageId: '',
              serverSeq: 0,
              userId: '',
              emoji: '',
              createdAt: DateTime.now(),
            ),
      );
      final removedEmoji = myReaction.emoji;

      // Optimistic update
      final updatedReactions =
          currentReactions.where((r) => r.userId != _currentUserId).toList();

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
    debugPrint(
      'toggleReaction called: messageId=$messageId, emoji=$emoji, userId=$_currentUserId',
    );
    await addReaction(messageId, emoji);
  }
}
