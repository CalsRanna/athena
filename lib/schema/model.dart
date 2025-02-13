import 'package:isar/isar.dart';

part 'model.g.dart';

@collection
@Name('models')
class Model {
  Id id = Isar.autoIncrement;
  @Name('input_price')
  String inputPrice = '';
  @Name('max_token')
  int maxToken = 0;
  String name = '';
  @Name('output_price')
  String outputPrice = '';
  @Name('released_at')
  String releasedAt = '';
  @Name('support_function_call')
  bool supportFunctionCall = false;
  @Name('support_thinking')
  bool supportThinking = false;
  @Name('support_visual_recognition')
  bool supportVisualRecognition = false;
  String value = '';
  @Name('provider_id')
  int providerId = 0;

  Model();

  Model.fromJson(Map<String, dynamic> json) {
    inputPrice = json['input_price'] ?? '';
    maxToken = json['max_token'] ?? 0;
    name = json['name'] ?? '';
    outputPrice = json['output_price'] ?? '';
    releasedAt = json['released_at'] ?? '';
    supportFunctionCall = json['support_function_call'] ?? false;
    supportThinking = json['support_thinking'] ?? false;
    supportVisualRecognition = json['support_visual_recognition'] ?? false;
    value = json['value'] ?? '';
    providerId = json['provider_id'] ?? 0;
  }

  Model copyWith({
    int? id,
    String? inputPrice,
    int? maxToken,
    String? name,
    String? outputPrice,
    String? releasedAt,
    bool? supportFunctionCall,
    bool? supportThinking,
    bool? supportVisualRecognition,
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
