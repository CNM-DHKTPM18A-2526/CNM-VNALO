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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Fresh Install v2: Manually create FTS and Triggers
      await _createFtsTables();
      await _createFtsTriggers();
      await _deduplicateFtsRows();
      await _createReadStateTable();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // SEQUENTIAL TRANSACTIONAL EXECUTION (managed by Drift runner)

        // 1. Drop old triggers (if any)
        await customStatement('DROP TRIGGER IF EXISTS messages_ai');
        await customStatement('DROP TRIGGER IF EXISTS messages_ad');
        await customStatement('DROP TRIGGER IF EXISTS contacts_ai');
        await customStatement('DROP TRIGGER IF EXISTS contacts_ad');

        // 2. Re-create FTS tables (Independent FTS5 schema)
        await customStatement('DROP TABLE IF EXISTS messages_fts');
        await customStatement('DROP TABLE IF EXISTS contacts_fts');

        // 3. Re-create FTS tables and rebuild indexes from source tables
        await _createFtsTables();
        await customStatement(
          'INSERT INTO messages_fts(content, external_id) SELECT content, id FROM messages',
        );
        await customStatement(
          'INSERT INTO contacts_fts(display_name, external_id) SELECT display_name, id FROM contacts',
        );

        // 4. Re-create triggers after rebuild to avoid side effects during migration
        await _createFtsTriggers();
        await _deduplicateFtsRows();
      }
      if (from < 3) {
        await _createReadStateTable();
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

  Future<void> _deduplicateFtsRows() async {
    await customStatement(
      'DELETE FROM messages_fts WHERE rowid NOT IN ('
      '  SELECT MIN(rowid) FROM messages_fts GROUP BY external_id'
      ')',
    );
    await customStatement(
      'DELETE FROM contacts_fts WHERE rowid NOT IN ('
      '  SELECT MIN(rowid) FROM contacts_fts GROUP BY external_id'
      ')',
    );
  }

  // --- SEARCH QUERIES ---

  Future<List<LocalMessageSearchResult>> searchMessages(String query) async {
    final results =
        await customSelect(
          'SELECT m.*, c.name as conv_name, c.avatar_url as conv_avatar FROM messages m '
          'JOIN conversations c ON m.conversation_id = c.id '
          'WHERE m.id IN ( '
          '  SELECT DISTINCT f.external_id FROM messages_fts f WHERE f.content MATCH ? '
          ') '
          'ORDER BY m.created_at DESC',
          variables: [Variable.withString('$query*')],
        ).get();

    return results
        .map(
          (row) => LocalMessageSearchResult(
            message: LocalMessage(
              id: row.read<String>('id'),
              content: row.read<String>('content'),
              conversationId: row.read<String>('conversation_id'),
              createdAt: row.read<DateTime>('created_at'),
              senderId: row.read<String>('sender_id'),
              messageType: row.readNullable<String>('message_type') ?? 'TEXT',
              mediaUrl: row.readNullable<String>('media_url'),
              thumbUrl: row.readNullable<String>('thumb_url'),
              localPath: row.readNullable<String>('local_path'),
              mediaMimeType: row.readNullable<String>('media_mime_type'),
              mediaSizeBytes: row.readNullable<int>('media_size_bytes'),
            ),
            conversationName: row.readNullable<String>('conv_name'),
            conversationAvatar: row.readNullable<String>('conv_avatar'),
          ),
        )
        .toList();
  }

  Future<List<LocalContact>> searchContacts(String query) async {
    final results =
        await customSelect(
          'SELECT c.* FROM contacts c '
          'WHERE c.id IN ( '
          '  SELECT f.external_id FROM contacts_fts f WHERE f.display_name MATCH ? '
          '  UNION '
          '  SELECT c2.id FROM contacts c2 WHERE c2.phone LIKE ? '
          ') '
          'ORDER BY c.display_name COLLATE NOCASE',
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
            phone: row.read<String>('phone'),
            avatarUrl: row.read<String>('avatar_url'),
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
      name: row.read<String>('name'),
      type: row.read<String>('type'),
      avatarUrl: row.read<String>('avatar_url'),
      lastMessage: row.read<String>('last_message'),
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

  Future<List<LocalMessage>> getMessagesByConversation(String conversationId) async {
    final query = select(messages)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);
    return query.get();
  }

  Future<int> deleteMessage(String messageId) {
    return (delete(messages)..where((t) => t.id.equals(messageId))).go();
  }

  Future<void> updateLocalPath(String messageId, String localPath) {
    return (update(messages)..where((t) => t.id.equals(messageId)))
        .write(MessagesCompanion(localPath: Value(localPath)));
  }

  Future<void> clearStalePaths(List<String> ids) {
    return (update(messages)..where((t) => t.id.isIn(ids)))
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
