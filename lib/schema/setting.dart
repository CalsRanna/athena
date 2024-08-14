import 'package:isar/isar.dart';

part 'setting.g.dart';

@collection
@Name('settings')
class Setting {
  Id id = Isar.autoIncrement;
  @Name('dark_mode')
  bool darkMode = false;
  double height = 720;
  String model = '';
  String key = '';
  bool latex = false;
  String url = '';
  double width = 960;
}
