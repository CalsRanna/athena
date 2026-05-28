import 'dart:io';

import 'package:athena/agent/tool/shell_runner.dart';
import 'package:flutter_test/flutter_test.dart';

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
