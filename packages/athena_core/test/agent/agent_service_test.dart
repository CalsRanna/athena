import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/elicit/elicit_prompt.dart' show ElicitChannel;
import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/evolution/reflection.dart';
import 'package:athena_core/agent/run_outcome.dart';
import 'package:athena_core/agent/tool/ask_user_question_tool.dart';
import 'package:athena_core/agent/tool/tool_result.dart';
import 'package:athena_core/agent/tool/experience_learn_tool.dart';
import 'package:athena_core/agent/tool/tool_interface.dart' as athena;
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:test/test.dart';
import 'package:athena_core/agent/runtime_context.dart';
import 'package:openai_dart/openai_dart.dart'
    show
        ChatMessage,
        ChatStreamEvent,
        FunctionCall,
        JsonObjectResponseFormat,
        ResponseFormat,
        SystemMessage,
        Tool,
        ToolCall,
        UserMessage;

class _BlockingTool extends athena.Tool implements athena.CancellableTool {
  final entered = Completer<void>();

  @override
  String get name => 'blocking';

  @override
  String get description => 'Waits for cancellation';

  @override
  Map<String, dynamic> get parameters => {'type': 'object'};

  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async => 'unexpected';

  @override
  Future<String> executeCancellable(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
    required Future<void> cancelSignal,
  }) async {
    entered.complete();
    await cancelSignal;
    throw const CancelledException();
  }
}

void main() {
  test('可取消工具会收到 run 的取消信号', () async {
    final tool = _BlockingTool();
    final registry = ToolRegistry()..register(tool);
    final service = AgentService(
      chatService: ChatCompletionsService(llmClient: LlmClient()),
      toolRegistry: registry,
    );
    final token = CancelToken();
    final future = service.executeToolCallInternal(
      toolCall: ToolCall(
        id: 'c1',
        type: 'function',
        function: const FunctionCall(name: 'blocking', arguments: '{}'),
      ),
      cancelToken: token,
    );

    await tool.entered.future;
    token.cancel();

    await expectLater(future, throwsA(isA<CancelledException>()));
  });

  test('提问工具经引擎拿到 run 的通道，答案随工具结果交回', () async {
    final registry = ToolRegistry()..register(AskUserQuestionTool());
    final service = AgentService(
      chatService: ChatCompletionsService(llmClient: LlmClient()),
      toolRegistry: registry,
    );
    var seenChatId = -1;
    final result = await service.executeToolCallInternal(
      toolCall: ToolCall(
        id: 'q1',
        type: 'function',
        function: FunctionCall(
          name: 'ask_user_question',
          arguments: jsonEncode({
            'questions': [
              {
                'question': '输出用哪种格式？',
                'header': '格式',
                'options': [
                  {'label': '摘要', 'description': '简短概览'},
                  {'label': '详细', 'description': '完整说明'},
                ],
              },
            ],
          }),
        ),
      ),
      cancelToken: CancelToken(),
      elicitChannel: ElicitChannel(
        chatId: 3,
        prompt: (chatId, questions, _) async {
          seenChatId = chatId;
          return {questions.single.question: '摘要'};
        },
        cancelToken: CancelToken(),
      ),
    );

    expect(seenChatId, 3);
    expect(result.status, ToolResultStatus.success);
    expect(result.rawResult, contains('格式: 输出用哪种格式？ -> 摘要'));
  });

  test('未注入通道时提问工具降级为「按假定继续」，不等待不报错', () async {
    final registry = ToolRegistry()..register(AskUserQuestionTool());
    final service = AgentService(
      chatService: ChatCompletionsService(llmClient: LlmClient()),
      toolRegistry: registry,
    );

    final result = await service.executeToolCallInternal(
      toolCall: ToolCall(
        id: 'q2',
        type: 'function',
        function: FunctionCall(
          name: 'ask_user_question',
          arguments: jsonEncode({
            'questions': [
              {
                'question': '输出用哪种格式？',
                'header': '格式',
                'options': [
                  {'label': '摘要', 'description': '简短概览'},
                  {'label': '详细', 'description': '完整说明'},
                ],
              },
            ],
          }),
        ),
      ),
      cancelToken: CancelToken(),
    );

    expect(result.rawResult, AskUserQuestionTool.noChannelMessage);
    expect(result.status, ToolResultStatus.success);
  });

  _jsonModeTests();
  _runtimePromptTests();
  _skillPromptTests();
  _reflectionTests();
}

