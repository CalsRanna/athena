/// 键值存储抽象：核心代码不依赖任何平台实现（SharedPreferences / 文件等）。
///
/// GUI 用 [SharedPreferences] 实现；TUI 可用 JSON 文件实现。
abstract interface class KeyValueStore {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<int?> getInt(String key);

  Future<void> setInt(String key, int value);

  Future<void> remove(String key);

  Future<Set<String>> getKeys();
}
