import 'package:athena/database/database.dart';
import 'package:athena/util/logger_util.dart';

/// 清理 OpenRouter provider 下不属于 007 迁移的预设模型。
///
/// 保留 007 新增的 10 个模型，删除其余所有 is_preset=1 的模型。
class Migration202606240013CleanOpenRouterModels {
  static const name = 'migration_202606240013_clean_openrouter_models';

  /// 007 迁移添加的模型（保留）
  static const _keep = {
    'google/gemini-3.5-flash',
    'google/gemini-3.1-pro-preview',
    'openai/gpt-5.5',
    'openai/gpt-5.4-mini',
    'anthropic/claude-fable-5',
    'anthropic/claude-opus-4.8',
    'anthropic/claude-sonnet-4.6',
    'anthropic/claude-haiku-4.5',
    'deepseek/deepseek-v4-pro',
    'deepseek/deepseek-v4-flash',
  };

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      var rows = await laconic.select(
        "SELECT id FROM providers WHERE name = 'Open Router' AND is_preset = 1",
      );
      if (rows.isEmpty) {
        LoggerUtil.i('Migration $name: Open Router not found, skipping');
        await laconic.table('migrations').insert([{'name': name}]);
        return;
      }
      var providerId = rows.first.toMap()['id'] as int;

      // 查出所有预设模型
      var models = await laconic.select(
        'SELECT id, model_id FROM models WHERE provider_id = ? AND is_preset = 1',
        [providerId],
      );

      var deleted = 0;
      for (var model in models) {
        var map = model.toMap();
        var modelId = map['model_id'] as String;
        if (_keep.contains(modelId)) continue;

        var id = map['id'] as int;

        // 将引用此模型的 chat 迁到 DeepSeek V4 Flash（通用兜底）
        var fallback = await laconic.select(
          "SELECT id FROM models WHERE model_id = 'deepseek/deepseek-v4-flash' AND provider_id = ?",
          [providerId],
        );
        if (fallback.isNotEmpty) {
          var fallbackId = fallback.first.toMap()['id'] as int;
          await laconic.statement(
            'UPDATE chats SET model_id = ? WHERE model_id = ?',
            [fallbackId, id],
          );
        }

        await laconic.table('models').where('id', id).delete();
        deleted++;
        LoggerUtil.i('Migration $name: deleted $modelId');
      }

      LoggerUtil.i('Migration $name: deleted $deleted stale models');

      await laconic.table('migrations').insert([{'name': name}]);
    });
  }
}
