import 'package:isar/isar.dart';

part 'model.g.dart';

@collection
@Name('models')
class Model {
  Id id = Isar.autoIncrement;
  @Name('model_id')
  late String modelId;
  @Name('max_length')
  late int maxLength;
  late String name;
  @Name('token_limit')
  late int tokenLimit;
}
