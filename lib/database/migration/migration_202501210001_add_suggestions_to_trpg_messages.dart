import 'package:athena/database/database.dart';

class Migration202501210001AddSuggestionsToTrpgMessages {
  static const name = 'migration_202501210001_add_suggestions_to_trpg_messages';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    // 为 trpg_messages 表添加 suggestions 字段
    await laconic.statement('''
      ALTER TABLE trpg_messages ADD COLUMN suggestions TEXT DEFAULT ''
    ''');

    // 记录迁移
    await laconic.table('migrations').insert([
      {'name': name},
    ]);
  }
}
