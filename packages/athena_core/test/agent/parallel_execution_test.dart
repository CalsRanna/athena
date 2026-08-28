import 'dart:async';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/tool/bash_shell_tool.dart';
import 'package:athena_core/agent/tool/tool_interface.dart' as athena;
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/chat_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:openai_dart/openai_dart.dart'
    show
        ChatCompletionsResource,
        ChatResource,
        ChatStreamEvent,
        ChatStreamChoice,
        ChatCompletionCreateRequest,
        ChatDelta,
        ChatMessage,
        FinishReason,
        FunctionCall,
        FunctionCallDelta,
        InterceptorChain,
        OpenAIClient,
        OpenAIConfig,
        ToolCall,
        ToolCallDelta;
// RequestBuilder 未被 openai_dart 公开导出，直接引用内部文件。
import 'package:openai_dart/src/client/request_builder.dart';

// ─── 伪 LLM：按调用次序返回预设 chunk 序列 ──────────────────────

/// 记录每次 createStream 调用，按次序执行预设脚本。
class _FakeCompletions extends ChatCompletionsResource {
  final List<List<ChatStreamEvent> Function()> _script;
  int calls = 0;

  _FakeCompletions(this._script)
      : super(
          config: const OpenAIConfig(baseUrl: 'http://fake'),
          httpClient: http.Client(),
          interceptorChain: InterceptorChain(
            interceptors: [],
            httpClient: http.Client(),
          ),
          requestBuilder:
              RequestBuilder(config: const OpenAIConfig(baseUrl: 'http://fake')),
        );

  @override
  Stream<ChatStreamEvent> createStream(
    ChatCompletionCreateRequest request, {
    Future<void>? abortTrigger,
  }) async* {
    final script = _script[calls];
    calls++;
    for (final event in script()) {
      yield event;
    }
  }
}

class _FakeChatResource extends ChatResource {
  final _FakeCompletions completionsOverride;

  _FakeChatResource(this.completionsOverride)
      : super(
          config: const OpenAIConfig(baseUrl: 'http://fake'),
          httpClient: http.Client(),
          interceptorChain: InterceptorChain(
            interceptors: [],
            httpClient: http.Client(),
          ),
          requestBuilder:
              RequestBuilder(config: const OpenAIConfig(baseUrl: 'http://fake')),
        );

  @override
  ChatCompletionsResource get completions => completionsOverride;
}

class _FakeOpenAIClient extends OpenAIClient {
  final _FakeChatResource chatOverride;

  _FakeOpenAIClient(this.chatOverride)
      : super(config: const OpenAIConfig(baseUrl: 'http://fake'));

  @override
  ChatResource get chat => chatOverride;
}

// ─── chunk 构造辅助 ──────────────────────────────────────────

ChatStreamEvent _toolCallChunk(
  int index,
  String id,
  String name,
  String args,
) =>
    ChatStreamEvent(
      choices: [
        ChatStreamChoice(
          index: 0,
          delta: ChatDelta(
            toolCalls: [
              ToolCallDelta(
                index: index,
                id: id,
                type: 'function',
                function: FunctionCallDelta(name: name, arguments: args),
              ),
            ],
          ),
        ),
      ],
    );

ChatStreamEvent _finishChunk(FinishReason reason) => ChatStreamEvent(
      choices: [
        ChatStreamChoice(
          index: 0,
          delta: const ChatDelta(),
          finishReason: reason,
        ),
      ],
    );

ChatStreamEvent _textChunk(String text) => ChatStreamEvent(
      choices: [ChatStreamChoice(index: 0, delta: ChatDelta(content: text))],
    );

// ─── 测试工具 ────────────────────────────────────────────────

/// 并行只读测试工具：可配延迟，记录并发峰值。
class _ParTool extends athena.Tool {
  _ParTool({this.delay = Duration.zero});

  final Duration delay;
  int active = 0;
  int maxActive = 0;

  @override
  String get name => 'par_tool';

  @override
  String get description => 'parallel test tool';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'id': {'type': 'string'},
        },
      };

  @override
  ExecutionMode get executionMode => ExecutionMode.parallel;

  @override
  athena.ToolRisk get risk => athena.ToolRisk.readOnly;

  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async {
    active++;
    if (active > maxActive) maxActive = active;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    active--;
    return 'done:${args['id']}';
  }
}

