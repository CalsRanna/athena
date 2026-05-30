import 'dart:convert';

import 'package:athena/util/tool_args_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatToolArgsForApproval', () {
    test('includes the tool name header line', () {
      final output = formatToolArgsForApproval(
        'file_read',
        jsonEncode({'path': '/tmp/a.txt'}),
      );
      expect(output, contains('Agent wants to use: file_read'));
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

    test('bash arg that is NOT command follows 120-char truncation', () {
      final longTimeout = 't' * 200;
      final command = 'echo hi';
      final output = formatToolArgsForApproval(
        'bash',
        jsonEncode({'command': command, 'timeout': longTimeout}),
      );

      // The command (short) shown in full.
      expect(output, contains('command: $command'));
      // The non-command arg is truncated.
      expect(output, contains('${'t' * 120}...'));
      expect(output, isNot(contains('t' * 121)));
    });

    test('falls back to raw arguments when JSON is invalid', () {
      final output = formatToolArgsForApproval('bash', 'not-json');
      expect(output, contains('Agent wants to use: bash'));
      expect(output, contains('not-json'));
    });

    test('truncates raw arguments over 200 chars in fallback branch', () {
      final raw = 'z' * 300;
      final output = formatToolArgsForApproval('bash', raw);
      expect(output, contains('${'z' * 200}...'));
    });
  });
}