class _ReflectionChatCompletionsService extends ChatCompletionsService {
  _ReflectionChatCompletionsService(this.reflectionResponse)
    : super(llmClient: LlmClient());

  final String reflectionResponse;
  int completeCalls = 0;

  @override
  Stream<ChatStreamEvent> getCompletion({
    required ChatEntity chat,
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    List<Tool>? tools,
    ResponseFormat? responseFormat,
    Future<void>? cancelSignal,
  }) async* {}

  @override
  Future<String> complete({
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    Future<void>? cancelSignal,
  }) async {
    completeCalls++;
    return reflectionResponse;
  }
}

void _reflectionTests() {
  test('Reflection 丢弃超过 Memory lesson 上限的候选', () {
    final lesson = 'x' * 501;
    final proposal = ReflectionProposal.tryParse(
      '{"should_learn":true,"lesson":"$lesson","confidence":0.9}',
    );
    expect(proposal, isNull);
  });

  test('ReflectionPolicy 只接受最大迭代或同工具重复失败', () {
    expect(
      ReflectionPolicy.shouldReflect(
        const AgentRunOutcome(
          termination: AgentRunTermination.maxIterations,
          iterations: 100,
        ),
      ),
      isTrue,
    );
    expect(
      ReflectionPolicy.shouldReflect(
        const AgentRunOutcome(
          termination: AgentRunTermination.completed,
          iterations: 2,
          toolFailures: [
            ToolFailure(
              toolName: 'file_update',
              status: ToolResultStatus.executionError,
              message: 'first',
            ),
            ToolFailure(
              toolName: 'file_update',
              status: ToolResultStatus.executionError,
              message: 'second',
            ),
          ],
        ),
      ),
      isTrue,
    );
    expect(
      ReflectionPolicy.shouldReflect(
        const AgentRunOutcome(
          termination: AgentRunTermination.cancelled,
          iterations: 1,
        ),
      ),
      isFalse,
    );
    expect(
      ReflectionPolicy.shouldReflect(
        const AgentRunOutcome(
          termination: AgentRunTermination.maxIterations,
          iterations: 100,
          toolFailures: [
            ToolFailure(
              toolName: 'file_write',
              status: ToolResultStatus.blocked,
              message: 'User denied the tool execution.',
            ),
          ],
        ),
      ),
      isFalse,
    );
    expect(
      ReflectionPolicy.shouldReflect(
        const AgentRunOutcome(
          termination: AgentRunTermination.completed,
          iterations: 2,
          toolFailures: [
            ToolFailure(
              toolName: 'experience_learn',
              status: ToolResultStatus.blocked,
              message: 'denied',
            ),
            ToolFailure(
              toolName: 'experience_learn',
              status: ToolResultStatus.blocked,
              message: 'denied again',
            ),
          ],
        ),
      ),
      isFalse,
    );
  });

  test('最大迭代后的 Reflection 复用 experience_learn 权限与执行链路', () async {
    final temp = Directory.systemTemp.createTempSync('reflection_agent_test');
    addTearDown(() => temp.deleteSync(recursive: true));
    final repository = ExperienceRepository(homeDir: temp.path);
    final registry = ToolRegistry()
      ..register(ExperienceLearnTool(repository: repository));
    final chatService = _ReflectionChatCompletionsService('''
{"should_learn":true,"lesson":"Re-read a file before exact replacement.","context":"Editing stale files","tags":["file-update"],"scope":"self","confidence":0.9}
''');
    final service = AgentService(
      chatService: chatService,
      toolRegistry: registry,
    );
    var approvals = 0;

    final events = await service
        .run(
          runId: 41,
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [ChatMessage.user('update this file')],
          sentinelId: 's1',
          maxIterations: 0,
          onPermission: (name, arguments) async {
            approvals++;
            expect(name, 'experience_learn');
            expect(arguments, contains('Re-read a file'));
            return true;
          },
        )
        .toList();

    expect(chatService.completeCalls, 1);
    expect(approvals, 1);
    expect(
      events.whereType<AgentToolCallEvent>().single.name,
      'experience_learn',
    );
    final outcome = events.whereType<AgentRunOutcomeEvent>().single.outcome;
    expect(outcome.termination, AgentRunTermination.maxIterations);
    expect(outcome.reflectionAttempted, isTrue);
    final stored = await repository.listForSentinel('s1');
    expect(stored.single.lesson, 'Re-read a file before exact replacement.');
  });

  test('用户拒绝 Reflection 的普通工具审批时不写经验', () async {
    final temp = Directory.systemTemp.createTempSync('reflection_deny_test');
    addTearDown(() => temp.deleteSync(recursive: true));
    final repository = ExperienceRepository(homeDir: temp.path);
    final registry = ToolRegistry()
      ..register(ExperienceLearnTool(repository: repository));
    final service = AgentService(
      chatService: _ReflectionChatCompletionsService('''
{"should_learn":true,"lesson":"A proposed lesson.","context":"test","tags":[],"scope":"self","confidence":0.9}
'''),
      toolRegistry: registry,
    );

    final events = await service
        .run(
          runId: 42,
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [ChatMessage.user('task')],
          sentinelId: 's1',
          maxIterations: 0,
          onPermission: (_, __) async => false,
        )
        .toList();

    expect(await repository.listForSentinel('s1'), isEmpty);
    expect(
      events.whereType<AgentToolResultEvent>().single.status,
      ToolResultStatus.blocked,
    );
  });
}

