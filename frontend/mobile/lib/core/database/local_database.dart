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
  int get schemaVersion => 2;

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

  Future<List<LocalMessage>> searchMessages(String query) async {
    final results =
        await customSelect(
          'SELECT m.* FROM messages m '
          'JOIN messages_fts f ON m.id = f.external_id '
          'WHERE f.content MATCH ? '
          'ORDER BY m.created_at DESC',
          variables: [Variable.withString('$query*')],
        ).get();

    return results
        .map(
          (row) => LocalMessage(
            id: row.read<String>('id'),
            content: row.read<String>('content'),
            conversationId: row.read<String>('conversation_id'),
            createdAt: row.read<DateTime>('created_at'),
            senderId: row.read<String>('sender_id'),
          ),
        )
        .toList();
  }

  Future<List<LocalContact>> searchContacts(String query) async {
    final results =
        await customSelect(
          'SELECT c.* FROM contacts c '
          'JOIN contacts_fts f ON c.id = f.external_id '
          'WHERE f.display_name MATCH ? OR c.phone LIKE ?',
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
}
