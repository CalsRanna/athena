import 'package:athena/database/database.dart';
import 'package:athena/util/logger_util.dart';

/// 为 messages 表添加 compacted 列，支持 compact 压缩持久化。
///
/// compacted = 0（默认）：正常消息，参与上下文组装。
/// compacted = 1：已被 compact 摘要覆盖，不参与上下文组装，保留在 DB 中供回溯。
class Migration202606240004AddCompactedToMessages {
  static const name = 'migration_202606240004_add_compacted_to_messages';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      await laconic.statement(
        'ALTER TABLE messages ADD COLUMN compacted INTEGER DEFAULT 0',
      );

      LoggerUtil.i('Migration $name: added compacted column to messages');

      await laconic.table('migrations').insert([
        {'name': name},
      ]);
    });
  }
}
