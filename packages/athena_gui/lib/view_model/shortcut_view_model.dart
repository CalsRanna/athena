import 'package:athena_gui/model/shortcut.dart';
import 'package:athena_gui/repository/shortcut_repository.dart';
import 'package:signals/signals.dart';

/// Shortcut（快捷入口）ViewModel：管理首页卡片行的数据。
class ShortcutViewModel {
  final ShortcutRepository _shortcutRepository;

  ShortcutViewModel({required ShortcutRepository shortcutRepository})
      : _shortcutRepository = shortcutRepository;

  final shortcuts = listSignal<Shortcut>([]);
  final isLoading = signal(false);
  final error = signal<String?>(null);

  Future<void> getShortcuts() async {
    isLoading.value = true;
    error.value = null;
    try {
      shortcuts.value = await _shortcutRepository.getAllShortcuts();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createShortcut(Shortcut shortcut) async {
    isLoading.value = true;
    error.value = null;
    try {
      var id = await _shortcutRepository.createShortcut(shortcut);
      var created = shortcut.copyWith(id: id);
      shortcuts.value = [...shortcuts.value, created];
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateShortcut(Shortcut shortcut) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _shortcutRepository.updateShortcut(shortcut);
      var index = shortcuts.value.indexWhere((s) => s.id == shortcut.id);
      if (index >= 0) {
        var copy = List<Shortcut>.from(shortcuts.value);
        copy[index] = shortcut;
        shortcuts.value = copy;
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteShortcut(int id) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _shortcutRepository.deleteShortcut(id);
      shortcuts.value =
          shortcuts.value.where((s) => s.id != id).toList();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 绑定关系的反向查询：Shortcut 的专属 Sentinel 由外键级联删除保护。
  Future<Shortcut?> getShortcutBySentinelId(int sentinelId) {
    return _shortcutRepository.getShortcutBySentinelId(sentinelId);
  }
}
