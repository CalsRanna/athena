/// 一条经验记录：Agent 从交互中学到的可复用的教训或洞察。
///
/// Unlike other entities (ChatEntity, MessageEntity, etc.) which are stored in
/// SQLite via Laconic ORM, ExperienceEntity is persisted as JSON files on disk
/// (one file per experience). This explains the structural differences:
/// - `id` is a String (filename without extension) rather than int?
/// - `tags` is `List<String>` rather than a comma-separated String
/// - `createdAt` is serialized as ISO 8601 string rather than millisecond timestamp
/// - No `copyWith()` method (experiences are rewritten atomically)
class ExperienceEntity {
  /// 文件名（不含扩展名），作为唯一标识
  final String id;

  /// 创建时间
  final DateTime createdAt;

  /// 经验正文：具体、可操作的教训或洞察
  final String lesson;

  /// 触发该经验的上下文简述
  final String context;

  /// 检索标签
  final List<String> tags;

  /// 经验来源："auto" / "manual" / "reflection"
  final String source;

  /// 作用域："self"（仅当前 Sentinel 可见）| "shared"（所有 Sentinel 可见）
  final String scope;

  /// 所属 Sentinel 的唯一 ID。shared 经验此字段为 "shared"
  final String sentinelId;

  const ExperienceEntity({
    required this.id,
    required this.createdAt,
    required this.lesson,
    this.context = '',
    this.tags = const [],
    this.source = 'auto',
    this.scope = 'self',
    required this.sentinelId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'lesson': lesson,
        'context': context,
        'tags': tags,
        'source': source,
        'scope': scope,
        'sentinel_id': sentinelId,
      };

  factory ExperienceEntity.fromJson(Map<String, dynamic> json) {
    return ExperienceEntity(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lesson: json['lesson'] as String,
      context: (json['context'] as String?) ?? '',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      source: (json['source'] as String?) ?? 'auto',
      scope: (json['scope'] as String?) ?? 'self',
      sentinelId: (json['sentinel_id'] as String?) ?? 'shared',
    );
  }
}
