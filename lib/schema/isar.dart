import 'package:athena/schema/chat.dart';
import 'package:athena/schema/setting.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

late Isar isar;

class IsarInitializer {
  static Future<void> ensureInitialized() async {
    final directory = await getApplicationSupportDirectory();
    isar = await Isar.open(
      [ChatSchema, MessageSchema, SentinelSchema, SettingSchema],
      directory: directory.path,
    );
  }
}
