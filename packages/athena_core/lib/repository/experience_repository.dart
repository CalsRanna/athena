import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:athena_core/entity/experience_entity.dart';

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
///
/// [homeDir] 可覆盖 `.athena` 的根目录（移动端沙盒没有可靠 `$HOME`，
/// 由 GUI 装配层传入 Application Support 目录；桌面端不传，维持 `$HOME`）。
class ExperienceRepository {
  ExperienceRepository({String? homeDir}) : _homeDir = homeDir;

  final String? _homeDir;

  String get _basePath {
    final home =
        _homeDir ??
        Platform.environment['HOME'] ??
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
    final isShared = scope == 'shared';
    final dir = isShared ? _sharedPath : '$_basePath/$sentinelId';
    _ensureDir(dir);
    final id = await _uniqueId(dir);
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

    final file = File('$dir/$id.json');
    await file.writeAsString(_prettyJson(entity.toJson()));
    return entity;
  }

  // === 检索 ===

  /// 列出指定 Sentinel 的私有经验（仅 scope="self"），按时间倒序。
  Future<List<ExperienceEntity>> _listPrivate(
    String sentinelId, {
    bool includeArchived = false,
  }) {
    final dir = Directory('$_basePath/$sentinelId');
    return _filterArchived(_listDir(dir), includeArchived);
  }

  /// 列出所有 shared 经验，按时间倒序。
  Future<List<ExperienceEntity>> listShared({bool includeArchived = false}) {
    final dir = Directory(_sharedPath);
    return _filterArchived(_listDir(dir), includeArchived);
  }

  /// 默认过滤 archived 经验（保留为反例，但不参与常规检索）。
  Future<List<ExperienceEntity>> _filterArchived(
    Future<List<ExperienceEntity>> future,
    bool includeArchived,
  ) async {
    final all = await future;
    if (includeArchived) return all;
    return all
        .where((e) => e.status != ExperienceEntity.statusArchived)
        .toList();
  }

