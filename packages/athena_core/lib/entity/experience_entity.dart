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
/// 生命周期字段为后续版本新增：旧 JSON 文件没有 `status` 时，`fromJson`
/// 必须容忍缺省（文件式存储天然免迁移）。
class ExperienceEntity {
  /// 经验状态："active"（默认，正常可检索）| "archived"（已归档，
  /// 默认不再被检索，保留作反例）
  static const String statusActive = 'active';
  static const String statusArchived = 'archived';

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
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory ExperienceEntity.fromJson(Map<String, dynamic> json) {
    // 旧版本把用户证伪记录成 user_verdict=refuted，但仍保持 active，导致
    // 已证伪经验继续参与检索。新生命周期只保留 active/archived；读取旧文件
    // 时把 refuted 直接视为 archived，后续任意更新都会按新格式重写文件。
    final legacyRefuted = json['user_verdict'] == 'refuted';
    return ExperienceEntity(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lesson: json['lesson'] as String,
      context: (json['context'] as String?) ?? '',
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      source: (json['source'] as String?) ?? 'auto',
      scope: (json['scope'] as String?) ?? 'self',
      sentinelId: (json['sentinel_id'] as String?) ?? 'shared',
      status: legacyRefuted
          ? statusArchived
          : (json['status'] as String?) ?? statusActive,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
