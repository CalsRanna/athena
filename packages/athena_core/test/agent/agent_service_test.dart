import 'dart:async';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/tool/tool_interface.dart' as athena;
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/chat_service.dart';
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

/// 返回固定字符串的伪工具。
class _EchoTool extends athena.Tool {
  @override
  String get name => 'echo';

  @override
  String get description => 'Echo back';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'required': ['message'],
    'properties': {
      'message': {'type': 'string'},
    },
  };

  @override
  Future<String> execute(Map<String, dynamic> args, {void Function(String)? onUpdate}) async {
    return 'echo: ${args['message']}';
  }
}

class _BlockingTool extends athena.Tool implements athena.CancellableTool {
  final entered = Completer<void>();

  @override
  String get name => 'blocking';

  @override
  String get description => 'Waits for cancellation';

  @override
  Map<String, dynamic> get parameters => {'type': 'object'};

  @override
  Future<String> execute(Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async =>
      'unexpected';

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
  late AgentService agentService;

  setUp(() {
    final registry = ToolRegistry();
    registry.register(_EchoTool());
    agentService = AgentService(
      chatService: ChatService(llmClient: LlmClient()),
      toolRegistry: registry,
    );
  });

  ToolCall buildToolCall([String args = '{"message": "hello"}']) => ToolCall(
    id: 'c1',
    type: 'function',
    function: FunctionCall(name: 'echo', arguments: args),
  );

  test('beforeToolCall block: true 拒绝执行', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: buildToolCall(),
      cancelToken: null,
      beforeToolCall: (ctx) async => (block: true, reason: 'blocked'),
    );

    expect(result.processedResult, contains('blocked'));
  });

  test('beforeToolCall block: false 允许执行', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: buildToolCall(),
      cancelToken: null,
      beforeToolCall: (ctx) async => (block: false, reason: ''),
    );

    expect(result.processedResult, contains('echo: hello'));
  });

  test('不提供 beforeToolCall 时正常执行', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: buildToolCall(),
      cancelToken: null,
    );

    expect(result.processedResult, contains('echo: hello'));
  });

  test('afterToolCall 可覆写结果', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: buildToolCall(),
      cancelToken: null,
      afterToolCall: (ctx) async => (
        content: 'overridden',
        isError: false,
      ),
    );

    expect(result.processedResult, 'overridden');
  });

  test('不提供 afterToolCall 时使用原始结果', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: buildToolCall(),
      cancelToken: null,
    );

    expect(result.processedResult, contains('echo: hello'));
  });

  test('beforeToolCall + afterToolCall 串联', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: buildToolCall(),
      cancelToken: null,
      beforeToolCall: (ctx) async {
        expect(ctx.args['message'], 'hello');
        return (block: false, reason: '');
      },
      afterToolCall: (ctx) async {
        expect(ctx.rawResult, contains('echo: hello'));
        return (content: 'final: ${ctx.rawResult}', isError: false);
      },
    );

    expect(result.processedResult, 'final: echo: hello');
  });

  test('可取消工具会收到 run 的取消信号', () async {
    final tool = _BlockingTool();
    final registry = ToolRegistry()..register(tool);
    final service = AgentService(
      chatService: ChatService(llmClient: LlmClient()),
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

  _jsonModeTests();
  _runtimePromptTests();
}

/// 记录 getCompletion 收到的 responseFormat 的伪 ChatService。
class _RecordingChatService extends ChatService {
  _RecordingChatService() : super(llmClient: LlmClient());

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
    final recording = _RecordingChatService();
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
    final recording = _RecordingChatService();
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
  test('runtimePrompt 注入在系统提示词之后、历史消息之前', () async {
    final recording = _RecordingChatService();
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
          runtimePrompt: runtimeContextPrompt(RuntimeEnvironment.gui),
        )
        .toList();

    final messages = recording.lastMessages!;
    expect((messages[0] as SystemMessage).content, 'SENTINEL');
    expect(
      (messages[1] as SystemMessage).content,
      contains('Athena GUI application'),
    );
    expect(messages[2], isA<UserMessage>());
  });

  test('sentinel 保持首位，历史类摘要（digest）紧跟 runtime', () async {
    final recording = _RecordingChatService();
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
    expect((messages[0] as SystemMessage).content, 'SENTINEL');
    expect(
      (messages[1] as SystemMessage).content,
      contains('Athena TUI (terminal)'),
    );
    expect((messages[2] as SystemMessage).content, 'DIGEST');
    expect(messages[3], isA<UserMessage>());
  });

  test('evolution 不再插顶：插在 sentinel 之后（sentinel 首位）', () async {
    final recording = _RecordingChatService();
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
    expect(messages[2], isA<UserMessage>());
  });

  test('含 base 摘要（digest）：sentinel → runtime → evolution → digest', () async {
    final recording = _RecordingChatService();
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
    expect(contents[1], contains('Athena GUI application'));
    expect(contents[2], 'EVOLUTION');
    expect(contents[3], 'DIGEST');
    expect(messages.last, isA<UserMessage>());
  });

  test('含 compact 摘要：sentinel → runtime → evolution → summary', () async {
    final recording = _RecordingChatService();
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
    expect(contents[1], contains('Athena GUI application'));
    expect(contents[2], 'EVOLUTION');
    expect(contents[3], startsWith('Previous conversation summary:'));
    expect(contents[4], 'DIGEST');
    expect(messages.last, isA<UserMessage>());
  });

  test('无 sentinel 时 runtime 和 evolution 位于历史摘要之前', () async {
    final recording = _RecordingChatService();
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
    expect(contents[0], contains('Athena GUI application'));
    expect(contents[1], 'EVOLUTION');
    expect(contents[2], 'DIGEST');
    expect(messages.last, isA<UserMessage>());
  });

  test('不提供 runtimePrompt 时不注入 system 消息', () async {
    final recording = _RecordingChatService();
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
          baseMessages: [ChatMessage.system('SENTINEL'), ChatMessage.user('hi')],
        )
        .toList();

    final messages = recording.lastMessages!;
    expect(messages, hasLength(2));
    expect(messages[1], isA<UserMessage>());
  });
}
