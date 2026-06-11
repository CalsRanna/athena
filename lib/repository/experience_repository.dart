import 'dart:convert';
import 'dart:io';

/// 一条经验记录：Agent 从交互中学到的可复用的教训或洞察。
class ExperienceEntity {
  final String id; // 文件名（不含扩展名），作为唯一标识
  final DateTime createdAt;
  final String lesson; // 经验正文
  final String context; // 触发该经验的上下文简述
  final List<String> tags; // 标签，用于检索
  final String source; // 经验来源："auto" / "manual" / "reflection"

  const ExperienceEntity({
    required this.id,
    required this.createdAt,
    required this.lesson,
    this.context = '',
    this.tags = const [],
    this.source = 'auto',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'lesson': lesson,
        'context': context,
        'tags': tags,
        'source': source,
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
    );
  }
}

/// 文件系统持久化的经验仓库。
///
/// 存储位置：`$HOME/.athena/experiences/`，每个经验一个 `.json` 文件。
/// 文件名格式：`{id}.json`，其中 id 为时间戳 + 随机后缀。
class ExperienceRepository {
  String get _basePath {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
    return '$home/.athena/experiences';
  }

  Directory get _directory {
    final dir = Directory(_basePath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// 保存一条新经验。
  Future<ExperienceEntity> save({
    required String lesson,
    String context = '',
    List<String> tags = const [],
    String source = 'auto',
  }) async {
    final now = DateTime.now();
    final id =
        '${now.millisecondsSinceEpoch}_${_randomSuffix(6)}';
    final entity = ExperienceEntity(
      id: id,
      createdAt: now,
      lesson: lesson,
      context: context,
      tags: tags,
      source: source,
    );
    final file = File('$_basePath/$id.json');
    await file.writeAsString(_prettyJson(entity.toJson()));
    return entity;
  }

  /// 列出所有经验，按时间倒序。
  List<ExperienceEntity> listAll() {
    final dir = _directory;
    final entities = <ExperienceEntity>[];
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

  /// 按关键词搜索经验（匹配 lesson、context、tags）。
  List<ExperienceEntity> search(String query) {
    final all = listAll();
    if (query.trim().isEmpty) return all;
    final lower = query.toLowerCase();
    return all.where((e) {
      if (e.lesson.toLowerCase().contains(lower)) return true;
      if (e.context.toLowerCase().contains(lower)) return true;
      if (e.tags.any((t) => t.toLowerCase().contains(lower))) return true;
      return false;
    }).toList();
  }

  /// 按 ID 删除单条经验。
  Future<bool> delete(String id) async {
    final file = File('$_basePath/$id.json');
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  /// 清空所有经验。
  Future<void> clearAll() async {
    final dir = _directory;
    for (final f in dir.listSync()) {
      if (f is File && f.path.endsWith('.json')) {
        await f.delete();
      }
    }
  }

  /// 经验总数。
  int get count {
    final dir = Directory(_basePath);
    if (!dir.existsSync()) return 0;
    return dir
        .listSync()
        .where((f) => f is File && f.path.endsWith('.json'))
        .length;
  }

  static String _randomSuffix(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = List.generate(length, (_) => chars[DateTime.now().microsecond % chars.length]);
    return r.join();
  }

  static String _prettyJson(Map<String, dynamic> json) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }
}
