import 'package:isar/isar.dart';

part 'model.g.dart';

@collection
@Name('models')
class Model {
  Id id = Isar.autoIncrement;
  bool enabled = false;
  String name = '';
  String value = '';
  @Name('provider_id')
  int providerId = 0;

  Model copyWith({
    int? id,
    bool? enabled,
    String? name,
    String? value,
    int? providerId,
  }) {
    return Model()
      ..id = id ?? this.id
      ..enabled = enabled ?? this.enabled
      ..name = name ?? this.name
      ..value = value ?? this.value
      ..providerId = providerId ?? this.providerId;
  }
}