/// 需要审批的并行工具（dangerous 且无规则命中 → check 返回 null）。
class _ParDangerTool extends _ParTool {
  @override
  String get name => 'par_danger';

  @override
  athena.ToolRisk get risk => athena.ToolRisk.dangerous;
}

/// 覆写 execute 的 bash，复用 BashShellTool 的 canExecuteParallel 判定。
class _FakeBashTool extends BashShellTool {
  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async {
    return 'ok:${args['command']}';
  }
}

// ─── 通用构造 ───────────────────────────────────────────────

ToolCall _call(String id, String name, [String args = '{}']) => ToolCall(
      id: id,
      type: 'function',
      function: FunctionCall(name: name, arguments: args),
    );

ChatEntity _chat() => ChatEntity(
      title: 't',
      modelId: 1,
      sentinelId: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

ProviderEntity _provider() => ProviderEntity(
      name: 'p',
      baseUrl: 'http://fake',
      apiKey: 'k',
      createdAt: DateTime(2026),
    );

ModelEntity _model() => ModelEntity(
      name: 'm',
      modelId: 'm1',
      providerId: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// 使用预设脚本的 LLM 客户端，脚本按 createStream 调用次序执行。
///
/// [_FakeCompletions] 必须在 factory 之外共享：LlmClient 每轮请求都会
/// 新建客户端实例，若在 factory 内创建，calls 计数器会每次归零，
/// 导致所有轮次都返回同一脚本。
LlmClient _fakeLlm(List<List<ChatStreamEvent> Function()> script) {
  final completions = _FakeCompletions(script);
  return LlmClient(
    clientFactory: ({required String apiKey, required String? baseUrl}) =>
        _FakeOpenAIClient(_FakeChatResource(completions)),
  );
}

void main() {
  // ─── 分组决策单测 ─────────────────────────────────────────
  group('selectParallelCalls 分组决策', () {
    late AgentService service;

    setUp(() {
      final registry = ToolRegistry()
        ..register(_ParTool())
        ..register(_ParDangerTool())
        ..register(_FakeBashTool());
      service = AgentService(
        chatService: ChatService(llmClient: LlmClient()),
        toolRegistry: registry,
      );
    });

    test('无权限系统时 parallel 工具进并行组', () {
      final parallel = service.selectParallelCalls(
          runId: 1,
        [
        _call('a', 'par_tool'),
        _call('b', 'par_tool'),
      ]);
      expect(parallel.length, 2);
    });

    test('需弹窗的调用在权限预检下降级串行', () {
      final permissionService = PermissionService(
        store: PermissionStore()..rules = [],
      );
      final parallel = service.selectParallelCalls(
          runId: 1,
        [
          _call('a', 'par_danger'), // dangerous 无规则 → 降级
          _call('b', 'par_tool'), // readOnly → 保留
        ],
        permissionService: permissionService,
        onPermission: (name, args) async => true,
      );
      expect(parallel.map((c) => c.id), ['b']);
    });

    test('无 permissionService 但配置 onPermission 时保守全部串行', () {
      final parallel = service.selectParallelCalls(
          runId: 1,
        [_call('a', 'par_tool')],
        onPermission: (name, args) async => true,
      );
      expect(parallel, isEmpty);
    });

    test('无权限系统（两者皆空）时不做预检降级', () {
      final parallel = service.selectParallelCalls(
          runId: 1,
        [_call('a', 'par_tool')]);
      expect(parallel.length, 1);
    });

    test('bash 只读命令可并行、有副作用命令串行', () {
      final parallel = service.selectParallelCalls(
          runId: 1,
        [
        _call('a', 'bash', '{"command": "ls -la"}'),
        _call('b', 'bash', '{"command": "rm foo"}'),
      ]);
      expect(parallel.map((c) => c.id), ['a']);
    });

    test('参数解析失败自动归入串行', () {
      final parallel = service.selectParallelCalls(
          runId: 1,
        [
        _call('a', 'par_tool', 'not-json'),
      ]);
      expect(parallel, isEmpty);
    });

    test('未知工具不进并行组', () {
      final parallel = service.selectParallelCalls(
          runId: 1,
        [
        _call('a', 'no_such_tool'),
      ]);
      expect(parallel, isEmpty);
    });
  });

  // ─── run() 并发行为 ───────────────────────────────────────
  group('run() 并行执行', () {
    AgentService buildService(
      ToolRegistry registry,
      List<List<ChatStreamEvent> Function()> script, {
      PermissionService? permissionService,
    }) {
      return AgentService(
        chatService: ChatService(llmClient: _fakeLlm(script)),
        toolRegistry: registry,
      );
    }

    List<List<ChatStreamEvent> Function()> toolScript(List<ChatStreamEvent> firstRound) => [
          () => firstRound,
          () => [_textChunk('done'), _finishChunk(FinishReason.stop)],
        ];

    test('并行工具并发执行：3 个 80ms 调用总耗时 < 240ms', () async {
      final parTool = _ParTool(delay: const Duration(milliseconds: 80));
      final registry = ToolRegistry()..register(parTool);
      final service = buildService(registry, toolScript([
        _toolCallChunk(0, 'c1', 'par_tool', '{"id": "1"}'),
        _toolCallChunk(1, 'c2', 'par_tool', '{"id": "2"}'),
        _toolCallChunk(2, 'c3', 'par_tool', '{"id": "3"}'),
        _finishChunk(FinishReason.toolCalls),
      ]));

      final sw = Stopwatch()..start();
      final events = await service
          .run(
            runId: 1,
            chat: _chat(),
            provider: _provider(),
            model: _model(),
            baseMessages: [ChatMessage.user('hi')],
          )
          .toList();
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(240),
          reason: '串行执行至少需要 240ms，并行应在 ~80ms 完成');
      expect(parTool.maxActive, 3, reason: '三个调用应真正并发执行');
      expect(events.whereType<AgentToolResultEvent>().length, 3);
      expect(events.whereType<AgentDoneEvent>().length, 1);
    });

    test('信号量限流：9 个并行调用并发峰值不超过 8', () async {
      final parTool = _ParTool(delay: const Duration(milliseconds: 50));
      final registry = ToolRegistry()..register(parTool);
      final firstRound = [
        for (var i = 0; i < 9; i++)
          _toolCallChunk(i, 'c$i', 'par_tool', '{"id": "$i"}'),
        _finishChunk(FinishReason.toolCalls),
      ];
      final service = buildService(registry, toolScript(firstRound));

      final sw = Stopwatch()..start();
      await service
          .run(
            runId: 1,
            chat: _chat(),
            provider: _provider(),
            model: _model(),
            baseMessages: [ChatMessage.user('hi')],
          )
          .toList();
      sw.stop();

      expect(parTool.maxActive, lessThanOrEqualTo(8));
      expect(parTool.maxActive, greaterThanOrEqualTo(2));
      // 串行需要 450ms；限流 8 下约 100ms
      expect(sw.elapsedMilliseconds, lessThan(300));
    });

    test('需弹窗的并行工具降级串行，onPermission 无并发', () async {
      final parTool = _ParTool();
      final dangerTool = _ParDangerTool();
      final registry = ToolRegistry()
        ..register(parTool)
        ..register(dangerTool);
      final service = buildService(registry, toolScript([
        _toolCallChunk(0, 'c1', 'par_danger', '{"id": "d1"}'),
        _toolCallChunk(1, 'c2', 'par_tool', '{"id": "r1"}'),
        _toolCallChunk(2, 'c3', 'par_danger', '{"id": "d2"}'),
        _finishChunk(FinishReason.toolCalls),
      ]));

      var permissionActive = 0;
      var permissionMaxActive = 0;
      final permissionCalls = <String>[];

      await service
          .run(
            runId: 1,
            chat: _chat(),
            provider: _provider(),
            model: _model(),
            baseMessages: [ChatMessage.user('hi')],
            permissionService: PermissionService(
              store: PermissionStore()..rules = [],
            ),
            onPermission: (toolName, arguments) async {
              permissionCalls.add(toolName);
              permissionActive++;
              if (permissionActive > permissionMaxActive) {
                permissionMaxActive = permissionActive;
              }
              await Future<void>.delayed(const Duration(milliseconds: 20));
              permissionActive--;
              return true;
            },
          )
          .toList();

      expect(permissionCalls.length, 2, reason: '两个 dangerous 调用都需审批');
      expect(permissionMaxActive, 1,
          reason: '弹窗必须逐个出现，不得并发');
      expect(parTool.maxActive, 1,
          reason: 'readOnly 调用保留并行，但降级后组内只剩它，峰值应为 1');
    });

    test('取消时不被慢工具拖住', () async {
      final parTool = _ParTool(delay: const Duration(milliseconds: 600));
      final registry = ToolRegistry()..register(parTool);
      final service = buildService(registry, toolScript([
        _toolCallChunk(0, 'c1', 'par_tool', '{"id": "1"}'),
        _finishChunk(FinishReason.toolCalls),
      ]));

      final cancelToken = CancelToken();
      final errorCompleter = Completer<Object?>();
      final startCompleter = Completer<void>();

      final sub = service
          .run(
            runId: 1,
            chat: _chat(),
            provider: _provider(),
            model: _model(),
            baseMessages: [ChatMessage.user('hi')],
            cancelToken: cancelToken,
          )
          .listen(
            (e) {
              if (e is AgentToolExecutionStartEvent &&
                  !startCompleter.isCompleted) {
                startCompleter.complete();
              }
            },
            onError: (Object e) {
              if (!errorCompleter.isCompleted) errorCompleter.complete(e);
            },
            onDone: () {
              if (!errorCompleter.isCompleted) errorCompleter.complete(null);
            },
          );

      await startCompleter.future;
      final sw = Stopwatch()..start();
      cancelToken.cancel();
      final error = await errorCompleter.future
          .timeout(const Duration(seconds: 3));
      sw.stop();

      expect(error, isA<CancelledException>());
      // 取消后排空在飞工具（最多 2s）：600ms 工具完成即返回，
      // 不应等满工具的原始超时。
      expect(sw.elapsedMilliseconds, lessThan(2500),
          reason: '排空窗口 2s，慢工具 600ms 完成后取消应立即结束');
      await sub.cancel();
    });

    test('取消后排空在飞工具：结果被吞、不产出事件、无未处理错误',
        () async {
      final parTool = _ParTool(delay: const Duration(milliseconds: 120));
      final registry = ToolRegistry()..register(parTool);
      final service = buildService(registry, toolScript([
        _toolCallChunk(0, 'c1', 'par_tool', '{"id": "1"}'),
        _finishChunk(FinishReason.toolCalls),
      ]));

      final cancelToken = CancelToken();
      final events = <AgentEvent>[];
      final errorCompleter = Completer<Object?>();
      final startCompleter = Completer<void>();

      final sub = service
          .run(
            runId: 1,
            chat: _chat(),
            provider: _provider(),
            model: _model(),
            baseMessages: [ChatMessage.user('hi')],
            cancelToken: cancelToken,
          )
          .listen(
            (e) {
              events.add(e);
              if (e is AgentToolExecutionStartEvent &&
                  !startCompleter.isCompleted) {
                startCompleter.complete();
              }
            },
            onError: (Object e) {
              if (!errorCompleter.isCompleted) errorCompleter.complete(e);
            },
            onDone: () {
              if (!errorCompleter.isCompleted) errorCompleter.complete(null);
            },
          );

      await startCompleter.future
          .timeout(const Duration(seconds: 2), onTimeout: () {
        fail('tool start event never arrived');
      });
      cancelToken.cancel();
      final error = await errorCompleter.future
          .timeout(const Duration(seconds: 5));

      // 取消以 CancelledException 呈现；在飞工具完成后的结果事件
      // 被排空丢弃（120ms 工具在排空窗口内完成，但其结果不再产出）。
      expect(error, isA<CancelledException>());
      expect(
        events.whereType<AgentToolResultEvent>().isEmpty,
        isTrue,
        reason: '取消后工具结果不应继续产出',
      );
      await sub.cancel();
    });
  });
}
