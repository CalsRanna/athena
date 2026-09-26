import 'dart:async';

import 'package:athena_core/service/llm_client.dart';
import 'package:test/test.dart';

/// `Stream.timeout` 对「async* 生成器 + await for」不触发（AGENTS 硬约束 9），
/// 流式请求的空闲超时全靠 [withIdleTimeout]。
void main() {
  const timeout = Duration(milliseconds: 60);

  test('源流长时间没有新事件时以 TimeoutException 结束，并取消源流', () async {
    var sourceCancelled = false;
    final source = StreamController<int>(
      onCancel: () => sourceCancelled = true,
    );

    await expectLater(
      withIdleTimeout(source.stream, timeout),
      emitsError(isA<TimeoutException>()),
    );
    expect(sourceCancelled, isTrue, reason: '超时后不能继续挂着上游连接');
  });

  test('async* 生成器卡住时同样超时', () async {
    Stream<int> stalled() async* {
      yield 1;
      await Completer<void>().future; // 永不继续
    }

    await expectLater(
      withIdleTimeout(stalled(), timeout),
      emitsInOrder([1, emitsError(isA<TimeoutException>())]),
    );
  });

  test('持续有事件就一直不超时，总时长可以远超超时时间', () async {
    Stream<int> steady() async* {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        yield i;
      }
    }

    expect(
      await withIdleTimeout(steady(), timeout).toList(),
      List.generate(8, (i) => i),
    );
  });

  test('下游取消后不再报超时', () async {
    final source = StreamController<int>();
    final errors = <Object>[];
    final sub = withIdleTimeout(
      source.stream,
      timeout,
    ).listen((_) {}, onError: errors.add);

    await sub.cancel();
    await Future<void>.delayed(timeout * 2);

    expect(errors, isEmpty);
  });
}
