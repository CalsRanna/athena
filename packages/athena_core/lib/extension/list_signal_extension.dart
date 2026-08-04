import 'package:signals/signals.dart';

/// Signals ListSignal 工具扩展。
extension ListSignalX<T> on ListSignal<T> {
  /// 替换列表中第一个匹配 [test] 的元素为 [replacement]。
  /// 返回 true 表示找到了匹配项并替换。
  bool replaceWhere(bool Function(T) test, T replacement) {
    final index = value.indexWhere(test);
    if (index < 0) return false;
    final copy = List<T>.from(value);
    copy[index] = replacement;
    value = copy;
    return true;
  }
}
