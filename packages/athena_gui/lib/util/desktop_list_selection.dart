import 'package:flutter/services.dart';

class DesktopListSelection<T> {
  final selectedIds = <T>{};
  T? _anchor;

  void clear() {
    selectedIds.clear();
    _anchor = null;
  }

  bool handleTap(T? id, {required List<T> ids, T? activeId}) {
    selectedIds.retainAll(ids);
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isMetaPressed || keyboard.isControlPressed) {
      if (id != null && ids.contains(id)) {
        if (!selectedIds.remove(id)) {
          selectedIds.add(id);
          _anchor = id;
        } else if (selectedIds.isEmpty) {
          _anchor = null;
        }
      }
      return false;
    }
    if (keyboard.isShiftPressed) {
      if (id == null) return false;
      final end = ids.indexOf(id);
      if (end < 0) return false;
      final firstSelected = ids.where(selectedIds.contains).firstOrNull;
      final anchor = firstSelected ?? _anchor ?? activeId;
      final start = anchor == null ? -1 : ids.indexOf(anchor);
      if (start >= 0) {
        selectedIds.addAll(
          ids.sublist(
            start < end ? start : end,
            (start > end ? start : end) + 1,
          ),
        );
        return false;
      }
    }
    clear();
    _anchor = id;
    return true;
  }
}
