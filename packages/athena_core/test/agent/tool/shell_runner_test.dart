import 'dart:io';

import 'package:athena_core/agent/tool/shell_runner.dart';
import 'package:test/test.dart';

void main() {
  late String root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('athena_shell_runner_').path;
  });

  tearDown(() => Directory(root).deleteSync(recursive: true));

  Future<String> run(String script, {int timeoutSeconds = 60}) {
    return runShellProcess(
      executable: 'sh',
      arguments: ['-c', script],
      workdir: root,
      timeoutSeconds: timeoutSeconds,
    );
  }

  String between(String text, String start, String end) {
    final from = text.indexOf(start);
    expect(from, isNonNegative, reason: '缺少起始标记');
    final to = text.indexOf(end, from + start.length);
    expect(to, isNonNegative, reason: '缺少结束标记');
    return text.substring(from + start.length, to);
  }

  /// 越界用例的产出量：明确大于 [ShellOutputPolicy.budgetChars]。
  const producedBodyChars = 4 * 1024 * 1024;

  /// 'HEAD_MARKER\n' 的 12 字符 + '\nTAIL_MARKER\n' 的 13 字符。
  const markerChars = 25;

  String bigScript() =>
      "printf 'HEAD_MARKER\\n'; "
      "head -c $producedBodyChars /dev/zero | tr '\\0' 'x'; "
      "printf '\\nTAIL_MARKER\\n'";

  group('未越界：输出逐字完整', () {
    test('小输出原样返回，不出现截断标记', () async {
      final result = await run("printf 'HELLO\\n'");

      expect(result, contains('HELLO'));
      expect(result, isNot(contains('output truncated')));
      expect(result, contains('[exit code: 0]'));
    });

    test('正好等于头部额度的输出一个字符都不少', () async {
      final result = await run(
        "printf 'BEGIN\\n'; "
        "head -c ${ShellOutputPolicy.headChars} /dev/zero | tr '\\0' 'x'; "
        "printf '\\nEND\\n'",
      );

      final body = between(result, 'BEGIN\n', '\nEND\n');
      expect(body.length, ShellOutputPolicy.headChars);
      expect(body.split('').every((c) => c == 'x'), isTrue);
      expect(result, isNot(contains('output truncated')));
    });
  });

  group('越界：保留头尾并显式说明丢弃量', () {
    test('头尾标记都在，中间被标记丢弃，总量有界', () async {
      final result = await run(bigScript());

      // 命令产出的总量远超上限，但结果必须被压在上限附近——
      // 这正是「攒完再交给输出策略」会 OOM 的那条路被堵住的证据。
      expect(result, contains('HEAD_MARKER'));
      expect(result, contains('TAIL_MARKER'));
      expect(result, contains('output truncated'));
      expect(result, contains('[exit code: 0]'));
      expect(result.length, lessThan(ShellOutputPolicy.budgetChars + 4096));

      final reported = RegExp(
        r'showing the first (\d+) and the last (\d+)',
      ).firstMatch(result);
      expect(reported, isNotNull, reason: '截断说明要写清保留了多少');
      expect(int.parse(reported!.group(1)!), ShellOutputPolicy.headChars);
      expect(int.parse(reported.group(2)!), ShellOutputPolicy.tailChars);

      final dropped = RegExp(r': (\d+) characters dropped').firstMatch(result);
      expect(dropped, isNotNull);
      expect(
        int.parse(dropped!.group(1)!),
        producedBodyChars + markerChars - ShellOutputPolicy.budgetChars,
      );
    });

    test('被截断的命令照常退出，不会被管道阻塞', () async {
      // 若越界后停止读取 stdout，子进程会写满 pipe buffer 永久阻塞，
      // 这条会以超时失败而不是通过。
      final result = await run(
        "head -c ${8 * 1024 * 1024} /dev/zero | tr '\\0' 'x'",
        timeoutSeconds: 30,
      );

      expect(result, contains('[exit code: 0]'));
      expect(result, isNot(contains('timed out')));
    });

    test('stderr 同样受限并带 [stderr] 标记', () async {
      final result = await run(
        "head -c $producedBodyChars /dev/zero | tr '\\0' 'e' >&2",
      );

      expect(result, contains('[stderr]'));
      expect(result, contains('output truncated'));
      expect(result.length, lessThan(ShellOutputPolicy.budgetChars + 4096));
    });
  });
}
