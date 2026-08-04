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
  Future<List<ExperienceEntity>> _listPrivate(String sentinelId) {
    final dir = Directory('$_basePath/$sentinelId');
    return _listDir(dir);
  }

  /// 列出所有 shared 经验，按时间倒序。
  Future<List<ExperienceEntity>> listShared() {
    final dir = Directory(_sharedPath);
    return _listDir(dir);
  }

  /// 获取当前 Sentinel 的所有私有经验 + 所有 shared 经验。
  Future<List<ExperienceEntity>> listForSentinel(String sentinelId) async {
    final results = <ExperienceEntity>[];
    results.addAll(await _listPrivate(sentinelId));
    results.addAll(await listShared());
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  /// 在当前 Sentinel 私有经验 + shared 经验中搜索。
  Future<List<ExperienceEntity>> searchForSentinel(
      String sentinelId, String query) async {
    final all = await listForSentinel(sentinelId);
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
  Future<List<ExperienceEntity>> listPrivate(String sentinelId) {
    return _listPrivate(sentinelId);
  }

  /// 在指定 Sentinel 的私有经验中搜索（不含 shared）。
  Future<List<ExperienceEntity>> searchPrivate(
      String sentinelId, String query) async {
    final all = await listPrivate(sentinelId);
    if (query.trim().isEmpty) return all;
    final lower = query.toLowerCase();
    return all.where((e) {
      if (e.lesson.toLowerCase().contains(lower)) return true;
      if (e.context.toLowerCase().contains(lower)) return true;
      if (e.tags.any((t) => t.toLowerCase().contains(lower))) return true;
      return false;
    }).toList();
  }

  Future<List<ExperienceEntity>> _listDir(Directory dir) async {
    final entities = <ExperienceEntity>[];
    if (!await dir.exists()) return entities;
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final json =
            jsonDecode(await f.readAsString()) as Map<String, dynamic>;
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
      final id =
          '${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix(6)}';
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
