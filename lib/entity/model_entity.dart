import 'package:athena/extension/json_map_extension.dart';

class ModelEntity {
  final int? id;
  final String name;
  final String modelId;
  final int providerId;
  final String contextWindow;
  final String inputPrice;
  final String outputPrice;
  final String releasedAt;
  final bool reasoning;
  final bool vision;
  final DateTime createdAt;
  final DateTime updatedAt;

  ModelEntity({
    this.id,
    required this.name,
    required this.modelId,
    required this.providerId,
    this.contextWindow = '',
    this.inputPrice = '',
    this.outputPrice = '',
    this.releasedAt = '',
    this.reasoning = false,
    this.vision = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ModelEntity.fromJson(Map<String, dynamic> json) {
    return ModelEntity(
      id: json.getIntOrNull('id'),
      name: json.getString('name'),
      modelId: json.getString('model_id'),
      providerId: json.getInt('provider_id'),
      contextWindow: json.getString('context_window'),
      inputPrice: json.getString('input_price'),
      outputPrice: json.getString('output_price'),
      releasedAt: json.getString('released_at'),
      reasoning: json.getBool('reasoning'),
      vision: json.getBool('vision'),
      createdAt: json.getDateTime('created_at'),
      updatedAt: json.getDateTime('updated_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'model_id': modelId,
      'provider_id': providerId,
      'context_window': contextWindow,
      'input_price': inputPrice,
      'output_price': outputPrice,
      'released_at': releasedAt,
      'reasoning': reasoning ? 1 : 0,
      'vision': vision ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  ModelEntity copyWith({
    int? id,
    String? name,
    String? modelId,
    int? providerId,
    String? contextWindow,
    String? inputPrice,
    String? outputPrice,
    String? releasedAt,
    bool? reasoning,
    bool? vision,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ModelEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      modelId: modelId ?? this.modelId,
      providerId: providerId ?? this.providerId,
      contextWindow: contextWindow ?? this.contextWindow,
      inputPrice: inputPrice ?? this.inputPrice,
      outputPrice: outputPrice ?? this.outputPrice,
      releasedAt: releasedAt ?? this.releasedAt,
      reasoning: reasoning ?? this.reasoning,
      vision: vision ?? this.vision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
