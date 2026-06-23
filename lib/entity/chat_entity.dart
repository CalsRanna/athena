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
  final int tokenTotal;
  /// 最近一次推理的 prompt token 数（覆盖写，用于上下文窗口占用率）。
  final int contextTokens;
  /// 最近一次推理的缓存命中 token 数（覆盖写，用于缓存命中率）。
  final int cachedTokens;
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
    this.contextTokens = 0,
    this.cachedTokens = 0,
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
      contextTokens: json.getInt('context_tokens', defaultValue: 0),
      cachedTokens: json.getInt('cached_tokens', defaultValue: 0),
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
      'context_tokens': contextTokens,
      'cached_tokens': cachedTokens,
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
    int? contextTokens,
    int? cachedTokens,
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
      contextTokens: contextTokens ?? this.contextTokens,
      cachedTokens: cachedTokens ?? this.cachedTokens,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}