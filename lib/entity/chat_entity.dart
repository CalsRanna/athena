import 'package:athena/extension/json_map_extension.dart';

class ChatEntity {
  final int? id;
  final String title;
  final int modelId;
  final int sentinelId;
  final double temperature;
  final int context;
  final bool enableSearch;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatEntity({
    this.id,
    required this.title,
    required this.modelId,
    required this.sentinelId,
    this.temperature = 1.0,
    this.context = 0,
    this.enableSearch = false,
    this.pinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatEntity.fromJson(Map<String, dynamic> json) {
    return ChatEntity(
      id: json.getIntOrNull('id'),
      title: json.getString('title'),
      modelId: json.getInt('model_id'),
      sentinelId: json.getInt('sentinel_id'),
      temperature: json.getDouble('temperature', defaultValue: 1.0),
      context: json.getInt('context'),
      enableSearch: json.getBool('enable_search'),
      pinned: json.getBool('pinned'),
      createdAt: json.getDateTime('created_at'),
      updatedAt: json.getDateTime('updated_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'model_id': modelId,
      'sentinel_id': sentinelId,
      'temperature': temperature,
      'context': context,
      'enable_search': enableSearch ? 1 : 0,
      'pinned': pinned ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  ChatEntity copyWith({
    int? id,
    String? title,
    int? modelId,
    int? sentinelId,
    double? temperature,
    int? context,
    bool? enableSearch,
    bool? pinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      modelId: modelId ?? this.modelId,
      sentinelId: sentinelId ?? this.sentinelId,
      temperature: temperature ?? this.temperature,
      context: context ?? this.context,
      enableSearch: enableSearch ?? this.enableSearch,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
