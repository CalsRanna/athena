import 'dart:io';

import 'package:athena/database/migration/migration_202501170001_init.dart';

import 'package:athena/database/migration/migration_202501200001_fix_providers_models_schema.dart';
import 'package:athena/database/migration/migration_202501200002_add_trpg_tables.dart';
import 'package:athena/database/migration/migration_202501210001_add_suggestions_to_trpg_messages.dart';
import 'package:athena/database/migration/migration_202501210002_simplify_trpg_games.dart';
import 'package:athena/database/migration/migration_202511280001_fix_models_schema_types.dart';
import 'package:athena/database/migration/migration_202605210001_add_tool_fields.dart';
import 'package:athena/database/migration/migration_202605260001_db_integrity.dart';
import 'package:athena/database/migration/migration_202606110001_dedup_presets.dart';
import 'package:athena/database/migration/migration_202606170001_add_preset_flag.dart';
import 'package:athena/database/migration/migration_202606230001_add_chat_token_total.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/preset/provider.dart';
import 'package:athena/preset/sentinel.dart';
import 'package:athena/util/logger_util.dart';
import 'package:laconic/laconic.dart';
import 'package:laconic_sqlite/laconic_sqlite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class Database {
  static final Database instance = Database._internal();

  late Laconic laconic;

  final _migrationCreateSql = '''
    CREATE TABLE migrations(
      name TEXT NOT NULL
    );
  ''';

  final _checkMigrationExistSql = '''
    SELECT name FROM sqlite_master
    WHERE type='table' AND name='migrations';
  ''';

  static const _presetProvidersMarker = 'preset_providers_v1';
  static const _presetSentinelsMarker = 'preset_sentinels_v1';

  Database._internal();

  Future<void> ensureInitialized() async {
    var directory = await getApplicationSupportDirectory();
    var path = join(directory.path, 'athena.db');
    LoggerUtil.i('Database path: $path');
    var file = File(path);
    var exists = await file.exists();
    if (!exists) {
      await file.create(recursive: true);
    }

    laconic = Laconic(
      SqliteDriver(SqliteConfig(path)),
      listen: (query) {
        LoggerUtil.d(query.sql);
      },
    );

    await _migrate();
    // 启用外键级联，必须在所有迁移（含孤儿清理）完成之后
    await laconic.statement('PRAGMA foreign_keys = ON');
    await _preset();
  }

  Future<void> _migrate() async {
    var tables = await laconic.select(_checkMigrationExistSql);
    if (tables.isEmpty) {
      await laconic.statement(_migrationCreateSql);
    }

    // 按顺序执行迁移
    await Migration202501170001Init().migrate();
    await Migration202501200001FixProvidersModelsSchema().migrate();
    await Migration202501200002AddTrpgTables().migrate();
    await Migration202501210001AddSuggestionsToTrpgMessages().migrate();
    await Migration202501210002SimplifyTrpgGames().migrate();
    await Migration202511280001FixModelsSchemaTypes().migrate();
    await Migration202605210001AddToolFields().migrate();
    await Migration202605260001DbIntegrity().migrate();
    await Migration202606110001DedupPresets().migrate();
    await Migration202606170001AddPresetFlag().migrate();
    await Migration202606230001AddChatTokenTotal().migrate();
  }

  Future<void> _preset() async {
    await _presetSentinel();
    await _presetProviders();
  }

  Future<void> _presetProviders() async {
    var done = await laconic
        .table('migrations')
        .where('name', _presetProvidersMarker)
        .count();
    if (done > 0) return;

    await laconic.transaction(() async {
      var now = DateTime.now();
      var providers = PresetProvider.providers;

      for (var providerData in providers) {
        var provider = ProviderEntity(
          name: providerData['name'] as String,
          baseUrl: providerData['base_url'] as String,
          apiKey: providerData['api_key'] as String,
          enabled: false,
          isPreset: providerData['is_preset'] as bool,
          createdAt: now,
        );

        var providerJson = provider.toJson();
        providerJson.remove('id');
        var providerId = await laconic
            .table('providers')
            .insertGetId(providerJson);

        var models = providerData['models'] as List<Map<String, dynamic>>;
        var modelJsonList = <Map<String, dynamic>>[];

        for (var modelData in models) {
          var model = ModelEntity(
            name: modelData['name'] as String,
            modelId: modelData['model_id'] as String,
            providerId: providerId,
            contextWindow: modelData['context_window'] as String,
            inputPrice: modelData['input_price'] as String,
            outputPrice: modelData['output_price'] as String,
            releasedAt: modelData['released_at'] as String,
            reasoning: modelData['reasoning'] as bool,
            vision: modelData['vision'] as bool,
            isPreset: true,
            createdAt: now,
            updatedAt: now,
          );

          var modelJson = model.toJson();
          modelJson.remove('id');
          modelJsonList.add(modelJson);
        }

        if (modelJsonList.isNotEmpty) {
          await laconic.table('models').insert(modelJsonList);
        }
      }

      await laconic.table('migrations').insert([
        {'name': _presetProvidersMarker},
      ]);
    });
  }

  Future<void> _presetSentinel() async {
    var done = await laconic
        .table('migrations')
        .where('name', _presetSentinelsMarker)
        .count();
    if (done > 0) return;

    await laconic.transaction(() async {
      var preset = PresetSentinel.defaultPresetSentinel;

      var sentinel = SentinelEntity(
        name: preset['name'] as String,
        avatar: preset['avatar'] as String,
        description: preset['description'] as String,
        prompt: preset['prompt'] as String,
        tags: preset['tags'] as String,
        isPreset: true,
      );

      var json = sentinel.toJson();
      json.remove('id');
      await laconic.table('sentinels').insert([json]);

      await laconic.table('migrations').insert([
        {'name': _presetSentinelsMarker},
      ]);
    });
  }

  /// 重置数据库：清空所有数据并重新执行迁移和预设
  Future<void> reset() async {
    // DROP 阶段不包事务（单个 DROP IF EXISTS 是原子的，失败可重启重试）
    var tables = await laconic.select('''
      SELECT name FROM sqlite_master
      WHERE type='table' AND name NOT LIKE 'sqlite_%'
    ''');

    for (var table in tables) {
      var tableName = table['name'] as String;
      await laconic.statement('DROP TABLE IF EXISTS "$tableName"');
    }

    await _migrate();
    await laconic.statement('PRAGMA foreign_keys = ON');
    await _preset();
  }
}
