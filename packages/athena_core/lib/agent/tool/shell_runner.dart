import 'dart:async';
import 'dart:collection';
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

/// Shell 输出在内存里的保留上限：**内存护栏，不是输出策略**。
///
/// 输出策略（内联上限 24000 字符、超长转存 `tool_outputs/` 供
/// `tool_output_read` 分页取回）在 ToolOutputStore 里，不在这里。这里只挡一种
/// 情况：`cat` 一个几百 MB 的文件时，把整份输出攒进内存、等着那个策略生效，
/// 进程先被 OOM 杀掉——策略再能兜底也没机会跑。
///
/// 上限取「远超内联上限、又小到不撑爆内存」：单流 2 MiB 以内逐字完整保留，
/// 常规调用完全不受影响。越界后保留头部 1 MiB 与尾部 1 MiB——shell 输出的两头
/// 最有信息量（开头是上下文，结尾往往是报错），中间丢了多少字符会显式写进结果
/// 交给模型，让它换更窄的命令重跑，而不是收到一份看起来完整、实际被悄悄砍掉的
/// 输出。
///
/// 被否决的方案：把完整输出流式落盘、让上层按文件处理。那才是这里原本的
/// 「保留完整输出」想要的形态，但要把 runShellProcess 的返回值、shell 工具与
/// ToolOutputStore.prepare 一起改成文件形态，属管线级改动，不该混进「先止住
/// 内存风险」这一次里。上限在此是过渡手段。
abstract final class ShellOutputPolicy {
  /// 单流保留的头部字符数。
  static const int headChars = 1 << 20;

  /// 单流保留的尾部字符数（滚动窗口）。
  static const int tailChars = 1 << 20;

