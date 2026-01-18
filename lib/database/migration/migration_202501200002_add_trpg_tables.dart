import 'package:athena/database/database.dart';

class Migration202501200002AddTrpgTables {
  static const name = 'migration_202501200002_add_trpg_tables';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    // 创建 trpg_games 表
    await laconic.statement('''
      CREATE TABLE trpg_games(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        game_style TEXT NOT NULL,
        character_class TEXT NOT NULL,
        game_mode TEXT NOT NULL,
        current_hp INTEGER DEFAULT 100,
        max_hp INTEGER DEFAULT 100,
        current_mp INTEGER DEFAULT 50,
        max_mp INTEGER DEFAULT 50,
        inventory TEXT DEFAULT '',
        current_quest TEXT DEFAULT '',
        current_scene TEXT DEFAULT '',
        model_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 创建 trpg_messages 表
    await laconic.statement('''
      CREATE TABLE trpg_messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');

    // 记录迁移
    await laconic.table('migrations').insert([
      {'name': name},
    ]);
  }
}
