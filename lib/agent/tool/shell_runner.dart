import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Shell 工具共享配置：默认与最大超时（秒）。
class ShellTimeoutPolicy {
  static const int defaultSeconds = 120;
  static const int maxSeconds = 600;
  static const int minSeconds = 1;

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

String shellTimeoutParamDescription() => 'Timeout in seconds. '
    'Default ${ShellTimeoutPolicy.defaultSeconds}s. '
    'Maximum ${ShellTimeoutPolicy.maxSeconds}s. '
    'Pick a value based on the command: short queries (git status, ls, '
    'pwd) need ${ShellTimeoutPolicy.defaultSeconds}s; package installs '
    '(npm install, pub get, pip install) typically need 180-300s; full '
    'builds (flutter build, cargo build) often need 300-600s. '
    'If a previous call returned a timeout error, retry with a larger '
    'value (up to ${ShellTimeoutPolicy.maxSeconds}s) before giving up.';

String shellWorkdirParamDescription() =>
    'Working directory for the command. Defaults to the user home directory.';

/// 输出截断上限。超过任一条目即触发头尾保留 + 中间省略。
class OutputLimit {
  static const int maxLines = 100;
  static const int maxChars = 5000;
}

/// 根据命令的第一个 token 推断缩小输出的建议。
String _hintForCommand(String? command) {
  if (command == null || command.isEmpty) return _defaultHint;
  final firstWord = command.trim().split(RegExp(r'[\s|;&]')).first.toLowerCase();
  return switch (firstWord) {
    'grep' || 'rg' || 'select-string' || 'findstr' =>
      'Pipe to head (| head -100) or add --include / --glob to narrow matches.',
    'ls' || 'dir' || 'get-childitem' || 'find' =>
      'Limit depth (e.g. -maxdepth 2 for find) or pipe to head.',
    'cat' || 'type' || 'get-content' || 'tail' || 'head' =>
      'Use offset/limit with file_read tool, or pipe to head/tail.',
    _ => _defaultHint,
  };
}

const _defaultHint =
    'Narrow output with grep, head, tail, or redirect to a file and read with file_read.';

/// 保留输出头尾，截断中间并告知 LLM 原因和缩小范围的建议。
String _truncateOutput(String output, String? command) {
  final lines = output.split('\n');
  if (lines.length <= OutputLimit.maxLines &&
      output.length <= OutputLimit.maxChars) {
    return output;
  }
  final headLines = (OutputLimit.maxLines * 0.6).round();
  final tailLines = OutputLimit.maxLines - headLines;
  final head = lines.take(headLines).join('\n');
  final tail = lines.skip(lines.length - tailLines).join('\n');
  final skippedLines = lines.length - headLines - tailLines;
  return '$head\n'
      '\n'
      '[output truncated: $skippedLines lines / ${output.length - OutputLimit.maxChars} chars skipped '
      '(limit ${OutputLimit.maxLines} lines / ${OutputLimit.maxChars} chars)]\n'
      'Hint: ${_hintForCommand(command)}\n'
      '\n'
      '$tail';
}

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
  int? exitCode;
  try {
    exitCode = await process.exitCode.timeout(
      Duration(seconds: timeoutSeconds),
    );
  } on TimeoutException {
    timedOut = true;
    // 主动杀掉进程，避免孤儿。先 SIGTERM，给一秒清理时间再 SIGKILL。
    process.kill(ProcessSignal.sigterm);
    try {
      exitCode = await process.exitCode.timeout(const Duration(seconds: 1));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      try {
        exitCode = await process.exitCode;
      } catch (_) {
        exitCode = -1;
      }
    }
  }

  // 等待 stdout/stderr 流的完成，最多再给 500ms 兜底（防止极端情况下挂住）。
  try {
    await Future.wait([stdoutDone, stderrDone])
        .timeout(const Duration(milliseconds: 500));
  } catch (_) {
    // 忽略：流读取失败不该阻塞结果返回。
  }

  final stdout = stdoutBuffer.toString().trim();
  final stderr = stderrBuffer.toString().trim();
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
    buffer.writeln(stdout);
  }
  if (stderr.isNotEmpty) {
    buffer.writeln('[stderr]');
    buffer.writeln(stderr);
  }
  buffer.writeln('[exit code: $exitCode]');
  return _truncateOutput(buffer.toString().trim(), command);
}
