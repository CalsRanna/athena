import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/migration.dart';
import 'package:isar/isar.dart';

class Migration202503051715 {
  static Future<void> migrate() async {
    var chats = await isar.chats.where().findAll();
    var updatedChats = chats.map((chat) {
      return chat.copyWith(context: 0, temperature: 1.0);
    }).toList();
    await isar.writeTxn(() async {
      await isar.chats.putAll(updatedChats);
    });
    var migration = Migration()..migration = '202503051715';
    await isar.writeTxn(() async {
      await isar.migrations.put(migration);
    });
  }
}
