import 'package:athena_core/extension/json_map_extension.dart';

class ChatEntity {
  /// `sentinel_id == 0` 表示用户显式选择不使用 Sentinel。
  ///
  /// 持久化 Sentinel 使用正整数 ID，因此 0 可作为无需额外实体的保留值。
  static const int noSentinelId = 0;

  final int? id;
  final String title;
  final int modelId;
  final int sentinelId;
  final double temperature;

  /// OpenAI 官方推理强度值（low/medium/high/none/minimal/xhigh）。
  /// null = 不传参，使用模型默认推理强度。
  final String? reasoningEffort;

  /// 上下文保留策略。0 = 无历史（每次独立请求），-1 = 自动管理（compact）。
  final int retention;
  final bool pinned;

  /// 最近一次推理的 prompt token 数（覆盖写，用于上下文窗口占用率）。
  final int contextTokens;

  /// 最近一次推理的缓存命中 token 数（覆盖写，用于缓存命中率）。
  final int cachedTokens;

  /// 本会话可选的工作文件夹（绝对路径）。
  ///
  /// null = 不指定：shell 默认在用户主目录执行、文件工具的相对路径按进程
  /// 当前目录解析（与引入本字段之前的行为一致）。非 null 时，本轮 run 的
  /// shell 默认工作目录与文件工具的相对路径基准都落在该目录。
  ///
  /// 挂在会话上而不是进程上：多对话可同时运行，进程级可变基准会串台。
  final String? workspacePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasSentinel => sentinelId != noSentinelId;

  ChatEntity({
    this.id,
    required this.title,
    required this.modelId,
    required this.sentinelId,
    this.temperature = 1.0,
    this.reasoningEffort,
    this.retention = -1,
    this.pinned = false,
    this.contextTokens = 0,
    this.cachedTokens = 0,
    this.workspacePath,
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
      reasoningEffort: json.getStringOrNull('reasoning_effort'),
      retention: json.getInt('retention', defaultValue: -1),
      pinned: json.getBool('pinned'),
      contextTokens: json.getInt('context_tokens', defaultValue: 0),
      cachedTokens: json.getInt('cached_tokens', defaultValue: 0),
      workspacePath: json.getStringOrNull('workspace_path'),
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
      if (reasoningEffort != null) 'reasoning_effort': reasoningEffort,
      'retention': retention,
      'pinned': pinned ? 1 : 0,
      'context_tokens': contextTokens,
      'cached_tokens': cachedTokens,
      // 无条件写出（含 null）：updateChat 是「键存在才更新该列」，
      // 条件写法会让「清空工作文件夹」落不了库。
      'workspace_path': workspacePath,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// 哨兵:区分「未传参(保留原值)」与「显式置 null」。
  static const _unset = Object();

  ChatEntity copyWith({
    int? id,
    String? title,
    int? modelId,
    int? sentinelId,
    double? temperature,
    Object? reasoningEffort = _unset,
    int? retention,
    Object? workspacePath = _unset,
    bool? pinned,
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
      reasoningEffort: identical(reasoningEffort, _unset)
          ? this.reasoningEffort
          : reasoningEffort as String?,
      retention: retention ?? this.retention,
      workspacePath: identical(workspacePath, _unset)
          ? this.workspacePath
          : workspacePath as String?,
      pinned: pinned ?? this.pinned,
      contextTokens: contextTokens ?? this.contextTokens,
      cachedTokens: cachedTokens ?? this.cachedTokens,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
