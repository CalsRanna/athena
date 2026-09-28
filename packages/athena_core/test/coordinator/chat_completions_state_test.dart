import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
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
import 'package:athena_core/service/chat_completions_state.dart';
import 'package:athena_core/entity/api_format.dart';
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
      responsesProvider().copyWith(apiFormat: ApiFormat.chatCompletions),
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
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    chat = chat.copyWith(id: await storage.sessionRepository.createChat(chat));
    bodies = [];
    replies = [chatEvents(tools: true), chatEvents(), chatEvents()];
    var index = 0;
    final chatService = ChatCompletionsService(
      llmClient: LlmClient(
        retryConfig: const RetryConfig(maxAttempts: 1),
        clientFactory: ({required apiKey, required baseUrl}) {
          final mock = MockClient((request) async {
            expect(request.url.path, '/v1/chat/completions');
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              replies[index++].map((e) => 'data: ${jsonEncode(e)}\n\n').join(),
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
      agentSettings: AgentSettings()..approvalMode.value = ApprovalMode.manual,
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

  test('reasoning 与 reasoning_details 在工具续接及文件重载后完整回传', () async {
    final events = await send();
    expect(events.whereType<RunError>(), isEmpty);
    expect(echo.values, ['0', '1']);
    final assistant = (bodies[1]['messages'] as List).singleWhere(
      (m) => m['role'] == 'assistant',
    );
    expect(assistant['reasoning'], '思考中');
    expect(assistant['reasoning_details'], reasoningDetails);
    final reopened = FileStorage(root: tmp);
    await reopened.load();
    final saved = (await reopened.sessionRepository.getMessagesByChatId(
      chat.id!,
    )).where((m) => m.role == 'assistant').toList();
    expect(saved.first.reasoningContent, '思考中');
    expect(
      ChatCompletionsState.decode(
        saved.first.chatCompletionsState,
      )!.message.reasoning,
      '思考中',
    );
    expect(
      jsonDecode(saved.first.completionDetails)['finish_reason'],
      'tool_calls',
    );
    final next = await send();
    expect(next.whereType<RunError>(), isEmpty);
    final history = (bodies.last['messages'] as List).where(
      (m) => m['role'] == 'assistant',
    );
    expect(history.first['reasoning_details'], reasoningDetails);
  });

  test('提前 EOF 不执行工具、不保存原生状态，并闭合工具结果', () async {
    replies[0].removeWhere(
      (e) => (e['choices'] as List).any((c) => c['finish_reason'] != null),
    );
    final events = await send();
    expect(events.whereType<RunError>(), hasLength(1));
    expect(echo.values, isEmpty);
    final saved = await storage.sessionRepository.getMessagesByChatId(chat.id!);
    final assistant = saved.firstWhere((m) => m.toolCalls.isNotEmpty);
    expect(assistant.chatCompletionsState, isEmpty);
    expect(jsonDecode(assistant.toolResults), hasLength(2));
  });

  test('拒答流在界面与落库正文中保留，历史回传仍使用原始 refusal', () async {
    replies[0] = [
      {
        'choices': [
          {
            'index': 0,
            'delta': {'refusal': 'Cannot answer'},
          },
        ],
      },
      {
        'choices': [
          {'index': 0, 'delta': <String, dynamic>{}, 'finish_reason': 'stop'},
        ],
      },
    ];
    final events = await send();
    expect(events.whereType<RunError>(), isEmpty);
    expect(
      events.whereType<RunMessageUpdated>().any(
        (e) => e.message.content == 'Cannot answer',
      ),
      isTrue,
    );
    final saved = await storage.sessionRepository.getMessagesByChatId(chat.id!);
    expect(
      saved.singleWhere((m) => m.role == 'assistant').content,
      'Cannot answer',
    );
    await send();
    final history = (bodies.last['messages'] as List).firstWhere(
      (m) => m['role'] == 'assistant',
    );
    expect(history['refusal'], 'Cannot answer');
    expect(history['content'], isNull);
  });
}

final reasoningDetails = [
  {
    'type': 'reasoning.text',
    'text': '思考中',
    'signature': 'signature',
    'index': 0,
  },
  {'type': 'reasoning.encrypted', 'data': 'opaque', 'index': 1},
];

List<Map<String, dynamic>> chatEvents({bool tools = false}) => [
  {
    'choices': [
      {
        'index': 0,
        'delta': {'reasoning': '思考中', 'reasoning_details': reasoningDetails},
      },
    ],
  },
  {
    'choices': [
      {
        'index': 0,
        'delta': {'content': tools ? '准备执行。' : '完成。'},
      },
    ],
  },
  if (tools)
    {
      'choices': [
        {
          'index': 0,
          'delta': {
            'tool_calls': [
              for (var i = 0; i < 2; i++)
                {
                  'index': i,
                  'id': 'call_$i',
                  'type': 'function',
                  'function': {
                    'name': 'echo',
                    'arguments': jsonEncode({
                      'value': '$i',
                      'call_description': '测试读取',
                    }),
                  },
                },
            ],
          },
        },
      ],
    },
  {
    'choices': [
      {
        'index': 0,
        'delta': <String, dynamic>{},
        'finish_reason': tools ? 'tool_calls' : 'stop',
      },
    ],
  },
];

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
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String partialResult)? onUpdate,
  }) async {
    values.add(args['value'] as String);
    return 'ok';
  }
}
