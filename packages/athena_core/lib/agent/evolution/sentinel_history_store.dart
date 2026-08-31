import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:athena_core/entity/sentinel_entity.dart';

/// 一条快照的元信息（id / 时间 / 原因），供 `sentinel_revert` 展示可回滚点。
class SentinelSnapshotMeta {
  final String id;
  final DateTime savedAt;
  final String reason;

  const SentinelSnapshotMeta({
    required this.id,
    required this.savedAt,
    required this.reason,
  });
}

/// Sentinel 变更历史存储（文件系统）。
///
/// `sentinel_evolve` / `sentinel_revert` 在修改前各写一条快照，
/// 使角色演进可追溯、可回滚。
///
/// 存储结构：
/// ```
/// $HOME/.athena/sentinels/
///   {encoded_name}/          # Uri.encodeComponent(sentinel.name)
///     history/{millis}_{rand}.json
/// ```
///
/// 每个快照文件包含完整的 sentinel 旧态 + 变更原因 + 时间。
/// [homeDir] 可覆盖 `.athena` 根目录（移动端沙盒由装配层传入，与
/// ExperienceRepository 约定一致）。
class SentinelHistoryStore {
  SentinelHistoryStore({String? homeDir}) : _homeDir = homeDir;

  final String? _homeDir;

  String get _basePath {
    final home = _homeDir ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
    return '$home/.athena/sentinels';
  }

  String _dirOf(String name) => '$_basePath/${Uri.encodeComponent(name)}';

  Directory _ensureDir(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// 写入一条快照，返回快照 id（文件名不含扩展名）。
  ///
  /// [entity] 是变更前的 sentinel 旧态；[reason] 说明本次变更原因。
  Future<String> save(
    String name,
    SentinelEntity entity, {
    String reason = '',
  }) async {
    final historyDir = _ensureDir('${_dirOf(name)}/history');
    final id = await _uniqueId(historyDir);
    final json = {
      'snapshot_id': id,
      'saved_at': DateTime.now().toIso8601String(),
      'reason': reason,
      'sentinel': entity.toJson(),
    };
    await File('${historyDir.path}/$id.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    return id;
  }

  /// 列出某 sentinel 的全部快照，按时间倒序。目录缺失/文件损坏跳过。
  Future<List<SentinelSnapshotMeta>> list(String name) async {
    final dir = Directory('${_dirOf(name)}/history');
    final metas = <SentinelSnapshotMeta>[];
    if (!await dir.exists()) return metas;
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final json =
            jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        metas.add(SentinelSnapshotMeta(
          id: json['snapshot_id'] as String,
          savedAt: DateTime.parse(json['saved_at'] as String),
          reason: (json['reason'] as String?) ?? '',
        ));
      } catch (_) {
        // 跳过损坏文件
      }
    }
    metas.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return metas;
  }

  /// 读取指定快照中的 sentinel 旧态；不存在或损坏返回 null。
  Future<SentinelEntity?> load(String name, String snapshotId) async {
    final file = File('${_dirOf(name)}/history/$snapshotId.json');
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return SentinelEntity.fromJson(json['sentinel'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 生成时间戳 + 随机后缀的快照 id，并确保文件不存在。
  static Future<String> _uniqueId(Directory dir) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final id = '${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix(6)}';
      if (!await File('${dir.path}/$id.json').exists()) return id;
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
}
