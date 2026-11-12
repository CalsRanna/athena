import 'dart:convert';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/tool/tool_result.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

import '../support/fake_tool.dart';

void main() {
  final now = DateTime.now();

  Future<List<String>> requestToolNames({Set<String>? enabledTools}) async {
    final chatService = _FakeChatService();
    final registry = ToolRegistry()
      ..register(FakeTool('file_read'))
      ..register(FakeTool('web_search'));
    final service = AgentService(
      chatService: chatService,
      toolRegistry: registry,
    );
    try {
      await service
          .run(
            runId: 1,
            chat: ChatEntity(
              title: 't',
              modelId: 'm',
              sentinelId: null,
              createdAt: now,
              updatedAt: now,
            ),
            provider: ProviderEntity(
              name: 'p',
              baseUrl: 'http://localhost',
              apiKey: 'k',
              createdAt: now,
            ),
            model: ModelEntity(
              name: 'm',
              modelId: 'm',
              providerId: 'p',
              contextWindow: 200000,
              createdAt: now,
              updatedAt: now,
            ),
            baseMessages: [
              ChatMessage.system('system'),
              ChatMessage.user('hello'),
            ],
            hasSentinelPrompt: false,
            allowReflection: false,
            enabledTools: enabledTools,
          )
          .drain<void>();
    } finally {
      registry.backgroundTasks.dispose();
    }
    return chatService.requestedToolNames.single;
  }

  test('未配置白名单时暴露全部已注册工具', () async {
    expect(await requestToolNames(), [
      'file_read',
      'web_search',
      'tool_output_read',
    ]);
  });

  test('白名单决定模型可见工具，常开工具强制保留', () async {
    expect(await requestToolNames(enabledTools: {'file_read'}), [
      'file_read',
      'tool_output_read',
    ]);
  });

  test('被角色禁用的工具在执行前被拒，且不触发审批', () async {
    final registry = ToolRegistry()..register(FakeTool('file_read'));
    final service = AgentService(
      chatService: ChatCompletionsService(llmClient: LlmClient()),
      toolRegistry: registry,
    );
    addTearDown(() => registry.backgroundTasks.dispose());
    var permissionCalls = 0;

    final result = await service.executeToolCallInternal(
      toolCall: ToolCall(
        id: 'call_1',
        type: 'function',
        function: FunctionCall(
          name: 'file_read',
          arguments: jsonEncode({'call_description': 'read a file'}),
        ),
      ),
      cancelToken: CancelToken(),
      toolRegistry: registry.filtered(enabled: const <String>{}),
      permissionGate: (ctx) async {
        permissionCalls++;
        return (block: false, reason: '');
      },
    );

    expect(result.status, ToolResultStatus.blocked);
    expect(result.rawResult, contains('not available'));
    expect(permissionCalls, 0, reason: '不可用的工具不该先弹一次审批');
  });

  test('白名单内的工具正常执行', () async {
    final registry = ToolRegistry()..register(FakeTool('file_read'));
    final service = AgentService(
      chatService: ChatCompletionsService(llmClient: LlmClient()),
      toolRegistry: registry,
    );
    addTearDown(() => registry.backgroundTasks.dispose());

    final result = await service.executeToolCallInternal(
      toolCall: ToolCall(
        id: 'call_1',
        type: 'function',
        function: FunctionCall(
          name: 'file_read',
          arguments: jsonEncode({'call_description': 'read a file'}),
        ),
      ),
      cancelToken: CancelToken(),
      toolRegistry: registry.filtered(enabled: {'file_read'}),
    );

    expect(result.status, ToolResultStatus.success);
    expect(result.rawResult, 'ok');
  });
}

/// 记录每次请求实际带上的工具名。
class _FakeChatService implements ChatCompletionsService {
  final requestedToolNames = <List<String>>[];

  @override
  Stream<ChatStreamEvent> getCompletion({
    required ChatEntity chat,
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    List<Tool>? tools,
    ResponseFormat? responseFormat,
    Future<void>? cancelSignal,
    int? outputRoom,
  }) async* {
    requestedToolNames.add([
      for (final tool in tools ?? const <Tool>[]) tool.function.name,
    ]);
    yield const ChatStreamEvent(
      choices: [ChatStreamChoice(index: 0, delta: ChatDelta(content: 'ok'))],
    );
    yield const ChatStreamEvent(
      choices: [
        ChatStreamChoice(
          index: 0,
          delta: ChatDelta(),
          finishReason: FinishReason.stop,
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
