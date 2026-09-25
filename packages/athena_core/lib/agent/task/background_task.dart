import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/tool/shell_runner.dart' as shell;
import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:path/path.dart' as p;

/// 后台任务状态。
enum BackgroundTaskStatus {
  /// 进程仍在运行。
  running,

  /// 正常退出（退出码 0）。
  completed,

  /// 以非零退出码结束。
  failed,

  /// 被用户/会话停止，或随 run 取消而终止。与 [failed] 区分：用户需要知道
  /// 是「我停的」还是「它自己挂了」。
  cancelled,

  /// 进程尚未成功启动（可执行文件不可用等）。
  launchFailed,
}

/// 任务结束是否应当触发一次自动汇报。
///
/// 只汇报真正跑完的任务：[BackgroundTaskStatus.cancelled] 是用户刚按下的
/// 停止（或被删除会话连带停止），再起一个回合只会让用户在按下停止后收到
/// 「任务已取消」的报告；[BackgroundTaskStatus.launchFailed] 在工具调用
/// 当场就已经回给模型了。
bool shouldReportTaskCompletion(BackgroundTask task) =>
    task.status == BackgroundTaskStatus.completed ||
    task.status == BackgroundTaskStatus.failed;

/// 一个后台任务：命令、进程、持续累积的输出与终态。
///
/// 输出保留在内存中直到任务被清理，**停止任务不丢已产生的输出**——
/// 这是「取消即杀」能被接受的前提：杀掉的是进程，不是证据。
class BackgroundTask {
  BackgroundTask({
    required this.id,
    required this.chatId,
    required this.command,
    required this.workdir,
    required this.startedAt,
  });

  /// 面向前后端的短 id（bg-1、bg-2…）：模型要把它写进工具调用参数。
  final String id;
  final int chatId;
  final String command;
  final String workdir;
  final DateTime startedAt;

  BackgroundTaskStatus status = BackgroundTaskStatus.running;
  int? exitCode;
  DateTime? finishedAt;

  /// 进程启动失败的说明（仅 [BackgroundTaskStatus.launchFailed]）。
  String? launchError;

  Process? _process;

  final StringBuffer _stdout = StringBuffer();
  final StringBuffer _stderr = StringBuffer();

  bool get isRunning => status == BackgroundTaskStatus.running;

  int get outputLength => _stdout.length + _stderr.length;

  Duration get elapsed => (finishedAt ?? DateTime.now()).difference(startedAt);

  /// 与前台 shell 结果同一格式：stdout 在前，stderr 单独成段。
  String get output {
    final buffer = StringBuffer(_stdout.toString());
    final stderr = _stderr.toString();
    if (stderr.isNotEmpty) {
      if (buffer.isNotEmpty && !buffer.toString().endsWith('\n')) {
        buffer.writeln();
      }
      buffer.writeln('[stderr]');
      buffer.write(stderr);
    }
    return buffer.toString();
  }

  /// 分页读取（按 Unicode 码点计数，与 tool_output_read 同一口径）。
  ({String text, int nextOffset, bool hasMore}) page({
    int offset = 0,
    required int limit,
  }) {
    final text = output;
    final runes = text.runes;
    final total = runes.length;
    if (offset >= total) {
      return (text: '', nextOffset: total, hasMore: false);
    }
    final take = runes.skip(offset).take(limit).toList();
    final next = offset + take.length;
    return (
      text: String.fromCharCodes(take),
      nextOffset: next,
      hasMore: next < total,
    );
  }

  /// 状态行：任务列表与工具结果都用它，保证口径一致。
  String get statusLine {
    final buffer = StringBuffer(_statusLabel(status));
    final code = exitCode;
    if (code != null) buffer.write(' (exit code $code)');
    buffer.write(
      ', elapsed ${elapsed.inSeconds}s, '
      '$outputLength characters of output',
    );
    final error = launchError;
    if (error != null) buffer.write(', $error');
    return buffer.toString();
  }

  static String _statusLabel(BackgroundTaskStatus status) => switch (status) {
    BackgroundTaskStatus.running => 'running',
    BackgroundTaskStatus.completed => 'completed',
    BackgroundTaskStatus.failed => 'failed',
    BackgroundTaskStatus.cancelled => 'cancelled',
    BackgroundTaskStatus.launchFailed => 'launch failed',
  };

  void _attach(Process process) {
    _process = process;
  }

