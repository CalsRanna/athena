import 'package:athena/database/database.dart';

class Migration202501170001Init {
  static const name = 'migration_202501170001_init';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    // 创建 chats 表
    await laconic.statement('''
      CREATE TABLE chats(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        model_id INTEGER NOT NULL,
        sentinel_id INTEGER NOT NULL,
        temperature REAL DEFAULT 1.0,
        context INTEGER DEFAULT 0,
        enable_search INTEGER DEFAULT 0,
        pinned INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 创建 messages 表
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
        searching INTEGER DEFAULT 0,
        reasoning_started_at INTEGER NOT NULL,
        reasoning_updated_at INTEGER NOT NULL,
        FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE
      )
    ''');

    // 创建 models 表
    await laconic.statement('''
      CREATE TABLE models(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        value TEXT NOT NULL,
        provider_id INTEGER NOT NULL,
        context TEXT DEFAULT '',
        input_price TEXT DEFAULT '',
        output_price TEXT DEFAULT '',
        released_at TEXT DEFAULT '',
        support_reasoning INTEGER DEFAULT 0,
        support_visual INTEGER DEFAULT 0
      )
    ''');

    // 创建 providers 表
    await laconic.statement('''
      CREATE TABLE providers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        key TEXT NOT NULL,
        enabled INTEGER DEFAULT 0,
        is_preset INTEGER DEFAULT 0
      )
    ''');

    // 创建 sentinels 表
    await laconic.statement('''
      CREATE TABLE sentinels(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        avatar TEXT DEFAULT '',
        description TEXT DEFAULT '',
        prompt TEXT NOT NULL,
        tags TEXT DEFAULT '[]'
      )
    ''');

    // 创建 tools 表
    await laconic.statement('''
      CREATE TABLE tools(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        key TEXT NOT NULL,
        description TEXT DEFAULT ''
      )
    ''');

    // 创建 servers 表
    await laconic.statement('''
      CREATE TABLE servers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        command TEXT NOT NULL,
        arguments TEXT DEFAULT '[]',
        environment_variables TEXT DEFAULT '{}',
        enabled INTEGER DEFAULT 1
      )
    ''');

    // 创建索引
    await laconic.statement('''
      CREATE INDEX idx_messages_chat_id ON messages(chat_id)
    ''');

    await laconic.statement('''
      CREATE INDEX idx_chats_updated_at ON chats(updated_at DESC)
    ''');

    await laconic.statement('''
      CREATE INDEX idx_models_provider_id ON models(provider_id)
    ''');

    await laconic.table('migrations').insert([
      {'name': name},
    ]);
  }
}
