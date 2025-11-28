import 'package:athena/database/database.dart';

/// 修复 models 表字段类型，使其与 ModelEntity 定义匹配
/// - context_window: INTEGER -> TEXT
/// - input_price: REAL -> TEXT
/// - output_price: REAL -> TEXT
/// - released_at: INTEGER -> TEXT
/// - 添加 updated_at 字段
class Migration202511280001FixModelsSchemaTypes {
  static const name = 'migration_202511280001_fix_models_schema_types';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    // 1. 创建新的 models 表，字段类型与 Entity 匹配
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
        updated_at INTEGER NOT NULL
      )
    ''');

    // 2. 复制数据，转换类型
    await laconic.statement('''
      INSERT INTO models_new (id, name, model_id, provider_id, context_window,
                              input_price, output_price, released_at, reasoning, vision,
                              created_at, updated_at)
      SELECT id, name, model_id, provider_id,
             CAST(context_window AS TEXT),
             CAST(input_price AS TEXT),
             CAST(output_price AS TEXT),
             CAST(released_at AS TEXT),
             reasoning,
             vision,
             created_at,
             created_at
      FROM models
    ''');

    // 3. 删除旧表
    await laconic.statement('DROP TABLE models');

    // 4. 重命名新表
    await laconic.statement('ALTER TABLE models_new RENAME TO models');

    // 5. 重建索引
    await laconic.statement('''
      CREATE INDEX idx_models_provider_id ON models(provider_id)
    ''');

    // 记录迁移
    await laconic.table('migrations').insert([
      {'name': name},
    ]);
  }
}
