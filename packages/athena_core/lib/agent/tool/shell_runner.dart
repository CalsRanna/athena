import 'dart:async';
import 'dart:io';

import 'package:athena_core/agent/cancel_token.dart';
import 'package:path/path.dart' as p;

/// Shell 工具共享配置：默认与最大超时（秒）。
///
/// 最大超时默认 3600s，可用环境变量 `ATHENA_SHELL_MAX_TIMEOUT`（秒）覆盖，
/// 以便在需要真正长时间运行的任务（大构建、长测试、数据迁移）时无需改代码。
class ShellTimeoutPolicy {
  static const int defaultSeconds = 120;
  static const int minSeconds = 1;

  static const int _defaultMaxSeconds = 3600;
  static const String maxTimeoutEnvVar = 'ATHENA_SHELL_MAX_TIMEOUT';

  /// 解析最大超时：环境变量优先，非法值（非数字或小于默认值）回退默认。
  /// 独立成纯函数便于测试。
  static int resolveMaxSeconds(Map<String, String> env) {
    final raw = env[maxTimeoutEnvVar];
    if (raw == null) return _defaultMaxSeconds;
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed < _defaultMaxSeconds) {
      return _defaultMaxSeconds;
    }
    return parsed;
  }

  static final int maxSeconds = resolveMaxSeconds(Platform.environment);

  /// 把 LLM 传入的 timeout 值 clamp 到 [minSeconds, maxSeconds]，并返回是否做了截断。
  static ({int effective, bool clamped, int? requested}) normalize(int? raw) {
    if (raw == null) {
      return (effective: defaultSeconds, clamped: false, requested: null);
    }
    if (raw < minSeconds) {
      return (effective: minSeconds, clamped: true, requested: raw);
    }
    if (raw > maxSeconds) {
      return (effective: maxSeconds, clamped: true, requested: raw);
    }
    return (effective: raw, clamped: false, requested: raw);
  }
}

/// 共享的参数描述生成（嵌入策略数字，避免散落）。
String shellCommandParamDescription(String shellName) =>
    'The $shellName command to execute. Avoid commands that wait for '
    'interactive user input (they will hang until timeout).';

String shellTimeoutParamDescription() =>
    'Timeout in seconds. '
    'Default ${ShellTimeoutPolicy.defaultSeconds}s. '
    'Maximum ${ShellTimeoutPolicy.maxSeconds}s. '
    'Pick a value based on the command: short queries (git status, ls, '
    'pwd) need ${ShellTimeoutPolicy.defaultSeconds}s; package installs '
    '(npm install, pub get, pip install) typically need 180-300s; full '
    'builds (flutter build, cargo build) often need 300-600s; very long '
    'tasks (large migrations, full test suites) may need up to '
    '${ShellTimeoutPolicy.maxSeconds}s. '
    'If a previous call returned a timeout error, retry with a larger '
    'value (up to ${ShellTimeoutPolicy.maxSeconds}s) before giving up.';

String shellWorkdirParamDescription([String? defaultWorkdir]) =>
    defaultWorkdir == null
    ? 'Working directory for the command. '
          'Defaults to the user home directory.'
    : 'Working directory for the command. Defaults to $defaultWorkdir.';

/// 构建传递给子进程的环境变量，在当前进程环境基础上扩展 PATH，
/// 确保 Homebrew、用户级二进制目录等常见安装路径可被找到。
Map<String, String> _buildEnvironment() {
  final env = Map<String, String>.from(Platform.environment);
  final home = env['HOME'] ?? env['USERPROFILE'] ?? '/';

  // 按优先级排列的额外 PATH 目录（仅当目录实际存在时才加入）
  final candidates = <String>[
    '/opt/homebrew/bin',
    '/opt/homebrew/sbin',
    '/usr/local/bin',
    '/usr/local/sbin',
    p.join(home, '.local', 'bin'),
    p.join(home, '.cargo', 'bin'),
    p.join(home, 'go', 'bin'),
  ];

  final extraPaths = <String>[];
  for (final dir in candidates) {
    if (Directory(dir).existsSync()) {
      extraPaths.add(dir);
    }
  }

  if (extraPaths.isNotEmpty) {
    final currentPath = env['PATH'] ?? '';
    final separator = Platform.isWindows ? ';' : ':';
    env['PATH'] = '${extraPaths.join(separator)}$separator$currentPath';
  }

  return env;
}

