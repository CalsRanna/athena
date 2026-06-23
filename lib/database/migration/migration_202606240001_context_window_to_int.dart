import 'package:athena/database/database.dart';
import 'package:athena/util/context_window_util.dart';
import 'package:athena/util/logger_util.dart';

/// 把 models.context_window 列从 TEXT（"64K context" / "200,000 context" /
/// "1,000,000 context" 等自由文本）迁移为 INTEGER（单位：token）。
///
/// 背景：实现"上下文窗口占用率"指标需要拿到 contextWindow 的数值；
/// 旧格式无法可靠用于比例计算。本迁移：
/// - 重建 models 表，context_window INTEGER DEFAULT 0
/// - 解析每行旧字符串（[parseContextWindow]）：去尾缀、千分位、K/M
///   大小写后缀；解析失败回退 0。
/// - 外键与索引照搬现有 schema。
class Migration202606240001ContextWindowToInt {
  static const name = 'migration_202606240001_context_window_to_int';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      // 1. 读旧数据 → 解析为 int
      var rows = await laconic.select('SELECT id, context_window FROM models');
      final Map<int, int> parsed = {};
      for (var row in rows) {
        var map = row.toMap();
        var id = map['id'] as int;
        var cw = map['context_window'];
        parsed[id] = parseContextWindow(cw?.toString() ?? '');
      }
      LoggerUtil.i(
        'Migration $name: parsed ${parsed.length} rows '
        '(${parsed.values.where((v) => v == 0).length} fell back to 0)',
      );

      // 2. 重建表为 INTEGER 列
      await laconic.statement('''
        CREATE TABLE models_new(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          model_id TEXT NOT NULL,
          provider_id INTEGER NOT NULL,
          context_window INTEGER DEFAULT 0,
          input_price TEXT DEFAULT '',
          output_price TEXT DEFAULT '',
          released_at TEXT DEFAULT '',
          reasoning INTEGER DEFAULT 0,
          vision INTEGER DEFAULT 0,
          is_preset INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
        )
      ''');

      await laconic.statement('''
        INSERT INTO models_new (id, name, model_id, provider_id, context_window,
                                input_price, output_price, released_at,
                                reasoning, vision, is_preset,
                                created_at, updated_at)
        SELECT id, name, model_id, provider_id, 0,
               input_price, output_price, released_at,
               reasoning, vision, COALESCE(is_preset, 0),
               created_at, updated_at
        FROM models
      ''');

      // 3. 写回解析后的整数
      for (var entry in parsed.entries) {
        if (entry.value <= 0) continue;
        await laconic
            .table('models_new')
            .where('id', entry.key)
            .update({'context_window': entry.value});
      }

      await laconic.statement('DROP TABLE models');
      await laconic.statement('ALTER TABLE models_new RENAME TO models');
      await laconic.statement('''
        CREATE INDEX IF NOT EXISTS idx_models_provider_id ON models(provider_id)
      ''');

      await laconic.table('migrations').insert([
        {'name': name},
      ]);
    });
  }
}