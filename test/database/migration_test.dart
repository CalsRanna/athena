import 'package:flutter_test/flutter_test.dart';
import 'package:laconic/laconic.dart';
import 'package:laconic_sqlite/laconic_sqlite.dart';

/// Builds an in-memory Laconic instance with a production-like schema after
/// all migrations, including the db_integrity FK rebuild.
Future<Laconic> _buildSchema() async {
  final laconic = Laconic(SqliteDriver(SqliteConfig(':memory:')));

  await laconic.statement('''
    CREATE TABLE providers(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      base_url TEXT NOT NULL,
      api_key TEXT NOT NULL,
      enabled INTEGER DEFAULT 1,
      is_preset INTEGER DEFAULT 0,
      created_at INTEGER NOT NULL
    )
  ''');
  await laconic.statement('''
    CREATE TABLE models(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      model_id TEXT NOT NULL,
      provider_id INTEGER NOT NULL,
      context_window INTEGER DEFAULT 0,
      input_price TEXT DEFAULT '',
      output_price TEXT DEFAULT '',
      released_at TEXT DEFAULT '',
      reasoning INTEGER DEFAULT 0,
      vision INTEGER DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
    )
  ''');
  await laconic.statement('''
    CREATE TABLE sentinels(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT DEFAULT '',
      avatar TEXT DEFAULT '',
      prompt TEXT NOT NULL,
      tags TEXT DEFAULT '',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await laconic.statement('''
    CREATE TABLE chats(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      model_id INTEGER NOT NULL,
      sentinel_id INTEGER NOT NULL,
      temperature REAL DEFAULT 1.0,
      context INTEGER DEFAULT 0,
      pinned INTEGER DEFAULT 0,
      token_total INTEGER DEFAULT 0,
      context_tokens INTEGER DEFAULT 0,
      cached_tokens INTEGER DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await laconic.statement('''
    CREATE TABLE messages(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      chat_id INTEGER NOT NULL,
      role TEXT NOT NULL,
      content TEXT NOT NULL DEFAULT '',
      reasoning_content TEXT DEFAULT '',
      reasoning INTEGER DEFAULT 0,
      expanded INTEGER DEFAULT 1,
      image_urls TEXT DEFAULT '',
      reference TEXT DEFAULT '',
      tool_calls TEXT DEFAULT '',
      tool_results TEXT DEFAULT '',
      reasoning_started_at INTEGER NOT NULL,
      reasoning_updated_at INTEGER NOT NULL,
      FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE
    )
  ''');
  await laconic.statement('''
    CREATE TABLE trpg_games(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      model_id INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await laconic.statement('''
    CREATE TABLE trpg_messages(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      game_id INTEGER NOT NULL,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      suggestions TEXT DEFAULT '',
      created_at INTEGER NOT NULL
    )
  ''');
  await laconic.statement('''
    CREATE TABLE memories(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      key TEXT NOT NULL,
      value TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');

  await laconic.statement('PRAGMA foreign_keys = ON');
  return laconic;
}

/// Helper to insert a row without ambiguous literal errors.
Future<void> _insert(Laconic laconic, String table, Map<String, dynamic> row) async {
  await laconic.table(table).insert([row]);
}

void main() {
  // ---------- FK cascade ----------

  test('provider deletion cascades to its models', () async {
    final laconic = await _buildSchema();

    final providerId = await laconic.table('providers').insertGetId(<String, dynamic>{
      'name': 'TestP',
      'base_url': 'http://localhost',
      'api_key': 'k',
      'enabled': 1,
      'is_preset': 0,
      'created_at': 1,
    });
    await _insert(laconic, 'models', <String, dynamic>{
      'name': 'TestM',
      'model_id': 'test-m',
      'provider_id': providerId,
      'context_window': 0,
      'input_price': '',
      'output_price': '',
      'released_at': '',
      'reasoning': 0,
      'vision': 0,
      'created_at': 1,
      'updated_at': 1,
    });
    expect(await laconic.table('models').count(), 1);

    await laconic.table('providers').where('id', providerId).delete();
    expect(await laconic.table('models').count(), 0,
        reason: 'model should be cascade-deleted with provider');
  });

  test('chat deletion cascades to its messages', () async {
    final laconic = await _buildSchema();

    final chatId = await laconic.table('chats').insertGetId(<String, dynamic>{
      'title': 'TestChat',
      'model_id': 1,
      'sentinel_id': 1,
      'temperature': 1.0,
      'context': 0,
      'pinned': 0,
      'created_at': 1,
      'updated_at': 1,
    });
    await _insert(laconic, 'messages', <String, dynamic>{
      'chat_id': chatId,
      'role': 'user',
      'content': 'hello',
      'reasoning_content': '',
      'reasoning': 0,
      'expanded': 1,
      'image_urls': '',
      'reference': '',
      'tool_calls': '',
      'tool_results': '',
      'reasoning_started_at': 1,
      'reasoning_updated_at': 1,
    });
    expect(await laconic.table('messages').count(), 1);

    await laconic.table('chats').where('id', chatId).delete();
    expect(await laconic.table('messages').count(), 0,
        reason: 'message should be cascade-deleted with chat');
  });

  // ---------- orphan cleanup (db_integrity logic) ----------

  test('orphan messages (chat_id not in chats) are cleaned', () async {
    final laconic = await _buildSchema();
    // Disable FK so we can insert orphan rows (simulating pre-migration state).
    await laconic.statement('PRAGMA foreign_keys = OFF');

    final chatId = await laconic.table('chats').insertGetId(<String, dynamic>{
      'title': 'GoodChat',
      'model_id': 1,
      'sentinel_id': 1,
      'temperature': 1.0,
      'context': 0,
      'pinned': 0,
      'created_at': 1,
      'updated_at': 1,
    });
    await _insert(laconic, 'messages', <String, dynamic>{
      'chat_id': chatId,
      'role': 'user',
      'content': 'good',
      'reasoning_content': '',
      'reasoning': 0,
      'expanded': 1,
      'image_urls': '',
      'reference': '',
      'tool_calls': '',
      'tool_results': '',
      'reasoning_started_at': 1,
      'reasoning_updated_at': 1,
    });
    // Insert an orphan via raw SQL (bypass FK to non-existent chat)
    await laconic.statement(
      "INSERT INTO messages (chat_id, role, content, reasoning_content, reasoning, "
      "expanded, image_urls, reference, tool_calls, tool_results, "
      "reasoning_started_at, reasoning_updated_at) "
      "VALUES (99999, 'user', 'orphan', '', 0, 1, '', '', '', '', 1, 1)",
    );
    expect(await laconic.table('messages').count(), 2);

    await laconic.statement('''
      DELETE FROM messages
      WHERE chat_id NOT IN (SELECT id FROM chats)
    ''');
    expect(await laconic.table('messages').count(), 1);

    final remaining = await laconic.table('messages').get();
    expect(remaining.first.toMap()['content'], 'good');
  });

  test('orphan models (provider_id not in providers) are cleaned', () async {
    final laconic = await _buildSchema();
    // Disable FK so we can insert orphan rows (simulating pre-migration state).
    await laconic.statement('PRAGMA foreign_keys = OFF');

    final providerId = await laconic.table('providers').insertGetId(<String, dynamic>{
      'name': 'GoodProvider',
      'base_url': 'http://localhost',
      'api_key': 'k',
      'enabled': 1,
      'is_preset': 0,
      'created_at': 1,
    });
    await _insert(laconic, 'models', <String, dynamic>{
      'name': 'GoodModel',
      'model_id': 'gm',
      'provider_id': providerId,
      'context_window': 0,
      'input_price': '',
      'output_price': '',
      'released_at': '',
      'reasoning': 0,
      'vision': 0,
      'created_at': 1,
      'updated_at': 1,
    });
    await laconic.statement(
      "INSERT INTO models (name, model_id, provider_id, context_window, "
      "input_price, output_price, released_at, reasoning, vision, created_at, updated_at) "
      "VALUES ('OrphanModel', 'om', 99999, 0, '', '', '', 0, 0, 1, 1)",
    );
    expect(await laconic.table('models').count(), 2);

    await laconic.statement('''
      DELETE FROM models
      WHERE provider_id NOT IN (SELECT id FROM providers)
    ''');
    expect(await laconic.table('models').count(), 1);

    final remaining = await laconic.table('models').get();
    expect(remaining.first.toMap()['name'], 'GoodModel');
  });

  // ---------- context_window INTEGER 迁移验证 ----------

  test('context_window column is now INTEGER', () async {
    final laconic = await _buildSchema();
    // 验证 data_type 不是 TEXT
    final info = await laconic.select("PRAGMA table_info('models')");
    var type = '';
    for (var row in info) {
      if (row.toMap()['name'] == 'context_window') {
        type = (row.toMap()['type'] as String).toUpperCase();
      }
    }
    expect(type, contains('INT'));
    expect(type, isNot(contains('TEXT')));
  });

  test('chats table has context_tokens and cached_tokens columns', () async {
    final laconic = await _buildSchema();
    final info = await laconic.select("PRAGMA table_info('chats')");
    final columns = info.map((r) => r.toMap()['name'] as String).toSet();
    expect(columns, contains('context_tokens'));
    expect(columns, contains('cached_tokens'));
  });

  // ---------- schema verification ----------

  // ---------- schema verification ----------

  test('messages table has tool_calls and tool_results columns', () async {
    final laconic = await _buildSchema();
    final info = await laconic.select("PRAGMA table_info('messages')");
    final columns = info.map((r) => r.toMap()['name'] as String).toSet();
    expect(columns, contains('tool_calls'));
    expect(columns, contains('tool_results'));
  });

  test('models table has context_window column', () async {
    final laconic = await _buildSchema();
    final info = await laconic.select("PRAGMA table_info('models')");
    final columns = info.map((r) => r.toMap()['name'] as String).toSet();
    expect(columns, contains('context_window'));
  });

  test('chats table has token_total column after migration', () async {
    final laconic = await _buildSchema();
    final info = await laconic.select("PRAGMA table_info('chats')");
    final columns = info.map((r) => r.toMap()['name'] as String).toSet();
    expect(columns, contains('token_total'));
  });

  test('token_total defaults to 0 and accumulates on increment', () async {
    final laconic = await _buildSchema();
    final chatId = await laconic.table('chats').insertGetId(<String, dynamic>{
      'title': 'T',
      'model_id': 1,
      'sentinel_id': 1,
      'temperature': 1.0,
      'context': 0,
      'pinned': 0,
      'created_at': 1,
      'updated_at': 1,
    });
    final inserted =
        await laconic.table('chats').where('id', chatId).first();
    expect(inserted.toMap()['token_total'], 0,
        reason: 'new chats default to token_total 0');
    await laconic.statement(
      'UPDATE chats SET token_total = token_total + ? WHERE id = ?',
      <Object?>[5, chatId],
    );
    await laconic.statement(
      'UPDATE chats SET token_total = token_total + ? WHERE id = ?',
      <Object?>[7, chatId],
    );
    final updated =
        await laconic.table('chats').where('id', chatId).first();
    expect(updated.toMap()['token_total'], 12,
        reason: 'token_total should accumulate');
  });

  test('all expected tables exist after full migration', () async {
    final laconic = await _buildSchema();
    final tables =
        await laconic.select("SELECT name FROM sqlite_master WHERE type='table'");
    final names = tables.map((r) => r.toMap()['name'] as String).toSet();
    for (final expected in [
      'chats',
      'messages',
      'models',
      'providers',
      'sentinels',
      'trpg_games',
      'trpg_messages',
      'memories',
    ]) {
      expect(names, contains(expected),
          reason: 'table "$expected" should exist after migrations');
    }
  });
}

/// ProviderRepository
