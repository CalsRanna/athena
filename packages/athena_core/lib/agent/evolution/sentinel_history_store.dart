import 'dart:convert';
import 'dart:io';
import 'package:athena_core/storage/id_generator.dart';
import 'package:athena_core/storage/file_lock.dart';

import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:path/path.dart' as p;

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
///   by-id/{sentinel_id}/history/{uuidv7}.json         # 当前布局
///   {encoded_name}/history/{millis}_{rand}.json         # 旧布局（只读）
/// ```
///
/// 按 **id** 归档：演进可以改名，按名字归档时改名前的快照落在旧名目录，
/// 之后用新名字回滚会找不到，改名这一步无法撤销；反过来，别的角色日后
/// 用了这个旧名字，又会「继承」不属于它的快照，回滚会把别人的提示词
/// 恢复到它身上。旧布局的快照继续可读：每条快照都存着完整的角色 JSON
/// （含 id），按 id 认领，不看目录名。`by-id/` 下是角色 UUID 目录，而旧布局
/// 的名字目录下直接就是 `history/`，两者不会混淆。
///
/// 每个快照文件包含完整的 sentinel 旧态 + 变更原因 + 时间。
/// [homeDir] 可覆盖 `.athena` 根目录（移动端沙盒由装配层传入，与
/// ExperienceRepository 约定一致）。
class SentinelHistoryStore {
  SentinelHistoryStore({String? homeDir}) : _homeDir = homeDir;

  final String? _homeDir;

  String get _basePath {
    final home =
        _homeDir ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
    return '$home/.athena/sentinels';
  }

  static const _byIdDir = 'by-id';

  String _historyDirOf(String sentinelId) =>
      '$_basePath/$_byIdDir/$sentinelId/history';

  Directory _ensureDir(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// 写入一条快照，返回快照 id（文件名不含扩展名）。
  ///
  /// [entity] 是变更前的 sentinel 旧态（必须已落库、带 id）；[reason]
  /// 说明本次变更原因。
  Future<String> save(SentinelEntity entity, {String reason = ''}) async {
    final sentinelId = entity.id;
    if (sentinelId == null) {
      throw ArgumentError('Cannot snapshot a sentinel without an id.');
    }
    final historyDir = _ensureDir(_historyDirOf(sentinelId));
    final id = const IdGenerator().next();
    final json = {
      'snapshot_id': id,
      'saved_at': DateTime.now().toIso8601String(),
      'reason': reason,
      'sentinel': entity.toJson(),
    };
    final target = File('${historyDir.path}/$id.json');
    await atomicWriteString(
      target,
      const JsonEncoder.withIndent('  ').convert(json),
    );
    return id;
  }

  /// 列出 [sentinel] 的全部快照（含旧布局里属于它的），按时间倒序。
  /// 目录缺失 / 文件损坏跳过。
  Future<List<SentinelSnapshotMeta>> list(SentinelEntity sentinel) async {
    final metas = <SentinelSnapshotMeta>[];
    for (final file in await _snapshotFiles(sentinel)) {
      final json = await _readSnapshot(file);
      if (json == null) continue;
      try {
        metas.add(
          SentinelSnapshotMeta(
            id: json['snapshot_id'] as String,
            savedAt: DateTime.parse(json['saved_at'] as String),
            reason: (json['reason'] as String?) ?? '',
          ),
        );
      } catch (_) {
        // 跳过损坏文件
      }
    }
    metas.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return metas;
  }

  /// 读取 [sentinel] 的指定快照中的旧态；不存在、损坏或不属于它时返回 null。
  Future<SentinelEntity?> load(
    SentinelEntity sentinel,
    String snapshotId,
  ) async {
    // 快照 id 来自模型参数，直接拼进路径前必须是单个文件名段
    if (!_validSnapshotId.hasMatch(snapshotId)) return null;
    for (final file in await _snapshotFiles(sentinel)) {
      if (p.basenameWithoutExtension(file.path) != snapshotId) continue;
      final json = await _readSnapshot(file);
      if (json == null) return null;
      try {
        return SentinelEntity.fromJson(
          json['sentinel'] as Map<String, dynamic>,
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static final _validSnapshotId = RegExp(r'^[A-Za-z0-9_-]+$');

  /// [sentinel] 名下的快照文件：`by-id/{id}/history` 全部，加上旧布局
  /// 各名字目录里 `sentinel.id` 与它相同的那些。
  Future<List<File>> _snapshotFiles(SentinelEntity sentinel) async {
    final sentinelId = sentinel.id;
    if (sentinelId == null) return const [];
    final files = <File>[];
    final current = Directory(_historyDirOf(sentinelId));
    if (await current.exists()) {
      await for (final f in current.list()) {
        if (f is File && f.path.endsWith('.json')) files.add(f);
      }
    }
    final base = Directory(_basePath);
    if (!await base.exists()) return files;
    await for (final dir in base.list()) {
      if (dir is! Directory || p.basename(dir.path) == _byIdDir) continue;
      final legacy = Directory(p.join(dir.path, 'history'));
      if (!await legacy.exists()) continue;
      await for (final f in legacy.list()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        final json = await _readSnapshot(f);
        final owner = json?['sentinel'];
        if (owner is Map && owner['id'] == sentinelId) files.add(f);
      }
    }
    return files;
  }

  static Future<Map<String, dynamic>?> _readSnapshot(File file) async {
    try {
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, dynamic> ? json : null;
    } catch (_) {
      return null;
    }
  }
}
