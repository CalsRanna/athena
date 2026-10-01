import 'dart:convert';
import 'dart:io';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
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
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_core/service/chat_store_service.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/service/messages_state.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/util/retry.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

import '../support/messages_fixture.dart';

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
      messagesProvider(),
    );
    final modelId = await storage.modelRepository.createModel(
      ModelEntity(
        name: 'reasoner',
        modelId: 'claude-sonnet-4-6',
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
      thinkingEvents(thinkingMessage()),
      thinkingEvents(thinkingMessage(tools: false, suffix: '2')),
      thinkingEvents(thinkingMessage(tools: false, suffix: '3')),
    ];
    var index = 0;
    final chatService = ChatCompletionsService(
      llmClient: LlmClient(
        retryConfig: const RetryConfig(maxAttempts: 1),
        anthropicClientFactory: ({required apiKey, required baseUrl}) {
          final mock = MockClient((request) async {
            expect(request.url.path, '/v1/messages');
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              messagesSse(replies[index++]),
              200,
              headers: {'content-type': 'text/event-stream; charset=utf-8'},
            );
          });
          return anthropic.AnthropicClient(
            config: anthropic.AnthropicConfig(
              authProvider: anthropic.ApiKeyProvider(apiKey),
              baseUrl: baseUrl,
              retryPolicy: const anthropic.RetryPolicy(maxRetries: 0),
            ),
            httpClient: mock,
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
      manageService: ChatStoreService(
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
      permissionPrompt: (chatId, name, arguments, cancelToken) async =>
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

  test('thinking 显示落库；同 run 工具续接与下轮输入回传原始块', () async {
    final events = await send();
    expect(events.whereType<RunError>(), isEmpty);
    expect(echo.values, ['0', '1']);
    expect(bodies, hasLength(2));
    expect(bodies.first['thinking'], {
      'type': 'adaptive',
      'display': 'summarized',
    });
    expect(bodies.first['output_config'], {'effort': 'high'});
    expect(bodies.first, isNot(contains('temperature')));
    final history = bodies[1]['messages'] as List;
    final assistants = history.where((m) => m['role'] == 'assistant').toList();
    expect(assistants.single['content'], thinkingMessage()['content']);
    expect((history.last['content'] as List).map((b) => b['tool_use_id']), [
      'toolu_1_0',
      'toolu_1_1',
    ]);

    final reopened = FileStorage(root: tmp);
    await reopened.load();
    final saved = (await reopened.sessionRepository.getMessagesByChatId(
      chat.id!,
    )).where((m) => m.role == 'assistant').toList();
    expect(saved, hasLength(2));
    expect(
      saved.map((m) => m.reasoningContent),
      everyElement('先读取配置。\n\n再验证结果。'),
    );
    expect(
      MessagesState.decode(saved.first.messagesState)!.content,
      thinkingMessage()['content'],
    );
    expect(
      events.whereType<RunMessageUpdated>().any(
        (e) => e.message.reasoningContent.contains('先读取'),
      ),
      isTrue,
    );

    final next = await send();
    expect(next.whereType<RunError>(), isEmpty);
    final nextHistory = (bodies.last['messages'] as List)
        .where((m) => m['role'] == 'assistant')
        .toList();
    expect(nextHistory.map((m) => m['content']), [
      thinkingMessage()['content'],
      thinkingMessage(tools: false, suffix: '2')['content'],
    ]);
    expect(echo.values, ['0', '1'], reason: '回传的历史工具不会重新执行');
  });

  for (final reason in ['max_tokens', 'model_context_window_exceeded']) {
    test('无工具的 $reason 不再误报正常完成', () async {
      final response = thinkingMessage(tools: false)..['stop_reason'] = reason;
      replies[0] = thinkingEvents(response);
      final events = await send();
      expect(events.whereType<RunError>(), hasLength(1));
      expect(
        events.whereType<RunOutcomeChanged>().last.outcome.termination,
        AgentRunTermination.error,
      );
      final saved = await storage.sessionRepository.getMessagesByChatId(
        chat.id!,
      );
      final message = saved.singleWhere((m) => m.role == 'assistant');
      expect(message.content, startsWith('准备执行。'));
      expect(message.messagesState, isEmpty);
      expect(jsonDecode(message.completionDetails)['stop_reason'], reason);
      expect((await send()).whereType<RunError>(), isEmpty);
    });
  }

  test('截断不保存原生推理、不执行工具，下轮请求继续成功', () async {
    replies[0] = thinkingEvents(thinkingMessage(stop: 'max_tokens'));
    final events = await send();
    expect(events.whereType<RunError>(), isEmpty);
    expect(echo.values, isEmpty);
    expect(jsonEncode(bodies[1]), isNot(contains('signature_')));
    final saved = await storage.sessionRepository.getMessagesByChatId(chat.id!);
    final toolMessage = saved.firstWhere((m) => m.toolCalls.isNotEmpty);
    expect(toolMessage.messagesState, isEmpty);
    expect(toolMessage.reasoningContent, '先读取配置。\n\n再验证结果。');
  });

  test('提前 EOF 不执行已收到的工具，也不保存未完成的推理状态', () async {
    replies[0].removeLast();
    final events = await send();
    expect(events.whereType<RunError>(), hasLength(1));
    expect(echo.values, isEmpty);
    expect(bodies, hasLength(1));
    final saved = await storage.sessionRepository.getMessagesByChatId(chat.id!);
    expect(
      saved.where((m) => m.role == 'assistant').map((m) => m.messagesState),
      everyElement(isEmpty),
    );
    final next = await send();
    expect(next.whereType<RunError>(), isEmpty);
    expect(jsonEncode(bodies.last), isNot(contains('signature_')));
  });

  test('窗口耗尽不执行工具，并保留原始停止原因和缓存用量', () async {
    final response = thinkingMessage(stop: 'model_context_window_exceeded');
    response['usage'] = {
      'input_tokens': 10,
      'output_tokens': 30,
      'cache_read_input_tokens': 100,
      'cache_creation_input_tokens': 20,
    };
    replies[0] = thinkingEvents(response);
    (replies[0].first['message'] as Map)['usage'] = response['usage'];
    replies[0].singleWhere((e) => e['type'] == 'message_delta')['usage'] = {
      'output_tokens': 30,
    };
    final events = await send();
    expect(events.whereType<RunError>(), isEmpty);
    expect(echo.values, isEmpty);
    final saved = await storage.sessionRepository.getMessagesByChatId(chat.id!);
    final message = saved.firstWhere((m) => m.toolCalls.isNotEmpty);
    final details = jsonDecode(message.completionDetails);
    expect(details['stop_reason'], 'model_context_window_exceeded');
    expect(message.messagesState, isEmpty);
    final usage = events.whereType<RunUsageChanged>().first.usage;
    expect(usage.promptTokens, 130);
    expect(usage.totalTokens, 160);
    expect(usage.cacheCreationTokens, 20);
  });

  test('fetch 经真实 SDK 保留 thinking、signature 与工具', () async {
    final provider = messagesProvider();
    final client = LlmClient(
      anthropicClientFactory: ({required apiKey, required baseUrl}) =>
          anthropic.AnthropicClient(
            config: anthropic.AnthropicConfig(
              authProvider: anthropic.ApiKeyProvider(apiKey),
              baseUrl: baseUrl,
            ),
            httpClient: MockClient((request) async {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['thinking'], {
                'type': 'adaptive',
                'display': 'summarized',
              });
              expect(body['output_config'], {'effort': 'high'});
              return http.Response(
                jsonEncode(thinkingMessage()),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
    );
    final result = await client.fetch(
      provider: provider,
      request: ChatCompletionCreateRequest(
        model: 'claude-sonnet-4-6',
        messages: [ChatMessage.user('hi')],
        reasoningEffort: ReasoningEffort.high,
      ),
    );
    final message = result.choices.single.message as MessagesAssistantMessage;
    expect(message.reasoningContent, '先读取配置。\n\n再验证结果。');
    expect(message.messagesState!.content, thinkingMessage()['content']);
    expect(message.toolCalls, hasLength(2));
    expect(result.usage!.completionTokensDetails!.reasoningTokens, 25);
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
