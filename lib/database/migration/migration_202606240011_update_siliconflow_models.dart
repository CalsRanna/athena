import 'package:athena/database/database.dart';
import 'package:athena/util/logger_util.dart';

/// 更新硅基流动预设模型。
///
/// 新增 5 个常用模型，删除旧的 DeepSeek-R1 / DeepSeek-V3，
/// chat 自动迁移到 DeepSeek-V4-Flash。
class Migration202606240011UpdateSiliconFlowModels {
  static const name = 'migration_202606240011_update_siliconflow_models';

  static const _migrationMap = <String, String>{
    'deepseek-ai/DeepSeek-R1': 'deepseek-ai/DeepSeek-V4-Flash',
    'deepseek-ai/DeepSeek-V3': 'deepseek-ai/DeepSeek-V4-Flash',
  };

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      var rows = await laconic.select(
        "SELECT id FROM providers WHERE name = '硅基流动' AND is_preset = 1",
      );
      if (rows.isEmpty) {
        LoggerUtil.i('Migration $name: 硅基流动 not found, skipping');
        await laconic.table('migrations').insert([{'name': name}]);
        return;
      }
      var providerId = rows.first.toMap()['id'] as int;
      var now = DateTime.now().millisecondsSinceEpoch;

      // ---- 插入新模型 ----
      await _insert(
        'DeepSeek-V4-Pro', 'deepseek-ai/DeepSeek-V4-Pro', providerId,
        contextWindow: 1000000,
        inputPrice: '¥12/M input tokens',
        outputPrice: '¥24/M output tokens',
        releasedAt: 'Released Apr 24, 2026',
        reasoning: true, now: now,
      );
      await _insert(
        'DeepSeek-V4-Flash', 'deepseek-ai/DeepSeek-V4-Flash', providerId,
        contextWindow: 1000000,
        inputPrice: '¥1/M input tokens',
        outputPrice: '¥2/M output tokens',
        releasedAt: 'Released Apr 24, 2026',
        reasoning: true, now: now,
      );
      await _insert(
        'GLM-5.2', 'zai-org/GLM-5.2', providerId,
        contextWindow: 1000000,
        inputPrice: '¥6/M input tokens',
        outputPrice: '¥28/M output tokens',
        releasedAt: 'Released Jun 17, 2026',
        reasoning: true, now: now,
      );
      await _insert(
        'Kimi-K2.7-Code', 'moonshotai/Kimi-K2.7-Code', providerId,
        contextWindow: 1000000,
        inputPrice: '¥6.5/M input tokens',
        outputPrice: '¥27/M output tokens',
        releasedAt: 'Released Jun 12, 2026',
        reasoning: true, now: now,
      );
      // ---- 迁移 chat + 删除旧模型 ----
      for (var entry in _migrationMap.entries) {
        var oldModelId = entry.key;
        var newModelId = entry.value;

        var oldRows = await laconic.select(
          'SELECT id FROM models WHERE model_id = ? AND provider_id = ?',
          [oldModelId, providerId],
        );
        if (oldRows.isEmpty) continue;
        var oldId = oldRows.first.toMap()['id'] as int;

        var newRows = await laconic.select(
          'SELECT id FROM models WHERE model_id = ? AND provider_id = ?',
          [newModelId, providerId],
        );
        if (newRows.isEmpty) {
          LoggerUtil.i(
            'Migration $name: target $newModelId not found, skipping $oldModelId',
          );
          continue;
        }
        var newId = newRows.first.toMap()['id'] as int;

        await laconic.statement(
          'UPDATE chats SET model_id = ? WHERE model_id = ?',
          [newId, oldId],
        );

        await laconic.table('models').where('id', oldId).delete();
        LoggerUtil.i('Migration $name: $oldModelId → $newModelId');
      }

      await laconic.table('migrations').insert([{'name': name}]);
      LoggerUtil.i('Migration $name: done');
    });
  }

  Future<void> _insert(
    String name,
    String modelId,
    int providerId, {
    required int contextWindow,
    required String inputPrice,
    required String outputPrice,
    required String releasedAt,
    bool reasoning = false,
    required int now,
  }) async {
    var laconic = Database.instance.laconic;

    var exists = await laconic
        .table('models')
        .where('model_id', modelId)
        .where('provider_id', providerId)
        .count();
    if (exists > 0) return;

    await laconic.table('models').insert([
      {
        'name': name,
        'model_id': modelId,
        'provider_id': providerId,
        'context_window': contextWindow,
        'input_price': inputPrice,
        'output_price': outputPrice,
        'released_at': releasedAt,
        'reasoning': reasoning ? 1 : 0,
        'vision': 0,
        'is_preset': 1,
        'created_at': now,
        'updated_at': now,
      },
    ]);
  }
}
