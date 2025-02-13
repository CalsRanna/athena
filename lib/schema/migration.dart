import 'package:isar/isar.dart';

part 'migration.g.dart';

@collection
@Name('migrations')
class Migration {
  Id id = Isar.autoIncrement;
  String migration = '';
}
