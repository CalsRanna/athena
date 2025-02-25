import 'package:athena/preset/tool.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/migration.dart';
import 'package:athena/schema/tool.dart';

class Migration202502251014 {
  static Future<void> migrate() async {
    await isar.writeTxn(() async {
      await isar.tools.clear();
    });
    List<Tool> tools = [];
    for (var preset in PresetTool.tools) {
      tools.add(Tool.fromJson(preset));
    }
    await isar.writeTxn(() async {
      await isar.tools.putAll(tools);
    });
    var migration = Migration()..migration = '202502251014';
    await isar.writeTxn(() async {
      await isar.migrations.put(migration);
    });
  }
}
