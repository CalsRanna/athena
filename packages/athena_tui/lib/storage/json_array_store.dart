import 'dart:convert';
import 'dart:io';

import 'package:athena_tui/storage/id_allocator.dart';
import 'package:athena_tui/storage/serial_lock.dart';

/// JSON 数组文件存储:`[ {...}, {...} ]` 单文件,`id` 字段为行主键。
///
/// 用于整列表数据(模型/角色),读-改-整文件写的使用方式:
/// - **串行锁**:所有公开方法在单次锁内完成,并发写不互相覆盖
/// - **原子写**:临时文件 + rename 替换,避免写一半损坏文件
/// - 损坏文件按空列表容错(不覆盖,等下次写入重建)
class JsonArrayStore {
  JsonArrayStore({required this.file, required this.idAllocator});

  final File file;
  final IdAllocator idAllocator;

  Future<void>? _lock;

  Future<T> _serialized<T>(Future<T> Function() action) {
    return serialLock(_lock, action, (f) => _lock = f);
  }

  Future<List<Map<String, dynamic>>> readAll() {
    return _serialized(_readAll);
  }

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

  Future<void> _writeAll(List<Map<String, dynamic>> rows) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(rows));
    await tmp.rename(file.path);
  }

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
