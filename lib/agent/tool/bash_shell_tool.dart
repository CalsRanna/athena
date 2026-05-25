import 'dart:io';

import 'package:athena/agent/permission/sandbox.dart';

import 'tool_interface.dart';

class BashShellTool implements Tool {
  final PathSandbox sandbox;

  BashShellTool({required this.sandbox});

  @override
  String get name => 'bash';

  @override
  String get description => 'Execute a bash shell command. '
      'Use when you need to run terminal commands like git, npm, dart, etc. '
      'Commands run in the user home directory by default.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'command': {
            'type': 'string',
            'description': 'The shell command to execute.',
          },
          'timeout': {
            'type': 'integer',
            'description': 'Timeout in seconds. Defaults to 30.',
          },
          'workdir': {
            'type': 'string',
            'description': 'Working directory for the command. '
                'Defaults to the user home directory.',
          },
        },
        'required': ['command'],
      };

  @override
  DangerLevel get dangerLevel => DangerLevel.needsApproval;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final command = args['command'] as String;
    final timeoutSeconds = args['timeout'] as int? ?? 30;
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    final workdir = args['workdir'] as String? ?? home;

    if (!sandbox.canExecute(command)) {
      return 'Error: command rejected by sandbox policy (matches a hard-denied pattern).';
    }
    if (!sandbox.canWrite(workdir)) {
      return 'Error: workdir "$workdir" is in a restricted system area and cannot be used.';
    }

    try {
      final result = await Process.run(
        '/bin/sh',
        ['-c', command],
        workingDirectory: workdir,
      ).timeout(Duration(seconds: timeoutSeconds));

      final stdout = result.stdout.toString().trim();
      final stderr = result.stderr.toString().trim();
      final buffer = StringBuffer();
      if (stdout.isNotEmpty) {
        buffer.writeln(stdout);
      }
      if (stderr.isNotEmpty) {
        buffer.writeln('[stderr]');
        buffer.writeln(stderr);
      }
      buffer.writeln('[exit code: ${result.exitCode}]');
      return buffer.toString().trim();
    } catch (e) {
      return 'Error executing command: $e';
    }
  }
}
