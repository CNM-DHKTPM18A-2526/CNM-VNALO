import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:vnalo_mobile/core/database/local_database.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/friend_service.dart';
import 'package:vnalo_mobile/services/storage_service.dart';

class LocalSyncService {
  final LocalDatabase db;
  final ChatService chatService;
  final FriendService friendService;
  final StorageService storageService;

  bool _isSyncing = false;

  LocalSyncService({
    required this.db,
    required this.chatService,
    required this.friendService,
    required this.storageService,
  });

  /// Sync data for the last 60 days
  Future<void> syncRecently() async {
    if (_isSyncing) {
      debugPrint('[Sync] Already in progress, skipping...');
      return;
    }

    final userId = await storageService.getUserId();
    if (userId == null) {
      debugPrint('[Sync] No userId found, skipping sync.');
      return;
    }

    _isSyncing = true;
    try {
      debugPrint('[Sync] Starting... (60-day sync) for user: $userId');
      
      // 1. Sync contacts into local cache.
      final friends = await friendService.getFriends();
      await db.batch((batch) {
        batch.insertAll(
          db.contacts,
          friends.map((f) => ContactsCompanion.insert(
            id: f.id,
            ownerId: userId,
            displayName: f.displayName,
            phone: Value(f.phone),
            avatarUrl: Value(f.avatarUrl),
          )),
          mode: InsertMode.insertOrReplace,
        );
      });

      // 2. Sync recent conversations and messages.
      final conversations = await chatService.getInbox();
      for (final conv in conversations) {
        try {
          await db.into(db.conversations).insert(
            ConversationsCompanion.insert(
              id: conv.id,
              ownerId: userId,
              name: Value(conv.title ?? 'Cuộc hội thoại'),
              type: conv.type.name,
              avatarUrl: Value(conv.avatarUrl),
              lastMessage: Value(conv.lastMessage?.content),
              updatedAt: conv.updatedAt ?? conv.createdAt ?? DateTime.now(),
            ),
            mode: InsertMode.insertOrReplace,
          );

          // Fetch a recent message slice for each conversation.
          final messages = await chatService.getMessages(conv.id, limit: 100);
          await db.batch((batch) {
            batch.insertAll(
              db.messages,
              messages.map((m) => MessagesCompanion.insert(
                id: m.id,
                ownerId: userId,
                conversationId: conv.id,
                senderId: m.senderId,
                content: m.content ?? '',
                createdAt: m.createdAt,
                messageType: Value(m.messageType.name),
                mediaUrl: Value(m.mediaUrl),
                mediaMimeType: Value(m.mediaMimeType),
                mediaSizeBytes: Value(m.mediaSizeBytes),
              )),
              mode: InsertMode.insertOrReplace,
            );
          });
        } catch (e) {
          // Skip conversations that return 403 (user already left)
          debugPrint('[Sync] Skipping conv ${conv.id}: $e');
        }
      }
      
      debugPrint('[Sync] Sync completed.');
    } catch (e) {
      debugPrint('[Sync] Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Handle incoming message from socket
  Future<void> handleNewMessage(dynamic message) async {
    // Logic to insert single message into DB
  }
}
