import 'package:athena/database/database.dart';

/// 添加 servers 表的 description 和 tools 字段
class Migration202501170002AddServerFields {
  static const name = 'migration_202501170002_add_server_fields';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    // 添加 description 字段
    await laconic.statement('''
      ALTER TABLE servers ADD COLUMN description TEXT DEFAULT ''
    ''');

    // 添加 tools 字段
    await laconic.statement('''
      ALTER TABLE servers ADD COLUMN tools TEXT DEFAULT '[]'
    ''');

    // 记录迁移
    await laconic.table('migrations').insert([
      {'name': name},
    ]);
  }
}