/// 记录 getCompletion 收到的 responseFormat 的伪 ChatCompletionsService。
class _RecordingChatCompletionsService extends ChatCompletionsService {
  _RecordingChatCompletionsService() : super(llmClient: LlmClient());

  ResponseFormat? lastResponseFormat;
  List<ChatMessage>? lastMessages;

  @override
  Stream<ChatStreamEvent> getCompletion({
    required ChatEntity chat,
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    List<Tool>? tools,
    ResponseFormat? responseFormat,
    Future<void>? cancelSignal,
  }) async* {
    lastResponseFormat = responseFormat;
    lastMessages = messages;
    // 空流：让 run 正常走完（toolCalls 为空 → done）
  }
}

ChatEntity _chat() => ChatEntity(
  id: 1,
  title: 'Test',
  sentinelId: 1,
  modelId: 1,
  retention: -1,
  temperature: 1.0,
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
);

ProviderEntity _provider() => ProviderEntity(
  name: 'Test',
  baseUrl: 'http://localhost',
  apiKey: '',
  enabled: true,
  isPreset: false,
  createdAt: DateTime(2025),
);

ModelEntity _model() => ModelEntity(
  name: 'Test',
  modelId: 'test-model',
  providerId: 1,
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
);

void _jsonModeTests() {
  test('jsonMode: true 时请求带 response_format json_object', () async {
    final recording = _RecordingChatCompletionsService();
    final service = AgentService(
      chatService: recording,
      toolRegistry: ToolRegistry(),
    );

    await service
        .run(
          runId: 1,
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [ChatMessage.user('hi')],
          jsonMode: true,
        )
        .toList();

    expect(recording.lastResponseFormat, isA<JsonObjectResponseFormat>());
  });

  test('jsonMode: false（默认）时请求不带 response_format', () async {
    final recording = _RecordingChatCompletionsService();
    final service = AgentService(
      chatService: recording,
      toolRegistry: ToolRegistry(),
    );

    await service
        .run(
          runId: 1,
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [ChatMessage.user('hi')],
        )
        .toList();

    expect(recording.lastResponseFormat, isNull);
  });
}

