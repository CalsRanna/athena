import 'dart:io';

import 'package:athena_core/agent/permission/command_analyzer.dart';
import 'package:athena_core/agent/task/background_task.dart';
import 'package:athena_core/agent/tool/shell_runner.dart';

import 'shell_background.dart';
import 'tool_interface.dart';

class PowerShellShellTool implements Tool, CancellableTool {
  /// 默认工作目录。未传入时退化为用户主目录(原有行为)。
  /// 桌面端可注入启动时指定的工作区,让命令默认在项目目录里执行。
  PowerShellShellTool({String? defaultWorkdir, BackgroundTaskService? tasks})
    : _defaultWorkdir = defaultWorkdir,
      _tasks = tasks;

  final String? _defaultWorkdir;

  /// 后台任务登记表。null = 本宿主不支持后台任务。
  final BackgroundTaskService? _tasks;

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
      '- Deleting: prefer explicit targets (Remove-Item path). Prefer '
      'multiple explicit paths over recursion. Recursive or otherwise '
      'destructive deletes are not forbidden, but they stop for user '
      'approval before running.\n'
      'For long-running tasks, pass a larger "timeout" value, or pass '
      '"background": true to start it without waiting (it keeps running '
      'after the turn ends; check it with the background_task tool). '
      'Commands run in $_defaultWorkdirHint by default.';

  /// 默认目录的措辞。装配期已确定的注入值（TUI 启动参数）直接报出来；
  /// 为 null 时默认目录随会话变化（工作文件夹），而工具描述是构造期的
  /// 静态文本，只能说明优先级，具体路径由运行时上下文声明。
  String get _defaultWorkdirHint =>
      _defaultWorkdir ??
      'the session working folder when one is set, otherwise the user home '
          'directory';

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
          'background': {
            'type': 'boolean',
            'description':
                'Run the command in the background: the call returns '
                'immediately with a task id instead of waiting, and the '
                'command keeps running after this turn ends (timeout does not '
                'apply). Use it for long builds, test suites and installs, '
                'then keep working; read progress with the background_task '
                'tool. Say so in call_description: the user approving it must '
                'know the command will keep running after the turn.',
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

    if (args['background'] == true) {
      final tasks = _tasks;
      if (tasks == null) {
        return 'Error: background tasks are not available in this host.';
      }
      return startBackgroundShellTask(
        tasks: tasks,
        args: args,
        executable: 'powershell.exe',
        arguments: ['-Command', command],
        workdir: workdir,
        command: command,
      );
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
