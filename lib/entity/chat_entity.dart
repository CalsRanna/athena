import 'package:athena/extension/json_map_extension.dart';

class ChatEntity {
  final int? id;
  final String title;
  final int modelId;
  final int sentinelId;
  final double temperature;
  final int context;
  final bool pinned;
  /// 本会话累计消耗的 token 总量（跨重启持久化）。
  /// 由 AgentStreamDelegate 在每次推理调用返回 usage 时累加落库。
  final int tokenTotal;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatEntity({
    this.id,
    required this.title,
    required this.modelId,
    required this.sentinelId,
    this.temperature = 1.0,
    this.context = 0,
    this.pinned = false,
    this.tokenTotal = 0,
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
      pinned: json.getBool('pinned'),
      tokenTotal: json.getInt('token_total', defaultValue: 0),
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
      'pinned': pinned ? 1 : 0,
      'token_total': tokenTotal,
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
    bool? pinned,
    int? tokenTotal,
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
      pinned: pinned ?? this.pinned,
      tokenTotal: tokenTotal ?? this.tokenTotal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}