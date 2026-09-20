import 'package:athena_core/util/logger_util.dart';
import 'package:athena_gui/database/database.dart';
import 'package:athena_gui/database/migration/athena_preset_prompt.dart';
import 'package:laconic/laconic.dart';

/// 将内置 Athena 的系统提示词升级为「每次调用都要填 call_description」的版本。
///
/// 引擎已把 call_description 列为工具 schema 的必填字段(见
/// ToolRegistry.parametersFor),提示词需同步要求模型填写;否则卡片 header
/// 只能退回展示命令、路径或参数 JSON。新提示词见 [athenaPresetPrompt]。
///
/// 只更新**仍在使用上一版默认提示词**的内置 Athena:
/// 通过 sentinel_evolve 修改过提示词的 Athena 保留用户定制,不覆盖。
class Migration202609200002RequireToolCallDescription {
  static const name = 'migration_202609200002_require_tool_call_description';

  /// 测试可注入内存实例;生产环境默认使用全局 [Database.instance]。
  final Laconic? _laconic;

  Migration202609200002RequireToolCallDescription({Laconic? laconic})
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
        if (prompt != agentAthenaPresetPromptV1) continue;
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
