/// 一条经验记录：Agent 从交互中学到的可复用的教训或洞察。
///
/// Unlike other entities (ChatEntity, MessageEntity, etc.) which are stored in
/// SQLite via Laconic ORM, ExperienceEntity is persisted as JSON files on disk
/// (one file per experience). This explains the structural differences:
/// - `id` is a String (filename without extension) rather than int?
/// - `tags` is `List<String>` rather than a comma-separated String
/// - `createdAt` is serialized as ISO 8601 string rather than millisecond timestamp
/// - No `copyWith()` method (experiences are rewritten atomically)
///
/// 生命周期字段（`status` / `userVerdict` 等）为后续版本新增：旧 JSON 文件
/// 没有这些键，`fromJson` 必须容忍缺省（文件式存储天然免迁移）。
class ExperienceEntity {
  /// 经验状态："active"（默认，正常可检索）| "archived"（已归档，
  /// 默认不再被检索，保留作反例）
  static const String statusActive = 'active';
  static const String statusArchived = 'archived';

  /// 用户对经验的验证结论："none"（无结论）| "confirmed"（用户明确认可）
  /// | "refuted"（用户明确证伪）。信号必须来自用户，而非 Agent 自评。
  static const String verdictNone = 'none';
  static const String verdictConfirmed = 'confirmed';
  static const String verdictRefuted = 'refuted';

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

  /// 经验来源："auto" / "manual" / "reflection" / "evolution"
  final String source;

  /// 作用域："self"（仅当前 Sentinel 可见）| "shared"（所有 Sentinel 可见）
  final String scope;

  /// 所属 Sentinel 的唯一 ID。shared 经验此字段为 "shared"
  final String sentinelId;

  /// 经验状态，见 [statusActive] / [statusArchived]
  final String status;

  /// 用户验证结论，见 [verdictNone] / [verdictConfirmed] / [verdictRefuted]
  final String userVerdict;

  /// 最近一次用户验证的时间（无验证时为 null）
  final DateTime? lastVerdictAt;

  /// 最近一次用户验证的备注（无验证时为 null）
  final String? lastVerdictNote;

  /// 最近更新时间（创建后未修改过则为 null）
  final DateTime? updatedAt;

  const ExperienceEntity({
    required this.id,
    required this.createdAt,
    required this.lesson,
    this.context = '',
    this.tags = const [],
    this.source = 'auto',
    this.scope = 'self',
    required this.sentinelId,
    this.status = statusActive,
    this.userVerdict = verdictNone,
    this.lastVerdictAt,
    this.lastVerdictNote,
    this.updatedAt,
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
        'status': status,
        'user_verdict': userVerdict,
        'last_verdict_at': lastVerdictAt?.toIso8601String(),
        'last_verdict_note': lastVerdictNote,
        'updated_at': updatedAt?.toIso8601String(),
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
      status: (json['status'] as String?) ?? statusActive,
      userVerdict: (json['user_verdict'] as String?) ?? verdictNone,
      lastVerdictAt: json['last_verdict_at'] != null
          ? DateTime.parse(json['last_verdict_at'] as String)
          : null,
      lastVerdictNote: json['last_verdict_note'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
