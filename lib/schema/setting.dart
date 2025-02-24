import 'package:isar/isar.dart';

part 'setting.g.dart';

@collection
@Name('settings')
class Setting {
  Id id = Isar.autoIncrement;
  double height = 720;
  double width = 960;
  int chatModelId = 0;
  int chatNamingModelId = 0;
  int chatSearchDecisionModelId = 0;
  int sentinelMetadataGenerationModelId = 0;
}
