import 'package:athena/database/database.dart';

/// 综合数据完整性迁移：
/// - 清理孤儿 messages 与 models
/// - 给 models 表加 provider_id 外键（ON DELETE CASCADE）
/// - 把 context_window 中纯数字格式归一为 "{千分位} context"
class Migration202605260001DbIntegrity {
  static const name = 'migration_202605260001_db_integrity';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      // 清理孤儿 messages
      await laconic.statement('''
        DELETE FROM messages
        WHERE chat_id NOT IN (SELECT id FROM chats)
      ''');

      // 清理孤儿 models
      await laconic.statement('''
        DELETE FROM models
        WHERE provider_id NOT IN (SELECT id FROM providers)
      ''');

      // 重建 models 表加 FK
      await laconic.statement('''
        CREATE TABLE models_new(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          model_id TEXT NOT NULL,
          provider_id INTEGER NOT NULL,
          context_window TEXT DEFAULT '',
          input_price TEXT DEFAULT '',
          output_price TEXT DEFAULT '',
          released_at TEXT DEFAULT '',
          reasoning INTEGER DEFAULT 0,
          vision INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
        )
      ''');

      await laconic.statement('''
        INSERT INTO models_new (id, name, model_id, provider_id, context_window,
                                input_price, output_price, released_at, reasoning, vision,
                                created_at, updated_at)
        SELECT id, name, model_id, provider_id, context_window,
               input_price, output_price, released_at, reasoning, vision,
               created_at, updated_at
        FROM models
      ''');

      await laconic.statement('DROP TABLE models');
      await laconic.statement('ALTER TABLE models_new RENAME TO models');
      await laconic.statement('''
        CREATE INDEX idx_models_provider_id ON models(provider_id)
      ''');

      // context_window 归一化（Dart 侧处理千分位格式化）
      var rows = await laconic.select('SELECT id, context_window FROM models');
      for (var row in rows) {
        var map = row.toMap();
        var id = map['id'] as int;
        var cw = map['context_window'] as String?;
        if (cw == null || cw.isEmpty) continue;
        if (cw.contains('context')) continue;
        if (cw.contains('K') || cw.contains('M')) continue;
        var digits = cw.replaceAll(',', '');
        var n = int.tryParse(digits);
        if (n == null) continue;
        var formatted = '${_formatThousands(n)} context';
        await laconic
            .table('models')
            .where('id', id)
            .update({'context_window': formatted});
      }

      await laconic.table('migrations').insert([
        {'name': name},
      ]);
    });
  }

  static String _formatThousands(int n) {
    var s = n.toString();
    var buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
