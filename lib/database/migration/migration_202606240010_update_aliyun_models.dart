import 'package:athena/database/database.dart';
import 'package:athena/util/logger_util.dart';

/// 更新阿里云百炼预设模型。
///
/// 新增 4 个模型，删除全部 5 个旧模型，chat 自动迁移到同系列替代品。
class Migration202606240010UpdateAliyunModels {
  static const name = 'migration_202606240010_update_aliyun_models';

  static const _migrationMap = <String, String>{
    'deepseek-r1': 'deepseek-v4-flash',
    'deepseek-v3': 'deepseek-v4-flash',
    'qwen-max': 'qwen3.7-max',
    'qwen-plus': 'qwen3.7-plus',
    'qwen-turbo': 'qwen3.7-plus',
  };

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      var rows = await laconic.select(
        "SELECT id FROM providers WHERE name = '阿里云百炼' AND is_preset = 1",
      );
      if (rows.isEmpty) {
        LoggerUtil.i('Migration $name: 阿里云百炼 not found, skipping');
        await laconic.table('migrations').insert([{'name': name}]);
        return;
      }
      var providerId = rows.first.toMap()['id'] as int;
      var now = DateTime.now().millisecondsSinceEpoch;

      // ---- 插入新模型 ----
      await _insert(
        'Qwen3.7-Plus', 'qwen3.7-plus', providerId,
        contextWindow: 1000000,
        inputPrice: '¥1.6/M input tokens',
        outputPrice: '¥6.4/M output tokens',
        releasedAt: 'Released 2026',
        reasoning: true, vision: true, now: now,
      );
      await _insert(
        'Qwen3.7-Max', 'qwen3.7-max', providerId,
        contextWindow: 1000000,
        inputPrice: '¥6/M input tokens',
        outputPrice: '¥18/M output tokens',
        releasedAt: 'Released 2026',
        reasoning: true, now: now,
      );
      await _insert(
        'DeepSeek-V4-Pro', 'deepseek-v4-pro', providerId,
        contextWindow: 1000000,
        inputPrice: '¥12/M input tokens',
        outputPrice: '¥24/M output tokens',
        releasedAt: 'Released 2026',
        reasoning: true, now: now,
      );
      await _insert(
        'DeepSeek-V4-Flash', 'deepseek-v4-flash', providerId,
        contextWindow: 1000000,
        inputPrice: '¥1/M input tokens',
        outputPrice: '¥2/M output tokens',
        releasedAt: 'Released 2026',
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
    bool vision = false,
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
        'vision': vision ? 1 : 0,
        'is_preset': 1,
        'created_at': now,
        'updated_at': now,
      },
    ]);
  }
}
