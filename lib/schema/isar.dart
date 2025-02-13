import 'package:athena/migration/migration_202502140332.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/migration.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/schema/setting.dart';
import 'package:isar/isar.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
    ];
    isar = await Isar.open(schemas, directory: directory.path);
    await _migrate();
  }

  static Future<void> _migrate() async {
    var package = await PackageInfo.fromPlatform();
    var buildNumber = package.buildNumber;
    var builder = isar.migrations.filter().migrationEqualTo('202502140332');
    var migrated = (await builder.count()) > 0;
    if (!migrated && int.parse(buildNumber) <= 75) {
      await Migration202502140332.migrate();
    }
  }
}
