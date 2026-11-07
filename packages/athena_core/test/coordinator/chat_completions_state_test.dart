import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/run_outcome.dart';
import 'package:athena_core/agent/permission/permission_prompt.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/tool/tool_interface.dart' as agent;
import 'package:athena_core/agent/tool/experience_learn_tool.dart';
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
import 'package:athena_core/service/chat_completions_state.dart';
import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/util/retry.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:path/path.dart' as p;
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
  String? reflectionResponse;
  Stream<List<int>> Function(int, List<Map<String, dynamic>>)? responseStream;

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
      approvalMode: ApprovalMode.manual,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    chat = chat.copyWith(id: await storage.sessionRepository.createChat(chat));
    bodies = [];
    replies = [chatEvents(tools: true), chatEvents(), chatEvents()];
    responseStream = null;
    reflectionResponse = null;
    var index = 0;
    final chatService = ChatCompletionsService(
      llmClient: LlmClient(
        retryConfig: const RetryConfig(maxAttempts: 1),
        clientFactory: ({required apiKey, required baseUrl}) {
          final mock = MockClient.streaming((request, bodyStream) async {
            expect(request.url.path, '/v1/chat/completions');
            bodies.add(
              jsonDecode(await bodyStream.bytesToString())
                  as Map<String, dynamic>,
            );
            if (reflectionResponse != null && bodies.last['stream'] != true) {
              return http.StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'id': 'reflection',
                      'object': 'chat.completion',
                      'created': 1,
                      'model': 'test-reasoner',
                      'choices': [
                        {
                          'index': 0,
                          'message': {
                            'role': 'assistant',
                            'content': reflectionResponse,
                          },
                          'finish_reason': 'stop',
                        },
                      ],
                    }),
                  ),
                ),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            final replyIndex = index++;
            final reply = replies[replyIndex];
            return http.StreamedResponse(
              responseStream?.call(replyIndex, reply) ??
                  Stream.value(
                    utf8.encode(
                      reply.map((e) => 'data: ${jsonEncode(e)}\n\n').join(),
                    ),
                  ),
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

  test('反思包含本轮后续验证结果，经验来源指向真实落库的工具消息', () async {
    // 所选目录暂时不存在，记忆仍应绑定该项目，不能降为无项目限制。
    final workspace = p.join(tmp.path, 'temporarily-unavailable-project');
    chat = chat.copyWith(workspacePath: workspace);
    await storage.sessionRepository.updateChat(chat);
    final experiences = ExperienceRepository(homeDir: tmp.path);
    registry.register(ExperienceLearnTool(repository: experiences));
    echo.failuresRemaining = 2;
    replies = [
      for (var i = 0; i < 5; i++) chatEvents(tools: true),
      chatEvents(),
    ];
    reflectionResponse = jsonEncode({
      'should_learn': true,
      'durability': 'long_term',
      'reuse_reason':
          'Future configuration checks use the same verified format constraint.',
      'evidence': 'The corrected configuration passed the subsequent checks.',
      'lesson': 'Check the corrected configuration with the tool.',
      'context': 'The first two checks failed; later checks returned ok.',
      'confidence': 0.9,
    });

    final events = await send();
    expect(events.whereType<RunError>(), isEmpty);
    final request = bodies.singleWhere((b) => b['stream'] != true);
    final input =
        jsonDecode((request['messages'] as List).last['content'] as String)
            as Map<String, dynamic>;
    expect(input['tool_failures'], hasLength(2));
    expect(input['recent_tool_results'], hasLength(8));
    for (final result in input['recent_tool_results'] as List) {
      expect(result['tool'], 'echo');
      expect(result['status'], 'success');
      expect(result['result'], 'ok');
      expect(jsonDecode(result['arguments'] as String), contains('value'));
    }
    expect(input['final_response'], '完成。');

    final learned = (await experiences.listAll()).single;
    expect(learned.source, 'reflection');
    expect(learned.workspacePath, workspace);
    expect(learned.sourceChatId, chat.id);
    expect(learned.sourceMessageId, isNotNull);
    final source = await storage.sessionRepository.getMessageById(
      learned.sourceChatId!,
      learned.sourceMessageId!,
    );
    expect(source, isNotNull);
    expect(source!.role, 'assistant');
    expect(source.toolCalls, contains('experience_learn'));
    expect(source.toolResults, contains('Experience recorded successfully'));
  });

  test('反思修订相关旧经验，下一轮目录只使用修订结论且保留来源与作用域', () async {
    chat = chat.copyWith(workspacePath: tmp.path);
    await storage.sessionRepository.updateChat(chat);
    final experiences = ExperienceRepository(homeDir: tmp.path);
    registry.register(ExperienceLearnTool(repository: experiences));
    final original = await experiences.save(
      lesson: '配置旧规则',
      sentinelId: 'direct',
      scope: 'shared',
      sourceChatId: chat.id,
      sourceMessageId: 'original-message',
    );
    await experiences.save(lesson: '配置其他角色', sentinelId: 'other');
    await experiences.save(
      lesson: '配置另一个项目',
      sentinelId: 'direct',
      workspacePath: p.join(tmp.path, 'other-project'),
    );
    final retired = await experiences.save(
      lesson: '配置归档',
      sentinelId: 'direct',
    );
    await experiences.update(
      sentinelId: 'direct',
      id: retired.id,
      status: 'archived',
    );
    echo.failuresRemaining = 2;
    replies = [
      chatEvents(tools: true),
      chatEvents(tools: true),
      chatEvents(),
      chatEvents(),
    ];
    reflectionResponse = jsonEncode({
      'should_learn': true,
      'action': 'update',
      'experience_id': original.id,
      'durability': 'long_term',
      'confidence': 0.95,
      'reuse_reason': 'Future configuration checks use this stable constraint.',
      'evidence': 'The corrected format passed the later checks.',
      'lesson': '配置修订规则',
      'scope': 'self',
    });

    final events = await send();
    expect(events.whereType<RunError>(), isEmpty);
    final request = bodies.singleWhere((b) => b['stream'] != true);
    final input =
        jsonDecode((request['messages'] as List).last['content'] as String)
            as Map;
    expect((input['related_experiences'] as List).map((e) => e['id']), [
      original.id,
    ]);
    final saved = (await experiences.listForSentinel('direct')).single;
    expect(saved.id, original.id);
    expect(saved.lesson, '配置修订规则');
    expect(saved.scope, 'shared');
    expect(saved.workspacePath, isNull);
    expect(saved.sourceMessageId, 'original-message');
    expect(saved.context, contains('The corrected format'));

    await send();
    final nextContext = jsonEncode(bodies.last['messages']);
    expect(nextContext, contains('配置修订规则'));
    final systems = (bodies.last['messages'] as List).where(
      (m) => m['role'] == 'system',
    );
    expect(jsonEncode(systems.toList()), isNot(contains('配置旧规则')));
    expect(jsonEncode(systems.toList()), isNot(contains('配置另一个项目')));
  });

  for (final extra in <Map<String, dynamic>>[
    {'durability': 'session_only'},
    {'reuse_reason': ''},
    {'evidence': ''},
    {'action': 'update', 'experience_id': 'not-a-candidate'},
  ]) {
    test('不持久化无长期价值或不合法的反思：$extra', () async {
      final experiences = ExperienceRepository(homeDir: tmp.path);
      registry.register(ExperienceLearnTool(repository: experiences));
      echo.failuresRemaining = 2;
      reflectionResponse = jsonEncode({
        'should_learn': true,
        'action': 'create',
        'durability': 'long_term',
        'confidence': 1.0,
        'lesson': 'Temporary port for this run',
        'reuse_reason': 'future use',
        'evidence': 'a check result',
        ...extra,
      });
      final events = await send();
      expect(events.whereType<RunError>(), isEmpty);
      expect(
        events.whereType<RunOutcomeChanged>().last.outcome.reflectionAttempted,
        isTrue,
      );
      expect(await experiences.listAll(), isEmpty);
      final saved = await storage.sessionRepository.getMessagesByChatId(
        chat.id!,
      );
      expect(
        saved.any((m) => m.toolCalls.contains('experience_learn')),
        isFalse,
      );
    });
  }

  test('累计多次调用的输出 token，排除输入与重复推理用量，重载保留且下次归零', () async {
    for (final (index, reply) in replies.indexed) {
      reply.add({
        'choices': <dynamic>[],
        'usage': {
          'prompt_tokens': 100 + index,
          'completion_tokens': 20 + index,
          'completion_tokens_details': {'reasoning_tokens': 5},
          'total_tokens': 120 + index * 2,
        },
      });
    }
    final events = await send();
    expect(events.whereType<RunError>(), isEmpty);
    final first = events.whereType<RunAssistantAppended>().first.message;
    expect(first.runStatistics!.outputTokens, isNull);
    expect(first.runStatistics!.finishedAt, isNull);
    final last = events.whereType<RunMessageUpdated>().last.message;
    expect(last.runStatistics!.outputTokens, 41);
    expect(last.runStatistics!.id, first.runStatistics!.id);
    expect(last.runStatistics!.finishedAt, isNotNull);
    expect(
      last.runStatistics!.finishedAt!.isBefore(first.runStatistics!.startedAt),
      isFalse,
    );

    final reopened = FileStorage(root: tmp);
    await reopened.load();
    final saved = await reopened.sessionRepository.getMessagesByChatId(
      chat.id!,
    );
    expect(saved.last.runStatistics!.toJson(), last.runStatistics!.toJson());

    final nextEvents = await send();
    final next = nextEvents.whereType<RunMessageUpdated>().last.message;
    expect(next.runStatistics!.outputTokens, 22);
    expect(next.runStatistics!.id, isNot(first.runStatistics!.id));
    expect(jsonEncode(bodies), isNot(contains('run_statistics')));
  });

  test('每次 LLM 独立计时，推理和工具参数参与计时，首包尾包与工具等待被排除', () async {
    final responseWatches = <Stopwatch>[];
    echo.delay = const Duration(milliseconds: 200);
    for (final (index, reply) in replies.indexed) {
      reply.add({
        'choices': <dynamic>[],
        'usage': {
          'prompt_tokens': 100,
          'completion_tokens': 20 + index * 20,
          'total_tokens': 120 + index * 20,
        },
      });
    }
    responseStream = (replyIndex, events) async* {
      final watch = Stopwatch()..start();
      responseWatches.add(watch);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      for (final (index, event) in events.indexed) {
        final choices = event['choices'] as List;
        if (choices.any((choice) => choice['finish_reason'] != null)) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        } else if (index > 0 && choices.isNotEmpty) {
          await Future<void>.delayed(
            Duration(milliseconds: replyIndex == 0 ? 50 : 100),
          );
        }
        yield utf8.encode('data: ${jsonEncode(event)}\n\n');
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
      watch.stop();
    };

    final events = await send();
    expect(events.whereType<RunError>(), isEmpty);
    final usages = events
        .whereType<RunUsageChanged>()
        .map((event) => event.usage)
        .toList();
    expect(usages, hasLength(2));
    for (final (index, usage) in usages.indexed) {
      final duration = usage.outputDuration!;
      expect(duration, greaterThanOrEqualTo(const Duration(milliseconds: 90)));
      expect(
        responseWatches[index].elapsed - duration,
        greaterThan(const Duration(milliseconds: 450)),
      );
    }
    final last = events
        .whereType<RunMessageUpdated>()
        .last
        .message
        .runStatistics!;
    expect(last.outputTokens, 60);
    final lastDurationMicros = usages.last.outputDuration!.inMicroseconds;
    expect(
      last.outputTokensPerSecond,
      closeTo(
        40 *
            Duration.microsecondsPerSecond /
            (lastDurationMicros < Duration.microsecondsPerSecond
                ? Duration.microsecondsPerSecond
                : lastDurationMicros),
        0.000001,
      ),
    );
    expect(
      last.elapsedAt(last.finishedAt!) -
          usages.fold(
            Duration.zero,
            (sum, usage) => sum + usage.outputDuration!,
          ),
      greaterThan(const Duration(milliseconds: 1100)),
    );
    final saved = await storage.sessionRepository.getMessagesByChatId(chat.id!);
    expect(
      saved.last.runStatistics!.outputTokensPerSecond,
      last.outputTokensPerSecond,
    );
  });

  test('单个输出片段无法测量生成速度，仍保存输出 token 总数', () async {
    replies[0] = [
      {
        'choices': [
          {
            'index': 0,
            'delta': {'content': 'done'},
          },
        ],
      },
      {
        'choices': [
          {'index': 0, 'delta': <String, dynamic>{}, 'finish_reason': 'stop'},
        ],
      },
      {
        'choices': <dynamic>[],
        'usage': {
          'prompt_tokens': 100,
          'completion_tokens': 3,
          'total_tokens': 103,
        },
      },
    ];
    final events = await send();
    expect(events.whereType<RunError>(), isEmpty);
    expect(
      events.whereType<RunUsageChanged>().single.usage.outputDuration,
      isNull,
    );
    final stats = events
        .whereType<RunMessageUpdated>()
        .last
        .message
        .runStatistics!;
    expect(stats.outputTokens, 3);
    expect(stats.outputTokensPerSecond, isNull);
  });

  test('取消后冻结运行时间并保留已上报的 token', () async {
    replies.first.add({
      'choices': <dynamic>[],
      'usage': {
        'prompt_tokens': 100,
        'completion_tokens': 20,
        'total_tokens': 120,
      },
    });
    final events = <RunEvent>[];
    await for (final event in coordinator.send(
      message: MessageEntity(chatId: chat.id!, role: 'user', content: '检查配置'),
      chat: chat,
    )) {
      events.add(event);
      if (event is RunUsageChanged) coordinator.stop(chat.id!);
    }
    final last = events.whereType<RunMessageUpdated>().last.message;
    expect(last.content, contains('[Cancelled]'));
    expect(last.runStatistics!.outputTokens, 20);
    expect(last.runStatistics!.finishedAt, isNotNull);
    final saved = await storage.sessionRepository.getMessagesByChatId(chat.id!);
    expect(saved.last.runStatistics!.toJson(), last.runStatistics!.toJson());
  });

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

  test('仅有 reasoning_details 时仍逐步显示、落库并回传原始状态', () async {
    for (final reply in replies) {
      for (final event in reply) {
        for (final choice in event['choices'] as List) {
          (choice['delta'] as Map).remove('reasoning');
        }
      }
    }
    final events = await send();
    expect(events.whereType<RunError>(), isEmpty);
    final saved = await storage.sessionRepository.getMessagesByChatId(chat.id!);
    expect(
      saved.where((m) => m.role == 'assistant').map((m) => m.reasoningContent),
      everyElement('思考中'),
    );
    expect(
      events.whereType<RunMessageUpdated>().any(
        (e) => e.message.reasoningContent == '思考中',
      ),
      isTrue,
    );
    final history = (bodies.last['messages'] as List).firstWhere(
      (m) => m['role'] == 'assistant',
    );
    expect(history['reasoning_details'], reasoningDetails);
    expect(history['reasoning_content'], isNull);
  });

  for (final content in ['', '部分回答']) {
    test('无工具的 length 响应明确失败并保留内容：$content', () async {
      replies[0] = [
        {
          'choices': [
            {
              'index': 0,
              'delta': {'content': content},
              'finish_reason': 'length',
            },
          ],
        },
      ];
      final events = await send();
      expect(events.whereType<RunError>(), hasLength(1));
      expect(
        events.whereType<RunOutcomeChanged>().last.outcome.termination,
        AgentRunTermination.error,
      );
      final saved = await storage.sessionRepository.getMessagesByChatId(
        chat.id!,
      );
      final assistant = saved.singleWhere((m) => m.role == 'assistant');
      expect(assistant.content, startsWith(content));
      expect(
        jsonDecode(assistant.completionDetails)['finish_reason'],
        'length',
      );
      expect(assistant.chatCompletionsState, isEmpty);
      expect((await send()).whereType<RunError>(), isEmpty);
    });
  }

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
  int failuresRemaining = 0;
  Duration delay = Duration.zero;
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
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failuresRemaining > 0) {
      failuresRemaining--;
      return const agent.ToolExecutionResult.error('validation failed');
    }
    return const agent.ToolExecutionResult.success('ok');
  }
}
