import 'dart:convert';
import 'dart:io';

import 'package:athena_tui/storage/serial_lock.dart';

/// 跨文件共享的自增 id 分配器。
///
/// 计数持久化在 meta.json(GUI 用 SQLite 自增主键,TUI 用此等价物)。
/// 进程内与跨重启均单调递增,保证 chat/message 的引用 id 不会被复用。
class IdAllocator {
  IdAllocator(this.file);

  final File file;
  final Map<String, int> _counters = {};
  Future<void>? _pending;

  Future<int> next(String key) {
    final result = _serialized(() async {
      await _load();
      final next = (_counters[key] ?? 0) + 1;
      _counters[key] = next;
      await _save();
      return next;
    });
    return result;
  }

  /// 清空内存缓存,强制下次 [next] 重读 meta 文件。
  ///
  /// 迁移代码直接改写 meta.json 后调用,避免旧计数覆盖迁移结果。
  void reset() {
    _counters.clear();
  }

  Future<void> _load() async {
    if (_counters.isNotEmpty) return;
    if (!await file.exists()) return;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      json.forEach((k, v) => _counters[k] = v as int);
    } catch (_) {
      // 损坏的 meta 文件按空计数处理,id 从头分配
    }
  }

  Future<void> _save() async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(_counters));
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    return serialLock(_pending, action, (f) => _pending = f);
  }
}
