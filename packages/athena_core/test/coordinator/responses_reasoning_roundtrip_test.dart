import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/run_outcome.dart';
import 'package:athena_core/agent/permission/permission_prompt.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/tool/tool_interface.dart' as agent;
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/coordinator/agent_run_coordinator.dart';
import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/storage/experience_repository.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_core/storage/chat_store.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/service/responses_state.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/util/retry.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

import '../support/responses_fixture.dart';

/// 通过真实 SDK + 临时文件仓储验证完整链路，HTTP 只使用脚本化响应。
void main() {
  late Directory tmp;
  late FileStorage storage;
  late ToolRegistry registry;
  late _Echo echo;
  late AgentRunCoordinator coordinator;
  late ChatEntity chat;
  late List<Map<String, dynamic>> bodies;
  late List<List<Map<String, dynamic>>> replies;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('athena_reasoning_run_');
    storage = FileStorage(root: tmp);
    await storage.load();
    final providerId = await storage.providerRepository.storeProvider(
      responsesProvider(),
    );
    final modelId = await storage.modelRepository.createModel(
      ModelEntity(
        name: 'reasoner',
        modelId: 'test-reasoner',
        providerId: providerId,
        reasoning: true,
        contextWindow: 100000,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    chat = ChatEntity(
      title: 'test',
      modelId: modelId,
      sentinelId: ChatEntity.noSentinelId,
      approvalMode: ApprovalMode.manual,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    chat = chat.copyWith(id: await storage.sessionRepository.createChat(chat));
    bodies = [];
    replies = [
      reasoningEvents(reasoningResponse()),
      reasoningEvents(reasoningResponse(tools: false, suffix: '2')),
      reasoningEvents(reasoningResponse(tools: false, suffix: '3')),
    ];
    var index = 0;
    final chatService = ChatCompletionsService(
      llmClient: LlmClient(
        retryConfig: const RetryConfig(maxAttempts: 1),
        clientFactory: ({required apiKey, required baseUrl}) {
          final mock = MockClient((request) async {
            expect(request.url.path, '/v1/responses');
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              responsesSse(replies[index++]),
              200,
              headers: {'content-type': 'text/event-stream; charset=utf-8'},
            );
          });
          return OpenAIClient.withApiKey(
            apiKey,
            baseUrl: baseUrl,
            httpClient: mock,
            streamClientFactory: () => mock,
          );
        },
      ),
    );
    echo = _Echo();
    registry = ToolRegistry()..register(echo);
    coordinator = AgentRunCoordinator(
      agentService: AgentService(
        chatService: chatService,
        toolRegistry: registry,
      ),
      chatStore: ChatStore(
        chatRepository: storage.sessionRepository,
        messageRepository: storage.sessionRepository,
        modelRepository: storage.modelRepository,
        providerRepository: storage.providerRepository,
        sentinelRepository: storage.sentinelRepository,
      ),
      messageService: ChatMessageConverter(
        messageRepository: storage.sessionRepository,
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
      agentSettings: AgentSettings(),
      permissionService: PermissionService(store: PermissionStore()),
      permissionPrompt:
          (chatId, name, arguments, cancelToken, {reviewReason}) async =>
              const PermissionDecision(approved: true),
      experienceRepository: ExperienceRepository(homeDir: tmp.path),
    );
  });

  tearDown(() async {
    await coordinator.dispose();
    await registry.backgroundTasks.dispose();
    await tmp.delete(recursive: true);
  });

  Future<List<RunEvent>> send() => coordinator
      .send(
        message: MessageEntity(chatId: chat.id!, role: 'user', content: '检查配置'),
        chat: chat,
      )
      .toList();

  test('摘要显示并落库；同 run 工具续接和下一次用户输入都回传原生推理', () async {
    final events = await send();
    expect(events.whereType<RunError>(), isEmpty);
    expect(echo.values, ['0', '1']);
    expect(bodies, hasLength(2));
    expect(bodies.first['reasoning'], {'effort': 'high', 'summary': 'auto'});
    expect(bodies.first['store'], isFalse);
    expect(bodies.first['include'], contains('reasoning.encrypted_content'));
    final input = bodies[1]['input'] as List;
    final reasoningIndex = input.indexWhere(
      (item) => item['type'] == 'reasoning',
    );
    final raw = Response.fromJson(
      reasoningResponse(),
    ).output.map((item) => item.toJson()).toList();
    expect(input.sublist(reasoningIndex, reasoningIndex + 4), raw);
    expect(input.sublist(reasoningIndex + 4).map((item) => item['call_id']), [
      'call_1_0',
      'call_1_1',
    ]);
    final reopened = FileStorage(root: tmp);
    await reopened.load();
    final saved = (await reopened.sessionRepository.getMessagesByChatId(
      chat.id!,
    )).where((message) => message.role == 'assistant').toList();
    expect(saved, hasLength(2));
    expect(
      saved.map((message) => message.reasoningContent),
      everyElement('先读取配置。\n\n再验证结果。'),
    );
    expect(ResponsesState.decode(saved.first.responsesState)!.output, raw);
    expect(
      ResponsesState.decode(saved.last.responsesState)!.output.first['id'],
      'rs_2',
    );
    expect(
      events.whereType<RunMessageUpdated>().any(
        (event) => event.message.reasoningContent.contains('先读取'),
      ),
      isTrue,
    );

    final next = await send();
    expect(next.whereType<RunError>(), isEmpty);
    final nextInput = bodies.last['input'] as List;
    expect(
      nextInput
          .where((item) => item['type'] == 'reasoning')
          .map((item) => item['id']),
      ['rs_1', 'rs_2'],
    );
    expect(echo.values, ['0', '1'], reason: '回传历史不会重新执行旧调用');
  });

  test('只有 completed 快照也能展示并执行完整工具、原样续接', () async {
    replies[0] = [
      {'type': 'response.completed', 'response': reasoningResponse()},
    ];
    final events = await send();
    expect(events.whereType<RunError>(), isEmpty);
    expect(echo.values, ['0', '1']);
    final saved = await storage.sessionRepository.getMessagesByChatId(chat.id!);
    final message = saved.firstWhere((m) => m.toolCalls.isNotEmpty);
    expect(message.content, '准备执行。');
    expect(message.responsesState, isNotEmpty);
    expect(
      (bodies[1]['input'] as List).any((i) => i['type'] == 'reasoning'),
      isTrue,
    );
  });

  test('无工具的 incomplete 保留正文、失败状态及原始停止原因', () async {
    replies[0] = [
      {
        'type': 'response.incomplete',
        'response': reasoningResponse(tools: false, status: 'incomplete'),
      },
    ];
    final events = await send();
    expect(events.whereType<RunError>(), hasLength(1));
    expect(
      events.whereType<RunOutcomeChanged>().last.outcome.termination,
      AgentRunTermination.error,
    );
    final saved = await storage.sessionRepository.getMessagesByChatId(chat.id!);
    final message = saved.singleWhere((m) => m.role == 'assistant');
    expect(message.content, startsWith('完成。'));
    expect(message.responsesState, isEmpty);
    expect(jsonDecode(message.completionDetails)['status'], 'incomplete');
    expect((await send()).whereType<RunError>(), isEmpty);
  });

  test('截断响应不存原生状态，工具调用不执行，仍可继续下一轮', () async {
    replies[0] = reasoningEvents(reasoningResponse(status: 'incomplete'));
    final events = await send();
    expect(events.whereType<RunError>(), isEmpty);
    expect(echo.values, isEmpty);
    expect(
      (bodies[1]['input'] as List).where((item) => item['type'] == 'reasoning'),
      isEmpty,
    );
    final saved = await storage.sessionRepository.getMessagesByChatId(chat.id!);
    final toolMessage = saved.firstWhere(
      (message) => message.toolCalls.isNotEmpty,
    );
    expect(toolMessage.responsesState, isEmpty);
    expect(toolMessage.reasoningContent, '先读取配置。\n\n再验证结果。');
  });

  for (final mode in ['eof', 'error', 'filtered']) {
    test('$mode 不执行已收到的工具调用，落库闭合工具结果', () async {
      replies[0].removeLast();
      if (mode == 'error') {
        replies[0].add({
          'type': 'error',
          'code': 'server_error',
          'message': 'broken',
        });
      } else if (mode == 'filtered') {
        replies[0].add({
          'type': 'response.incomplete',
          'response': {
            ...reasoningResponse(status: 'incomplete'),
            'incomplete_details': {'reason': 'content_filter'},
          },
        });
      }
      final events = await send();
      expect(events.whereType<RunError>(), hasLength(1));
      expect(echo.values, isEmpty);
      expect(bodies, hasLength(1));
      final saved = await storage.sessionRepository.getMessagesByChatId(
        chat.id!,
      );
      final assistant = saved.firstWhere((m) => m.toolCalls.isNotEmpty);
      expect(jsonDecode(assistant.toolResults), hasLength(2));
      expect(assistant.responsesState, isEmpty);
      if (mode == 'filtered') {
        expect(jsonDecode(assistant.completionDetails)['incomplete_details'], {
          'reason': 'content_filter',
        });
      }
    });
  }

  test('仅拒答响应实时显示并落库，结束时不覆盖成空文本', () async {
    replies[0] = [
      {
        'type': 'response.refusal.delta',
        'output_index': 0,
        'content_index': 0,
        'delta': 'Cannot answer',
      },
      {
        'type': 'response.completed',
        'response': {
          ...reasoningResponse(tools: false),
          'output': [
            {
              'type': 'message',
              'id': 'msg',
              'role': 'assistant',
              'status': 'completed',
              'content': [
                {'type': 'refusal', 'refusal': 'Cannot answer'},
              ],
            },
          ],
        },
      },
    ];
    final events = await send();
    expect(events.whereType<RunError>(), isEmpty);
    final saved = await storage.sessionRepository.getMessagesByChatId(chat.id!);
    final assistant = saved.singleWhere((m) => m.role == 'assistant');
    expect(assistant.content, 'Cannot answer');
    expect(jsonDecode(assistant.completionDetails)['refusal'], 'Cannot answer');
  });

  test('fetch 经真实 SDK 提取摘要并携带原生状态', () async {
    final provider = responsesProvider();
    final client = LlmClient(
      clientFactory: ({required apiKey, required baseUrl}) =>
          OpenAIClient.withApiKey(
            apiKey,
            baseUrl: baseUrl,
            httpClient: MockClient((request) async {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['reasoning'], {'effort': 'high', 'summary': 'auto'});
              return http.Response(
                jsonEncode(reasoningResponse()),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
    );
    final result = await client.fetch(
      provider: provider,
      request: ChatCompletionCreateRequest(
        model: 'test-reasoner',
        messages: [ChatMessage.user('hi')],
        reasoningEffort: ReasoningEffort.high,
      ),
    );
    final message = result.choices.single.message as ResponsesAssistantMessage;
    expect(message.reasoningContent, '先读取配置。\n\n再验证结果。');
    expect(
      message.responsesState!.matches(provider, 'test-reasoner', message),
      isTrue,
    );
  });
}

class _Echo extends agent.Tool {
  final values = <String>[];
  @override
  String get name => 'echo';
  @override
  String get description => 'Echo a test value.';
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'value': {'type': 'string'},
    },
    'required': ['value'],
  };
  @override
  Future<agent.ToolExecutionResult> executeResult(
    Map<String, dynamic> args, {
    void Function(String partialResult)? onUpdate,
  }) async {
    values.add(args['value'] as String);
    return const agent.ToolExecutionResult.success('ok');
  }
}
