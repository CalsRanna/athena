import 'package:athena_gui/model/shortcut.dart';

/// Shortcut（快捷入口）存储接口。持久化策略由实现方决定。
abstract class ShortcutRepository {
  Future<List<Shortcut>> getAllShortcuts();

  Future<Shortcut?> getShortcutById(int id);

  Future<int> createShortcut(Shortcut shortcut);

  Future<void> updateShortcut(Shortcut shortcut);

  Future<void> deleteShortcut(int id);

  Future<void> batchCreateShortcuts(List<Shortcut> shortcuts);

  /// 按绑定的 Sentinel id 查找（一个 Sentinel 至多被一个 Shortcut 绑定）。
  Future<Shortcut?> getShortcutBySentinelId(int sentinelId);
}