void _runtimePromptTests() {
  test('runtimePrompt 与当前日期合为最后一条 system 消息', () async {
    final recording = _RecordingChatCompletionsService();
    final service = AgentService(
      chatService: recording,
      toolRegistry: ToolRegistry(),
      now: () => DateTime(2026, 9, 14),
    );

    await service
        .run(
          runId: 1,
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [
            ChatMessage.system('SENTINEL'),
            ChatMessage.user('hello'),
          ],
          runtimePrompt: runtimeContextPrompt(RuntimeEnvironment.gui),
        )
        .toList();

    final messages = recording.lastMessages!;
    expect(messages, hasLength(3));
    expect((messages[0] as SystemMessage).content, 'SENTINEL');
    expect(
      (messages[1] as SystemMessage).content,
      '${runtimeContextPrompt(RuntimeEnvironment.gui)}\n'
      'Current date: 2026-09-14.',
    );
    expect(messages[2], isA<UserMessage>());
  });

  test('sentinel 保持首位，runtime 位于历史类摘要（digest）之后', () async {
    final recording = _RecordingChatCompletionsService();
    final service = AgentService(
      chatService: recording,
      toolRegistry: ToolRegistry(),
    );

    await service
        .run(
          runId: 1,
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [
            ChatMessage.system('SENTINEL'),
            ChatMessage.system('DIGEST'),
            ChatMessage.user('hello'),
          ],
          runtimePrompt: runtimeContextPrompt(RuntimeEnvironment.tui),
        )
        .toList();

    final messages = recording.lastMessages!;
    expect(messages, hasLength(4));
    expect((messages[0] as SystemMessage).content, 'SENTINEL');
    expect((messages[1] as SystemMessage).content, 'DIGEST');
    expect(
      (messages[2] as SystemMessage).content,
      allOf(contains('Athena TUI (terminal)'), contains('\nCurrent date: ')),
    );
    expect(messages[3], isA<UserMessage>());
  });

  test('evolution 位于 sentinel 之后、运行上下文之前', () async {
    final recording = _RecordingChatCompletionsService();
    final service = AgentService(
      chatService: recording,
      toolRegistry: ToolRegistry(),
    );

    await service
        .run(
          runId: 1,
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [
            ChatMessage.system('SENTINEL'),
            ChatMessage.user('hello'),
          ],
          evolutionPrompt: 'EVOLUTION',
        )
        .toList();

    final messages = recording.lastMessages!;
    expect((messages[0] as SystemMessage).content, 'SENTINEL');
    expect((messages[1] as SystemMessage).content, 'EVOLUTION');
    expect(
      (messages[2] as SystemMessage).content,
      startsWith('Current date: '),
    );
    expect(messages[3], isA<UserMessage>());
  });

  test('含 base 摘要（digest）：sentinel → evolution → digest → runtime', () async {
    final recording = _RecordingChatCompletionsService();
    final service = AgentService(
      chatService: recording,
      toolRegistry: ToolRegistry(),
    );

    await service
        .run(
          runId: 1,
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [
            ChatMessage.system('SENTINEL'),
            ChatMessage.system('DIGEST'),
            ChatMessage.user('hello'),
          ],
          runtimePrompt: runtimeContextPrompt(RuntimeEnvironment.gui),
          evolutionPrompt: 'EVOLUTION',
        )
        .toList();

    final messages = recording.lastMessages!;
    final contents = messages
        .whereType<SystemMessage>()
        .map((m) => m.content)
        .take(4)
        .toList();
    expect(contents[0], 'SENTINEL');
    expect(contents[1], 'EVOLUTION');
    expect(contents[2], 'DIGEST');
    expect(contents[3], contains('Athena GUI application'));
    expect(messages.last, isA<UserMessage>());
  });

  test('含 compact 摘要：runtime 位于全部摘要与 Memory 之后', () async {
    final recording = _RecordingChatCompletionsService();
    final service = AgentService(
      chatService: recording,
      toolRegistry: ToolRegistry(),
    );

    await service
        .run(
          runId: 1,
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [
            ChatMessage.system('SENTINEL'),
            ChatMessage.system('Previous conversation summary:\nk'),
            ChatMessage.system('DIGEST'),
            ChatMessage.user('hello'),
          ],
          runtimePrompt: runtimeContextPrompt(RuntimeEnvironment.gui),
          evolutionPrompt: 'EVOLUTION',
        )
        .toList();

    final messages = recording.lastMessages!;
    final contents = messages
        .whereType<SystemMessage>()
        .map((m) => m.content)
        .toList();
    expect(contents[0], 'SENTINEL');
    expect(contents[1], 'EVOLUTION');
    expect(contents[2], startsWith('Previous conversation summary:'));
    expect(contents[3], 'DIGEST');
    expect(contents[4], contains('Athena GUI application'));
    expect(messages.last, isA<UserMessage>());
  });

  test('无 sentinel 时 runtime 仍位于最后一条 system 消息', () async {
    final recording = _RecordingChatCompletionsService();
    final service = AgentService(
      chatService: recording,
      toolRegistry: ToolRegistry(),
    );

    await service
        .run(
          runId: 1,
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [
            ChatMessage.system('DIGEST'),
            ChatMessage.user('hello'),
          ],
          runtimePrompt: runtimeContextPrompt(RuntimeEnvironment.gui),
          evolutionPrompt: 'EVOLUTION',
          hasSentinelPrompt: false,
        )
        .toList();

    final messages = recording.lastMessages!;
    final contents = messages
        .whereType<SystemMessage>()
        .map((m) => m.content)
        .toList();
    expect(contents[0], 'EVOLUTION');
    expect(contents[1], 'DIGEST');
    expect(contents[2], contains('Athena GUI application'));
    expect(messages.last, isA<UserMessage>());
  });

  test('不提供 runtimePrompt 时仍然提供当前日期', () async {
    final recording = _RecordingChatCompletionsService();
    final service = AgentService(
      chatService: recording,
      toolRegistry: ToolRegistry(),
    );

    await service
        .run(
          runId: 1,
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [
            ChatMessage.system('SENTINEL'),
            ChatMessage.user('hi'),
          ],
        )
        .toList();

    final messages = recording.lastMessages!;
    expect(messages, hasLength(3));
    expect(
      (messages[1] as SystemMessage).content,
      startsWith('Current date: '),
    );
    expect(messages[2], isA<UserMessage>());
  });
}