  void _appendStdout(String chunk) => _stdout.write(chunk);

  void _appendStderr(String chunk) => _stderr.write(chunk);
}

/// 后台任务登记表。
///
/// 按会话归属（不是按 run）：run 正常结束不杀任务，用户取消 run / 删除会话 /
/// 优雅退出才杀。归属会话而非 run，是因为「取消」在用户那里是「这个会话先停下」
/// 而不是「这一轮先停下」。
///
/// 单例由 [ToolRegistry] 持有（与 [ToolOutputStore] 同级），工具与协调层共用。
class BackgroundTaskService {
  BackgroundTaskService({
    DateTime Function()? now,
    Directory? stateDirectory,
    this.maxRetainedPerChat = 20,
  }) : _now = now ?? DateTime.now,
       _stateDirectory = stateDirectory;

  final DateTime Function() _now;

  /// 孤儿记录目录（null = 不记录：该宿主放弃跨进程清理）。
  final Directory? _stateDirectory;

  /// 每个会话保留的已完成任务上限（运行中的永不淘汰）。
  final int maxRetainedPerChat;

  final List<BackgroundTask> _tasks = [];
  final StreamController<BackgroundTask> _completions =
      StreamController<BackgroundTask>.broadcast();

  /// 任务 id → stdout/stderr 排空 future（终态前等待，见 [_onExit]）。
  final Map<String, Future<void>> _drains = {};

  int _nextId = 0;

  /// 任务结束（含被停止）时发出，供协调层决定是否自动汇报。
  Stream<BackgroundTask> get completions => _completions.stream;

  List<BackgroundTask> tasksOf(int chatId) =>
      _tasks.where((t) => t.chatId == chatId).toList();

  BackgroundTask? task(String id, {int? chatId}) {
    for (final task in _tasks) {
      if (task.id == id && (chatId == null || task.chatId == chatId)) {
        return task;
      }
    }
    return null;
  }

  List<BackgroundTask> get runningTasks =>
      _tasks.where((t) => t.isRunning).toList();

  /// 启动一个后台任务，**立即返回**（不等待进程结束）。
  Future<BackgroundTask> start({
    required int chatId,
    required String executable,
    required List<String> arguments,
    required String workdir,
    required String command,
  }) async {
    final task = BackgroundTask(
      id: 'bg-${++_nextId}',
      chatId: chatId,
      command: command,
      workdir: workdir,
      startedAt: _now(),
    );
    _tasks.add(task);

    Process process;
    try {
      process = await shell.startShellProcess(
        executable: executable,
        arguments: arguments,
        workdir: workdir,
      );
    } catch (e) {
      task.launchError = 'Error launching command: $e';
      _finish(task, BackgroundTaskStatus.launchFailed);
      return task;
    }

    task._attach(process);
    await _writeOrphanState();
    final stdoutDone = process.stdout
        .transform(systemEncoding.decoder)
        .listen(task._appendStdout, onError: (_) {})
        .asFuture<void>()
        .catchError((Object _) {});
    final stderrDone = process.stderr
        .transform(systemEncoding.decoder)
        .listen(task._appendStderr, onError: (_) {})
        .asFuture<void>()
        .catchError((Object _) {});
    // 输出排空早于终态：「已结束但输出为空」会同时误导模型与汇报回合，
    // 所以 exitCode 回调先等这两条流收尾再记账。
    _drains[task.id] = Future.wait<void>([
      stdoutDone,
      stderrDone,
    ]).then((_) {}, onError: (Object _) {});
    unawaited(
      process.exitCode.then(
        (code) => _onExit(task, code),
        onError: (Object error) => _onExit(task, null, error: error),
      ),
    );
    _prune();
    return task;
  }

  /// 停止单个任务。返回是否真的停掉了一个运行中的任务。
  Future<bool> stop(String taskId, {int? chatId}) async {
    final task = this.task(taskId, chatId: chatId);
    if (task == null || !task.isRunning) return false;
    await _stopTask(task);
    return true;
  }

  /// 停止一个会话的全部后台任务（取消 run / 删除会话 / 优雅退出）。
  ///
  /// 返回被停止的任务数，供 UI 明确告知「已同时停止 N 个后台任务」——
  /// 静默杀会让用户以为构建还在跑。
  Future<int> stopChatTasks(int chatId) async {
    final running = tasksOf(chatId).where((t) => t.isRunning).toList();
    for (final task in running) {
      await _stopTask(task);
    }
    return running.length;
  }

