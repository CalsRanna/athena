import 'dart:io';

import 'package:athena_core/agent/tool/shell_runner.dart';
import 'package:test/test.dart';

void main() {
  group('ShellTimeoutPolicy.normalize', () {
    test('null returns default, not clamped', () {
      final r = ShellTimeoutPolicy.normalize(null);
      expect(r.effective, ShellTimeoutPolicy.defaultSeconds);
      expect(r.clamped, isFalse);
      expect(r.requested, isNull);
    });

    test('in-range value passes through', () {
      final r = ShellTimeoutPolicy.normalize(60);
      expect(r.effective, 60);
      expect(r.clamped, isFalse);
      expect(r.requested, 60);
    });

    test('below minimum is clamped up to min', () {
      final r = ShellTimeoutPolicy.normalize(0);
      expect(r.effective, ShellTimeoutPolicy.minSeconds);
      expect(r.clamped, isTrue);
      expect(r.requested, 0);
    });

    test('negative is clamped to min', () {
      final r = ShellTimeoutPolicy.normalize(-5);
      expect(r.effective, ShellTimeoutPolicy.minSeconds);
      expect(r.clamped, isTrue);
    });

    test('above maximum is clamped down to max', () {
      final r = ShellTimeoutPolicy.normalize(99999);
      expect(r.effective, ShellTimeoutPolicy.maxSeconds);
      expect(r.clamped, isTrue);
      expect(r.requested, 99999);
    });

    test('exact max is allowed without clamping', () {
      final r = ShellTimeoutPolicy.normalize(ShellTimeoutPolicy.maxSeconds);
      expect(r.effective, ShellTimeoutPolicy.maxSeconds);
      expect(r.clamped, isFalse);
    });
  });

  group('ShellTimeoutPolicy.resolveMaxSeconds', () {
    test('absent env uses default max (3600s)', () {
      expect(ShellTimeoutPolicy.resolveMaxSeconds({}), 3600);
    });

    test('valid env value is used', () {
      expect(
        ShellTimeoutPolicy.resolveMaxSeconds(
            {ShellTimeoutPolicy.maxTimeoutEnvVar: '7200'}),
        7200,
      );
    });

    test('surrounding whitespace is tolerated', () {
      expect(
        ShellTimeoutPolicy.resolveMaxSeconds(
            {ShellTimeoutPolicy.maxTimeoutEnvVar: ' 9000 '}),
        9000,
      );
    });

    test('non-numeric value falls back to default', () {
      expect(
        ShellTimeoutPolicy.resolveMaxSeconds(
            {ShellTimeoutPolicy.maxTimeoutEnvVar: 'abc'}),
        ShellTimeoutPolicy.resolveMaxSeconds({}),
      );
    });

    test('value below default falls back to default', () {
      expect(
        ShellTimeoutPolicy.resolveMaxSeconds(
            {ShellTimeoutPolicy.maxTimeoutEnvVar: '60'}),
        ShellTimeoutPolicy.resolveMaxSeconds({}),
      );
    });
  });

  group('truncateOutput edge cases', () {
    test('within both limits returns output unchanged', () {
      final output = List.generate(10, (i) => 'line $i').join('\n');
      expect(truncateOutput(output, null), output);
    });

    test('many short lines: no negative chars, head+tail kept, middle dropped',
        () {
      final output = List.generate(200, (i) => 'line $i').join('\n');
      final result = truncateOutput(output, 'ls -la');
      expect(result, contains('[output truncated: 100 lines / 0 chars skipped'));
      // head 与 tail 各保留一段
      expect(result, contains('line 0'));
      expect(result, contains('line 199'));
      // 中间行被省略
      expect(result, isNot(contains('line 100')));
    });

    test('few long lines: no crash, no duplicate output', () {
      final line = 'x' * 2000;
      final output = List.generate(5, (_) => line).join('\n');
      final result = truncateOutput(output, 'cat big.txt');
      expect(result, contains('[output truncated: 0 lines / '
          '${output.length - OutputLimit.maxChars} chars skipped'));
      // 每行只出现一次（此前 tail 会重复整段输出，或 skip 负数抛 RangeError）
      expect(RegExp(RegExp.escape(line)).allMatches(result).length, 5);
    });

    test('overlapping head/tail: every line appears exactly once', () {
      // 80 行长行：超字符上限（触发截断）但行数不足以填满 head+tail
      final lines = List.generate(80, (i) => 'line $i ${'x' * 80}');
      final result = truncateOutput(lines.join('\n'), null);
      expect(result, contains('[output truncated: 0 lines /'));
      for (final l in lines) {
        expect(RegExp(RegExp.escape(l)).allMatches(result).length, 1,
            reason: '$l 应恰好出现一次');
      }
    });

    test('chars over budget with exactly 100 lines: all kept, no overlap', () {
      // 100 行 × 长内容：超字符上限但行数刚好填满 head+tail
      final lines = List.generate(100, (i) => 'L$i ${'x' * 100}');
      final long = lines.join('\n');
      final result = truncateOutput(long, null);
      for (final l in lines) {
        expect(RegExp(RegExp.escape(l)).allMatches(result).length, 1);
      }
      expect(result, contains('0 lines / '));
    });

    test('truncation message includes command hint', () {
      final output = List.generate(200, (i) => 'line $i').join('\n');
      final result = truncateOutput(output, 'grep foo');
      expect(result, contains('Hint:'));
      expect(result, contains('head'));
    });
  });

  group('shellTimeoutParamDescription', () {
    test('mentions default and max for LLM guidance', () {
      final desc = shellTimeoutParamDescription();
      expect(desc, contains('${ShellTimeoutPolicy.defaultSeconds}'));
      expect(desc, contains('${ShellTimeoutPolicy.maxSeconds}'));
      expect(desc.toLowerCase(), contains('retry'));
    });
  });

  group('runShellProcess timeout behavior', () {
    // 选一个跨平台都能跑的"长任务"：Windows 用 powershell 的 Start-Sleep，
    // 其他平台用 /bin/sh 的 sleep。
    late String executable;
    late List<String> Function(int seconds) sleepArgs;

    setUp(() {
      if (Platform.isWindows) {
        executable = 'powershell.exe';
        sleepArgs = (s) => ['-Command', 'Start-Sleep -Seconds $s'];
      } else {
        executable = '/bin/sh';
        sleepArgs = (s) => ['-c', 'sleep $s'];
      }
    });

    test('completes within timeout returns exit code 0', () async {
      final result = await runShellProcess(
        executable: executable,
        arguments: sleepArgs(0),
        workdir: Directory.current.path,
        timeoutSeconds: 5,
      );
      expect(result, contains('[exit code: 0]'));
      expect(result, isNot(contains('timed out')));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('exceeding timeout kills process and returns timeout error',
        () async {
      final stopwatch = Stopwatch()..start();
      final result = await runShellProcess(
        executable: executable,
        arguments: sleepArgs(60),
        workdir: Directory.current.path,
        timeoutSeconds: 2,
      );
      stopwatch.stop();

      expect(result, contains('timed out'));
      expect(result, contains('larger "timeout"'));
      // 进程应在大约 2-3 秒内被杀掉（不应等到 60 秒）。
      expect(stopwatch.elapsed.inSeconds, lessThan(10));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('clamped timeout includes a note in the output', () async {
      final result = await runShellProcess(
        executable: executable,
        arguments: sleepArgs(0),
        workdir: Directory.current.path,
        timeoutSeconds: ShellTimeoutPolicy.maxSeconds,
        clamped: true,
        requestedTimeout: 99999,
      );
      expect(result, contains('clamped'));
      expect(result, contains('99999'));
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
