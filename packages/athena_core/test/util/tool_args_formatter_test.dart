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

    test('bash includes workdir and timeout alongside the command', () {
      final output = formatToolArgsForApproval(
        'bash',
        jsonEncode({
          'command': 'echo hi',
          'workdir': '/tmp/project',
          'timeout': 30,
          'call_description': 'Print a greeting',
        }),
      );

      expect(output, 'echo hi\nworkdir: /tmp/project\ntimeout: 30');
    });

    test('file writes retain the complete content for approval', () {
      final content = 'x' * 200;
      final output = formatToolArgsForApproval(
        'file_write',
        jsonEncode({'path': '/tmp/a.txt', 'content': content}),
      );

      expect(output, contains(content));
    });

    test('long paths are never truncated in approval details', () {
      final longPath = '/tmp/${'d' * 200}/file.txt';
      final output = formatToolArgsForApproval(
        'file_read',
        jsonEncode({'path': longPath}),
      );

      expect(output, contains(longPath));
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

    test('preserves raw arguments when approval JSON is invalid', () {
      final raw = 'z' * 300;
      final output = formatToolArgsForApproval('bash', raw);
      expect(output, raw);
    });

    test('skill description remains business data, separate from intent', () {
      final output = formatToolArgsForApproval(
        'skill_evolve',
        jsonEncode({
          'description': 'Runs tests',
          'call_description': 'Create the testing skill',
        }),
      );
      expect(output, 'description: Runs tests');
    });
  });

  group('toolArgPreview', () {
    test('uses a trimmed model description before the command', () {
      expect(
        toolArgPreview(
          'bash',
          jsonEncode({
            'command': 'git push',
            'call_description': '  推送当前分支\n到远程仓库  ',
          }),
        ),
        '推送当前分支 到远程仓库',
      );
    });

    for (final description in [null, '', '  ', 123, <String>[]]) {
      test('falls back to the key argument for $description', () {
        expect(
          toolArgPreview(
            'file_read',
            jsonEncode({
              'path': '/tmp/a.dart',
              'call_description': description,
            }),
          ),
          '/tmp/a.dart',
        );
      });
    }

    test('business description is not treated as call intent', () {
      expect(
        toolArgPreview('skill_evolve', '{"description":"Runs tests"}'),
        '{"description":"Runs tests"}',
      );
    });

    test('missing description preserves shell, file and web previews', () {
      for (final (tool, key, value) in [
        ('powershell', 'command', 'Get-ChildItem'),
        ('file_write', 'path', '/tmp/a.dart'),
        ('web_fetch', 'url', 'https://example.com'),
        ('web_search', 'query', 'Dart test'),
      ]) {
        expect(toolArgPreview(tool, jsonEncode({key: value})), value);
      }
    });

    test('partial streaming JSON and non-object JSON do not throw', () {
      for (final raw in ['{"command":', '[]', 'null', '']) {
        expect(toolArgPreview('bash', raw), raw);
        expect(toolCallDescription(raw), isNull);
      }
    });

    test('compact JSON and Unicode descriptions have bounded previews', () {
      expect(
        toolArgPreview('unknown', '{\n  "name": "test"\n}'),
        '{"name":"test"}',
      );
      expect(
        toolArgPreview('bash', jsonEncode({'call_description': '😀' * 205})),
        '${'😀' * 200}…',
      );
    });
  });
}
