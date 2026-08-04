import 'package:athena_core/storage/key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [KeyValueStore] 的 SharedPreferences 实现（GUI 侧）。
class SharedPrefsKeyValueStore implements KeyValueStore {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  @override
  Future<String?> getString(String key) async {
    return (await _prefs).getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    await (await _prefs).setString(key, value);
  }

  @override
  Future<int?> getInt(String key) async {
    return (await _prefs).getInt(key);
  }

  @override
  Future<void> setInt(String key, int value) async {
    await (await _prefs).setInt(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await (await _prefs).remove(key);
  }

  @override
  Future<Set<String>> getKeys() async {
    return (await _prefs).getKeys();
  }
}
