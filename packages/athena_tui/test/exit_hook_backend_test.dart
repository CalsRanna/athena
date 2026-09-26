import 'dart:async';

import 'package:athena_tui/exit_hook_backend.dart';
import 'package:nocterm/nocterm.dart' show TerminalBackend;
import 'package:test/test.dart';

/// 所有退出路径（/quit、Ctrl+C、SIGINT / SIGTERM）都经 `requestExit` 结束
/// 进程：后台任务必须在真正退出之前停掉。
void main() {
  test('先执行收尾，再交给内层真正退出', () async {
    final inner = _RecordingBackend();
    final order = <String>[];
    final backend = ExitHookBackend(
      inner..onExit = (code) => order.add('exit $code'),
      beforeExit: () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        order.add('stopAll');
      },
    );

    backend.requestExit(3);
    expect(order, isEmpty, reason: '收尾完成前不能退出');
    await inner.exited.future;

    expect(order, ['stopAll', 'exit 3']);
  });

  test('收尾超时或出错照常退出', () async {
    for (final beforeExit in <Future<void> Function()>[
      () => Completer<void>().future, // 永不完成
      () async => throw StateError('kill failed'),
    ]) {
      final inner = _RecordingBackend();
      ExitHookBackend(
        inner,
        beforeExit: beforeExit,
        timeout: const Duration(milliseconds: 20),
      ).requestExit();

      await expectLater(
        inner.exited.future.timeout(const Duration(seconds: 2)),
        completion(0),
      );
    }
  });

  test('收尾期间再次请求退出（连按 Ctrl+C）立即退出', () async {
    final inner = _RecordingBackend();
    final backend = ExitHookBackend(
      inner,
      beforeExit: () => Completer<void>().future,
    );

    backend.requestExit();
    backend.requestExit(130);

    expect(await inner.exited.future, 130);
  });
}

class _RecordingBackend implements TerminalBackend {
  final exited = Completer<int>();
  void Function(int code)? onExit;

  @override
  void requestExit([int exitCode = 0]) {
    onExit?.call(exitCode);
    if (!exited.isCompleted) exited.complete(exitCode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
