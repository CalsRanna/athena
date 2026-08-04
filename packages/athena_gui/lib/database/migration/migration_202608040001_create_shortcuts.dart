import 'package:athena_gui/database/database.dart';

/// 创建 shortcuts 表：Shortcut 作为一等公民，绑定一个 is_preset 的专属
/// Sentinel（sentinel_id 外键），并具备 page_target（定制 UI 标识）。
///
/// 外键级联删除：删除 Shortcut 时其专属 Sentinel 一并删除。
class Migration202608040001CreateShortcuts {
  static const name = 'migration_202608040001_create_shortcuts';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      await laconic.statement('''
        CREATE TABLE shortcuts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT DEFAULT '',
          icon TEXT DEFAULT '',
          page_target TEXT DEFAULT '',
          sentinel_id INTEGER NOT NULL,
          FOREIGN KEY (sentinel_id) REFERENCES sentinels(id) ON DELETE CASCADE
        )
      ''');

      await laconic.table('migrations').insert([
        {'name': name},
      ]);
    });
  }
}
