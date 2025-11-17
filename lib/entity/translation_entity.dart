class TranslationEntity {
  final int id;
  final String source;
  final String sourceText;
  final String target;
  final String targetText;
  final DateTime createdAt;

  TranslationEntity({
    required this.id,
    required this.source,
    required this.sourceText,
    required this.target,
    required this.targetText,
    required this.createdAt,
  });

  factory TranslationEntity.fromJson(Map<String, dynamic> json) {
    return TranslationEntity(
      id: json['id'] as int,
      source: json['source'] as String,
      sourceText: json['source_text'] as String,
      target: json['target'] as String,
      targetText: json['target_text'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != 0) 'id': id,
      'source': source,
      'source_text': sourceText,
      'target': target,
      'target_text': targetText,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  TranslationEntity copyWith({
    int? id,
    String? source,
    String? sourceText,
    String? target,
    String? targetText,
    DateTime? createdAt,
  }) {
    return TranslationEntity(
      id: id ?? this.id,
      source: source ?? this.source,
      sourceText: sourceText ?? this.sourceText,
      target: target ?? this.target,
      targetText: targetText ?? this.targetText,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
