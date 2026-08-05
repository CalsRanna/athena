import 'dart:convert';
import 'dart:io';

import 'package:athena_core/storage/key_value_store.dart';
import 'package:athena_tui/storage/serial_lock.dart';

/// KeyValueStore 的 JSON 文件实现(`~/.athena/tui/kv.json`)。
///
/// GUI 用 SharedPreferences,TUI 用单个 JSON 对象文件,接口行为对齐。
///
/// 写路径是"读-改-整文件写":所有公开方法包 [serialLock] 串行化,
/// 否则 Agent 运行期间 WebSearchTool(计数)与 AgentSettings 并发
/// setString 时,后写的整文件覆盖会丢失先写的更新。
class JsonFileKeyValueStore implements KeyValueStore {
  JsonFileKeyValueStore({required File file}) : _file = file;

  final File _file;
  Map<String, dynamic>? _cache;
  Future<void>? _lock;

  Future<T> _serialized<T>(Future<T> Function() action) {
    return serialLock(_lock, action, (f) => _lock = f);
  }

  Future<Map<String, dynamic>> _load() async {
    final cache = _cache;
    if (cache != null) return cache;
    if (await _file.exists()) {
      try {
        _cache = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
        return _cache!;
      } catch (_) {
        // 损坏文件按空 map 处理
      }
    }
    return _cache = {};
  }

  Future<void> _persist(Map<String, dynamic> map) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(map));
  }

  @override
  Future<String?> getString(String key) {
    return _serialized(() async {
      final map = await _load();
      final value = map[key];
      return value is String ? value : null;
    });
  }

  @override
  Future<void> setString(String key, String value) {
    return _serialized(() async {
      final map = await _load();
      map[key] = value;
      await _persist(map);
    });
  }

  @override
  Future<int?> getInt(String key) {
    return _serialized(() async {
      final map = await _load();
      final value = map[key];
      return value is int ? value : null;
    });
  }

  @override
  Future<void> setInt(String key, int value) {
    return _serialized(() async {
      final map = await _load();
      map[key] = value;
      await _persist(map);
    });
  }

  @override
  Future<void> remove(String key) {
    return _serialized(() async {
      final map = await _load();
      map.remove(key);
      await _persist(map);
    });
  }

  @override
  Future<Set<String>> getKeys() {
    return _serialized(() async {
      final map = await _load();
      return map.keys.toSet();
    });
  }
}
