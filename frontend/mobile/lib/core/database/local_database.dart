import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'connection/connection_stub.dart'
    if (dart.library.io) 'connection/native_connection.dart'
    if (dart.library.html) 'connection/web_connection.dart'
    as conn;

part 'local_database.g.dart';

@DriftDatabase(include: {'local_database.drift'})
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(conn.openConnection());

  @override
  int get schemaVersion => 5; // Schema version 5: Added owner_id for multi-user isolation.

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Fresh Install: Manually create FTS and Triggers
      await _createFtsTables();
      await _createFtsTriggers();
      await _deduplicateFtsRows();
      await _createReadStateTable();
    },
    onUpgrade: (m, from, to) async {
      if (from < 5) {
        // PER-USER ISOLATION MIGRATION (v5)
        // We drop and recreate all tables and triggers to ensure data privacy transition.
        // Data will be re-synced from server on next login.

        // 1. Drop old triggers
        await customStatement('DROP TRIGGER IF EXISTS messages_ai');
        await customStatement('DROP TRIGGER IF EXISTS messages_ad');
        await customStatement('DROP TRIGGER IF EXISTS contacts_ai');
        await customStatement('DROP TRIGGER IF EXISTS contacts_ad');

        // 2. Drop old FTS tables
        await customStatement('DROP TABLE IF EXISTS messages_fts');
        await customStatement('DROP TABLE IF EXISTS contacts_fts');

        // 3. Drop main tables to recreate with NEW schema (owner_id)
        // Note: Drift's Migrator.deleteTable is safer but custom SQL works too.
        await customStatement('DROP TABLE IF EXISTS messages');
        await customStatement('DROP TABLE IF EXISTS conversations');
        await customStatement('DROP TABLE IF EXISTS contacts');
        await customStatement('DROP TABLE IF EXISTS conversation_read_state');

        // 4. Recreate everything
        await m.createAll();
        await _createFtsTables();
        await _createFtsTriggers();
        await _createReadStateTable();
      } else {
        // Standard legacy migrations for sub-v5 users (if any still bypass v5 logic)
        if (from < 2) {
           // Skip older logic as v5 drops everything anyway
        }
      }
    },
  );

  Future<void> _createReadStateTable() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS conversation_read_state ('
      'conversation_id TEXT NOT NULL PRIMARY KEY, '
      'last_read_seq INTEGER NOT NULL DEFAULT 0, '
      'updated_at DATETIME NOT NULL'
      ')',
    );
  }

  Future<void> _createFtsTables() async {
    // FTS tables with owner_id for efficient cross-user isolation
    await customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(content, owner_id UNINDEXED, external_id UNINDEXED)',
    );
    await customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS contacts_fts USING fts5(display_name, owner_id UNINDEXED, external_id UNINDEXED)',
    );
  }

  Future<void> _createFtsTriggers() async {
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS messages_ai AFTER INSERT ON messages BEGIN
        INSERT INTO messages_fts(content, owner_id, external_id) VALUES (new.content, new.owner_id, new.id);
      END;
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS messages_ad AFTER DELETE ON messages BEGIN
        DELETE FROM messages_fts WHERE external_id = old.id AND owner_id = old.owner_id;
      END;
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS contacts_ai AFTER INSERT ON contacts BEGIN
        INSERT INTO contacts_fts(display_name, owner_id, external_id) VALUES (new.display_name, new.owner_id, new.id);
      END;
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS contacts_ad AFTER DELETE ON contacts BEGIN
        DELETE FROM contacts_fts WHERE external_id = old.id AND owner_id = old.owner_id;
      END;
    ''');
  }

  Future<void> _deduplicateFtsRows() async {
    await customStatement(
      'DELETE FROM messages_fts WHERE rowid NOT IN ('
      '  SELECT MIN(rowid) FROM messages_fts GROUP BY external_id, owner_id'
      ')',
    );
    await customStatement(
      'DELETE FROM contacts_fts WHERE rowid NOT IN ('
      '  SELECT MIN(rowid) FROM contacts_fts GROUP BY external_id, owner_id'
      ')',
    );
  }

  // --- SEARCH QUERIES ---

  Future<List<LocalMessageSearchResult>> searchMessages(String query, String currentUserId) async {
    final results = await customSelect(
      'SELECT DISTINCT m.*, c.name as conv_name, c.type as conv_type, c.avatar_url as conv_avatar FROM messages m '
      'JOIN conversations c ON m.conversation_id = c.id '
      'WHERE m.owner_id = ? AND m.id IN ( '
      '  SELECT DISTINCT f.external_id FROM messages_fts f WHERE f.owner_id = ? AND f.content MATCH ? '
      ') '
      'ORDER BY m.created_at DESC',
      variables: [
        Variable.withString(currentUserId),
        Variable.withString(currentUserId),
        Variable.withString('$query*')
      ],
    ).get();

    return results
        .map(
          (row) => LocalMessageSearchResult(
            message: LocalMessage(
              id: row.readNullable<String>('id') ?? '',
              ownerId: row.readNullable<String>('owner_id') ?? '',
              content: row.readNullable<String>('content') ?? '',
              conversationId: row.readNullable<String>('conversation_id') ?? '',
              createdAt: row.readNullable<DateTime>('created_at') ?? DateTime.now(),
              senderId: row.readNullable<String>('sender_id') ?? '',
              messageType: row.readNullable<String>('message_type') ?? 'TEXT',
              mediaUrl: row.readNullable<String>('media_url'),
              thumbUrl: row.readNullable<String>('thumb_url'),
              localPath: row.readNullable<String>('local_path'),
              mediaMimeType: row.readNullable<String>('media_mime_type'),
              mediaSizeBytes: row.readNullable<int>('media_size_bytes'),
            ),
            conversationName: row.readNullable<String>('conv_name'),
            conversationAvatar: row.readNullable<String>('conv_avatar'),
            conversationType: row.readNullable<String>('conv_type'),
          ),
        )
        .toList();
  }

  Future<List<LocalContact>> searchContacts(String query, String currentUserId) async {
    final results = await customSelect(
      'SELECT DISTINCT c.* FROM contacts c '
      'WHERE c.owner_id = ? AND c.id IN ( '
      '  SELECT f.external_id FROM contacts_fts f WHERE f.owner_id = ? AND f.display_name MATCH ? '
      '  UNION '
      '  SELECT c2.id FROM contacts c2 WHERE c2.owner_id = ? AND c2.phone LIKE ? '
      ') '
      'ORDER BY c.display_name COLLATE NOCASE',
      variables: [
        Variable.withString(currentUserId),
        Variable.withString(currentUserId),
        Variable.withString('$query*'),
        Variable.withString(currentUserId),
        Variable.withString('%$query%'),
      ],
    ).get();

    return results
        .map<LocalContact>(
          (row) => LocalContact(
            id: row.readNullable<String>('id') ?? '',
            ownerId: row.readNullable<String>('owner_id') ?? '',
            displayName: row.readNullable<String>('display_name') ?? '',
            phone: row.readNullable<String>('phone') ?? '',
            avatarUrl: row.readNullable<String>('avatar_url'),
          ),
        )
        .toList();
  }


  Future<LocalConversation?> getLocalConversationById(String id, String currentUserId) async {
    final results =
        await customSelect(
          'SELECT * FROM conversations WHERE id = ? AND owner_id = ? LIMIT 1',
          variables: [
            Variable.withString(id),
            Variable.withString(currentUserId)
          ],
        ).get();

    if (results.isEmpty) return null;

    final row = results.first;
    return LocalConversation(
      id: row.read<String>('id'),
      ownerId: row.read<String>('owner_id'),
      name: row.readNullable<String>('name'),
      type: row.read<String>('type'),
      avatarUrl: row.readNullable<String>('avatar_url'),
      lastMessage: row.readNullable<String>('last_message'),
      updatedAt: row.read<DateTime>('updated_at'),
    );
  }

  // --- PERSISTENCE METHODS ---

  Future<void> saveMessage(LocalMessage message) {
    return into(messages).insert(message, mode: InsertMode.insertOrReplace);
  }

  Future<void> saveMessagesBatch(List<LocalMessage> msgs) async {
    await batch((b) {
      b.insertAll(messages, msgs, mode: InsertMode.insertOrReplace);
    });
  }

  Future<List<LocalMessage>> getMessagesByConversation(String conversationId, String currentUserId) async {
    final query = select(messages)
      ..where((t) => t.ownerId.equals(currentUserId))
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);
    return query.get();
  }

  Future<int> deleteMessage(String messageId, String currentUserId) {
    return (delete(messages)..where((t) => t.id.equals(messageId))..where((t) => t.ownerId.equals(currentUserId))).go();
  }

  Future<void> updateLocalPath(String messageId, String localPath, String currentUserId) {
    return (update(messages)..where((t) => t.id.equals(messageId))..where((t) => t.ownerId.equals(currentUserId)))
        .write(MessagesCompanion(localPath: Value(localPath)));
  }

  Future<void> clearStalePaths(List<String> ids, String currentUserId) {
    return (update(messages)..where((t) => t.id.isIn(ids))..where((t) => t.ownerId.equals(currentUserId)))
        .write(const MessagesCompanion(localPath: Value(null)));
  }

  Future<void> upsertConversationReadState({
    required String conversationId,
    required int lastReadSeq,
  }) async {
    if (lastReadSeq <= 0) return;

    await customStatement(
      'INSERT INTO conversation_read_state (conversation_id, last_read_seq, updated_at) '
      'VALUES (?, ?, ?) '
      'ON CONFLICT(conversation_id) DO UPDATE SET '
      'last_read_seq = CASE '
      '  WHEN excluded.last_read_seq > conversation_read_state.last_read_seq THEN excluded.last_read_seq '
      '  ELSE conversation_read_state.last_read_seq '
      'END, '
      'updated_at = excluded.updated_at',
      [conversationId, lastReadSeq, DateTime.now().toIso8601String()],
    );
  }

  Future<Map<String, int>> getConversationReadStateMap(List<String> conversationIds) async {
    if (conversationIds.isEmpty) return const {};

    final placeholders = List.filled(conversationIds.length, '?').join(', ');
    final rows = await customSelect(
      'SELECT conversation_id, last_read_seq FROM conversation_read_state '
      'WHERE conversation_id IN ($placeholders)',
      variables: conversationIds.map(Variable.withString).toList(),
    ).get();

    final map = <String, int>{};
    for (final row in rows) {
      map[row.read<String>('conversation_id')] = row.read<int>('last_read_seq');
    }
    return map;
  }

  Future<void> deleteConversation(String conversationId, String currentUserId) async {
    await batch((b) {
      // 1. Delete messages
      b.deleteWhere(messages, (t) => t.ownerId.equals(currentUserId) & t.conversationId.equals(conversationId));
      // 2. Delete the conversation itself
      b.deleteWhere(conversations, (t) => t.ownerId.equals(currentUserId) & t.id.equals(conversationId));
    });
    // 3. Delete read state (custom table, not managed by Drift classes if created manually via customStatement)
    await customStatement(
      'DELETE FROM conversation_read_state WHERE conversation_id = ?',
      [conversationId],
    );
  }
}

class LocalMessageSearchResult {
  final LocalMessage message;
  final String? conversationName;
  final String? conversationAvatar;
  final String? conversationType;

  LocalMessageSearchResult({
    required this.message,
    this.conversationName,
    this.conversationAvatar,
    this.conversationType,
  });
}
