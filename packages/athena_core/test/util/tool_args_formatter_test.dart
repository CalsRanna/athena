import 'dart:convert';

import 'package:athena_core/util/tool_args_formatter.dart';
import 'package:test/test.dart';

void main() {
  group('formatToolArgsForApproval', () {
    test('非 shell 工具输出参数键值行', () {
      final output = formatToolArgsForApproval(
        'file_read',
        jsonEncode({'path': '/tmp/a.txt'}),
      );
      expect(output, contains('path: /tmp/a.txt'));
      // 工具名由对话框头部展示，不重复出现在内容里
      expect(output, isNot(contains('file_read')));
    });

    test('bash command longer than 120 chars is shown in full', () {
      final harmless = 'echo ${'a' * 130}';
      final command = '$harmless; rm -rf ~/x';
      expect(command.length, greaterThan(120));

      final output = formatToolArgsForApproval(
        'bash',
        jsonEncode({'command': command}),
      );

      // The dangerous tail must be visible.
      expect(output, contains('rm -rf ~/x'));
      // The full command must be present untruncated.
      expect(output, contains(command));
      // No truncation marker applied to the command.
      expect(output, isNot(contains('...')));
    });

    test('powershell command longer than 120 chars is shown in full', () {
      final command =
          'Write-Output ${'b' * 130}; Remove-Item -Recurse -Force ~/x';
      expect(command.length, greaterThan(120));

      final output = formatToolArgsForApproval(
        'powershell',
        jsonEncode({'command': command}),
      );

      expect(output, contains('Remove-Item -Recurse -Force ~/x'));
      expect(output, contains(command));
      expect(output, isNot(contains('...')));
    });

    test('bash 只展示命令本身，不含其他参数', () {
      final output = formatToolArgsForApproval(
        'bash',
        jsonEncode({'command': 'echo hi', 'timeout': 't' * 200}),
      );

      expect(output, 'echo hi');
      expect(output, isNot(contains('timeout')));
    });

    test('non-command arg longer than 120 chars is truncated to 120 + ...', () {
      final content = 'x' * 200;
      final output = formatToolArgsForApproval(
        'file_write',
        jsonEncode({'path': '/tmp/a.txt', 'content': content}),
      );

      expect(output, contains('${'x' * 120}...'));
      expect(output, isNot(contains('x' * 121)));
    });

    test('long path arg is truncated even for other tools', () {
      final longPath = '/tmp/${'d' * 200}/file.txt';
      final output = formatToolArgsForApproval(
        'file_read',
        jsonEncode({'path': longPath}),
      );

      expect(output, contains('...'));
      expect(output, isNot(contains(longPath)));
    });

    for (final toolName in const [
      'experience_learn',
      'skill_evolve',
      'sentinel_evolve',
    ]) {
      test('$toolName 在现有权限卡中完整展示自进化写入内容', () {
        final content = '${'lesson ' * 30}must remain visible';
        final output = formatToolArgsForApproval(
          toolName,
          jsonEncode({'content': content}),
        );

        expect(output, contains(content));
        expect(output, contains('must remain visible'));
        expect(output, isNot(contains('...')));
      });
    }

    test('falls back to raw arguments when JSON is invalid', () {
      final output = formatToolArgsForApproval('bash', 'not-json');
      expect(output, contains('not-json'));
    });

    test('truncates raw arguments over 200 chars in fallback branch', () {
      final raw = 'z' * 300;
      final output = formatToolArgsForApproval('bash', raw);
      expect(output, contains('${'z' * 200}...'));
    });
  });
}