/// 用 [Process.start] 跑一个 shell 进程，对超时主动 kill。
///
/// 与 [Process.run] 的关键差异：超时不再只是抛 TimeoutException 任由后台进程
/// 继续跑成为孤儿——这里会显式 [Process.kill]，并在错误信息里告诉 LLM 这是
/// 超时、可以传更大的 timeout 重试。
Future<String> runShellProcess({
  required String executable,
  required List<String> arguments,
  required String workdir,
  required int timeoutSeconds,
  Future<void>? cancelSignal,
  String? command,
  bool clamped = false,
  int? requestedTimeout,
}) async {
  Process process;
  try {
    process = await Process.start(
      executable,
      arguments,
      workingDirectory: workdir,
      environment: _buildEnvironment(),
    );
  } catch (e) {
    return 'Error launching command: $e';
  }

  final stdoutBuffer = StringBuffer();
  final stderrBuffer = StringBuffer();
  final stdoutDone = process.stdout
      .transform(systemEncoding.decoder)
      .listen(stdoutBuffer.write)
      .asFuture<void>();
  final stderrDone = process.stderr
      .transform(systemEncoding.decoder)
      .listen(stderrBuffer.write)
      .asFuture<void>();

  var timedOut = false;
  var cancelled = false;
  int? exitCode;
  final outcome =
      await Future.any<({bool cancelled, int? exitCode, bool timedOut})>([
        process.exitCode.then(
          (code) => (cancelled: false, exitCode: code, timedOut: false),
        ),
        Future.delayed(
          Duration(seconds: timeoutSeconds),
          () => (cancelled: false, exitCode: null, timedOut: true),
        ),
        if (cancelSignal != null)
          cancelSignal.then(
            (_) => (cancelled: true, exitCode: null, timedOut: false),
          ),
      ]);
  exitCode = outcome.exitCode;
  timedOut = outcome.timedOut;
  cancelled = outcome.cancelled;

  if (timedOut || cancelled) {
    // 停止与超时使用同一条进程树终止路径：先温和结束，1 秒后强杀。
    // 仅 kill shell 本身会遗留 sleep/build 等子进程，因此必须处理整棵树。
    exitCode = await _terminateProcessTree(process);
  }

  // 等待 stdout/stderr 流的完成，最多再给 500ms 兜底（防止极端情况下挂住）。
  try {
    await Future.wait([
      stdoutDone,
      stderrDone,
    ]).timeout(const Duration(milliseconds: 500));
  } catch (_) {
    // 忽略：流读取失败不该阻塞结果返回。
  }

  if (cancelled) throw const CancelledException();

  final stdout = stdoutBuffer.toString();
  final stderr = stderrBuffer.toString();
  final buffer = StringBuffer();

  if (timedOut) {
    buffer.writeln(
      'Error: command timed out after ${timeoutSeconds}s and the process was '
      'killed. If this command is expected to take longer, retry with a '
      'larger "timeout" value (max ${ShellTimeoutPolicy.maxSeconds}s).',
    );
    buffer.writeln();
  } else if (clamped && requestedTimeout != null) {
    buffer.writeln(
      'Note: requested timeout ${requestedTimeout}s was clamped to '
      '${timeoutSeconds}s (allowed range '
      '${ShellTimeoutPolicy.minSeconds}-${ShellTimeoutPolicy.maxSeconds}s).',
    );
    buffer.writeln();
  }

  if (stdout.isNotEmpty) {
    buffer.write(stdout);
    if (!stdout.endsWith('\n')) buffer.writeln();
  }
  if (stderr.isNotEmpty) {
    buffer.writeln('[stderr]');
    buffer.write(stderr);
    if (!stderr.endsWith('\n')) buffer.writeln();
  }
  buffer.writeln('[exit code: $exitCode]');
  // Preserve full output; the Agent applies one recoverable output policy.
  return buffer.toString();
}

/// 终止 shell 及其子进程。Windows 用 taskkill /T；Unix 先通过 ps 快照收集
/// 后代 PID，再从叶子到根发送信号，避免只杀 shell 留下构建/测试孤儿进程。
Future<int> _terminateProcessTree(Process process) async {
  await _signalProcessTree(process, force: false);
  try {
    return await process.exitCode.timeout(const Duration(seconds: 1));
  } on TimeoutException {
    await _signalProcessTree(process, force: true);
    try {
      return await process.exitCode.timeout(const Duration(seconds: 1));
    } catch (_) {
      return -1;
    }
  }
}

Future<void> _signalProcessTree(Process process, {required bool force}) async {
  if (Platform.isWindows) {
    try {
      await Process.run('taskkill', [
        '/PID',
        '${process.pid}',
        '/T',
        if (force) '/F',
      ]).timeout(const Duration(seconds: 1));
    } catch (_) {
      process.kill();
    }
    return;
  }

  final descendants = await _unixDescendantPids(process.pid);
  final signal = force ? ProcessSignal.sigkill : ProcessSignal.sigterm;
  for (final pid in descendants.reversed) {
    try {
      Process.killPid(pid, signal);
    } catch (_) {
      // 进程可能已自行退出；继续处理剩余进程。
    }
  }
  process.kill(signal);
}

Future<List<int>> _unixDescendantPids(int rootPid) async {
  try {
    final result = await Process.run('ps', [
      '-axo',
      'pid=,ppid=',
    ]).timeout(const Duration(seconds: 1));
    if (result.exitCode != 0) return const [];

    final childrenByParent = <int, List<int>>{};
    for (final line in result.stdout.toString().split('\n')) {
      final columns = line.trim().split(RegExp(r'\s+'));
      if (columns.length < 2) continue;
      final pid = int.tryParse(columns[0]);
      final parent = int.tryParse(columns[1]);
      if (pid == null || parent == null) continue;
      childrenByParent.putIfAbsent(parent, () => []).add(pid);
    }

    final descendants = <int>[];
    final pending = <int>[rootPid];
    while (pending.isNotEmpty) {
      final parent = pending.removeLast();
      final children = childrenByParent[parent] ?? const <int>[];
      descendants.addAll(children);
      pending.addAll(children);
    }
    return descendants;
  } catch (_) {
    return const [];
  }
}
