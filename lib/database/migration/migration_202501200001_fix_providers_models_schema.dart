import 'package:athena/database/database.dart';

/// 修复 providers 和 models 表的字段不一致问题
class Migration202501200001FixProvidersModelsSchema {
  static const name = 'migration_202501200001_fix_providers_models_schema';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    // ========== 修复 providers 表 ==========
    // 1. 创建新的 providers 表
    await laconic.statement('''
      CREATE TABLE providers_new(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        base_url TEXT NOT NULL,
        api_key TEXT NOT NULL,
        enabled INTEGER DEFAULT 0,
        is_preset INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // 2. 复制数据 (url → base_url, key → api_key, 为 created_at 设置默认值)
    await laconic.statement('''
      INSERT INTO providers_new (id, name, base_url, api_key, enabled, is_preset, created_at)
      SELECT id, name, url, key, enabled, is_preset,
             CAST(strftime('%s', 'now') * 1000 AS INTEGER)
      FROM providers
    ''');

    // 3. 删除旧表
    await laconic.statement('DROP TABLE providers');

    // 4. 重命名新表
    await laconic.statement('ALTER TABLE providers_new RENAME TO providers');

    // ========== 修复 models 表 ==========
    // 1. 创建新的 models 表
    await laconic.statement('''
      CREATE TABLE models_new(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        model_id TEXT NOT NULL,
        provider_id INTEGER NOT NULL,
        context_window INTEGER DEFAULT 0,
        input_price REAL DEFAULT 0,
        output_price REAL DEFAULT 0,
        released_at INTEGER,
        reasoning INTEGER DEFAULT 0,
        vision INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // 2. 复制数据 (转换字段名和类型)
    await laconic.statement('''
      INSERT INTO models_new (id, name, model_id, provider_id, context_window,
                              input_price, output_price, released_at, reasoning, vision, created_at)
      SELECT id, name, value, provider_id,
             CASE WHEN context = '' THEN 0 ELSE CAST(context AS INTEGER) END,
             CASE WHEN input_price = '' THEN 0.0 ELSE CAST(input_price AS REAL) END,
             CASE WHEN output_price = '' THEN 0.0 ELSE CAST(output_price AS REAL) END,
             CASE WHEN released_at = '' THEN NULL ELSE CAST(released_at AS INTEGER) END,
             support_reasoning,
             support_visual,
             CAST(strftime('%s', 'now') * 1000 AS INTEGER)
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
