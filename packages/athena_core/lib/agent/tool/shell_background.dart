import 'package:athena_core/agent/task/background_task.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';

/// 启动一个后台 shell 任务，返回给模型的说明文本。
///
/// bash 与 powershell 共用：后台化的差异只在可执行文件与参数拼法，
/// 归属判定、禁用口径与回给模型的措辞必须一致。
Future<String> startBackgroundShellTask({
  required BackgroundTaskService tasks,
  required Map<String, dynamic> args,
  required String executable,
  required List<String> arguments,
  required String workdir,
  required String command,
}) async {
  if (args[toolBackgroundDisabledKey] == true) {
    return 'Error: background tasks are not allowed in this run. '
        'Do this work in a normal run instead.';
  }

  final chatId = args[toolChatIdKey];
  if (chatId is! int) {
    return 'Error: background tasks are unavailable: this host has no '
        'session context (background tasks need a session to belong to).';
  }

  final task = await tasks.start(
    chatId: chatId,
    executable: executable,
    arguments: arguments,
    workdir: workdir,
    command: command,
  );

  if (!task.isRunning) {
    final detail = task.launchError == null ? '' : ' ${task.launchError}';
    return 'Error: the background task could not start. '
        '${task.statusLine}$detail';
  }

  return '[background task ${task.id} started]\n'
      'command: $command\n'
      'workdir: $workdir\n'
      'It does not block this turn and keeps running after the turn ends.\n'
      'It is stopped when the user cancels this conversation run, when the '
      'session is deleted, or on request via '
      'background_task(action="stop", task_id="${task.id}").\n'
      'Do not re-run the command to check on it: read progress with '
      'background_task(action="read", task_id="${task.id}"), or list every '
      'task with background_task(action="list").';
}
