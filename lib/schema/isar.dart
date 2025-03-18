import 'package:athena/migration/migration_202502140332.dart';
import 'package:athena/migration/migration_202502251014.dart';
import 'package:athena/migration/migration_202503051715.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/migration.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/schema/setting.dart';
import 'package:athena/schema/tool.dart';
import 'package:athena/schema/translation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

late Isar isar;

class IsarInitializer {
  static Future<void> ensureInitialized() async {
    final directory = await getApplicationSupportDirectory();
    var schemas = [
      ChatSchema,
      MessageSchema,
      MigrationSchema,
      ModelSchema,
      ProviderSchema,
      SentinelSchema,
      SettingSchema,
      ToolSchema,
      TranslationSchema,
    ];
    isar = await Isar.open(schemas, directory: directory.path);
    await _migrate();
  }

  static Future<void> _migrate() async {
    var builder = isar.migrations.filter().migrationEqualTo('202502140332');
    var migrated = (await builder.count()) > 0;
    if (!migrated) {
      await Migration202502140332.migrate();
    }
    builder = isar.migrations.filter().migrationEqualTo('202502251014');
    migrated = (await builder.count()) > 0;
    if (!migrated) {
      await Migration202502251014.migrate();
    }
    builder = isar.migrations.filter().migrationEqualTo('202503051715');
    migrated = (await builder.count()) > 0;
    if (!migrated) {
      await Migration202503051715.migrate();
    }
  }
}
