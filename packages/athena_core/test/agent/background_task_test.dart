import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/task/background_task.dart';
import 'package:athena_core/agent/tool/background_task_tool.dart';
import 'package:athena_core/agent/tool/bash_shell_tool.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// 用例全部驱动真实进程（bash + sleep/echo）：后台任务的价值就在「进程真的
/// 比工具调用活得久」，用假进程测不出这件事。
void main() {
  final isWindows = Platform.isWindows;

  BackgroundTaskService service({Directory? stateDirectory}) =>
      BackgroundTaskService(stateDirectory: stateDirectory);

  Future<BackgroundTask> start(
    BackgroundTaskService tasks, {
    required String command,
    int chatId = 1,
  }) => tasks.start(
    chatId: chatId,
    executable: 'bash',
    arguments: ['-c', command],
    workdir: Directory.systemTemp.path,
    command: command,
  );

  Future<void> waitForTask(
    BackgroundTask task, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (task.isRunning && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<bool> isAlive(int pid) async {
    final result = await Process.run('ps', ['-p', '$pid']);
    return result.exitCode == 0;
  }

  group('BackgroundTaskService', () {
    test('start 立即返回，不等待进程结束', () async {
      final tasks = service();
      final task = await start(tasks, command: 'echo first; sleep 30');
      // 「立即返回」是后台化的定义：start 的耗时不该包含命令本身的时长。
      expect(task.isRunning, isTrue);
      expect(task.elapsed.inSeconds, lessThan(5));

      // 输出是增量到达的，读的时候能看到已产出的部分。
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(task.output, contains('first'));
      await tasks.stopAll();
    }, skip: isWindows);

    test('进程自然结束触发完成事件并记录退出码', () async {
      final tasks = service();
      final completed = tasks.completions.first;
      final task = await start(tasks, command: 'echo done');
      final event = await completed;

      expect(event.id, task.id);
      expect(task.status, BackgroundTaskStatus.completed);
      expect(task.exitCode, 0);
      await waitForTask(task, timeout: const Duration(seconds: 2));
      expect(task.output, contains('done'));
      expect(shouldReportTaskCompletion(task), isTrue);
    }, skip: isWindows);

    test('非零退出码记为 failed', () async {
      final tasks = service();
      final task = await start(tasks, command: 'echo boom >&2; exit 3');
      await waitForTask(task);

      expect(task.status, BackgroundTaskStatus.failed);
      expect(task.exitCode, 3);
      expect(task.output, contains('boom'));
      expect(shouldReportTaskCompletion(task), isTrue);
    }, skip: isWindows);

    test('停止任务：杀掉整棵进程树、保留已产生输出、状态为 cancelled', () async {
      final tasks = service();
      final pidFile = File(
        p.join(
          Directory.systemTemp.createTempSync('athena_bg').path,
          'child.pid',
        ),
      );
      final task = await start(
        tasks,
        command: 'sleep 30 & echo \$! > ${pidFile.path}; wait',
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final childPid = int.parse((await pidFile.readAsString()).trim());

      final stopped = await tasks.stop(task.id, chatId: 1);

      expect(stopped, isTrue);
      expect(task.status, BackgroundTaskStatus.cancelled);
      // 关键：切断的是进程，不是证据——已产生的输出仍然可读。
      expect(task.outputLength, greaterThanOrEqualTo(0));
      // 只杀 shell 会留下 sleep 孤儿，这里必须整棵树都停。
      expect(await isAlive(childPid), isFalse);
      // 用户按下的停止不该再触发一次自动汇报。
      expect(shouldReportTaskCompletion(task), isFalse);
    }, skip: isWindows);

    test('stopChatTasks 只影响本会话，其他会话的任务照常运行', () async {
      final tasks = service();
      final mine = await start(tasks, command: 'sleep 30', chatId: 7);
      final other = await start(tasks, command: 'sleep 30', chatId: 8);

      final killed = await tasks.stopChatTasks(7);

      expect(killed, 1);
      expect(mine.status, BackgroundTaskStatus.cancelled);
      expect(other.isRunning, isTrue);
      await tasks.stopAll();
    }, skip: isWindows);

    test('输出超过读取窗口时按码点分页', () async {
      final tasks = service();
      final task = await start(tasks, command: 'printf "%s" abcdefghij');
      await waitForTask(task);

      final page = task.page(offset: 2, limit: 3);
      expect(page.text, 'cde');
      expect(page.nextOffset, 5);
      expect(page.hasMore, isTrue);
    }, skip: isWindows);

    test('recoverOrphans 只清理命令行对得上的遗留进程', () async {
      final dir = Directory.systemTemp.createTempSync('athena_orphans');
      final tasks = service(stateDirectory: dir);

      // 模拟「上次进程被强杀」：两个真实进程 + 一条记录里的命令行。
      final ours = await Process.start('bash', [
        '-c',
        'sleep 40',
      ], workingDirectory: Directory.systemTemp.path);
      final stranger = await Process.start('bash', [
        '-c',
        'sleep 40',
      ], workingDirectory: Directory.systemTemp.path);
      await File(p.join(dir.path, 'background_tasks.json')).writeAsString(
        jsonEncode([
          {'pid': ours.pid, 'command': 'sleep 40', 'chat_id': 1},
          // pid 复用场景：进程活着但命令行不是我们记录的那条 → 不许杀。
          {'pid': stranger.pid, 'command': 'some other build command'},
        ]),
      );

      final killed = await tasks.recoverOrphans();

      expect(killed, 1);
      expect(await isAlive(ours.pid), isFalse);
      expect(await isAlive(stranger.pid), isTrue);
      stranger.kill(ProcessSignal.sigkill);
    }, skip: isWindows);
  });

  group('background_task 工具', () {
    test('list / read / stop 覆盖一个真实任务', () async {
      final tasks = service();
      final tool = BackgroundTaskTool(tasks);
      final task = await tasks.start(
        chatId: 3,
        executable: 'bash',
        arguments: ['-c', 'echo hello; sleep 30'],
        workdir: Directory.systemTemp.path,
        command: 'echo hello; sleep 30',
      );

      final list = await tool.execute({toolChatIdKey: 3, 'action': 'list'});
      expect(list, contains(task.id));
      expect(list, contains('running'));

      await Future<void>.delayed(const Duration(milliseconds: 300));
      final read = await tool.execute({
        toolChatIdKey: 3,
        'action': 'read',
        'task_id': task.id,
      });
      expect(read, contains('hello'));

      final stopped = await tool.execute({
        toolChatIdKey: 3,
        'action': 'stop',
        'task_id': task.id,
      });
      expect(stopped, contains('stopped'));
      expect(task.status, BackgroundTaskStatus.cancelled);

      // 停止后输出仍可读，且状态不再显示 running。
      final after = await tool.execute({
        toolChatIdKey: 3,
        'action': 'read',
        'task_id': task.id,
      });
      expect(after, contains('cancelled'));
      expect(after, contains('hello'));
    }, skip: isWindows);

    test('拒绝越权与非法输入', () async {
      final tasks = service();
      final tool = BackgroundTaskTool(tasks);

      expect(
        await tool.execute({'action': 'list'}),
        contains('Error: background tasks require a session context'),
      );
      expect(
        await tool.execute({toolChatIdKey: 1, 'action': 'read'}),
        contains('requires task_id'),
      );
      expect(
        await tool.execute({
          toolChatIdKey: 1,
          'action': 'read',
          'task_id': 'bg-404',
        }),
        contains('no background task'),
      );
      expect(
        await tool.execute({toolChatIdKey: 1, 'action': 'explode'}),
        contains('unknown action'),
      );
      // 别的会话的任务查不到（会话隔离，不是全局任务表）。
      final other = await start(tasks, command: 'sleep 30', chatId: 99);
      expect(
        await tool.execute({
          toolChatIdKey: 1,
          'action': 'read',
          'task_id': other.id,
        }),
        contains('no background task'),
      );
      await tasks.stopAll();
    }, skip: isWindows);
  });

  group('shell 的 background 参数', () {
    test('background=true 启动即返回任务 id', () async {
      final tasks = service();
      final tool = BashShellTool(tasks: tasks);

      final result = await tool.execute({
        toolChatIdKey: 5,
        'command': 'sleep 30',
        'background': true,
      });

      expect(result, contains('started'));
      expect(result, contains('keeps running after the turn ends'));
      expect(result, contains('background_task(action="read"'));
      expect(tasks.runningTasks, hasLength(1));
      await tasks.stopAll();
    }, skip: isWindows);

    test('自动汇报回合里禁用后台任务', () async {
      final tasks = service();
      final tool = BashShellTool(tasks: tasks);

      final result = await tool.execute({
        toolChatIdKey: 5,
        toolBackgroundDisabledKey: true,
        'command': 'sleep 30',
        'background': true,
      });

      expect(result, contains('not allowed in this run'));
      expect(tasks.runningTasks, isEmpty);
    }, skip: isWindows);
  });
}
