class ModelEntity {
  final int? id;
  final String name;
  final String modelId;
  final int providerId;
  final int contextWindow;
  final double inputPrice;
  final double outputPrice;
  final DateTime? releasedAt;
  final bool reasoning;
  final bool vision;
  final DateTime createdAt;

  ModelEntity({
    this.id,
    required this.name,
    required this.modelId,
    required this.providerId,
    this.contextWindow = 0,
    this.inputPrice = 0.0,
    this.outputPrice = 0.0,
    this.releasedAt,
    this.reasoning = false,
    this.vision = false,
    required this.createdAt,
  });

  factory ModelEntity.fromJson(Map<String, dynamic> json) {
    return ModelEntity(
      id: json['id'] as int?,
      name: json['name'] as String,
      modelId: json['model_id'] as String,
      providerId: json['provider_id'] as int,
      contextWindow: json['context_window'] as int? ?? 0,
      inputPrice: (json['input_price'] as num?)?.toDouble() ?? 0.0,
      outputPrice: (json['output_price'] as num?)?.toDouble() ?? 0.0,
      releasedAt: json['released_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['released_at'] as int)
          : null,
      reasoning: (json['reasoning'] as int?) == 1,
      vision: (json['vision'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
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
      if (releasedAt != null) 'released_at': releasedAt!.millisecondsSinceEpoch,
      'reasoning': reasoning ? 1 : 0,
      'vision': vision ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  ModelEntity copyWith({
    int? id,
    String? name,
    String? modelId,
    int? providerId,
    int? contextWindow,
    double? inputPrice,
    double? outputPrice,
    DateTime? releasedAt,
    bool? reasoning,
    bool? vision,
    DateTime? createdAt,
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
    );
  }
}
