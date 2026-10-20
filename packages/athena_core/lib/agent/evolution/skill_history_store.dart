import 'dart:convert';
import 'dart:io';

import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/id_generator.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:path/path.dart' as p;

/// 一条技能快照的元信息（id / 时间 / 原因），供 `skill_revert` 展示可回滚点。
class SkillSnapshotMeta {
  final String id;
  final DateTime savedAt;
  final String reason;

  const SkillSnapshotMeta({
    required this.id,
    required this.savedAt,
    required this.reason,
  });
}

/// 技能变更历史存储（文件系统）。
///
/// 与 `SentinelHistoryStore` 同一套思路，但更快照的单位不同：技能是文件系统
/// 上的目录，快照存的是**整份 SKILL.md 原文**（含 front matter）而不是结构化
/// 字段——技能目录里还可能有 references/、脚本等资源文件，而那些不是
/// `skill_evolve` 写的（它只写 SKILL.md），回滚一个正文不该连带改写它们。
///
/// 存储结构：
/// ```
/// $HOME/.athena/skills/{skill_name}/history/{uuidv7}.json
/// ```
///
/// 按**技能名**归档而不是按目录的绝对路径：技能名就是它的唯一标识
/// （`SkillLoader.isValidSkillName` 保证是单个文件名段，另有路径校验兜底），
/// GUI 与 TUI 指向同一份用户级目录，名字不会因为 homeDir 不同而错位。
///
/// [homeDir] 可覆盖 `.athena` 根目录（移动端沙盒由装配层传入，与
/// ExperienceRepository / SentinelHistoryStore 约定一致）。
class SkillHistoryStore {
  SkillHistoryStore({String? homeDir}) : _homeDir = homeDir;

  final String? _homeDir;

  /// 每个技能保留的快照条数上限。
  ///
  /// 快照含完整 SKILL.md 原文，且没有任何其他回收路径（`StorageMaintenance`
  /// 明确不管技能与角色）。演进是偶发动作，50 条足够覆盖「改坏后想退几步」，
  /// 又不至于让一个反复微调的技能无限膨胀。
  static const int maxSnapshotsPerSkill = 50;

  String get _basePath {
    final home =
        _homeDir ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
    return '$home/.athena/skills';
  }

  String _historyDirOf(String skillName) => '$_basePath/$skillName/history';

  /// 写入一条快照，返回快照 id（文件名不含扩展名）。
  ///
  /// [content] 是变更前的 SKILL.md 全文。[reason] 说明本次变更原因。
  /// 超出 [maxSnapshotsPerSkill] 时删掉最旧的几条。
  Future<String> save(
    String skillName,
    String content, {
    String reason = '',
  }) async {
    final historyDir = Directory(_historyDirOf(skillName));
    await historyDir.create(recursive: true);
    final id = const IdGenerator().next();
    final json = {
      'snapshot_id': id,
      'saved_at': DateTime.now().toIso8601String(),
      'reason': reason,
      'content': content,
    };
    await atomicWriteString(
      File(p.join(historyDir.path, '$id.json')),
      const JsonEncoder.withIndent('  ').convert(json),
    );
    await _prune(skillName);
    return id;
  }

  /// 列出 [skillName] 的全部快照，按时间倒序。
  Future<List<SkillSnapshotMeta>> list(String skillName) async {
    final metas = <SkillSnapshotMeta>[];
    for (final file in await _snapshotFiles(skillName)) {
      final json = await _readSnapshot(file);
      if (json == null) continue;
      try {
        metas.add(
          SkillSnapshotMeta(
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

  /// 读取快照里的 SKILL.md 原文；不存在或损坏返回 null。
  Future<String?> load(String skillName, String snapshotId) async {
    // 快照 id 来自模型参数，直接拼进路径前必须是单个文件名段
    if (!_validSnapshotId.hasMatch(snapshotId)) return null;
    for (final file in await _snapshotFiles(skillName)) {
      if (p.basenameWithoutExtension(file.path) != snapshotId) continue;
      final json = await _readSnapshot(file);
      final content = json?['content'];
      return content is String ? content : null;
    }
    return null;
  }

  /// 删除某个技能的全部快照（随技能本身一起删除）。
  Future<void> deleteAllFor(String skillName) async {
    final dir = Directory(_historyDirOf(skillName));
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (e) {
        LoggerUtil.w('Failed to delete skill history ${dir.path}: $e');
      }
    }
  }

  static final _validSnapshotId = RegExp(r'^[A-Za-z0-9_-]+$');

  Future<List<File>> _snapshotFiles(String skillName) async {
    final dir = Directory(_historyDirOf(skillName));
    if (!await dir.exists()) return const [];
    final files = <File>[];
    await for (final entry in dir.list()) {
      if (entry is File && entry.path.endsWith('.json')) files.add(entry);
    }
    return files;
  }

  /// 超出上限时删最旧的。删除失败只记日志：留着多余快照不影响正确性。
  Future<void> _prune(String skillName) async {
    final files = await _snapshotFiles(skillName);
    if (files.length <= maxSnapshotsPerSkill) return;
    final byTime = <(File, DateTime)>[];
    for (final file in files) {
      try {
        byTime.add((file, await file.lastModified()));
      } catch (_) {
        // 读不到修改时间就跳过，下轮再清
      }
    }
    byTime.sort((a, b) => b.$2.compareTo(a.$2));
    for (final (file, _) in byTime.skip(maxSnapshotsPerSkill)) {
      try {
        await file.delete();
      } catch (e) {
        LoggerUtil.w('Failed to prune skill snapshot ${file.path}: $e');
      }
    }
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
