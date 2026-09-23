import 'package:athena_core/agent/task/background_task.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';

/// 查看、读取、停止后台任务。
///
/// 单独成一个工具而不是塞进 shell 的参数：后台任务的生命周期跨越多轮，
/// 而 shell 是「一次调用一次结果」的形状。
class BackgroundTaskTool extends Tool {
  BackgroundTaskTool(this.tasks);

  final BackgroundTaskService tasks;

  @override
  String get name => 'background_task';

  /// 只读：list/read 无副作用；stop 终止的进程只能是本会话自己启动、
  /// 且经过审批的命令，它只会减少副作用，不会新增——为它弹审批弹窗等于
  /// 让用户为「停止自己刚批准的事」再确认一次。
  @override
  ToolRisk get risk => ToolRisk.readOnly;

  @override
  String get description =>
      'Inspect background shell tasks started with bash/powershell '
      'background=true.\n'
      '- action="list": all tasks of this session with status and elapsed '
      'time. Default action when task_id is omitted.\n'
      '- action="read": the output of one task, paged by character offset. '
      'Output of a stopped task is still readable.\n'
      '- action="stop": terminate a running task (its process tree is '
      'killed, output is kept).\n'
      'Prefer this over re-running a command to see whether it finished.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'description':
            'One of "list" (default), "read", "stop". '
            'Omit to list all tasks of this session.',
      },
      'task_id': {
        'type': 'string',
        'description':
            'Task id from a previous background start (for example "bg-1"). '
            'Required for "read" and "stop".',
      },
      'offset': {
        'type': 'integer',
        'minimum': 0,
        'description': 'Zero-based character offset for "read". Defaults to 0.',
      },
      'limit': {
        'type': 'integer',
        'minimum': 1,
        'maximum': 24000,
        'description': 'Characters to read for "read". Defaults to 6000.',
      },
    },
  };

  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async {
    final chatId = args[toolChatIdKey];
    if (chatId is! int) {
      return 'Error: background tasks require a session context.';
    }

    final action = (args['action'] as String?)?.trim().toLowerCase() ?? 'list';
    final taskId = (args['task_id'] as String?)?.trim();

    switch (action) {
      case 'list':
        return _list(chatId);
      case 'read':
        if (taskId == null || taskId.isEmpty) {
          return 'Error: "read" requires task_id.';
        }
        return _read(chatId, taskId, args);
      case 'stop':
        if (taskId == null || taskId.isEmpty) {
          return 'Error: "stop" requires task_id.';
        }
        return _stop(chatId, taskId);
      default:
        return 'Error: unknown action "$action". Use "list", "read" or "stop".';
    }
  }

  String _list(int chatId) {
    final all = tasks.tasksOf(chatId);
    if (all.isEmpty) {
      return 'No background tasks in this session. Start one with '
          'bash(command: "...", background: true).';
    }
    final buffer = StringBuffer('[background tasks in this session]\n');
    for (final task in all) {
      buffer.writeln('- ${task.id}: ${task.statusLine} — ${task.command}');
    }
    buffer.write(
      'Read one with background_task(action="read", task_id="<id>").',
    );
    return buffer.toString();
  }

  String _read(int chatId, String taskId, Map<String, dynamic> args) {
    final task = tasks.task(taskId, chatId: chatId);
    if (task == null) {
      return 'Error: no background task "$taskId" in this session. '
          'Use background_task(action="list") to see available ids.';
    }

    final offset = args['offset'] as int? ?? 0;
    final limit = args['limit'] as int? ?? 6000;
    final page = task.page(offset: offset, limit: limit);
    final buffer = StringBuffer()
      ..writeln('[background task ${task.id}: ${task.statusLine}]')
      ..writeln('command: ${task.command}')
      ..writeln('workdir: ${task.workdir}')
      ..writeln('[characters $offset-${page.nextOffset}, end exclusive]');
    if (task.outputLength == 0) {
      buffer.writeln('(no output yet)');
    }
    if (page.hasMore) {
      buffer.writeln(
        'Continue with background_task(action="read", task_id="${task.id}", '
        'offset=${page.nextOffset}, limit=6000).',
      );
    } else if (task.outputLength > 0) {
      buffer.writeln('End of task output.');
    }
    buffer.write('\n${page.text}');
    return buffer.toString();
  }

  Future<String> _stop(int chatId, String taskId) async {
    final task = tasks.task(taskId, chatId: chatId);
    if (task == null) {
      return 'Error: no background task "$taskId" in this session. '
          'Use background_task(action="list") to see available ids.';
    }
    if (!task.isRunning) {
      return '[background task ${task.id}: ${task.statusLine}]\n'
          'It is not running, nothing to stop. Output is still readable with '
          'background_task(action="read", task_id="${task.id}").';
    }
    await tasks.stop(taskId, chatId: chatId);
    return '[background task ${task.id} stopped]\n'
        '${task.statusLine}\n'
        'The process tree was terminated; the output produced so far is kept '
        'and can be read with background_task(action="read", '
        'task_id="${task.id}").';
  }
}
