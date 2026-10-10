import 'package:athena_core/entity/run_statistics.dart';
import 'package:athena_core/entity/token_usage.dart';
import 'package:test/test.dart';

void main() {
  final start = DateTime(2026, 9, 29, 12);
  final statistics = RunStatistics(id: 'run-1', startedAt: start);

  TokenUsage usage(int? output, Duration? duration) => TokenUsage(
    promptTokens: 100,
    completionTokens: output,
    totalTokens: 100 + (output ?? 0),
    outputDuration: duration,
  );

  test('累计 token 归整个 run，速度只取最新一次响应的输出和生成时间', () {
    final first = statistics.withUsage(
      usage(30, const Duration(milliseconds: 500)),
    );
    expect(first.outputTokens, 30);
    // 500ms 不足 1 秒，按 1 秒计，即直接以本次 token 数为速率。
    expect(first.outputTokensPerSecond, 30);
    final next = first.withUsage(usage(60, const Duration(milliseconds: 1500)));
    expect(next.outputTokens, 90);
    expect(next.outputTokensPerSecond, 40);
  });

  test('观测窗口不足一秒时按一秒计，不把速率放大到几万', () {
    final burst = statistics.withUsage(
      usage(1000, const Duration(milliseconds: 13)),
    );
    expect(burst.outputTokens, 1000);
    expect(burst.outputTokensPerSecond, 1000);
    final subsecond = statistics.withUsage(
      usage(40, const Duration(milliseconds: 800)),
    );
    expect(subsecond.outputTokensPerSecond, 40);
  });

  test('输出 token 总数不变时保留上一次速度', () {
    final first = statistics.withUsage(
      usage(30, const Duration(milliseconds: 500)),
    );
    final unchanged = first.withUsage(usage(0, const Duration(seconds: 10)));
    expect(unchanged.outputTokens, 30);
    expect(unchanged.outputTokensPerSecond, 30);
    expect(first.withUsage(usage(null, null)).outputTokensPerSecond, 30);
  });

  test('结束后及文件重载后保留响应速度，不用 run 总耗时重算', () {
    final finished = statistics
        .withUsage(usage(30, const Duration(milliseconds: 500)))
        .copyWith(finishedAt: start.add(const Duration(minutes: 2)));
    final restored = RunStatistics.fromJson(finished.toJson());
    final later = start.add(const Duration(days: 1));
    expect(restored.elapsedAt(later), const Duration(minutes: 2));
    expect(restored.outputTokensPerSecond, 30);
    expect(restored.outputTokens, 30);
  });

  test('无法测量本次响应时显示未知速度，不沿用上一响应或 run 的时间', () {
    final first = statistics.withUsage(usage(30, const Duration(seconds: 1)));
    for (final duration in [
      null,
      Duration.zero,
      const Duration(microseconds: -1),
    ]) {
      final next = first.withUsage(usage(20, duration));
      expect(next.outputTokens, 50);
      expect(next.outputTokensPerSecond, isNull);
    }
    expect(
      statistics
          .withUsage(usage(0, const Duration(seconds: 1)))
          .outputTokensPerSecond,
      0,
    );
  });

  test('旧的输入加输出总量不能被解释为输出量', () {
    final restored = RunStatistics.fromJson({
      'id': 'legacy-run',
      'started_at': start.toIso8601String(),
      'finished_at': start.add(const Duration(seconds: 2)).toIso8601String(),
      'total_tokens': 1500,
    });
    expect(restored.outputTokens, isNull);
    expect(restored.outputTokensPerSecond, isNull);
  });

  test('旧的 run 平均速度不能作为单次 LLM 生成速度展示', () {
    final restored = RunStatistics.fromJson({
      'id': 'legacy-run',
      'started_at': start.toIso8601String(),
      'finished_at': start.add(const Duration(seconds: 2)).toIso8601String(),
      'output_tokens': 30,
      'output_tokens_per_second': 15,
    });
    expect(restored.outputTokens, 30);
    expect(restored.outputTokensPerSecond, isNull);
  });
}
