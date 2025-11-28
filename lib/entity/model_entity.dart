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
      id: json['id'] as int?,
      name: json['name'] as String,
      modelId: json['model_id'] as String,
      providerId: json['provider_id'] as int,
      contextWindow: json['context_window'] as String? ?? '',
      inputPrice: json['input_price'] as String? ?? '',
      outputPrice: json['output_price'] as String? ?? '',
      releasedAt: json['released_at'] as String? ?? '',
      reasoning: (json['reasoning'] as bool?) ?? false,
      vision: (json['vision'] as bool?) ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
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
      'reasoning': reasoning,
      'vision': vision,
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
