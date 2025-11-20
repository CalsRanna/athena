import 'dart:io';

import 'package:athena/database/migration/migration_202501170001_init.dart';
import 'package:athena/database/migration/migration_202501170002_add_server_fields.dart';
import 'package:athena/database/migration/migration_202501200001_fix_providers_models_schema.dart';
import 'package:athena/entity/sentinel_entity.dart';
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
    LoggerUtil.logger.i('Database path: $path');
    var file = File(path);
    var exists = await file.exists();
    if (!exists) {
      await file.create(recursive: true);
    }

    var config = SqliteConfig(path);
    laconic = Laconic.sqlite(
      config,
      listen: (query) {
        LoggerUtil.logger.d(query.sql);
      },
    );

    await _migrate();
    await _ensureDefaultSentinel();
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
  }

  Future<void> _ensureDefaultSentinel() async {
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
