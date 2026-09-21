import 'dart:convert';
import 'dart:io';

import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/id_allocator.dart';
import 'package:athena_core/storage/serial_lock.dart';

/// JSON 数组文件存储:`[ {...}, {...} ]` 单文件,`id` 字段为行主键。
///
/// 用于整列表数据(模型/角色),读-改-整文件写的使用方式:
/// - **串行锁 + 跨进程文件锁**:所有修改在单次锁内完成读-改-写,
///   同进程与另一进程(GUI/TUI 共享目录)的并发写都不互相覆盖
/// - **原子写**:临时文件 + rename 替换,避免写一半损坏文件;读不加锁,
///   读到的要么是旧文件要么是新文件
/// - 损坏文件按空列表容错(不覆盖,等下次写入重建)
class JsonArrayStore {
  JsonArrayStore({required this.file, required this.idAllocator});

  final File file;
  final IdAllocator idAllocator;

  Future<void>? _lock;

  /// 读-改-写:进程内串行 + 跨进程文件锁。
  Future<T> _serialized<T>(Future<T> Function() action) {
    return serialLock(
      _lock,
      () => withFileLock(lockFileFor(file), action),
      (f) => _lock = f,
    );
  }

  Future<List<Map<String, dynamic>>> readAll() => _readAll();

  Future<List<Map<String, dynamic>>> _readAll() async {
    if (!await file.exists()) return [];
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is! List) return [];
      return [
        for (final item in value)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    } catch (_) {
      // 损坏文件按空列表处理
      return [];
    }
  }

  Future<void> _writeAll(List<Map<String, dynamic>> rows) =>
      atomicWriteString(file, jsonEncode(rows));

  /// 分配 id 并追加,返回新 id。
  Future<int> insert(Map<String, dynamic> json) {
    return _serialized(() async {
      final id = await idAllocator.next(file.path);
      json['id'] = id;
      final rows = await _readAll();
      rows.add(json);
      await _writeAll(rows);
      return id;
    });
  }

  /// 按 id 整条替换(不存在则追加)。
  Future<void> replaceById(int id, Map<String, dynamic> json) {
    return _serialized(() async {
      final rows = await _readAll();
      json['id'] = id;
      final index = rows.indexWhere((r) => r['id'] == id);
      if (index >= 0) {
        rows[index] = json;
      } else {
        rows.add(json);
      }
      await _writeAll(rows);
    });
  }

  /// 以给定 [id] 原样写入(存在则整条覆盖,不存在则追加),并把 id 计数
  /// 抬到不低于该值。导入/恢复保留原 id 的数据时使用。
  Future<void> restore(int id, Map<String, dynamic> json) {
    return _serialized(() async {
      final rows = await _readAll();
      json['id'] = id;
      final index = rows.indexWhere((r) => r['id'] == id);
      if (index >= 0) {
        rows[index] = json;
      } else {
        rows.add(json);
      }
      await _writeAll(rows);
      await idAllocator.ensureAtLeast(file.path, id);
    });
  }

  /// 整文件替换为 [rows](导入用):带 `id` 的行原样保留并抬高计数,
  /// 缺 `id` 的行分配新 id。
  Future<void> replaceAll(List<Map<String, dynamic>> rows) {
    return _serialized(() async {
      var maxId = 0;
      final pending = <Map<String, dynamic>>[];
      for (final row in rows) {
        final id = row['id'];
        if (id is int) {
          if (id > maxId) maxId = id;
        } else {
          pending.add(row);
        }
      }
      if (maxId > 0) await idAllocator.ensureAtLeast(file.path, maxId);
      for (final row in pending) {
        row['id'] = await idAllocator.next(file.path);
      }
      await _writeAll(List.of(rows));
    });
  }

  Future<void> deleteById(int id) {
    return deleteWhere((row) => row['id'] == id);
  }

  Future<void> deleteWhere(bool Function(Map<String, dynamic> json) test) {
    return _serialized(() async {
      final rows = await _readAll();
      rows.removeWhere(test);
      await _writeAll(rows);
    });
  }

  Future<int> count() async {
    final rows = await readAll();
    return rows.length;
  }

  /// 删除整个文件。
  Future<void> deleteFile() {
    return _serialized(() async {
      if (await file.exists()) {
        await file.delete();
      }
    });
  }
}