  /// 获取当前 Sentinel 的所有私有经验 + 所有 shared 经验。
  Future<List<ExperienceEntity>> listForSentinel(
    String sentinelId, {
    bool includeArchived = false,
  }) async {
    final results = <ExperienceEntity>[];
    results.addAll(
      await _listPrivate(sentinelId, includeArchived: includeArchived),
    );
    results.addAll(await listShared(includeArchived: includeArchived));
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  /// 在当前 Sentinel 私有经验 + shared 经验中搜索。
  ///
  /// 结果按匹配质量排序（lesson 命中 3 分、tags 命中 2 分、context 命中
  /// 1 分），同分时按时间倒序——相关但旧的条目不会被新条目挤到后面。
  Future<List<ExperienceEntity>> searchForSentinel(
    String sentinelId,
    String query, {
    bool includeArchived = false,
  }) async {
    final all = await listForSentinel(
      sentinelId,
      includeArchived: includeArchived,
    );
    return _rankByScore(all, query);
  }

  /// 获取指定 Sentinel 的私有经验（不含 shared）。
  Future<List<ExperienceEntity>> listPrivate(
    String sentinelId, {
    bool includeArchived = false,
  }) {
    return _listPrivate(sentinelId, includeArchived: includeArchived);
  }

  /// 在指定 Sentinel 的私有经验中搜索（不含 shared），排序规则同
  /// [searchForSentinel]。
  Future<List<ExperienceEntity>> searchPrivate(
    String sentinelId,
    String query, {
    bool includeArchived = false,
  }) async {
    final all = await listPrivate(sentinelId, includeArchived: includeArchived);
    return _rankByScore(all, query);
  }

  /// 按分词后的匹配质量评分排序：匹配字段越多、权重越高的排前面。
  List<ExperienceEntity> _rankByScore(
    List<ExperienceEntity> all,
    String query,
  ) {
    if (query.trim().isEmpty) return all;
    final scored = <(ExperienceEntity, int)>[];
    for (final e in all) {
      final score = matchScore(e, query);
      if (score > 0) scored.add((e, score));
    }
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) return byScore;
      return b.$1.createdAt.compareTo(a.$1.createdAt);
    });
    return scored.map((e) => e.$1).toList();
  }

  /// 匹配评分：lesson token 命中 3 分、tags 命中 2 分、context 命中 1 分。
  ///
  /// 公开供注入侧（MemoryDigest）记录匹配质量，形成可观测性。
  static int matchScore(ExperienceEntity e, String query) {
    final queryTerms = _searchTerms(query);
    if (queryTerms.isEmpty) return 0;

    final lessonTerms = _searchTerms(e.lesson);
    final tagTerms = _searchTerms(e.tags.join(' '));
    final contextTerms = _searchTerms(e.context);
    var score = 0;
    for (final term in queryTerms) {
      if (lessonTerms.contains(term)) score += 3;
      if (tagTerms.contains(term)) score += 2;
      if (contextTerms.contains(term)) score += 1;
    }
    return score;
  }

  /// 英文按词、中文按二元字组切分，并丢弃常见虚词。此前用完整用户消息做
  /// substring，真实长句几乎无法命中短经验；不过直接做所有 token overlap
  /// 又会因 `please/use/这个` 等词召回无关记忆，因此这里保持轻量但偏保守。
  static Set<String> _searchTerms(String value) {
    final terms = <String>{};
    final matches = RegExp(
      r'[a-z0-9]+|[\u3400-\u9fff]+',
      caseSensitive: false,
    ).allMatches(value.toLowerCase());
    for (final match in matches) {
      final token = match.group(0)!;
      final chinese = token.codeUnitAt(0) >= 0x3400;
      if (!chinese) {
        if (token.length >= 2 && !_englishStopTerms.contains(token)) {
          terms.add(token);
        }
        continue;
      }
      if (token.length <= 2) {
        if (!_chineseStopTerms.contains(token)) terms.add(token);
      } else {
        for (var i = 0; i < token.length - 1; i++) {
          final pair = token.substring(i, i + 2);
          if (!_chineseStopTerms.contains(pair)) terms.add(pair);
        }
      }
    }
    return terms;
  }

  static const _englishStopTerms = {
    'a',
    'an',
    'and',
    'are',
    'be',
    'been',
    'being',
    'can',
    'could',
    'did',
    'do',
    'does',
    'for',
    'from',
    'help',
    'i',
    'in',
    'is',
    'it',
    'me',
    'my',
    'of',
    'on',
    'or',
    'our',
    'please',
    'should',
    'that',
    'the',
    'their',
    'these',
    'they',
    'this',
    'those',
    'to',
    'use',
    'using',
    'was',
    'we',
    'were',
    'with',
    'would',
    'you',
    'your',
  };

  static const _chineseStopTerms = {
    '帮我',
    '这个',
    '一下',
    '如何',
    '怎么',
    '是否',
    '可以',
    '需要',
  };

  Future<List<ExperienceEntity>> _listDir(Directory dir) async {
    final entities = <ExperienceEntity>[];
    if (!await dir.exists()) return entities;
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        entities.add(ExperienceEntity.fromJson(json));
      } catch (_) {
        // 跳过损坏文件
      }
    }
    entities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entities;
  }

  // === 更新 ===

  /// 定位经验的 JSON 文件：当前 Sentinel 私有目录与 shared 目录各试一次。
  /// 返回 null 表示未找到。
  File? _locateFile(String sentinelId, String id) {
    for (final dirPath in ['$_basePath/$sentinelId', _sharedPath]) {
      final file = File('$dirPath/$id.json');
      if (file.existsSync()) return file;
    }
    return null;
  }

  /// 读取单个经验文件；文件损坏返回 null（与 [_listDir] 的容错一致）。
  ExperienceEntity? _readFile(File file) {
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return ExperienceEntity.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 更新一条经验：仅覆盖提供的字段（未提供的保持原值）。
  ///
  /// scope 变更时把文件迁移到目标目录（旧文件删除）——修复误写为
  /// shared 的经验无需"删除后重建"。
  /// 返回更新后的实体；未找到或文件损坏返回 null。
  Future<ExperienceEntity?> update({
    required String sentinelId,
    required String id,
    String? lesson,
    String? context,
    List<String>? tags,
    String? scope,
    String? status,
  }) async {
    final file = _locateFile(sentinelId, id);
    if (file == null) return null;
    final original = _readFile(file);
    if (original == null) return null;

    final targetScope = scope ?? original.scope;
    final entity = ExperienceEntity(
      id: original.id,
      createdAt: original.createdAt,
      lesson: (lesson != null && lesson.trim().isNotEmpty)
          ? lesson.trim()
          : original.lesson,
      context: context ?? original.context,
      tags: tags ?? original.tags,
      source: original.source,
      scope: targetScope,
      sentinelId: targetScope == 'shared' ? 'shared' : sentinelId,
      status: status ?? original.status,
      updatedAt: DateTime.now(),
    );

    final targetDir = targetScope == 'shared'
        ? _sharedPath
        : '$_basePath/$sentinelId';
    _ensureDir(targetDir);
    final targetFile = File('$targetDir/${entity.id}.json');
    await targetFile.writeAsString(_prettyJson(entity.toJson()));
    if (file.path != targetFile.path) {
      await file.delete();
    }
    return entity;
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
  Future<Map<String, int>> get counts async {
    final result = <String, int>{'shared': 0};
    final baseDir = Directory(_basePath);
    if (!await baseDir.exists()) return result;

    await for (final entry in baseDir.list()) {
      if (entry is! Directory) continue;
      final name = entry.path.split(RegExp(r'[/\\]')).last;
      final count = (await _listDir(entry)).length;
      if (name == 'shared') {
        result['shared'] = count;
      } else {
        result[name] = count;
      }
    }
    return result;
  }

  // === 工具 ===

  /// 生成时间戳 + 随机后缀的文件名 ID，并确保文件不存在。
  ///
  /// 旧实现用 `DateTime.now().microsecond % chars.length` 生成"随机"后缀，
  /// Windows 时钟粒度下连续保存极易碰撞、互相覆盖；改用 Random 并
  /// 兜底重试（同毫秒连续碰撞时退回到更长后缀）。
  static Future<String> _uniqueId(String dir) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final id = '${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix(6)}';
      if (!await File('$dir/$id.json').exists()) return id;
    }
    return '${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix(12)}';
  }

  static final Random _random = Random();

  static String _randomSuffix(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  static String _prettyJson(Map<String, dynamic> json) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }
}
