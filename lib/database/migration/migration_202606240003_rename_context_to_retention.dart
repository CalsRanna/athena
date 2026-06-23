import 'package:athena/database/database.dart';
import 'package:athena/util/logger_util.dart';

/// 将 chats 表的 context 列重命名为 retention，语义从"保留 N 轮"迁移为：
/// - 0：无历史模式（每次独立请求）
/// - -1：自动管理（compact）
///
/// 旧值映射：所有旧值统一映射为 -1（自动管理），
/// 用户如需零上下文模式可手动开启。
class Migration202606240003RenameContextToRetention {
  static const name = 'migration_202606240003_rename_context_to_retention';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      await laconic.statement(
        'ALTER TABLE chats RENAME COLUMN context TO retention',
      );

      // 所有旧值统一设为 -1（自动管理）
      await laconic.statement('UPDATE chats SET retention = -1');

      LoggerUtil.i('Migration $name: renamed context → retention, '
          'all existing values mapped to -1 (auto)');

      await laconic.table('migrations').insert([
        {'name': name},
      ]);
    });
  }
}
