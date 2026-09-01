import 'dart:io';

import 'package:athena_core/agent/permission/command_analyzer.dart';
import 'package:athena_core/agent/tool/shell_runner.dart';

import 'tool_interface.dart';

class PowerShellShellTool implements Tool, CancellableTool {
  /// 默认工作目录。未传入时退化为用户主目录(原有行为)。
  /// 桌面端可注入启动时指定的工作区,让命令默认在项目目录里执行。
  PowerShellShellTool({String? defaultWorkdir}) : _defaultWorkdir = defaultWorkdir;

  final String? _defaultWorkdir;

  @override
  ExecutionMode get executionMode => ExecutionMode.sequential;

  @override
  ToolRisk get risk => ToolRisk.dangerous;

  /// 只读命令（CommandAnalyzer 白名单内）可并行执行，其余必须串行。
  @override
  bool canExecuteParallel(Map<String, dynamic> args) {
    final command = args['command'] as String?;
    return command != null && CommandAnalyzer.isReadOnlyCommand(command);
  }

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
      'Commands run in the ${_defaultWorkdir ?? 'user home'} directory by default.';

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
            'description': shellWorkdirParamDescription(_defaultWorkdir),
          },
        },
        'required': ['command'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) =>
      _execute(args, onUpdate: onUpdate);

  @override
  Future<String> executeCancellable(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
    required Future<void> cancelSignal,
  }) =>
      _execute(
        args,
        onUpdate: onUpdate,
        cancelSignal: cancelSignal,
      );

  Future<String> _execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
    Future<void>? cancelSignal,
  }) async {
    final command = args['command'] as String;
    final timeout = ShellTimeoutPolicy.normalize(args['timeout'] as int?);
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    // 优先级:调用参数 > 注入的默认工作目录(工作区) > 用户主目录
    final workdir = args['workdir'] as String? ?? _defaultWorkdir ?? home;

    // 递归删除拦截
    if (CommandAnalyzer.isRecursiveDelete(command)) {
      return 'Warning: This command contains potentially dangerous '
          'recursive delete patterns and was blocked by safety checks. '
          'To delete files, use explicit commands targeting specific files '
          '(e.g. Remove-Item path/to/file without -Recurse flag).'
          'If you genuinely need recursive deletion, the user must run '
          'the command manually outside this tool.';
    }

    final result = await runShellProcess(
      executable: 'powershell.exe',
      arguments: ['-Command', command],
      workdir: workdir,
      timeoutSeconds: timeout.effective,
      cancelSignal: cancelSignal,
      command: command,
      clamped: timeout.clamped,
      requestedTimeout: timeout.requested,
    );

    return result;
  }


}
