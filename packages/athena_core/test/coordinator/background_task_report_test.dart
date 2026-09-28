import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/permission/permission_prompt.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/task/background_task.dart';
import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:athena_core/agent/tool/tool_set.dart';
import 'package:athena_core/coordinator/agent_run_coordinator.dart';
import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_core/service/chat_store_service.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/storage/json_file_key_value_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// 后台任务「自动汇报」这条链路的端到端用例。
///
/// 用真实仓库（临时目录）+ 脚本化的假 LLM 驱动整个协调层：用户消息 → 模型
/// 调 bash(background) → 任务真的跑起来并结束 → 协调层自动起一个汇报回合 →
/// 模型读回输出 → 结论落库。项目里没有别的协调层测试脚手架，这里的装配就是
/// 最小可用的那一份。
void main() {
  final isWindows = Platform.isWindows;

  late Directory tmp;
  late FileStorage storage;
  late String providerId;
  late String modelId;
  late ChatEntity chat;
  late BackgroundTaskService tasks;
  late AgentSettings settings;
  late _ScriptedLlm llm;
  late AgentRunCoordinator coordinator;
  late List<String> approvalTools;

  Future<void> setUpHarness({
    bool temporary = true,
    String command = 'echo build-ok',
    int readLimit = 6000,
    ApprovalMode approvalMode = ApprovalMode.manual,
    List<List<Map<String, dynamic>>>? script,
  }) async {
    tmp = await Directory.systemTemp.createTemp('athena_bg_report_');
    storage = FileStorage(root: Directory(p.join(tmp.path, '.athena')));
    await storage.load();

    final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    providerId = await storage.providerRepository.storeProvider(
      ProviderEntity(
        name: 'fake',
        baseUrl: 'http://fake.local/v1',
        apiKey: 'k',
        enabled: true,
        createdAt: now,
      ),
    );
    modelId = await storage.modelRepository.createModel(
      ModelEntity(
        name: 'fake-model',
        modelId: 'fake-model',
        providerId: providerId,
        contextWindow: 100000,
        createdAt: now,
        updatedAt: now,
      ),
    );

    tasks = BackgroundTaskService(stateDirectory: storage.backgroundTasksDir);
    final outputStore = ToolOutputStore(directory: storage.toolOutputsDir);
    final toolRegistry = buildToolRegistry(
      skillRegistry: SkillRegistry(),
      experienceRepository: ExperienceRepository(homeDir: tmp.path),
      sentinelRepository: storage.sentinelRepository,
      store: JsonFileKeyValueStore(file: File(p.join(tmp.path, 'kv.json'))),
      outputStore: outputStore,
      backgroundTasks: tasks,
      defaultWorkdir: tmp.path,
    );

    // 原有汇报用例明确让任务在最后一条回答的请求发出后结束，避免与
    // 新增的运行中通知竞争；运行中通知用例自行控制任务完成时机。
    final reportGate = File(p.join(tmp.path, 'report-ready'));
    llm = _ScriptedLlm(script ?? [
      // ① 用户回合：模型要求后台跑一条命令
      [
        _toolCall(
          id: 'call_bg',
          name: 'bash',
          arguments: {
            'command': 'while [ ! -f "${reportGate.path}" ]; '
                'do sleep 0.01; done; $command',
            'background': true,
            'call_description': '后台跑一次构建',
          },
        ),
        _finish('tool_calls'),
      ],
      // ② 用户回合收尾：模型回一句
      [_text('已经开始了。'), _finish('stop')],
      // ③ 汇报回合：模型通过工具读取任务输出
      [
        _toolCall(
          id: 'call_read',
          name: 'background_task',
          arguments: {
            'action': 'read',
            'task_id': 'bg-1',
            'limit': readLimit,
            'call_description': '读后台任务输出',
          },
        ),
        _finish('tool_calls'),
      ],
      // ④ 汇报结论
      [_text('构建成功：build-ok'), _finish('stop')],
    ]);
    if (script == null) {
      llm.beforeResponse = (index) async {
        if (index != 1) return;
        final finished = tasks.completions.firstWhere(
          (task) => task.id == 'bg-1',
        );
        await reportGate.writeAsString('ready');
        await finished;
      };
    }

    final chatService = ChatCompletionsService(
      llmClient: LlmClient(
        clientFactory: ({required apiKey, required baseUrl}) =>
            OpenAIClient.withApiKey(
              apiKey,
              baseUrl: baseUrl,
              httpClient: llm.client,
              streamClientFactory: () => llm.client,
            ),
      ),
    );

    settings = AgentSettings();
    settings.approvalMode.value = approvalMode;
    settings.backgroundTaskReports.value = temporary;
    approvalTools = [];

    coordinator = AgentRunCoordinator(
      agentService: AgentService(
        chatService: chatService,
        toolRegistry: toolRegistry,
      ),
      manageService: ChatStoreService(
        chatRepository: storage.sessionRepository,
        messageRepository: storage.sessionRepository,
        modelRepository: storage.modelRepository,
        providerRepository: storage.providerRepository,
        sentinelRepository: storage.sentinelRepository,
      ),
      messageService: ChatMessageConverter(
        messageRepository: storage.sessionRepository,
        outputStore: outputStore,
      ),
      chatService: chatService,
      messageRepo: storage.sessionRepository,
      modelRepo: storage.modelRepository,
      sentinelRepo: storage.sentinelRepository,
      chatRepo: storage.sessionRepository,
      supportService: ChatUpdateService(
        chatRepository: storage.sessionRepository,
        providerRepository: storage.providerRepository,
        chatService: chatService,
      ),
      agentSettings: settings,
      permissionService: PermissionService(store: PermissionStore()),
      // 审批一律放行：本用例验的是汇报链路，不是权限链路。
      permissionPrompt: (chatId, toolName, arguments, cancelToken) async {
        approvalTools.add(toolName);
        return const PermissionDecision(approved: true);
      },
      experienceRepository: ExperienceRepository(homeDir: tmp.path),
    );

    final chatId = await storage.sessionRepository.createChat(
      ChatEntity(
        title: 't',
        modelId: modelId,
        sentinelId: ChatEntity.noSentinelId,
        createdAt: now,
        updatedAt: now,
      ),
    );
    chat = ChatEntity(
      id: chatId,
      title: 't',
      modelId: modelId,
      sentinelId: ChatEntity.noSentinelId,
      createdAt: now,
      updatedAt: now,
    );
  }

  tearDown(() async {
    await tasks.stopAll();
    await coordinator.dispose();
    await tasks.dispose();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<List<MessageEntity>> storedMessages() =>
      storage.sessionRepository.getMessagesByChatId(chat.id!);

  Future<void> sendMessage() => coordinator
      .send(
        message: MessageEntity(chatId: chat.id!, role: 'user', content: '跑构建'),
        chat: chat,
      )
      .drain<void>();

  Future<BackgroundTask> completeTask({
    String? chatId,
    String command = 'build',
    int exitCode = 0,
  }) async {
    final finished = tasks.completions.firstWhere(
      (task) => task.command == command,
    );
    await tasks.start(
      chatId: chatId ?? chat.id!,
      executable: 'bash',
      arguments: ['-c', 'echo PRIVATE-BUILD-OUTPUT; exit $exitCode'],
      workdir: tmp.path,
      command: command,
    );
    return finished;
  }

  List<Map> streamRequests() =>
      llm.requests.where((request) => request['stream'] == true).toList();

  List<Map<String, dynamic>> backgroundCall(String action, {String? taskId}) => [
    _toolCall(
      id: 'call_${action}_${taskId ?? "all"}',
      name: 'background_task',
      arguments: {
        'action': action,
        if (taskId != null) 'task_id': taskId,
        'call_description': '查看后台任务',
      },
    ),
    _finish('tool_calls'),
  ];

  for (final mode in [ApprovalMode.manual, ApprovalMode.aiReview]) {
    test('运行中完成的任务在下一次请求合并通知，沿用 ${mode.key} 审批且不重复汇报', () async {
      await setUpHarness(approvalMode: mode, script: [
        backgroundCall('list'),
        backgroundCall('read', taskId: 'bg-1'),
        [_text('根据构建结果继续处理。'), _finish('stop')],
      ]);
      final internal = <InternalRunEvent>[];
      final sub = coordinator.internalEvents.listen(internal.add);
      addTearDown(sub.cancel);
      llm.beforeResponse = (index) async {
        if (index != 0) return;
        await completeTask(command: 'failed-build', exitCode: 7);
        await completeTask(command: 'successful-build');
        await completeTask(chatId: 'another-chat', command: 'other-chat-build');
      };

      await sendMessage();

      final requests = streamRequests();
      expect(requests, hasLength(3));
      final messages = (requests[1]['messages'] as List).cast<Map>();
      final notification = messages.last['content'] as String;
      expect(messages.last['role'], 'user');
      expect(notification, contains('while this run is active'));
      expect(notification, contains('bg-1: failed'));
      expect(notification, contains('exit code 7'));
      expect(notification, contains('bg-2: completed'));
      expect(notification, isNot(contains('other-chat-build')));
      expect(notification, isNot(contains('PRIVATE-BUILD-OUTPUT')));
      expect(
        messages[messages.length - 2]['tool_call_id'],
        'call_list_all',
        reason: '通知应在整批工具结果之后，不破坏 assistant/tool 配对',
      );
      final finalMessages = (requests[2]['messages'] as List).cast<Map>();
      expect(
        finalMessages.where((m) => m['content'] == notification),
        hasLength(1),
      );
      final readResult = finalMessages.singleWhere(
        (m) => m['tool_call_id'] == 'call_read_bg-1',
      );
      expect(readResult['content'], contains('PRIVATE-BUILD-OUTPUT'));
      expect(internal, isEmpty, reason: '已完整响应的通知不再另起汇报回合');
      expect(
        (await storedMessages())
            .where((m) => m.role == 'user')
            .map((m) => m.content),
        ['跑构建'],
        reason: '运行时通知不落成用户消息',
      );
      if (mode == ApprovalMode.manual) {
        expect(approvalTools, ['background_task', 'background_task']);
      } else {
        expect(approvalTools, isEmpty);
        final reviews = llm.requests.where((r) => r['stream'] != true);
        expect(reviews, hasLength(2));
        for (final review in reviews) {
          final input = jsonDecode(
            ((review['messages'] as List).last as Map)['content'] as String,
          ) as Map;
          expect(
            (input['conversation'] as List).map((m) => (m as Map)['content']),
            ['跑构建'],
            reason: '任务通知和日志均不能成为 AI 审批授权来源',
          );
        }
      }
    }, skip: isWindows);
  }

  test('确认通知期间新完成的任务留到下一次模型请求', () async {
    await setUpHarness(script: [
      backgroundCall('list'),
      backgroundCall('read', taskId: 'bg-1'),
      [_text('完成。'), _finish('stop')],
    ]);
    llm.beforeResponse = (index) async {
      if (index < 2) await completeTask(command: 'build-$index');
    };
    await sendMessage();

    final requests = streamRequests();
    expect(requests, hasLength(3));
    final firstNotice =
        ((requests[1]['messages'] as List).last as Map)['content'] as String;
    expect(firstNotice, contains('bg-1'));
    expect(firstNotice, isNot(contains('bg-2')));
    final nextNotice =
        ((requests[2]['messages'] as List).last as Map)['content'] as String;
    expect(nextNotice, contains('bg-2'));
    expect(nextNotice, isNot(contains('bg-1')));
  }, skip: isWindows);

  test('带通知的请求截断后仍保留任务并在收尾汇报', () async {
    await setUpHarness(script: [
      backgroundCall('list'),
      [_text('回答被截断'), _finish('length')],
      backgroundCall('read', taskId: 'bg-1'),
      [_text('补充汇报构建结果。'), _finish('stop')],
    ]);
    llm.beforeResponse = (index) async {
      if (index == 0) await completeTask();
    };
    final internal = <InternalRunEvent>[];
    final sub = coordinator.internalEvents.listen(internal.add);
    addTearDown(sub.cancel);
    await sendMessage();

    final requests = streamRequests();
    expect(requests, hasLength(4));
    expect(
      ((requests[1]['messages'] as List).last as Map)['content'],
      contains('while this run is active'),
    );
    expect(
      ((requests[2]['messages'] as List).last as Map)['content'],
      contains('This is an automatic report'),
    );
    expect(internal, isNotEmpty);
  }, skip: isWindows);

  test('工具响应截断重试时保留同一条通知，成功后不再汇报', () async {
    await setUpHarness(script: [
      backgroundCall('list'),
      [
        ...backgroundCall('read', taskId: 'bg-1').take(1),
        _finish('length'),
      ],
      [_text('已收到任务完成通知。'), _finish('stop')],
    ]);
    llm.beforeResponse = (index) async {
      if (index == 0) await completeTask();
    };
    await sendMessage();

    final requests = streamRequests();
    expect(requests, hasLength(3));
    for (final request in requests.skip(1)) {
      expect(
        (request['messages'] as List).cast<Map>().where((m) =>
            m['role'] == 'user' &&
            (m['content'] as String).contains('while this run is active')),
        hasLength(1),
      );
    }
    expect(approvalTools, ['background_task'], reason: '截断的 read 调用不能执行');
  }, skip: isWindows);

  test('关闭开关时运行中的会话也不注入通知', () async {
    await setUpHarness(temporary: false, script: [
      backgroundCall('list'),
      [_text('完成。'), _finish('stop')],
    ]);
    llm.beforeResponse = (index) async {
      if (index == 0) await completeTask();
    };
    await sendMessage();
    final requests = streamRequests();
    expect(requests, hasLength(2));
    expect(
      (requests[1]['messages'] as List)
          .cast<Map>()
          .where((m) => m['role'] == 'user')
          .map((m) => m['content']),
      ['跑构建'],
    );
  }, skip: isWindows);

  test('任务结束后自动起汇报回合，结论落库', () async {
    await setUpHarness();
    final internal = <InternalRunEvent>[];
    final sub = coordinator.internalEvents.listen(internal.add);

    final events = await coordinator
        .send(
          message: MessageEntity(
            chatId: chat.id!,
            role: 'user',
            content: '跑构建',
          ),
          chat: chat,
        )
        .toList();
    await sub.cancel();

    // 用户回合把命令交给了后台，并且没等它跑完。
    final toolResults = events
        .whereType<RunMessageUpdated>()
        .map((e) => e.message.toolResults)
        .join();
    expect(toolResults, contains('[background task bg-1 started]'));

    // 任务完成触发了一次汇报回合：内部事件流里有它的流式消息。
    expect(internal, isNotEmpty);
    expect(internal.map((e) => e.chatId), everyElement(chat.id));
    final internalEvents = internal.map((e) => e.event).toList();
    expect(internalEvents.whereType<RunAssistantAppended>(), isNotEmpty);
    expect(
      internalEvents
          .whereType<RunMessageUpdated>()
          .map((e) => e.message.content)
          .join(),
      contains('构建成功'),
      reason: '汇报的流式内容应当出现在内部事件流里（前端据此实时渲染）',
    );

    // 结论落库：汇报回合的 assistant 消息。
    final messages = await storedMessages();
    expect(
      messages.any((m) => m.role == 'assistant' && m.content.contains('构建成功')),
      isTrue,
      reason: '汇报结论应当作为 assistant 消息留在会话里',
    );

    // 汇报回合使用同一工具集和审批模式，不再按风险标签筛选。
    expect(llm.requests, hasLength(4));
    final reportRequest = llm.requests[2];
    final reportMessages = (reportRequest['messages'] as List).cast<Map>();
    // 汇报说明是请求的最后一条 user 消息：历史以上一轮 assistant 回答结尾，
    // 不补这一条，Messages 协议会当作 prefill 拒绝
    expect(reportMessages.last['role'], 'user');
    final reportPrompt = reportMessages.last['content'] as String;
    expect(reportPrompt, contains('Background tasks have completed'));
    expect(reportPrompt, contains('bg-1'));
    expect(
      messages.map((m) => m.content),
      isNot(contains(contains('Background tasks have completed'))),
      reason: '汇报说明不落库',
    );

    final toolNames = (reportRequest['tools'] as List)
        .map((t) => ((t as Map)['function'] as Map)['name'])
        .toList();
    expect(toolNames, containsAll(['background_task', 'bash', 'file_write']));
    expect(approvalTools, ['bash', 'background_task']);

    // 汇报内容里带上了读到的任务输出。
    final reportReadResult = (llm.requests[3]['messages'] as List)
        .where((m) => (m as Map)['role'] == 'tool')
        .map((m) => (m as Map)['content'] as String)
        .join();
    expect(reportReadResult, contains('build-ok'));
    expect(
      reportMessages.where((m) => m['role'] == 'user').map((m) => m['content']),
      ['跑构建', reportPrompt],
      reason: '除了末尾的汇报说明，不能多出别的 user 消息（任务输出不以 user 角色进上下文）',
    );
  }, skip: isWindows);

  test('汇报仍可通过工具读取超过 6000 字符的完整输出', () async {
    await setUpHarness(
      command: 'printf START; printf "%07000d" 0; echo END',
      readLimit: 8000,
    );
    await coordinator.send(
      message: MessageEntity(chatId: chat.id!, role: 'user', content: '跑构建'),
      chat: chat,
    ).drain<void>();

    final output = (llm.requests[3]['messages'] as List)
        .cast<Map>()
        .singleWhere((m) => m['tool_call_id'] == 'call_read');
    final content = output['content'] as String;
    expect(content, contains('START${'0' * 7000}END'));
    expect(content, contains('End of task output.'));
  }, skip: isWindows);

  for (final mode in [ApprovalMode.aiReview, ApprovalMode.bypass]) {
    test('后台汇报沿用 ${mode.key} 审批模式', () async {
      await setUpHarness(approvalMode: mode);
      await coordinator.send(
        message: MessageEntity(chatId: chat.id!, role: 'user', content: '跑构建'),
        chat: chat,
      ).drain<void>();

      expect(approvalTools, isEmpty);
      final reviews = llm.requests.where((r) => r['stream'] != true).toList();
      expect(reviews, hasLength(mode == ApprovalMode.aiReview ? 2 : 0));
      if (reviews.isNotEmpty) {
        final input = jsonDecode(
          ((reviews.last['messages'] as List).last as Map)['content'] as String,
        ) as Map;
        expect((input['tool'] as Map)['name'], 'background_task');
        expect((input['conversation'] as List)
            .where((m) => (m as Map)['role'] == 'user')
            .map((m) => (m as Map)['content']), ['跑构建']);
      }
      final finalRequest = llm.requests.last;
      final output = (finalRequest['messages'] as List).cast<Map>()
          .singleWhere((m) => m['tool_call_id'] == 'call_read');
      expect(output['content'], contains('build-ok'));
    }, skip: isWindows);
  }

  test('被取消的任务不触发汇报', () async {
    await setUpHarness();
    final internal = <InternalRunEvent>[];
    final sub = coordinator.internalEvents.listen(internal.add);

    final task = await tasks.start(
      chatId: chat.id!,
      executable: 'bash',
      arguments: ['-c', 'sleep 30'],
      workdir: tmp.path,
      command: 'sleep 30',
    );
    await tasks.stopChatTasks(chat.id!);
    expect(task.status, BackgroundTaskStatus.cancelled);

    // 给「如果有汇报回合就会启动」留出窗口。
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await sub.cancel();

    expect(llm.requests, isEmpty, reason: '取消不该产生任何模型请求');
    expect(internal, isEmpty);
    expect((await storedMessages()).isEmpty, isTrue, reason: '不该凭空多出消息');
  }, skip: isWindows);

  test('关掉开关后不再自动汇报', () async {
    await setUpHarness(temporary: false);
    final internal = <InternalRunEvent>[];
    final sub = coordinator.internalEvents.listen(internal.add);

    await tasks.start(
      chatId: chat.id!,
      executable: 'bash',
      arguments: ['-c', 'echo done'],
      workdir: tmp.path,
      command: 'echo done',
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await sub.cancel();

    expect(llm.requests, isEmpty);
    expect(internal, isEmpty);
  }, skip: isWindows);
}

// ─── 脚本化的假 LLM ────────────────────────────────────────

Map<String, dynamic> _text(String content) => {
  'id': 'c',
  'object': 'chat.completion.chunk',
  'created': 0,
  'model': 'fake-model',
  'choices': [
    {
      'index': 0,
      'delta': {'content': content},
      'finish_reason': null,
    },
  ],
};

Map<String, dynamic> _toolCall({
  required String id,
  required String name,
  required Map<String, dynamic> arguments,
}) => {
  'id': 'c',
  'object': 'chat.completion.chunk',
  'created': 0,
  'model': 'fake-model',
  'choices': [
    {
      'index': 0,
      'delta': {
        'tool_calls': [
          {
            'index': 0,
            'id': id,
            'type': 'function',
            'function': {'name': name, 'arguments': jsonEncode(arguments)},
          },
        ],
      },
      'finish_reason': null,
    },
  ],
};

Map<String, dynamic> _finish(String reason) => {
  'id': 'c',
  'object': 'chat.completion.chunk',
  'created': 0,
  'model': 'fake-model',
  'choices': [
    {'index': 0, 'delta': <String, dynamic>{}, 'finish_reason': reason},
  ],
};

/// 按请求顺序返回预置的 SSE 分片，并记录每次请求体。
class _ScriptedLlm {
  _ScriptedLlm(this._script);

  final List<List<Map<String, dynamic>>> _script;
  final List<Map<String, dynamic>> requests = [];
  int _served = 0;
  Future<void> Function(int index)? beforeResponse;

  late final http.Client client = MockClient.streaming((
    request,
    bodyStream,
  ) async {
    final body =
        jsonDecode(await bodyStream.bytesToString()) as Map<String, dynamic>;
    requests.add(body);
    if (body['stream'] != true) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'id': 'review',
          'object': 'chat.completion',
          'created': 0,
          'model': 'fake-model',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': '{"decision":"allow","reason":"测试审批通过"}',
              },
              'finish_reason': 'stop',
            },
          ],
        }))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    final index = _served++;
    await beforeResponse?.call(index);
    final chunks = index < _script.length
        ? _script[index]
        : <Map<String, dynamic>>[_text(''), _finish('stop')];
    final sse =
        '${chunks.map((c) => 'data: ${jsonEncode(c)}\n\n').join()}'
        'data: [DONE]\n\n';
    return http.StreamedResponse(
      Stream.value(utf8.encode(sse)),
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  });
}
