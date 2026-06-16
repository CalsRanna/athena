import 'dart:io';

import 'package:athena/agent/tool/shell_runner.dart';

import 'tool_interface.dart';

class BashShellTool implements Tool {

  BashShellTool();

  @override
  String get name => 'bash';

  @override
  String get description =>
      'Execute a bash shell command. '
      'Use for terminal commands (git, npm, dart, etc.), '
      'listing directories (ls), searching code (grep -rn), '
      'and deleting files (rm).\n'
      '- Listing: prefer ls -la over recursive listing. '
      'For deep listings, pipe to head: | head -100\n'
      '- Searching: use grep -rn and filter extensions with --include. '
      'Pipe to head to limit output.\n'
      '- Deleting: ONLY delete single files (rm path/to/file). '
      'NEVER use rm -rf or any recursive delete.\n'
      'For long-running tasks, pass a larger "timeout" value. '
      'Commands run in the user home directory by default.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'command': {
            'type': 'string',
            'description': shellCommandParamDescription('bash'),
          },
          'timeout': {
            'type': 'integer',
            'description': shellTimeoutParamDescription(),
            'minimum': ShellTimeoutPolicy.minSeconds,
            'maximum': ShellTimeoutPolicy.maxSeconds,
            'default': ShellTimeoutPolicy.defaultSeconds,
          },
          'workdir': {
            'type': 'string',
            'description': shellWorkdirParamDescription(),
          },
        },
        'required': ['command'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final command = args['command'] as String;
    final timeout = ShellTimeoutPolicy.normalize(args['timeout'] as int?);
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    final workdir = args['workdir'] as String? ?? home;

    // 递归删除拦截：用户在弹窗中可以看到完整命令并决定是否放行
    if (_isRecursiveDelete(command)) {
      return 'Warning: This command contains recursive delete patterns. '
          'If you intended to delete a single file, use rm without -r flag. '
          'If you are sure you want recursive deletion, the user will approve '
          'this in the permission dialog.\n'
          'Aborting for safety. Please rephrase the command to delete only '
          'specific files.';
    }

    final result = await runShellProcess(
      executable: '/bin/sh',
      arguments: ['-c', command],
      workdir: workdir,
      timeoutSeconds: timeout.effective,
      clamped: timeout.clamped,
      requestedTimeout: timeout.requested,
    );

    // 输出截断：防止 ls -laR 或 grep 无限制输出撑爆上下文
    return _truncateOutput(result);
  }

  /// 检测递归删除命令模式。
  bool _isRecursiveDelete(String command) {
    final patterns = [
      RegExp(r'\brm\s+.*(?:-[a-zA-Z]*[rR]|--recursive)'),
      RegExp(r'\brmdir\b'),
      RegExp(r'\bfind\b.*\brm\b'),
      RegExp(r'\bdel\b\s+/[sS]'),
      RegExp(r'Remove-Item\s+.*-Recurse'),
    ];
    return patterns.any((p) => p.hasMatch(command));
  }

  /// 截断过长输出，保留头和尾。
  String _truncateOutput(String output, {int maxLines = 200, int maxChars = 10000}) {
    final lines = output.split('\n');
    if (lines.length <= maxLines && output.length <= maxChars) {
      return output;
    }
    final headLines = (maxLines * 0.7).round();
    final tailLines = maxLines - headLines;
    final head = lines.take(headLines).join('\n');
    final tail = lines.skip(lines.length - tailLines).join('\n');
    final skipped = lines.length - headLines - tailLines;
    return '$head\n\n... [truncated $skipped lines / ${output.length} total chars] ...\n\n$tail';
  }
}
