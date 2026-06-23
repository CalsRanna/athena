import 'package:athena/database/database.dart';
import 'package:athena/util/logger_util.dart';

/// 更新 DeepSeek 预设模型至 V4 系列。
///
/// 根据 DeepSeek 官方文档（2026/06）：
/// - deepseek-chat / deepseek-reasoner 将于 2026/07/24 弃用
/// - 新增 deepseek-v4-flash（替代上述二者，支持思考/非思考模式切换）
/// - 新增 deepseek-v4-pro
/// - 两者均支持思考模式，上下文 1M
/// - base_url 更新为 https://api.deepseek.com
///
/// 操作：
/// 1. 更新 Deep Seek provider 的 base_url
/// 2. 插入新模型 deepseek-v4-flash / deepseek-v4-pro
/// 3. 将使用旧模型的 chat 迁移到新模型
/// 4. 删除旧模型 deepseek-chat / deepseek-reasoner
class Migration202606240006UpdateDeepSeekModels {
  static const name = 'migration_202606240006_update_deepseek_models';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      // 1. 查找 Deep Seek provider
      var rows = await laconic.select(
        "SELECT id FROM providers WHERE name = 'Deep Seek' AND is_preset = 1",
      );
      if (rows.isEmpty) {
        LoggerUtil.i('Migration $name: Deep Seek provider not found, skipping');
        await laconic.table('migrations').insert([
          {'name': name},
        ]);
        return;
      }
      var providerId = rows.first.toMap()['id'] as int;

      // 3. 插入新模型（幂等：先查后插）
      var now = DateTime.now().millisecondsSinceEpoch;

      await _insertIfNotExists(
        name: 'DeepSeek-V4-Flash',
        modelId: 'deepseek-v4-flash',
        providerId: providerId,
        contextWindow: 1000000,
        inputPrice: '¥1/M input tokens (cache miss)',
        outputPrice: '¥2/M output tokens',
        releasedAt: 'Released 2026',
        reasoning: true,
        now: now,
      );

      await _insertIfNotExists(
        name: 'DeepSeek-V4-Pro',
        modelId: 'deepseek-v4-pro',
        providerId: providerId,
        contextWindow: 1000000,
        inputPrice: '¥3/M input tokens (cache miss)',
        outputPrice: '¥6/M output tokens',
        releasedAt: 'Released 2026',
        reasoning: true,
        now: now,
      );

      LoggerUtil.i('Migration $name: inserted V4 models');

      // 4. 取 V4 Flash 的 id，用于 chat 迁移
      var v4FlashRow = await laconic.select(
        "SELECT id FROM models WHERE model_id = 'deepseek-v4-flash' AND provider_id = ?",
        [providerId],
      );
      if (v4FlashRow.isEmpty) {
        LoggerUtil.i(
          'Migration $name: V4 Flash not found after insert, aborting',
        );
        return;
      }
      var v4FlashId = v4FlashRow.first.toMap()['id'] as int;

      // 5. 迁移 chat → 删除旧模型
      for (var oldModelId in ['deepseek-chat', 'deepseek-reasoner']) {
        var oldRows = await laconic.select(
          'SELECT id FROM models WHERE model_id = ? AND provider_id = ?',
          [oldModelId, providerId],
        );
        if (oldRows.isEmpty) continue;
        var oldId = oldRows.first.toMap()['id'] as int;

        // 迁移引用旧模型的 chat
        await laconic.statement(
          'UPDATE chats SET model_id = ? WHERE model_id = ?',
          [v4FlashId, oldId],
        );

        // 删除旧模型
        await laconic.table('models').where('id', oldId).delete();

        LoggerUtil.i(
          'Migration $name: deleted $oldModelId, chats migrated to deepseek-v4-flash',
        );
      }

      await laconic.table('migrations').insert([
        {'name': name},
      ]);
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _insertIfNotExists({
    required String name,
    required String modelId,
    required int providerId,
    required int contextWindow,
    required String inputPrice,
    required String outputPrice,
    required String releasedAt,
    required bool reasoning,
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
