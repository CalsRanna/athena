import 'package:isar/isar.dart';

part 'setting.g.dart';

@collection
@Name('settings')
class Setting {
  Id id = Isar.autoIncrement;
  @Name('dark_mode')
  bool darkMode = false;
  double height = 720;
  bool latex = false;
  double width = 960;
  int chatModelId = 0;
  int chatNamingModelId = 0;
  int sentinelMetadataGenerationModelId = 0;
}
