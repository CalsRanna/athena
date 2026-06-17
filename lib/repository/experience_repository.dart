import 'dart:convert';
import 'dart:io';

/// 一条经验记录：Agent 从交互中学到的可复用的教训或洞察。
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

/// 文件系统持久化的经验仓库。
///
/// 存储结构：
/// ```
/// $HOME/.athena/experiences/
///   shared/            # scope="shared" 的经验（所有 Sentinel 可见）
///   {sentinel_id}/     # 某 Sentinel 的私有经验（scope="self"）
/// ```
///
/// 每个经验一个 `.json` 文件。文件名格式：`{timestamp}_{randomSuffix}.json`。
class ExperienceRepository {
  String get _basePath {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
    return '$home/.athena/experiences';
  }

  /// shared 经验目录
  String get _sharedPath => '$_basePath/shared';

  Directory _ensureDir(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  // === 写入 ===

  /// 保存一条经验。
  ///
  /// 若 [scope] 为 "shared"，写入 shared/ 目录，[sentinelId] 强制设为 "shared"。
  /// 若 [scope] 为 "self"，写入 {sentinelId}/ 目录。
  Future<ExperienceEntity> save({
    required String lesson,
    String context = '',
    List<String> tags = const [],
    String source = 'auto',
    String scope = 'self',
    required String sentinelId,
  }) async {
    final now = DateTime.now();
    final id = '${now.millisecondsSinceEpoch}_${_randomSuffix(6)}';
    final isShared = scope == 'shared';
    final entity = ExperienceEntity(
      id: id,
      createdAt: now,
      lesson: lesson,
      context: context,
      tags: tags,
      source: source,
      scope: isShared ? 'shared' : 'self',
      sentinelId: isShared ? 'shared' : sentinelId,
    );

    final dir = isShared ? _sharedPath : '$_basePath/$sentinelId';
    _ensureDir(dir);
    final file = File('$dir/$id.json');
    await file.writeAsString(_prettyJson(entity.toJson()));
    return entity;
  }

  // === 检索 ===

  /// 列出指定 Sentinel 的私有经验（仅 scope="self"），按时间倒序。
  List<ExperienceEntity> _listPrivate(String sentinelId) {
    final dir = Directory('$_basePath/$sentinelId');
    return _listDir(dir);
  }

  /// 列出所有 shared 经验，按时间倒序。
  List<ExperienceEntity> listShared() {
    final dir = Directory(_sharedPath);
    return _listDir(dir);
  }

  /// 获取当前 Sentinel 的所有私有经验 + 所有 shared 经验。
  List<ExperienceEntity> listForSentinel(String sentinelId) {
    final results = <ExperienceEntity>[];
    results.addAll(_listPrivate(sentinelId));
    results.addAll(listShared());
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  /// 在当前 Sentinel 私有经验 + shared 经验中搜索。
  List<ExperienceEntity> searchForSentinel(String sentinelId, String query) {
    final all = listForSentinel(sentinelId);
    if (query.trim().isEmpty) return all;
    final lower = query.toLowerCase();
    return all.where((e) {
      if (e.lesson.toLowerCase().contains(lower)) return true;
      if (e.context.toLowerCase().contains(lower)) return true;
      if (e.tags.any((t) => t.toLowerCase().contains(lower))) return true;
      return false;
    }).toList();
  }

  /// 获取指定 Sentinel 的私有经验（不含 shared）。
  List<ExperienceEntity> listPrivate(String sentinelId) {
    return _listPrivate(sentinelId);
  }

  /// 在指定 Sentinel 的私有经验中搜索（不含 shared）。
  List<ExperienceEntity> searchPrivate(String sentinelId, String query) {
    final all = listPrivate(sentinelId);
    if (query.trim().isEmpty) return all;
    final lower = query.toLowerCase();
    return all.where((e) {
      if (e.lesson.toLowerCase().contains(lower)) return true;
      if (e.context.toLowerCase().contains(lower)) return true;
      if (e.tags.any((t) => t.toLowerCase().contains(lower))) return true;
      return false;
    }).toList();
  }

  List<ExperienceEntity> _listDir(Directory dir) {
    final entities = <ExperienceEntity>[];
    if (!dir.existsSync()) return entities;
    for (final f in dir.listSync()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        entities.add(ExperienceEntity.fromJson(json));
      } catch (_) {
        // 跳过损坏文件
      }
    }
    entities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entities;
  }

  // === 管理 ===

  /// 按 ID + sentinelId 删除。
  Future<bool> delete(String sentinelId, String id) async {
    // 尝试在私有目录和 shared 目录中查找
    for (final dirPath in ['$_basePath/$sentinelId', _sharedPath]) {
      final file = File('$dirPath/$id.json');
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    }
    return false;
  }

  /// 清空指定 Sentinel 的所有私有经验。
  Future<void> clearPrivate(String sentinelId) async {
    final dir = Directory('$_basePath/$sentinelId');
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  /// 清空所有 shared 经验。
  Future<void> clearShared() async {
    final dir = Directory(_sharedPath);
    if (dir.existsSync()) {
      for (final f in dir.listSync()) {
        if (f is File && f.path.endsWith('.json')) {
          await f.delete();
        }
      }
    }
  }

  /// 经验总数统计。
  Map<String, int> get counts {
    final result = <String, int>{'shared': 0};
    final baseDir = Directory(_basePath);
    if (!baseDir.existsSync()) return result;

    for (final entry in baseDir.listSync()) {
      if (entry is! Directory) continue;
      final name = entry.path.split('/').last;
      final count = _listDir(entry).length;
      if (name == 'shared') {
        result['shared'] = count;
      } else {
        result[name] = count;
      }
    }
    return result;
  }

  // === 工具 ===

  static String _randomSuffix(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = List.generate(
        length, (_) => chars[DateTime.now().microsecond % chars.length]);
    return r.join();
  }

  static String _prettyJson(Map<String, dynamic> json) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }
}
