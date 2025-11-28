import 'dart:io';

import 'package:athena/database/migration/migration_202501170001_init.dart';
import 'package:athena/database/migration/migration_202501170002_add_server_fields.dart';
import 'package:athena/database/migration/migration_202501200001_fix_providers_models_schema.dart';
import 'package:athena/database/migration/migration_202501200002_add_trpg_tables.dart';
import 'package:athena/database/migration/migration_202501210001_add_suggestions_to_trpg_messages.dart';
import 'package:athena/database/migration/migration_202501210002_simplify_trpg_games.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/preset/provider.dart';
import 'package:athena/preset/sentinel.dart';
import 'package:athena/util/logger_util.dart';
import 'package:laconic/laconic.dart';
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

    var config = SqliteConfig(path);
    laconic = Laconic.sqlite(
      config,
      listen: (query) {
        LoggerUtil.d(query.sql);
      },
    );

    await _migrate();
    await _preset();
  }

  Future<void> _migrate() async {
    var tables = await laconic.select(_checkMigrationExistSql);
    if (tables.isEmpty) {
      await laconic.statement(_migrationCreateSql);
    }

    // 按顺序执行迁移
    await Migration202501170001Init().migrate();
    await Migration202501170002AddServerFields().migrate();
    await Migration202501200001FixProvidersModelsSchema().migrate();
    await Migration202501200002AddTrpgTables().migrate();
    await Migration202501210001AddSuggestionsToTrpgMessages().migrate();
    await Migration202501210002SimplifyTrpgGames().migrate();
  }

  Future<void> _preset() async {
    await _presetSentinel();
    await _presetProviders();
  }

  Future<void> _presetProviders() async {
    var providerCount = await laconic.table('providers').count();
    if (providerCount > 0) return;

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
          contextWindow: modelData['context_window'] as int,
          inputPrice: (modelData['input_price'] as num).toDouble(),
          outputPrice: (modelData['output_price'] as num).toDouble(),
          reasoning: modelData['reasoning'] as bool,
          vision: modelData['vision'] as bool,
          createdAt: now,
        );

        var modelJson = model.toJson();
        modelJson.remove('id');
        modelJsonList.add(modelJson);
      }

      if (modelJsonList.isNotEmpty) {
        await laconic.table('models').insert(modelJsonList);
      }
    }
  }

  Future<void> _presetSentinel() async {
    var count = await laconic.table('sentinels').count();

    if (count == 0) {
      var preset = PresetSentinel.defaultPresetSentinel;
      var tags = (preset['tags'] as String)
          .split(',')
          .map((e) => e.trim())
          .toList();

      var sentinel = SentinelEntity(
        name: preset['name'] as String,
        avatar: preset['avatar'] as String,
        description: preset['description'] as String,
        prompt: preset['prompt'] as String,
        tags: tags,
      );

      var json = sentinel.toJson();
      json.remove('id');
      await laconic.table('sentinels').insert([json]);
    }
  }
}
