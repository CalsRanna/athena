import 'package:isar/isar.dart';

part 'model.g.dart';

@collection
@Name('models')
class Model {
  Id id = Isar.autoIncrement;
  String name = '';
  String value = '';
  @Name('provider_id')
  int providerId = 0;

  Model copyWith({
    int? id,
    String? name,
    String? value,
    int? providerId,
  }) {
    return Model()
      ..id = id ?? this.id
      ..name = name ?? this.name
      ..value = value ?? this.value
      ..providerId = providerId ?? this.providerId;
  }
}
