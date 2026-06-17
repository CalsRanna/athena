import 'package:athena/database/database.dart';
import 'package:athena/util/logger_util.dart';

/// 为 models 和 sentinels 表添加 is_preset 列，并回溯标记已有的预设数据。
///
/// - models 表：新增 is_preset INTEGER DEFAULT 0
/// - sentinels 表：新增 is_preset INTEGER DEFAULT 0
/// - 回溯：属于 is_preset 为 1 的 provider 的 model 标记为预设
/// - 回溯：名为 'Athena' 的 sentinel 标记为预设
class Migration202606170001AddPresetFlag {
  static const name = 'migration_202606170001_add_preset_flag';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      // 1. 为 models 表添加 is_preset 列
      await _addColumnIfNotExists(
        laconic,
        table: 'models',
        column: 'is_preset',
        definition: 'INTEGER DEFAULT 0',
      );

      // 2. 为 sentinels 表添加 is_preset 列
      await _addColumnIfNotExists(
        laconic,
        table: 'sentinels',
        column: 'is_preset',
        definition: 'INTEGER DEFAULT 0',
      );

      // 3. 回溯 models：属于预设 provider 的 model 标记为预设
      await laconic.statement(
        '''UPDATE models SET is_preset = 1
           WHERE provider_id IN (SELECT id FROM providers WHERE is_preset = 1)''',
      );
      LoggerUtil.i('Migration $name: backfilled preset models');

      // 4. 回溯 sentinels：名为 'Athena' 的是内置预设
      await laconic.statement(
        "UPDATE sentinels SET is_preset = 1 WHERE name = 'Athena'",
      );
      LoggerUtil.i('Migration $name: backfilled preset sentinels');

      await laconic.table('migrations').insert([
        {'name': name},
      ]);
    });
  }

  /// 安全添加列：先检查列是否已存在，避免重复执行报错
  Future<void> _addColumnIfNotExists(
    dynamic laconic, {
    required String table,
    required String column,
    required String definition,
  }) async {
    var result = await laconic.select(
      'PRAGMA table_info($table)',
    );
    var columns = result.map((r) => r.toMap()['name'] as String).toList();
    if (!columns.contains(column)) {
      await laconic.statement(
        'ALTER TABLE $table ADD COLUMN $column $definition',
      );
      LoggerUtil.i('Migration $name: added $column to $table');
    }
  }
}
