import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';
import 'package:athena/schema/setting.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

late Isar isar;

class IsarInitializer {
  static Future<void> ensureInitialized() async {
    final directory = await getApplicationSupportDirectory();
    var schemas = [
      ChatSchema,
      MessageSchema,
      ModelSchema,
      ProviderSchema,
      SentinelSchema,
      SettingSchema,
    ];
    isar = await Isar.open(schemas, directory: directory.path);
  }
}
