import 'package:athena/extension/json_map_extension.dart';

class TRPGGameEntity {
  final int? id;
  final int modelId;
  final DateTime createdAt;
  final DateTime updatedAt;

  TRPGGameEntity({
    this.id,
    required this.modelId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TRPGGameEntity.fromJson(Map<String, dynamic> json) {
    return TRPGGameEntity(
      id: json.getIntOrNull('id'),
      modelId: json.getInt('model_id'),
      createdAt: json.getDateTime('created_at'),
      updatedAt: json.getDateTime('updated_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'model_id': modelId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  TRPGGameEntity copyWith({
    int? id,
    int? modelId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TRPGGameEntity(
      id: id ?? this.id,
      modelId: modelId ?? this.modelId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
