import 'dart:io';

import 'package:athena/agent/tool/shell_runner.dart';

import 'tool_interface.dart';

class PowerShellShellTool implements Tool {

  PowerShellShellTool();

  @override
  String get name => 'powershell';

  @override
  String get description =>
      'Execute a PowerShell command. '
      'Use for terminal commands (git, npm, dart, etc.), '
      'listing directories (Get-ChildItem or dir), '
      'searching code (Select-String), '
      'and deleting files (Remove-Item).\n'
      '- Listing: use Get-ChildItem. For deep listings, use | Select-Object -First 100\n'
      '- Searching: use Get-ChildItem -Recurse -Include ... | Select-String -Pattern ...\n'
      '- Deleting: ONLY delete single files (Remove-Item path). '
      'NEVER use Remove-Item -Recurse or del /s.\n'
      'For long-running tasks, pass a larger "timeout" value. '
      'Commands run in the user home directory by default.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'command': {
            'type': 'string',
            'description': shellCommandParamDescription('PowerShell'),
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
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final workdir = args['workdir'] as String? ?? home;

    // 递归删除拦截
    if (_isRecursiveDelete(command)) {
      return 'Warning: This command contains recursive delete patterns. '
          'If you intended to delete a single file, use Remove-Item without -Recurse. '
          'If you are sure you want recursive deletion, the user will approve '
          'this in the permission dialog.\n'
          'Aborting for safety. Please rephrase the command to delete only '
          'specific files.';
    }

    final result = await runShellProcess(
      executable: 'powershell.exe',
      arguments: ['-Command', command],
      workdir: workdir,
      timeoutSeconds: timeout.effective,
      clamped: timeout.clamped,
      requestedTimeout: timeout.requested,
    );

    return _truncateOutput(result);
  }

  bool _isRecursiveDelete(String command) {
    final patterns = [
      RegExp(r'Remove-Item\s+.*-Recurse'),
      RegExp(r'\brm\s+.*(?:-[a-zA-Z]*[rR]|--recursive)'),
      RegExp(r'\brmdir\b'),
      RegExp(r'\bdel\b\s+/[sS]'),
    ];
    return patterns.any((p) => p.hasMatch(command));
  }

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
