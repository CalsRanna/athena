import 'dart:async';
import 'dart:io';

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
  bool clamped = false,
  int? requestedTimeout,
}) async {
  Process process;
  try {
    process = await Process.start(
      executable,
      arguments,
      workingDirectory: workdir,
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
  return buffer.toString().trim();
}
