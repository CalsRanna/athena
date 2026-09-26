import 'dart:async';

import 'package:nocterm/nocterm.dart';

/// 包装 [TerminalBackend]，在进程真正退出前执行 [beforeExit]。
///
/// nocterm 的所有退出路径——`shutdownApp()`（/quit）、Ctrl+C、SIGINT /
/// SIGTERM——最终都落到 `backend.requestExit`，而 `StdioBackend` 在那里 flush
/// 完就直接 `exit()`：`runApp` 永远不会返回，写在它后面的收尾代码是死代码。
/// 需要在退出前做的事（停掉后台任务）只能挂在这里。
///
/// [beforeExit] 最多等 [timeout]，超时照常退出——收尾是尽力而为，不能让一个
/// 杀不掉的进程把终端卡住；收尾期间再次请求退出（连按 Ctrl+C）立即退出。
class ExitHookBackend implements TerminalBackend {
  ExitHookBackend(
    this._inner, {
    required this.beforeExit,
    this.timeout = const Duration(seconds: 5),
  });

  final TerminalBackend _inner;
  final Future<void> Function() beforeExit;
  final Duration timeout;

  bool _exiting = false;

  @override
  void requestExit([int exitCode = 0]) {
    if (_exiting) {
      _inner.requestExit(exitCode);
      return;
    }
    _exiting = true;
    unawaited(
      beforeExit()
          .timeout(timeout)
          .catchError((Object _) {})
          .whenComplete(() => _inner.requestExit(exitCode)),
    );
  }

  @override
  void writeRaw(String data) => _inner.writeRaw(data);

  @override
  Size getSize() => _inner.getSize();

  @override
  bool get supportsSize => _inner.supportsSize;

  @override
  Stream<List<int>>? get inputStream => _inner.inputStream;

  @override
  Stream<Size>? get resizeStream => _inner.resizeStream;

  @override
  Stream<void>? get shutdownStream => _inner.shutdownStream;

  @override
  void enableRawMode() => _inner.enableRawMode();

  @override
  void disableRawMode() => _inner.disableRawMode();

  @override
  bool get isAvailable => _inner.isAvailable;

  @override
  void notifySizeChanged(Size newSize) => _inner.notifySizeChanged(newSize);

  @override
  void dispose() => _inner.dispose();
}
