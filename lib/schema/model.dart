import 'package:isar/isar.dart';

part 'model.g.dart';

@collection
@Name('models')
class Model {
  Id id = Isar.autoIncrement;
  String context = '';
  @Name('input_price')
  String inputPrice = '';
  String name = '';
  @Name('output_price')
  String outputPrice = '';
  @Name('released_at')
  String releasedAt = '';
  @Name('support_reasoning')
  bool supportReasoning = false;
  @Name('support_visual')
  bool supportVisual = false;
  String value = '';
  @Name('provider_id')
  int providerId = 0;

  Model();

  Model.fromJson(Map<String, dynamic> json) {
    context = json['context'] ?? '';
    inputPrice = json['input_price'] ?? '';
    name = json['name'] ?? '';
    outputPrice = json['output_price'] ?? '';
    releasedAt = json['released_at'] ?? '';
    supportReasoning = json['support_reasoning'] ?? false;
    supportVisual = json['support_visual'] ?? false;
    value = json['value'] ?? '';
    providerId = json['provider_id'] ?? 0;
  }

  Model copyWith({
    int? id,
    String? context,
    String? inputPrice,
    String? name,
    String? outputPrice,
    String? releasedAt,
    bool? supportReasoning,
    bool? supportVisual,
    String? value,
    int? providerId,
  }) {
    return Model()
      ..id = id ?? this.id
      ..context = context ?? this.context
      ..inputPrice = inputPrice ?? this.inputPrice
      ..name = name ?? this.name
      ..outputPrice = outputPrice ?? this.outputPrice
      ..releasedAt = releasedAt ?? this.releasedAt
      ..supportReasoning = supportReasoning ?? this.supportReasoning
      ..supportVisual = supportVisual ?? this.supportVisual
      ..value = value ?? this.value
      ..providerId = providerId ?? this.providerId;
  }
}
