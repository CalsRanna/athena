import 'dart:io';

import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:path/path.dart' as p;

/// 数据目录里可回收文件的分项统计。
class StorageUsage {
  const StorageUsage({
    this.rewindSnapshotBytes = 0,
    this.rewindSnapshotCount = 0,
    this.toolOutputBytes = 0,
    this.toolOutputCount = 0,
  });

  final int rewindSnapshotBytes;
  final int rewindSnapshotCount;
  final int toolOutputBytes;
  final int toolOutputCount;
}

/// 数据目录的统计与清理。
///
/// 只处理派生文件：回退快照与内容寻址的工具输出。会话正文、provider、
/// sentinel、经验与设置不在清理范围内。
///
/// 工具输出按内容寻址，可能仍被历史消息引用；这里不做自动淘汰，只提供显式
/// 清理入口（前端负责提示清理后旧引用不可读）。
class StorageMaintenance {
  StorageMaintenance(this._storage);

  final FileStorage _storage;

  static final _toolOutputName = RegExp(r'^[a-f0-9]{64}\.txt$');

  Future<StorageUsage> measure() async {
    final (rewindSnapshotBytes, rewindSnapshotCount) = await _measure(
      _storage.sessionsDir,
      (file) => p.basename(file.path).contains('.jsonl.rewind-'),
    );
    final (toolOutputBytes, toolOutputCount) = await _measure(
      _storage.toolOutputsDir,
      (file) => _toolOutputName.hasMatch(p.basename(file.path)),
    );
    return StorageUsage(
      rewindSnapshotBytes: rewindSnapshotBytes,
      rewindSnapshotCount: rewindSnapshotCount,
      toolOutputBytes: toolOutputBytes,
      toolOutputCount: toolOutputCount,
    );
  }

  /// 删除全部回退快照。删除前按会话文件取锁，避免与正在创建快照的回退交错。
  Future<int> clearRewindSnapshots() async {
    final directory = _storage.sessionsDir;
    if (!await directory.exists()) return 0;
    var deleted = 0;
    await for (final entry in directory.list()) {
      if (entry is! File) continue;
      final name = p.basename(entry.path);
      final marker = name.indexOf('.jsonl.rewind-');
      if (marker < 0) continue;
      final base = File(
        p.join(directory.path, '${name.substring(0, marker)}.jsonl'),
      );
      try {
        await withFileLock(_storage.locks.forTarget(base), () async {
          if (await entry.exists()) {
            await entry.delete();
            deleted++;
          }
        });
      } catch (e) {
        LoggerUtil.w('Failed to delete rewind snapshot ${entry.path}: $e');
      }
    }
    return deleted;
  }

  /// 删除全部已保存的工具输出。
  ///
  /// 调用方应先确保没有运行中的会话：新输出可能正在写入，且历史消息里的
  /// `output_id` 在清理后会读不回来。
  Future<int> clearToolOutputs() async {
    final directory = _storage.toolOutputsDir;
    if (!await directory.exists()) return 0;
    var deleted = 0;
    await for (final entry in directory.list()) {
      if (entry is! File || !_toolOutputName.hasMatch(p.basename(entry.path))) {
        continue;
      }
      await entry.delete();
      deleted++;
    }
    return deleted;
  }

  Future<(int, int)> _measure(
    Directory directory,
    bool Function(File file) include,
  ) async {
    if (!await directory.exists()) return (0, 0);
    var bytes = 0;
    var count = 0;
    await for (final entry in directory.list()) {
      if (entry is! File || !include(entry)) continue;
      try {
        bytes += await entry.length();
        count++;
      } catch (_) {
        // 统计是尽力而为；读不到大小的文件不应让设置页整个失败。
      }
    }
    return (bytes, count);
  }
}
