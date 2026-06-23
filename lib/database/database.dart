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
import 'package:athena/database/migration/migration_202606240001_context_window_to_int.dart';
import 'package:athena/database/migration/migration_202606240002_add_chat_token_snapshots.dart';
import 'package:athena/database/migration/migration_202606240003_rename_context_to_retention.dart';
import 'package:athena/database/migration/migration_202606240004_add_compacted_to_messages.dart';
import 'package:athena/database/migration/migration_202606240005_seed_presets.dart';
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
    await Migration202606240001ContextWindowToInt().migrate();
    await Migration202606240002AddChatTokenSnapshots().migrate();
    await Migration202606240003RenameContextToRetention().migrate();
    await Migration202606240004AddCompactedToMessages().migrate();
    await Migration202606240005SeedPresets().migrate();
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
  }
}
