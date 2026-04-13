import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:vnalo_mobile/core/database/local_database.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/friend_service.dart';

class LocalSyncService {
  final LocalDatabase db;
  final ChatService chatService;
  final FriendService friendService;

  bool _isSyncing = false;

  LocalSyncService({
    required this.db,
    required this.chatService,
    required this.friendService,
  });

  /// Sync data for the last 60 days
  Future<void> syncRecently() async {
    if (_isSyncing) {
      debugPrint('[Sync] Already in progress, skipping...');
      return;
    }

    _isSyncing = true;
    try {
      debugPrint('[Sync] Starting... (60-day sync)');
      
      // 1. Sync Contacts
      final friends = await friendService.getFriends();
      await db.batch((batch) {
        batch.insertAll(
          db.contacts,
          friends.map((f) => ContactsCompanion.insert(
            id: f.id,
            displayName: f.displayName,
            phone: Value(f.phone),
            avatarUrl: Value(f.avatarUrl),
          )),
          mode: InsertMode.insertOrReplace,
        );
      });

      // 2. Sync Conversations & Messages (Top recent)
      final conversations = await chatService.getInbox();
      for (final conv in conversations) {
        await db.into(db.conversations).insert(
          ConversationsCompanion.insert(
            id: conv.id,
            name: Value(conv.title ?? 'Cuộc hội thoại'),
            type: conv.type.name,
            avatarUrl: Value(conv.avatarUrl),
            lastMessage: Value(conv.lastMessage?.content),
            updatedAt: conv.updatedAt ?? conv.createdAt ?? DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );

        // Fetch messages for the last 60 days
        final messages = await chatService.getMessages(conv.id, limit: 100);
        await db.batch((batch) {
          batch.insertAll(
            db.messages,
            messages.map((m) => MessagesCompanion.insert(
              id: m.id,
              conversationId: conv.id,
              senderId: m.senderId,
              messageType: Value(m.messageType.name),
              content: Value(m.content),
              status: Value(m.status.name),
              createdAt: m.createdAt,
              messageType: Value(m.messageType.name),
              mediaUrl: Value(m.mediaUrl),
              mediaMimeType: Value(m.mediaMimeType),
              mediaSizeBytes: Value(m.mediaSizeBytes),
            )),
            mode: InsertMode.insertOrReplace,
          );
        });
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
