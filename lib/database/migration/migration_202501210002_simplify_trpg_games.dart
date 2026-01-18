import 'package:athena/database/database.dart';

class Migration202501210002SimplifyTrpgGames {
  static const name = 'migration_202501210002_simplify_trpg_games';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    // SQLite 不支持直接删除列，需要重建表
    // 1. 创建新的简化表
    await laconic.statement('''
      CREATE TABLE trpg_games_new(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        model_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 2. 复制数据到新表
    await laconic.statement('''
      INSERT INTO trpg_games_new (id, model_id, created_at, updated_at)
      SELECT id, model_id, created_at, updated_at FROM trpg_games
    ''');

    // 3. 删除旧表
    await laconic.statement('DROP TABLE trpg_games');

    // 4. 重命名新表
    await laconic.statement('ALTER TABLE trpg_games_new RENAME TO trpg_games');

    // 记录迁移
    await laconic.table('migrations').insert([
      {'name': name},
    ]);
  }
}
