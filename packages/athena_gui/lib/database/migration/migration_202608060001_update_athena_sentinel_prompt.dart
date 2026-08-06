import 'package:athena_gui/database/database.dart';
import 'package:athena_gui/database/migration/athena_preset_prompt.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:laconic/laconic.dart';

/// 将内置 Athena sentinel 的系统提示词升级为 Agent 模式版本。
///
/// 旧提示词按纯对话助手撰写,不含工具调用、多轮迭代、权限确认、
/// 自我进化等 Agent 能力描述,与 Agent 模式的 Athena 行为不符。
/// 新提示词见 [athenaPresetPrompt](与 seed migration 共用同一常量)。
///
/// 只更新**仍在使用旧默认提示词**的内置 Athena:
/// 通过 sentinel_evolve 修改过提示词的 Athena 保留用户定制,不覆盖。
class Migration202608060001UpdateAthenaSentinelPrompt {
  static const name = 'migration_202608060001_update_athena_sentinel_prompt';

  /// 测试可注入内存实例;生产环境默认使用全局 [Database.instance]。
  final Laconic? _laconic;

  Migration202608060001UpdateAthenaSentinelPrompt({Laconic? laconic})
      : _laconic = laconic;

  Future<void> migrate() async {
    var laconic = _laconic ?? Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      var rows = await laconic.select(
        'SELECT id, prompt FROM sentinels WHERE name = ? AND is_preset = 1',
        ['Athena'],
      );

      var updated = 0;
      for (final row in rows) {
        var id = row.toMap()['id'] as int;
        var prompt = row.toMap()['prompt'] as String? ?? '';
        if (prompt != legacyAthenaPresetPrompt) continue;
        await laconic
            .table('sentinels')
            .where('id', id)
            .update({'prompt': athenaPresetPrompt});
        updated++;
      }

      LoggerUtil.i('Migration $name: updated $updated sentinel(s)');

      await laconic.table('migrations').insert([
        {'name': name},
      ]);
    });
  }
}
