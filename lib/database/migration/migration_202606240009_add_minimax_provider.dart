import 'package:athena/database/database.dart';
import 'package:athena/util/logger_util.dart';

/// 新增预设 provider：MiniMax（M3）。
///
/// MiniMax M3 是首个同时具备前沿 Coding/Agentic 能力、1M 上下文、
/// 原生多模态的国产旗舰模型：
/// - 1M 上下文窗口
/// - 支持思考模式、Function Call、多模态（文本 + 图像）
/// - Base URL: https://api.minimaxi.com/v1
class Migration202606240009AddMinimaxProvider {
  static const name = 'migration_202606240009_add_minimax_provider';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      // ---- provider ----
      var existing = await laconic
          .table('providers')
          .where('name', 'MiniMax')
          .count();
      int providerId;

      if (existing > 0) {
        var rows = await laconic.select(
          "SELECT id FROM providers WHERE name = 'MiniMax'",
        );
        providerId = rows.first.toMap()['id'] as int;
        LoggerUtil.i(
          'Migration $name: MiniMax provider already exists (id=$providerId)',
        );
      } else {
        var now = DateTime.now().millisecondsSinceEpoch;
        providerId = await laconic.table('providers').insertGetId({
          'name': 'MiniMax',
          'base_url': 'https://api.minimaxi.com/v1',
          'api_key': '',
          'enabled': 0,
          'is_preset': 1,
          'created_at': now,
        });
      }

      // ---- model: MiniMax-M3 ----
      var modelExists = await laconic
          .table('models')
          .where('model_id', 'MiniMax-M3')
          .where('provider_id', providerId)
          .count();
      if (modelExists > 0) {
        LoggerUtil.i(
          'Migration $name: MiniMax-M3 already exists, skipping',
        );
      } else {
        var now = DateTime.now().millisecondsSinceEpoch;
        await laconic.table('models').insert([
          {
            'name': 'MiniMax-M3',
            'model_id': 'MiniMax-M3',
            'provider_id': providerId,
            'context_window': 1000000,
            'input_price': '¥2.10/M input tokens',
            'output_price': '¥8.40/M output tokens',
            'released_at': 'Released 2026',
            'reasoning': 1,
            'vision': 1,
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
