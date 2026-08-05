import 'dart:io';

import 'package:athena_core/agent/permission/command_analyzer.dart';

import 'shell_runner.dart';
import 'tool_interface.dart';

class BashShellTool implements Tool {
  /// 默认工作目录。未传入时退化为用户主目录(原有行为)。
  /// 桌面端可注入启动时指定的工作区,让命令默认在项目目录里执行。
  BashShellTool({String? defaultWorkdir}) : _defaultWorkdir = defaultWorkdir;

  final String? _defaultWorkdir;

  @override
  ExecutionMode get executionMode => ExecutionMode.sequential;
  @override
  ToolRisk get risk => ToolRisk.dangerous;

  /// 只读命令（ls、git status 等）可并行执行，有副作用命令必须串行。
  @override
  bool canExecuteParallel(Map<String, dynamic> args) {
    final command = args['command'] as String?;
    return command != null && CommandAnalyzer.isReadOnlyCommand(command);
  }

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
      'Commands run in the ${_defaultWorkdir ?? 'user home'} directory by default.';

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
            'description': shellWorkdirParamDescription(_defaultWorkdir),
          },
        },
        'required': ['command'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args, {void Function(String)? onUpdate}) async {
    final command = args['command'] as String;
    final timeout = ShellTimeoutPolicy.normalize(args['timeout'] as int?);
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    // 优先级:调用参数 > 注入的默认工作目录(工作区) > 用户主目录
    final workdir = args['workdir'] as String? ?? _defaultWorkdir ?? home;

    // 递归删除拦截：用户在弹窗中可以看到完整命令并决定是否放行
    if (_isRecursiveDelete(command)) {
      return 'Warning: This command contains potentially dangerous '
          'recursive delete patterns and was blocked by safety checks. '
          'To delete files, use explicit commands targeting specific files '
          '(e.g. rm file1 file2 without -r flag).'
          'If you genuinely need recursive deletion, the user must run '
          'the command manually outside this tool.';
    }

    final result = await runShellProcess(
      executable: _resolveShellExecutable(),
      arguments: ['-c', command],
      workdir: workdir,
      timeoutSeconds: timeout.effective,
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

  /// 检测递归删除命令模式。
  bool _isRecursiveDelete(String command) {
    final patterns = [
      RegExp(r'\brm\s+.*(?:-[a-zA-Z]*[rR]|--recursive)'),
      RegExp(r'\brmdir\b'),
      RegExp(r'\bfind\b.*\brm\b'),
      // find . -delete / -ok —— 无 rm 字面量也能递归删除
      RegExp(r'\bfind\b.*(?:-delete|-ok\b)'),
      RegExp(r'\bdel\b\s+/[sS]'),
      // Remove-Item 大小写均可（PowerShell 命令不区分大小写）；
      // 覆盖短参数 -R/-r 与别名 ri/rd
      RegExp(r'\bRemove-Item\b\s+.*-Recurse', caseSensitive: false),
      RegExp(r'\bRemove-Item\b\s+.*(?:-[a-zA-Z]*[rR]\b)', caseSensitive: false),
      RegExp(r'\bri\b\s+.*-Recurse', caseSensitive: false),
      RegExp(r'\bri\b\s+.*(?:-[a-zA-Z]*[rR]\b)', caseSensitive: false),
      // cmd 的 rd /s（rmdir 别名；要求 rd 与 /s 之间有空白，
      // 避免误伤 "ls rd/s" 这类路径写法）
      RegExp(r'\brd\b\s+/\s*[sS]'),
      // PowerShell 的 rd -R / rd -Recurse（rmdir 别名）
      RegExp(r'\brd\b\s+.*(?:-Recurse|-[a-zA-Z]*[rR]\b)', caseSensitive: false),
    ];
    return patterns.any((p) => p.hasMatch(command));
  }

}
