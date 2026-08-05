import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/tool/tool_interface.dart' as athena;
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/chat_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:test/test.dart';
import 'package:openai_dart/openai_dart.dart'
    show ChatMessage, ChatStreamEvent, FunctionCall, JsonObjectResponseFormat, ResponseFormat, Tool, ToolCall;

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

  ToolCall _toolCall([String args = '{"message": "hello"}']) => ToolCall(
    id: 'c1',
    type: 'function',
    function: FunctionCall(name: 'echo', arguments: args),
  );

  test('beforeToolCall block: true 拒绝执行', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: _toolCall(),
      cancelToken: null,
      beforeToolCall: (ctx) async => (block: true, reason: 'blocked'),
    );

    expect(result.processedResult, contains('blocked'));
  });

  test('beforeToolCall block: false 允许执行', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: _toolCall(),
      cancelToken: null,
      beforeToolCall: (ctx) async => (block: false, reason: ''),
    );

    expect(result.processedResult, contains('echo: hello'));
  });

  test('不提供 beforeToolCall 时正常执行', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: _toolCall(),
      cancelToken: null,
    );

    expect(result.processedResult, contains('echo: hello'));
  });

  test('afterToolCall 可覆写结果', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: _toolCall(),
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
      toolCall: _toolCall(),
      cancelToken: null,
    );

    expect(result.processedResult, contains('echo: hello'));
  });

  test('beforeToolCall + afterToolCall 串联', () async {
    final result = await agentService.executeToolCallInternal(
      toolCall: _toolCall(),
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

  _jsonModeTests();
}

/// 记录 getCompletion 收到的 responseFormat 的伪 ChatService。
class _RecordingChatService extends ChatService {
  _RecordingChatService() : super(llmClient: LlmClient());

  ResponseFormat? lastResponseFormat;

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
          chat: _chat(),
          provider: _provider(),
          model: _model(),
          baseMessages: [ChatMessage.user('hi')],
        )
        .toList();

    expect(recording.lastResponseFormat, isNull);
  });
}
