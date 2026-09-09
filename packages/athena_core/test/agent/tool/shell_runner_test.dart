import 'dart:io';

import 'package:athena_core/agent/cancel_token.dart';
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
        ShellTimeoutPolicy.resolveMaxSeconds({
          ShellTimeoutPolicy.maxTimeoutEnvVar: '7200',
        }),
        7200,
      );
    });

    test('surrounding whitespace is tolerated', () {
      expect(
        ShellTimeoutPolicy.resolveMaxSeconds({
          ShellTimeoutPolicy.maxTimeoutEnvVar: ' 9000 ',
        }),
        9000,
      );
    });

    test('non-numeric value falls back to default', () {
      expect(
        ShellTimeoutPolicy.resolveMaxSeconds({
          ShellTimeoutPolicy.maxTimeoutEnvVar: 'abc',
        }),
        ShellTimeoutPolicy.resolveMaxSeconds({}),
      );
    });

    test('value below default falls back to default', () {
      expect(
        ShellTimeoutPolicy.resolveMaxSeconds({
          ShellTimeoutPolicy.maxTimeoutEnvVar: '60',
        }),
        ShellTimeoutPolicy.resolveMaxSeconds({}),
      );
    });
  });

  test(
    'shell retains middle lines, long lines, stderr and exit status',
    () async {
      final temp = await Directory.systemTemp.createTemp('shell-full-output-');
      addTearDown(() => temp.delete(recursive: true));
      final fixture = File('${temp.path}/emit.dart');
      await fixture.writeAsString("""
import 'dart:io';
void main() {
  for (var i = 0; i < 300; i++) { stdout.writeln('line_\$i'); }
  stdout.writeln('x' * 30000);
  stderr.writeln('stderr preserved');
  exitCode = 7;
}
""");
      final result = await runShellProcess(
        executable: Platform.resolvedExecutable,
        arguments: [fixture.path],
        workdir: temp.path,
        timeoutSeconds: 10,
      );
      for (var i = 0; i < 300; i++) {
        expect(result, contains('line_$i\n'));
      }
      expect(result, contains('x' * 30000));
      expect(result, contains('[stderr]\nstderr preserved'));
      expect(result, contains('[exit code: 7]'));
      expect(result, isNot(contains('truncated')));
    },
  );

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

    test('exceeding timeout kills process and returns timeout error', () async {
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

    test('cancel signal promptly kills the shell process tree', () async {
      final temp = Directory.systemTemp.createTempSync('athena-shell-cancel-');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      final marker = File('${temp.path}/should-not-exist');
      final args = Platform.isWindows
          ? [
              '-Command',
              "Start-Sleep -Seconds 2; Set-Content -Path '${marker.path}' -Value done",
            ]
          : ['-c', 'sleep 2; touch "${marker.path}"'];
      final token = CancelToken();
      final stopwatch = Stopwatch()..start();

      final future = runShellProcess(
        executable: executable,
        arguments: args,
        workdir: temp.path,
        timeoutSeconds: 60,
        cancelSignal: token.whenCancelled,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      token.cancel();

      await expectLater(future, throwsA(isA<CancelledException>()));
      stopwatch.stop();
      expect(stopwatch.elapsed.inSeconds, lessThan(5));

      // 若只杀 shell 而遗留 sleep 子进程，两秒后仍会创建 marker。
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      expect(marker.existsSync(), isFalse);
    }, timeout: const Timeout(Duration(seconds: 15)));

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