  /// 停止所有会话的后台任务（应用退出）。
  Future<int> stopAll() async {
    final running = runningTasks;
    for (final task in running) {
      await _stopTask(task);
    }
    return running.length;
  }

  /// 清理上次进程被强杀（崩溃 / kill -9）后遗留的孤儿进程。
  ///
  /// 强杀时 Dart 侧没有机会执行 [stopAll]，子进程会被 reparent 给 launchd
  /// 继续跑。这里在启动时按记录核对并清理：只有 pid 存活且命令行与记录的
  /// 命令一致才动手——pid 复用是真实存在的，不能只凭 pid 杀。
  ///
  /// 无法避免孤儿（强杀时没有钩子可挂），只能发现并清理，因此崩溃期间
  /// 遗留的副作用窗口是这套设计的已知残余，需在文档中如实标注。
  ///
  /// GUI 与 TUI（以及多个 TUI）共用登记表：属主进程（`owner_pid`）仍在运行
  /// 的记录是**另一个活着的实例**的任务，原样保留、不许杀——只凭「任务 pid
  /// 活着且命令行匹配」会在打开第二个实例时杀掉第一个实例正在跑的任务。
  Future<int> recoverOrphans() async {
    var killed = 0;
    await _updateOrphanState(
      recover: (entries) async {
        final keep = <Map<String, dynamic>>[];
        for (final entry in entries) {
          final pidValue = entry['pid'];
          final command = entry['command'];
          if (pidValue is! int || command is! String) continue;
          final owner = entry['owner_pid'];
          if (owner is int && owner != pid && await _isLiveAthena(owner)) {
            keep.add(entry);
            continue;
          }
          if (!await _isOurProcess(pidValue, command)) continue;
          LoggerUtil.w(
            'Killing orphaned background task process $pidValue ($command)',
          );
          await shell.terminateShellProcessTreeByPid(pidValue);
          killed++;
        }
        return keep;
      },
    );
    return killed;
  }

  Future<void> dispose() async {
    await _completions.close();
  }

  // ─── 内部 ─────────────────────────────────────────────────

  Future<void> _stopTask(BackgroundTask task) async {
    // 先落终态再杀：exitCode 回调随后到达时不能再按「正常结束」触发汇报。
    _finish(task, BackgroundTaskStatus.cancelled);
    final process = task._process;
    if (process != null) {
      try {
        task.exitCode = await shell.terminateShellProcessTree(process);
      } catch (e) {
        LoggerUtil.w('Failed to stop background task ${task.id}: $e');
      }
    }
    await _writeOrphanState();
  }

  void _onExit(BackgroundTask task, int? code, {Object? error}) {
    if (!task.isRunning) return;
    task.exitCode = code;
    final status = error != null
        ? BackgroundTaskStatus.failed
        : (code == 0
              ? BackgroundTaskStatus.completed
              : BackgroundTaskStatus.failed);
    final drain = _drains.remove(task.id);
    if (drain == null) {
      _finish(task, status);
      unawaited(_writeOrphanState());
      return;
    }
    // 输出排空早于终态：否则「已结束但输出为空」会同时误导模型与汇报回合。
    // 上限 1s 兜底，极端情况下不让一个挂住的流卡住终态。
    unawaited(
      drain.timeout(const Duration(seconds: 1), onTimeout: () {}).then((_) {
        if (!task.isRunning) return;
        _finish(task, status);
        unawaited(_writeOrphanState());
      }),
    );
  }

  void _finish(BackgroundTask task, BackgroundTaskStatus status) {
    if (!task.isRunning) return;
    task.status = status;
    task.finishedAt = _now();
    _prune();
    if (!_completions.isClosed) _completions.add(task);
  }

  /// 淘汰最老的已完成任务，避免长时间运行的应用无限累积输出。
  void _prune() {
    final byChat = <int, List<BackgroundTask>>{};
    for (final task in _tasks) {
      byChat.putIfAbsent(task.chatId, () => []).add(task);
    }
    for (final entry in byChat.entries) {
      final finished = entry.value.where((t) => !t.isRunning).toList()
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
      final excess = finished.length - maxRetainedPerChat;
      for (var i = 0; i < excess; i++) {
        _tasks.remove(finished[i]);
      }
    }
  }