void _skillPromptTests() {
  test('装配 SkillRegistry 时自动注入 Level 1 技能目录', () async {
    final recording = _RecordingChatCompletionsService();
    final skillRegistry = SkillRegistry()
      ..registerBuiltin(
        const Skill(
          name: 'demo-skill',
          description: 'A demo skill',
          body: 'instructions',
          sourcePath: '(builtin)',
        ),
      );
    final service = AgentService(
      chatService: recording,
      toolRegistry: ToolRegistry(),
      skillRegistry: skillRegistry,
    );

    await service
        .run(
          runId: 1,
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [
            ChatMessage.system('SENTINEL'),
            ChatMessage.user('hello'),
          ],
        )
        .toList();

    final messages = recording.lastMessages!;
    expect((messages[0] as SystemMessage).content, 'SENTINEL');
    expect(
      (messages[1] as SystemMessage).content,
      allOf(contains('Available Skills'), contains('demo-skill')),
    );
    expect(
      (messages[2] as SystemMessage).content,
      startsWith('Current date: '),
    );
    expect(messages[3], isA<UserMessage>());
  });

  test('显式 skillPrompt 覆盖默认技能目录', () async {
    final recording = _RecordingChatCompletionsService();
    final service = AgentService(
      chatService: recording,
      toolRegistry: ToolRegistry(),
      skillRegistry: SkillRegistry()
        ..registerBuiltin(
          const Skill(
            name: 'demo-skill',
            description: 'A demo skill',
            body: 'instructions',
            sourcePath: '(builtin)',
          ),
        ),
    );

    await service
        .run(
          runId: 1,
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [
            ChatMessage.system('SENTINEL'),
            ChatMessage.user('hello'),
          ],
          skillPrompt: 'CUSTOM SKILLS',
        )
        .toList();

    final messages = recording.lastMessages!;
    expect((messages[1] as SystemMessage).content, 'CUSTOM SKILLS');
    expect(
      messages.whereType<SystemMessage>().any(
        (m) => m.content.contains('Available Skills'),
      ),
      isFalse,
    );
  });
}
