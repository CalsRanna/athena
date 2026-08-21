import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:athena_gui/database/database.dart';
import 'package:athena_gui/database/migration/athena_preset_prompt.dart';

/// 首次启动时创建 Athena 预设角色(sentinel)。
///
/// 预设 provider/模型种子已由 ModelCatalogService(models.dev)取代
/// (migration_202606240005_seed_presets 及 006~013 已删除),
/// sentinel 无外部数据源,保留为唯一的内置种子。
class Migration202608210001SeedSentinel {
  static const name = 'migration_202608210001_seed_sentinel';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var done = await laconic
        .table('migrations')
        .where('name', name)
        .count();
    if (done > 0) return;

    // 兼容旧 marker:老库已通过 migration_202606240005 种过角色
    var legacyDone = await laconic
        .table('migrations')
        .where('name', 'preset_sentinels_v1')
        .count();
    if (legacyDone > 0) return;

    var sentinel = SentinelEntity(
      name: 'Athena',
      avatar: '',
      description: '专业、冷静且深度的AI助手，以精准执行与逻辑严谨著称。',
      prompt: athenaPresetPrompt,
      tags: '专业助手, 冷静执行, 逻辑严谨, AI助手, 深度分析',
      isPreset: true,
    );

    var json = sentinel.toJson();
    json.remove('id');
    await laconic.table('sentinels').insert([json]);

    await laconic.table('migrations').insert([
      {'name': name},
    ]);
    LoggerUtil.i('Migration $name: seeded sentinel');
  }
}
