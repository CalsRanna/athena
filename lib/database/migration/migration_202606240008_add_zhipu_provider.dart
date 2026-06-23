import 'package:athena/database/database.dart';
import 'package:athena/util/logger_util.dart';

/// 新增预设 provider：智谱AI（GLM-5.2）。
///
/// GLM-5.2 是智谱旗舰基座模型：
/// - 1M 上下文窗口，128K 最大输出
/// - 支持思考模式、Function Call、流式输出
/// - 文本输入/输出
/// - Base URL: https://open.bigmodel.cn/api/paas/v4
class Migration202606240008AddZhipuProvider {
  static const name = 'migration_202606240008_add_zhipu_provider';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      // ---- provider ----
      var existing = await laconic
          .table('providers')
          .where('name', '智谱AI')
          .count();
      int providerId;

      if (existing > 0) {
        var rows = await laconic.select(
          "SELECT id FROM providers WHERE name = '智谱AI'",
        );
        providerId = rows.first.toMap()['id'] as int;
        LoggerUtil.i(
          'Migration $name: 智谱AI provider already exists (id=$providerId), '
          'skipping provider creation',
        );
      } else {
        var now = DateTime.now().millisecondsSinceEpoch;
        providerId = await laconic.table('providers').insertGetId({
          'name': '智谱AI',
          'base_url': 'https://open.bigmodel.cn/api/paas/v4',
          'api_key': '',
          'enabled': 0,
          'is_preset': 1,
          'created_at': now,
        });
      }

      // ---- model: GLM-5.2 ----
      var modelExists = await laconic
          .table('models')
          .where('model_id', 'glm-5.2')
          .where('provider_id', providerId)
          .count();
      if (modelExists > 0) {
        LoggerUtil.i(
          'Migration $name: glm-5.2 already exists for 智谱AI, skipping',
        );
      } else {
        var now = DateTime.now().millisecondsSinceEpoch;
        await laconic.table('models').insert([
          {
            'name': 'GLM-5.2',
            'model_id': 'glm-5.2',
            'provider_id': providerId,
            'context_window': 1000000,
            'input_price': '¥8/M input tokens',
            'output_price': '¥28/M output tokens',
            'released_at': 'Released 2026',
            'reasoning': 1,
            'vision': 0,
            'is_preset': 1,
            'created_at': now,
            'updated_at': now,
          },
        ]);
      }

      await laconic.table('migrations').insert([{'name': name}]);
      LoggerUtil.i('Migration $name: done');
    });
  }
}