  /// 单流保留的总字符数；未越界时输出逐字完整。
  static const int budgetChars = headChars + tailChars;
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
    ? 'Working directory for the command. Defaults to the session working '
          'folder when one is set (see the runtime context), otherwise to '
          'the user home directory.'
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

/// 启动 shell 进程但不等待它结束（后台任务的启动路径）。
///
/// 与 [runShellProcess] 共用同一份环境变量与工作目录口径，只是把
/// 「等到退出/超时/取消」这一步交给调用方：后台任务的退出由
/// BackgroundTaskService 观察。
Future<Process> startShellProcess({
  required String executable,
  required List<String> arguments,
  required String workdir,
}) => Process.start(
  executable,
  arguments,
  workingDirectory: workdir,
  environment: _buildEnvironment(),
);

/// 终止 [process] 及其全部后代进程，返回退出码。
///
/// 与前台 shell 的超时/取消共用同一条路径：只 kill shell 本身会遗留
/// 构建/测试等子进程。
Future<int> terminateShellProcessTree(Process process) =>
    _terminateProcessTree(process);

/// 按 pid 终止一棵进程树，供「上次进程被强杀后遗留的孤儿」清理使用。
///
/// 调用方必须先确认该 pid 上的进程确实是本应用启动的任务（孤儿记录里的
/// 命令行比对），否则 pid 复用会误杀无关进程。
Future<void> terminateShellProcessTreeByPid(int pid) async {
  if (Platform.isWindows) {
    try {
      await Process.run('taskkill', [
        '/PID',
        '$pid',
        '/T',
        '/F',
      ]).timeout(const Duration(seconds: 2));
    } catch (_) {
      // 进程可能已退出；孤儿清理是尽力而为。
    }
    return;
  }

  final descendants = await _unixDescendantPids(pid);
  for (final child in descendants.reversed) {
    try {
      Process.killPid(child, ProcessSignal.sigterm);
    } catch (_) {
      // 已退出。
    }
  }
  var alive = true;
  try {
    alive = Process.killPid(pid, ProcessSignal.sigterm);
  } catch (_) {
    alive = false;
  }
  if (!alive) return;
  await Future<void>.delayed(const Duration(seconds: 1));
  try {
    // 仍在运行（忽略 SIGTERM 的构建进程）时强杀。
    if (Process.killPid(pid, ProcessSignal.sigterm)) {
      final remaining = await _unixDescendantPids(pid);
      for (final child in remaining.reversed) {
        try {
          Process.killPid(child, ProcessSignal.sigkill);
        } catch (_) {
          // 已退出。
        }
      }
      Process.killPid(pid, ProcessSignal.sigkill);
    }
  } catch (_) {
    // 已退出。
  }
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

  // 两个流各用一份带上限的捕获器。为什么必须有上限、为什么被截断后仍要
  // 继续读取，都写在 _CappedOutputCapture 上。
  final stdoutCapture = _CappedOutputCapture();
  final stderrCapture = _CappedOutputCapture();
  final stdoutDone = process.stdout
      .transform(systemEncoding.decoder)
      .listen(stdoutCapture.add)
      .asFuture<void>();
  final stderrDone = process.stderr
      .transform(systemEncoding.decoder)
      .listen(stderrCapture.add)
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

  if (stdoutCapture.isNotEmpty) {
    _writeCaptured(buffer, stdoutCapture);
  }
  if (stderrCapture.isNotEmpty) {
    buffer.writeln('[stderr]');
    _writeCaptured(buffer, stderrCapture);
  }
  buffer.writeln('[exit code: $exitCode]');
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

/// 按 [ShellOutputPolicy] 的额度累积一路输出：未越界时逐字完整，越界后只留
/// 头部与滚动尾部，中间丢弃的字符数记在账上（见 [finish]）。
///
/// **越界之后仍要继续读取。** 停止消费管道会让子进程写满 pipe buffer 后永久
/// 阻塞：命令不退出，只能等超时被杀，比丢数据更糟。宁可丢数据也不能不排空。
class _CappedOutputCapture {
  /// 未越界前保留完整内容；越界后置 null，改由 [_head] 与 [_tail] 承担，
  /// 内存不再随输出长度增长。
  StringBuffer? _full = StringBuffer();
  String? _head;
  final Queue<String> _tail = Queue<String>();
  int _tailLength = 0;
  int _total = 0;

  bool get isNotEmpty => _total > 0;

  void add(String chunk) {
    if (chunk.isEmpty) return;
    _total += chunk.length;

    final full = _full;
    if (full != null) {
      full.write(chunk);
      if (_total <= ShellOutputPolicy.budgetChars) return;
      // 刚越界：切成头部 + 滚动尾部，随即释放完整副本。
      final text = full.toString();
      _head = text.substring(0, ShellOutputPolicy.headChars);
      final rest = text.substring(ShellOutputPolicy.headChars);
      _tail.add(rest);
      _tailLength = rest.length;
      _full = null;
      _trimTail();
      return;
    }

    _tail.add(chunk);
    _tailLength += chunk.length;
    _trimTail();
  }

  /// 只保留「扔掉队首之后仍有 [ShellOutputPolicy.tailChars] 可用」的块——
  /// 滚动窗口的不变式。
  void _trimTail() {
    while (_tail.length > 1 &&
        _tailLength - _tail.first.length >= ShellOutputPolicy.tailChars) {
      _tailLength -= _tail.removeFirst().length;
    }
  }

  /// [head] 与 [tail] 是保留下来的两段，[dropped] 是被丢弃的字符数。
  /// 未越界时 [head] 即全部内容、[tail] 为空、[dropped] 为 0。
  ({String head, String tail, int dropped}) finish() {
    final full = _full;
    if (full != null) return (head: full.toString(), tail: '', dropped: 0);

    final joined = _tail.join();
    final tail = joined.length <= ShellOutputPolicy.tailChars
        ? joined
        : joined.substring(joined.length - ShellOutputPolicy.tailChars);
    final head = _head ?? '';
    return (
      head: head,
      tail: tail,
      dropped: _total - head.length - tail.length,
    );
  }
}

/// 写入一段捕获到的输出；被截断时在头部与尾部之间显式说明丢了多少。
///
/// 文案是给模型看的（英文），并给出可执行的下一步：换更窄的命令重跑，而不是
/// 让它以为拿到的就是全部。
void _writeCaptured(StringBuffer buffer, _CappedOutputCapture capture) {
  final captured = capture.finish();
  if (captured.head.isNotEmpty) {
    buffer.write(captured.head);
    if (!captured.head.endsWith('\n')) buffer.writeln();
  }
  if (captured.dropped <= 0) return;

  buffer.writeln(
    '[output truncated: ${captured.dropped} characters dropped from the '
    'middle; showing the first ${captured.head.length} and the last '
    '${captured.tail.length}. Re-run with a narrower command '
    '(head / tail / grep) to read the missing part.]',
  );
  buffer.write(captured.tail);
  if (!captured.tail.endsWith('\n')) buffer.writeln();
}
