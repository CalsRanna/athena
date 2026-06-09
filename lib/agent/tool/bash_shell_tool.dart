import 'dart:io';

import 'package:athena/agent/permission/sandbox.dart';
import 'package:athena/agent/tool/shell_runner.dart';

import 'tool_interface.dart';

class BashShellTool implements Tool {
  final PathSandbox sandbox;

  BashShellTool({required this.sandbox});

  @override
  String get name => 'bash';

  @override
  String get description =>
      'Execute a bash shell command. Use when you need to run terminal '
      'commands like git, npm, dart, etc. Commands run in the user home '
      'directory by default. For long-running tasks (installs, builds), '
      'pass a larger "timeout" value rather than retrying with the default.';

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
  DangerLevel get dangerLevel => DangerLevel.needsApproval;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final command = args['command'] as String;
    final timeout = ShellTimeoutPolicy.normalize(args['timeout'] as int?);
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    final workdir = args['workdir'] as String? ?? home;

    if (!sandbox.canWrite(workdir)) {
      return 'Error: workdir "$workdir" is in a restricted system area and cannot be used.';
    }

    return runShellProcess(
      executable: '/bin/sh',
      arguments: ['-c', command],
      workdir: workdir,
      timeoutSeconds: timeout.effective,
      clamped: timeout.clamped,
      requestedTimeout: timeout.requested,
    );
  }
}
