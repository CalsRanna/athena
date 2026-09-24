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
  late int providerId;
  late int modelId;
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

    llm = _ScriptedLlm([
      // ① 用户回合：模型要求后台跑一条命令
      [
        _toolCall(
          id: 'call_bg',
          name: 'bash',
          arguments: {
            'command': command,
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
    final systemText = (reportRequest['messages'] as List)
        .where((m) => (m as Map)['role'] == 'system')
        .map((m) => (m as Map)['content'] as String)
        .join('\n');
    expect(systemText, contains('Background tasks have completed'));
    expect(systemText, contains('bg-1'));

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
    expect((reportRequest['messages'] as List)
        .where((m) => (m as Map)['role'] == 'user'), hasLength(1));
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
    final chunks = _served < _script.length
        ? _script[_served++]
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
