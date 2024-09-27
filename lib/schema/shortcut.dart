import 'package:isar/isar.dart';

part 'shortcut.g.dart';

@collection
@Name('shortcuts')
class Shortcut {
  Id id = Isar.autoIncrement;
  String description = '';
  String model = '';
  String prompt = '';
  String title = '';
  String type = '';
  @Name('created_at')
  DateTime createdAt = DateTime.now();
  @Name('updated_at')
  DateTime updatedAt = DateTime.now();
}