  static const _orphanFileName = 'background_tasks.json';

  /// 记录当前运行中的任务（pid + 命令行），供下次启动清理孤儿。
  Future<void> _writeOrphanState() => _updateOrphanState();

  /// 在登记表的跨进程锁内「读磁盘 → 保留别的实例的记录 → 换上本进程当前
  /// 运行中的任务 → 原子写回」。每个进程只拥有 `owner_pid` 是自己的记录，
  /// 整表覆盖会抹掉另一个实例的任务，它崩溃后遗留的进程就再也清理不到。
  ///
  /// [recover] 为 null 时保留所有非本进程的记录；否则把「除本进程当前任务
  /// 以外的全部记录」交给它，只保留它返回的（启动时的孤儿清理）。
  Future<void> _updateOrphanState({
    Future<List<Map<String, dynamic>>> Function(
      List<Map<String, dynamic>> entries,
    )? recover,
  }) async {
    final dir = _stateDirectory;
    if (dir == null) return;
    final file = File(p.join(dir.path, _orphanFileName));
    try {
      await withFileLock(lockFileFor(file), () async {
        final mine = <Map<String, Object?>>[];
        for (final task in runningTasks) {
          final taskPid = task._process?.pid;
          if (taskPid == null) continue;
          mine.add({
            'id': task.id,
            'pid': taskPid,
            'owner_pid': pid,
            'command': task.command,
            'chat_id': task.chatId,
            'started_at': task.startedAt.toIso8601String(),
          });
        }
        final minePids = {for (final entry in mine) entry['pid']};

        final onDisk = await _readOrphanEntries(file);
        final List<Map<String, dynamic>> others;
        if (recover == null) {
          others = [
            for (final entry in onDisk)
              if (entry['owner_pid'] != pid) entry,
          ];
        } else {
          // 与本进程同 pid 的旧记录来自 pid 复用的上一个实例，同样是孤儿
          // 候选；只有本进程此刻真正在跑的任务不交给清理
          others = await recover([
            for (final entry in onDisk)
              if (!(entry['owner_pid'] == pid &&
                  minePids.contains(entry['pid'])))
                entry,
          ]);
        }
        await atomicWriteString(file, jsonEncode([...others, ...mine]));
      });
    } catch (e) {
      // 孤儿记录是尽力而为：写不进去不该影响任务的启动与停止。
      LoggerUtil.w('Failed to record background task state: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> _readOrphanEntries(
    File file,
  ) async {
    if (!await file.exists()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is List
          ? decoded.whereType<Map<String, dynamic>>().toList()
          : [];
    } catch (e) {
      LoggerUtil.w('Background task orphan state unreadable: $e');
      return [];
    }
  }

  /// [ownerPid] 是否是一个仍在运行的 Athena 实例（GUI 或 TUI）。
  ///
  /// 除了存活还要求命令行里带 `athena`：属主退出后 pid 被别的程序复用时，
  /// 它的任务才会被认定为孤儿。Windows 无法免依赖地查询命令行，按「不在
  /// 运行」处理——那里 [_isOurProcess] 本就不杀进程，只是丢掉记录。
  Future<bool> _isLiveAthena(int ownerPid) async {
    if (Platform.isWindows) return false;
    try {
      final result = await Process.run('ps', [
        '-o',
        'command=',
        '-p',
        '$ownerPid',
      ]).timeout(const Duration(seconds: 2));
      if (result.exitCode != 0) return false;
      return result.stdout.toString().toLowerCase().contains('athena');
    } catch (_) {
      return false;
    }
  }

  /// pid 是否仍是「我们记录的那条命令」。
  ///
  /// Windows 没有免依赖的命令行查询能力，直接放弃核对（返回 false），
  /// 宁可漏清也不误杀。
  Future<bool> _isOurProcess(int pid, String command) async {
    if (Platform.isWindows) return false;
    try {
      final result = await Process.run('ps', [
        '-o',
        'command=',
        '-p',
        '$pid',
      ]).timeout(const Duration(seconds: 2));
      if (result.exitCode != 0) return false;
      final line = result.stdout.toString().trim();
      if (line.isEmpty) return false;
      // 记录的是 shell -c <command>，命令行里应包含原命令文本。
      final head = command.length > 40 ? command.substring(0, 40) : command;
      return line.contains(head);
    } catch (_) {
      return false;
    }
  }
}
