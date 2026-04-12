import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'connection/connection_stub.dart'
    if (dart.library.io) 'connection/native_connection.dart'
    if (dart.library.html) 'connection/web_connection.dart'
    as conn;

part 'local_database.g.dart';

@DriftDatabase(include: {'local_database.drift'})
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(conn.openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Fresh Install v2: Manually create FTS and Triggers
      await _createFtsTables();
      await _createFtsTriggers();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // SEQUENTIAL TRANSACTIONAL EXECUTION (managed by Drift runner)

        // 1. Drop old triggers (if any)
        await customStatement('DROP TRIGGER IF EXISTS messages_ai');
        await customStatement('DROP TRIGGER IF EXISTS messages_ad');
        await customStatement('DROP TRIGGER IF EXISTS contacts_ai');
        await customStatement('DROP TRIGGER IF EXISTS contacts_ad');

        // 2. Create base tables if missing (for users upgrading from v1)
        await m.createTable(messages);
        await m.createTable(contacts);
        await m.createTable(conversations);

        // 3. Re-create FTS tables (Independent FTS5 schema)
        await customStatement('DROP TABLE IF EXISTS messages_fts');
        await customStatement('DROP TABLE IF EXISTS contacts_fts');

        // 4. Re-create FTS tables and rebuild indexes from source tables
        await _createFtsTables();
        
        // Use try-catch for data migration to avoid blocking startup if tables are empty/corrupt
        try {
          await customStatement(
            'INSERT INTO messages_fts(content, external_id) SELECT content, id FROM messages',
          );
          await customStatement(
            'INSERT INTO contacts_fts(display_name, external_id) SELECT display_name, id FROM contacts',
          );
        } catch (e) {
          debugPrint('FTS indexing failed during migration: $e');
        }

        // 5. Re-create triggers after rebuild to avoid side effects during migration
        await _createFtsTriggers();
      }

      if (from < 3) {
        // WIPE poisoned data (ISO strings in INTEGER created_at column)
        await customStatement('DELETE FROM messages');
        await customStatement('DELETE FROM messages_fts');
        debugPrint('[Migration] Database v3: Purged legacy messages to fix formatting errors.');
      }
    },
  );

  Future<void> _createFtsTables() async {
    // FTS tables using explicit UNINDEXED column declaration.
    await customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(content, external_id UNINDEXED)',
    );
    await customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS contacts_fts USING fts5(display_name, external_id UNINDEXED)',
    );
  }

  Future<void> _createFtsTriggers() async {
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS messages_ai AFTER INSERT ON messages BEGIN
        INSERT INTO messages_fts(content, external_id) VALUES (new.content, new.id);
      END;
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS messages_ad AFTER DELETE ON messages BEGIN
        DELETE FROM messages_fts WHERE external_id = old.id;
      END;
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS contacts_ai AFTER INSERT ON contacts BEGIN
        INSERT INTO contacts_fts(display_name, external_id) VALUES (new.display_name, new.id);
      END;
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS contacts_ad AFTER DELETE ON contacts BEGIN
        DELETE FROM contacts_fts WHERE external_id = old.id;
      END;
    ''');
  }

  // --- SEARCH QUERIES ---

  Future<List<LocalMessageSearchResult>> searchMessages(String query) async {
    final results = await customSelect(
      'SELECT m.*, c.name as conv_name, c.avatar_url as conv_avatar FROM messages m '
      'LEFT JOIN conversations c ON m.conversation_id = c.id '
      'WHERE m.id IN ( '
      '  SELECT external_id FROM messages_fts WHERE content MATCH ? '
      ') OR m.content LIKE ? '
      'ORDER BY m.created_at DESC',
      variables: [
        Variable.withString('$query*'),
        Variable.withString('%$query%'),
      ],
    ).get();

    return results.map((row) {
      return LocalMessageSearchResult(
        message: LocalMessage(
          id: row.read<String>('id'),
          content: row.read<String>('content'),
          conversationId: row.read<String>('conversation_id'),
          createdAt: row.read<DateTime>('created_at'),
          senderId: row.read<String>('sender_id'),
        ),
        conversationName: row.readNullable<String>('conv_name'),
        conversationAvatar: row.readNullable<String>('conv_avatar'),
      );
    }).toList();
  }

  Future<List<LocalContact>> searchContacts(String query) async {
    final results = await customSelect(
      'SELECT * FROM contacts WHERE id IN ('
      '  SELECT external_id FROM contacts_fts WHERE display_name MATCH ?'
      ') OR phone LIKE ?',
      variables: [
        Variable.withString('$query*'),
        Variable.withString('%$query%'),
      ],
    ).get();

    return results
        .map(
          (row) => LocalContact(
            id: row.read<String>('id'),
            displayName: row.read<String>('display_name'),
            phone: row.readNullable<String>('phone'),
            avatarUrl: row.readNullable<String>('avatar_url'),
          ),
        )
        .toList();
  }

  Future<LocalConversation?> getLocalConversationById(String id) async {
    final results =
        await customSelect(
          'SELECT * FROM conversations WHERE id = ? LIMIT 1',
          variables: [Variable.withString(id)],
        ).get();

    if (results.isEmpty) return null;

    final row = results.first;
    return LocalConversation(
      id: row.read<String>('id'),
      name: row.readNullable<String>('name'),
      type: row.read<String>('type'),
      avatarUrl: row.readNullable<String>('avatar_url'),
      lastMessage: row.readNullable<String>('last_message'),
      updatedAt: row.read<DateTime>('updated_at'),
    );
  }

  Future<void> saveMessage(LocalMessage message) async {
    await into(messages).insert(message, mode: InsertMode.insertOrReplace);
  }

  Future<void> saveMessagesBatch(List<LocalMessage> messageList) async {
    await batch((batch) {
      batch.insertAll(messages, messageList, mode: InsertMode.insertOrReplace);
    });
  }

  Future<List<LocalMessage>> getMessagesByConversation(String conversationId) async {
    return (select(messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }
}

class LocalMessageSearchResult {
  final LocalMessage message;
  final String? conversationName;
  final String? conversationAvatar;

  LocalMessageSearchResult({
    required this.message,
    this.conversationName,
    this.conversationAvatar,
  });
}
