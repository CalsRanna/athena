import 'package:athena_core/agent/agent_service.dart';
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

/// 前 [errorCalls] 次请求抛 [error]，之后正常流式返回 'ok'。
///
/// 只替换模型调用：Agent 循环、压缩回调、上下文组装都是真的。
class _FakeChatService implements ChatCompletionsService {
  _FakeChatService({this.error, this.errorCalls = 1});

  final Object? error;
  final int errorCalls;
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
    if (error != null && calls <= errorCalls) throw error!;
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
  late AgentService service;

  /// 装配一次 run：压缩回调换成"已完成、只留摘要"的固定结果。
  Future<({List<AgentEvent> events, int compactCalls})> run(
    _FakeChatService chatService,
  ) async {
    var compactCalls = 0;
    registry = ToolRegistry();
    service = AgentService(chatService: chatService, toolRegistry: registry);
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
          maxIterations: 3,
          onCompact: (request) async* {
            compactCalls++;
            yield ContextCompactionUpdate(
              CompactionStep(
                messageId: 'c1',
                seq: 1,
                chatId: 'c1',
                runId: 1,
                phase: CompactionPhase.completed,
                startedAt: now,
                beforeTokens: 1000,
                afterTokens: 10,
                summary: 'compacted',
              ),
              messages: [
                ChatMessage.system('system'),
                ChatMessage.user('summary of earlier turns'),
              ],
            );
          },
        )
        .toList();
    return (events: events, compactCalls: compactCalls);
  }

  tearDown(() => registry.backgroundTasks.dispose());

  test('输入超限时强制压缩一次并重试，run 正常跑完', () async {
    final chatService = _FakeChatService(
      error: StateError(
        "This model's maximum context length is 8192 tokens, however you "
        'requested 12000 tokens',
      ),
    );

    final result = await run(chatService);

    expect(result.compactCalls, 1, reason: '超限触发一次强制压缩');
    expect(chatService.calls, 2, reason: '第一次超限、第二次重试');
    // 重试用的是压缩后的上下文：摘要进来、原历史退出。
    expect(
      chatService.requests.last.map((m) => m.toString()),
      contains(contains('summary of earlier turns')),
    );
    expect(
      chatService.requests.last.map((m) => m.toString()),
      isNot(contains(contains('hello'))),
    );
    expect(result.events.whereType<AgentCompactionEvent>(), hasLength(1));
    expect(
      result.events.whereType<AgentTextEvent>().map((e) => e.delta).join(),
      'ok',
    );
    expect(
      result.events
          .whereType<AgentRunOutcomeEvent>()
          .single
          .outcome
          .termination,
      AgentRunTermination.completed,
    );
  });

  test('非超限错误不触发压缩，原样冒泡', () async {
    final chatService = _FakeChatService(
      error: StateError('Error code: 401 - invalid api key'),
    );

    await expectLater(run(chatService), throwsA(isA<StateError>()));
    expect(chatService.calls, 1);
  });

  test('重试仍超限时如实抛错，不反复压缩', () async {
    final chatService = _FakeChatService(
      error: StateError('This model\'s maximum context length is 8192 tokens'),
      errorCalls: 2,
    );

    await expectLater(run(chatService), throwsA(isA<StateError>()));
    expect(chatService.calls, 2, reason: '兜底只重试一次');
  });
}
