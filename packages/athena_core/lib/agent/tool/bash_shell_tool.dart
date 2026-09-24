import 'dart:io';

import 'package:athena_core/agent/task/background_task.dart';

import 'shell_background.dart';
import 'shell_runner.dart';
import 'tool_interface.dart';

class BashShellTool implements Tool, CancellableTool {
  /// 默认工作目录。未传入时退化为用户主目录(原有行为)。
  /// 桌面端可注入启动时指定的工作区,让命令默认在项目目录里执行。
  BashShellTool({String? defaultWorkdir, BackgroundTaskService? tasks})
    : _defaultWorkdir = defaultWorkdir,
      _tasks = tasks;

  final String? _defaultWorkdir;

  /// 后台任务登记表。null = 本宿主不支持后台任务（移动端等）。
  final BackgroundTaskService? _tasks;

  @override
  ExecutionMode get executionMode => ExecutionMode.sequential;

  /// shell 统一串行,由审批模式处理完整调用,不推断命令的副作用。
  @override
  bool canExecuteParallel(Map<String, dynamic> args) => false;

  @override
  String get name => 'bash';

  /// 默认目录的措辞。装配期已确定的注入值（TUI 启动参数）直接报出来；
  /// 为 null 时默认目录随会话变化（工作文件夹），而工具描述是构造期的
  /// 静态文本，只能说明优先级，具体路径由运行时上下文声明。
  String get _defaultWorkdirHint =>
      _defaultWorkdir ??
      'the session working folder when one is set, otherwise the user home '
          'directory';

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
      '- Deleting: prefer explicit targets (rm path/to/file). Prefer '
      'multiple explicit paths over recursion. Recursive or otherwise '
      'destructive deletes are not forbidden, but they stop for user '
      'approval before running.\n'
      'For long-running tasks, pass a larger "timeout" value, or pass '
      '"background": true to start it without waiting (it keeps running '
      'after the turn ends; check it with the background_task tool). '
      'Commands run in $_defaultWorkdirHint by default.';

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
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
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
        executable: _resolveShellExecutable(),
        arguments: ['-c', command],
        workdir: workdir,
        command: command,
      );
    }

    final result = await runShellProcess(
      executable: _resolveShellExecutable(),
      arguments: ['-c', command],
      workdir: workdir,
      timeoutSeconds: timeout.effective,
      cancelSignal: cancelSignal,
      command: command,
      clamped: timeout.clamped,
      requestedTimeout: timeout.requested,
    );

    return result;
  }

  /// Windows 下解析可用的 sh 可执行文件。
  ///
  /// `/bin/sh` 是 Git Bash 会话内的虚拟路径，Windows 原生进程 API
  /// 无法解析（`Process.start('/bin/sh')` 报"系统找不到指定的文件"）。
  /// 依次探测：标准安装位置 → PATH 查找（where.exe，兼容 scoop 等
  /// 包管理器）→ 兜底返回原路径（让错误信息保持可读）。
  static String _resolveShellExecutable() {
    if (!Platform.isWindows) return '/bin/sh';
    const candidates = [
      r'C:\Program Files\Git\bin\bash.exe',
      r'C:\Program Files\Git\usr\bin\sh.exe',
      r'C:\Program Files (x86)\Git\bin\bash.exe',
      r'C:\Program Files (x86)\Git\usr\bin\sh.exe',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    try {
      final where = Process.runSync('where.exe', ['sh.exe']);
      if (where.exitCode == 0) {
        final first =
            (where.stdout as String).trim().split('\n').first.trim();
        if (first.isNotEmpty) return first;
      }
    } catch (_) {
      // PATH 查找失败时走兜底。
    }
    return '/bin/sh';
  }


}
