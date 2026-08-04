import 'dart:convert';
import 'dart:io';

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
    return _locked(_pending, action, (f) => _pending = f);
  }
}

/// 单次锁内可用的原始读写视图。
///
/// 只能由 [JsonlFileStore.inLock] 传入并在其回调内使用;
/// 这些方法不加锁,若在 inLock 之外调用会与其他写操作竞争。
class JsonlStoreView {
  JsonlStoreView._(this._file);

  final File _file;

  /// 读取全部行(按文件行序)。
  Future<List<Map<String, dynamic>>> readRows() async {
    if (!await _file.exists()) return [];
    final lines = await _file.readAsLines();
    final rows = <Map<String, dynamic>>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        rows.add(jsonDecode(line) as Map<String, dynamic>);
      } catch (_) {
        // 跳过损坏行,保证文件级容错
      }
    }
    return rows;
  }

  /// 整文件覆写。
  Future<void> writeRows(List<Map<String, dynamic>> rows) async {
    await _file.parent.create(recursive: true);
    final buf = StringBuffer();
    for (final row in rows) {
      buf.writeln(jsonEncode(row));
    }
    await _file.writeAsString(buf.toString());
  }

  /// 追加一行。
  Future<void> appendRow(Map<String, dynamic> row) async {
    await _file.parent.create(recursive: true);
    final sink = _file.openWrite(mode: FileMode.append);
    sink.write(jsonEncode(row));
    sink.write('\n');
    await sink.close();
  }
}

/// JSONL 文件存储基类:每行一个 JSON 对象,`id` 字段为行主键。
///
/// 设计要点:
/// - **单写者锁**:所有公开方法在单次锁内完成(读-改-写原子)。
///   防止 updateChat 与 recordUsage 并发写同一行时互相覆盖
///   (核心 ChatRepository 注释要求两路径解耦)
/// - **复合操作**:repo 层需要"读→改→写"的原子操作时,用 [inLock]
///   在单次锁内完成(如 recordUsage 的累加写)。禁止在锁内调用
///   其他加锁方法(会死锁),只允许 [JsonlStoreView] 的原始读写。
/// - 行更新采用整文件重写:消息/会话数据规模有限,重写简单可靠;
///   流式期间核心层只在 finalize/取消/错误时落库,更新频率低
class JsonlFileStore {
  JsonlFileStore({
    required this.file,
    required this.idAllocator,
    String idKey = 'id',
  }) : _view = JsonlStoreView._(file),
       _idKey = idKey;

  final File file;
  final IdAllocator idAllocator;
  final String _idKey;

  final JsonlStoreView _view;
  Future<void>? _lock;

  /// 复合读-改-写操作入口:单次锁内执行 [action]。
  ///
  /// [action] 只允许使用 [view] 的原始读写方法。
  Future<T> inLock<T>(Future<T> Function(JsonlStoreView view) action) {
    return _locked(_lock, () async {
      final result = await action(_view);
      return result;
    }, (f) => _lock = f);
  }

  /// 分配 id 并追加一行,返回新 id。
  Future<int> insert(Map<String, dynamic> json) {
    return inLock((view) async {
      final id = await idAllocator.next(file.path);
      json[_idKey] = id;
      await view.appendRow(json);
      return id;
    });
  }

  /// 按 id 整行替换(不存在则追加)。
  Future<void> replaceById(int id, Map<String, dynamic> json) {
    return inLock((view) async {
      final rows = await view.readRows();
      final index = rows.indexWhere((r) => r[_idKey] == id);
      json[_idKey] = id;
      if (index >= 0) {
        rows[index] = json;
      } else {
        rows.add(json);
      }
      await view.writeRows(rows);
    });
  }

  Future<void> deleteById(int id) {
    return deleteWhere((row) => row[_idKey] == id);
  }

  Future<void> deleteWhere(bool Function(Map<String, dynamic> json) test) {
    return inLock((view) async {
      final rows = await view.readRows();
      rows.removeWhere(test);
      await view.writeRows(rows);
    });
  }

  /// 单次锁内批量更新:对命中的行应用 [transform],返回命中数。
  Future<int> updateWhere(
    bool Function(Map<String, dynamic> json) test,
    Map<String, dynamic> Function(Map<String, dynamic> json) transform,
  ) {
    return inLock((view) async {
      final rows = await view.readRows();
      var changed = 0;
      for (final row in rows) {
        if (test(row)) {
          final updated = transform(row);
          updated[_idKey] = row[_idKey];
          row.clear();
          row.addAll(updated);
          changed++;
        }
      }
      if (changed > 0) {
        await view.writeRows(rows);
      }
      return changed;
    });
  }

  Future<Map<String, dynamic>?> readById(int id) async {
    final rows = await inLock((view) => view.readRows());
    for (final row in rows) {
      if (row[_idKey] == id) return row;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> readAll() {
    return inLock((view) => view.readRows());
  }

  Future<int> count() async {
    final rows = await inLock((view) => view.readRows());
    return rows.length;
  }

  /// 删除整个文件(如删除聊天时级联删除其消息文件)。
  Future<void> deleteFile() {
    return inLock((view) async {
      await view.deleteFile();
    });
  }
}

extension on JsonlStoreView {
  Future<void> deleteFile() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }
}

/// 通用串行锁:保证同一资源上的操作按提交顺序执行。
Future<T> _locked<T>(
  Future<void>? previous,
  Future<T> Function() action,
  void Function(Future<void>) setter,
) {
  final result = (previous ?? Future<void>.value()).then((_) => action());
  setter(result.then((_) {}, onError: (_) {}));
  return result;
}
