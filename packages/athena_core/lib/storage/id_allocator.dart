import 'dart:convert';
import 'dart:io';

import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/serial_lock.dart';

/// 跨文件共享的自增 id 分配器。
///
/// 计数持久化在 meta.json(自增主键的等价物),key 是文件/目录路径。
/// 进程内与跨重启均单调递增,保证 chat/message 的引用 id 不会被复用。
///
/// GUI 与 TUI 共享同一数据目录,可能同时运行:每次分配都在跨进程文件锁
/// 内完成"读 meta → 加一 → 原子写回",不缓存计数,两个进程不会分到
/// 同一个 id。
class IdAllocator {
  IdAllocator(this.file);

  final File file;
  Future<void>? _pending;

  Future<int> next(String key) {
    return _mutate((counters) {
      final next = (counters[key] ?? 0) + 1;
      counters[key] = next;
      return next;
    });
  }

  /// 把 [key] 的计数抬到不低于 [value](导入保留原 id 的数据后调用,
  /// 避免后续分配与已导入的 id 冲突)。
  Future<void> ensureAtLeast(String key, int value) {
    return _mutate<bool>((counters) {
      if ((counters[key] ?? 0) >= value) return false;
      counters[key] = value;
      return true;
    });
  }

  Future<T> _mutate<T>(T Function(Map<String, int> counters) mutate) {
    return _serialized(() {
      return withFileLock(lockFileFor(file), () async {
        final counters = await _load();
        final result = mutate(counters);
        await _save(counters);
        return result;
      });
    });
  }

  Future<Map<String, int>> _load() async {
    if (!await file.exists()) return {};
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return {};
      return {
        for (final entry in json.entries)
          if (entry.value is int) entry.key as String: entry.value as int,
      };
    } catch (_) {
      // 损坏的 meta 文件按空计数处理,id 从头分配
      return {};
    }
  }

  Future<void> _save(Map<String, int> counters) =>
      atomicWriteString(file, jsonEncode(counters));

  Future<T> _serialized<T>(Future<T> Function() action) {
    return serialLock(_pending, action, (f) => _pending = f);
  }
}
