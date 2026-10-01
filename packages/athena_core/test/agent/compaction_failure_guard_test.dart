import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/context_budget.dart';
import 'package:athena_core/agent/context_compaction.dart';
import 'package:athena_core/agent/run_outcome.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

/// 按调用序号返回脚本化的响应：第 0 次发起一个工具调用（让 run 进入第二个迭代），
/// 之后正常结束。
class _ScriptedChatService implements ChatCompletionsService {
  final requests = <List<ChatMessage>>[];
  var calls = 0;

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
    calls++;
    requests.add(List.of(messages));
    if (calls == 1) {
      yield const ChatStreamEvent(
        choices: [
          ChatStreamChoice(
            index: 0,
            delta: ChatDelta(
              toolCalls: [
                ToolCallDelta(
                  index: 0,
                  id: 'call_1',
                  function: FunctionCallDelta(
                    name: 'no_such_tool',
                    arguments: '{}',
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      yield const ChatStreamEvent(
        choices: [
          ChatStreamChoice(
            index: 0,
            delta: ChatDelta(),
            finishReason: FinishReason.toolCalls,
          ),
        ],
      );
      return;
    }
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

void main() {
  final now = DateTime.now();
  late ToolRegistry registry;

  tearDown(() => registry.backgroundTasks.dispose());

  test('压缩失败后同一个 run 不再重复压缩，run 照常跑完', () async {
    const window = 50000;
    final budget = ContextBudget(window);
    // 前缀长到刚好越过触发线，同时仍在输入上限内（prepare 不会再抛错）。
    var prefixChars = 70000;
    List<ChatMessage> withPrefix() => [
      ChatMessage.system('s' * prefixChars),
      ChatMessage.user('hello'),
    ];
    while (!budget.shouldCompact(withPrefix(), null)) {
      prefixChars += 1000;
    }

    final chatService = _ScriptedChatService();
    var compactCalls = 0;
    registry = ToolRegistry();
    final service = AgentService(
      chatService: chatService,
      toolRegistry: registry,
    );

    final events = await service
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
            contextWindow: window,
            createdAt: now,
            updatedAt: now,
          ),
          baseMessages: withPrefix(),
          hasSentinelPrompt: false,
          allowReflection: false,
          maxIterations: 3,
          onCompact: (request) async* {
            compactCalls++;
            // 压缩失败：候选上下文照旧，_messages 不变。
            yield ContextCompactionUpdate(
              CompactionStep(
                messageId: 'c1',
                seq: 1,
                chatId: 'c1',
                runId: 1,
                phase: CompactionPhase.failed,
                startedAt: now,
                beforeTokens: budget.estimate(request.messages, request.tools),
                error: 'Compaction did not reduce context usage',
              ),
            );
          },
        )
        .toList();

    expect(compactCalls, 1, reason: '第二个迭代不再压缩：同样的历史只会同样失败');
    expect(chatService.calls, 2, reason: '两个迭代各发一次请求');
    expect(
      events.whereType<AgentRunOutcomeEvent>().single.outcome.termination,
      AgentRunTermination.completed,
    );
    expect(events.whereType<AgentTextEvent>().map((e) => e.delta).join(), 'ok');
  });
}
