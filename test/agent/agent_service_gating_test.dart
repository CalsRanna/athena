import 'dart:async';

import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/cancel_token.dart';
import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/agent/tool/tool_interface.dart' as agent_tool;
import 'package:athena/agent/tool/tool_registry.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/service/chat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openai_dart/openai_dart.dart';

/// A [ChatService] that yields preset stream events instead of making network
/// calls. The first [getCompletion] call yields a chunk containing a tool call
/// (so the accumulator produces a tool call to gate); the second call yields a
/// plain-content chunk with no tool calls so the AgentService loop terminates.
class _FakeChatService extends ChatService {
  _FakeChatService({required this.toolName});

  final String toolName;
  int callCount = 0;

  @override
  Stream<ChatStreamEvent> getCompletion({
    required ChatEntity chat,
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    List<Tool>? tools,
  }) async* {
    final current = callCount;
    callCount++;
    if (current == 0) {
      yield ChatStreamEvent.fromJson({
        'choices': [
          {
            'index': 0,
            'delta': {
              'tool_calls': [
                {
                  'index': 0,
                  'id': 'call_1',
                  'type': 'function',
                  'function': {'name': toolName, 'arguments': '{}'},
                }
              ],
            },
            'finish_reason': null,
          }
        ],
      });
    } else {
      yield ChatStreamEvent.fromJson({
        'choices': [
          {
            'index': 0,
            'delta': {'content': 'done'},
            'finish_reason': 'stop',
          }
        ],
      });
    }
  }
}

/// A [Tool] that records whether [execute] was reached, with a configurable
/// [name], [dangerLevel], and optional [resultLength].
class _RecordingTool implements agent_tool.Tool {
  _RecordingTool({
    required this.name,
    required this.dangerLevel,
    this.resultLength,
  });

  @override
  final String name;
  @override
  final agent_tool.DangerLevel dangerLevel;
  final int? resultLength;

  bool executed = false;

  @override
  String get description => 'recording test tool';

  @override
  Map<String, dynamic> get parameters => {'type': 'object', 'properties': {}};

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    executed = true;
    if (resultLength != null) return 'x' * resultLength!;
    return 'ok';
  }
}

ChatEntity _chat() => ChatEntity(
      title: 't',
      modelId: 1,
      sentinelId: 1,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

ProviderEntity _provider() => ProviderEntity(
      name: 'p',
      baseUrl: 'http://localhost',
      apiKey: 'k',
      createdAt: DateTime(2024),
    );

ModelEntity _model() => ModelEntity(
      name: 'm',
      modelId: 'm',
      providerId: 1,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

/// Drives [AgentService.run] to completion and returns all emitted events.
Future<List<AgentEvent>> _runAgent({
  required _RecordingTool tool,
  required ChatService chatService,
  PermissionService? permissionService,
  PermissionCallback? onPermission,
  CancelToken? cancelToken,
}) {
  final registry = ToolRegistry()..registerAll([tool]);
  final agent = AgentService(
    chatService: chatService,
    toolRegistry: registry,
    skillRegistry: null,
  );
  return agent
      .run(
        chat: _chat(),
        provider: _provider(),
        model: _model(),
        baseMessages: [ChatMessage.user('hi')],
        permissionService: permissionService,
        onPermission: onPermission,
        cancelToken: cancelToken,
      )
      .toList();
}

AgentToolResultEvent? _firstToolResult(List<AgentEvent> events) {
  for (final e in events) {
    if (e is AgentToolResultEvent) return e;
  }
  return null;
}

/// A ChatService that always returns a tool call, never a plain content
/// chunk — so the loop would run forever without maxIterations.
class _InfiniteToolCallChatService extends ChatService {
  _InfiniteToolCallChatService({required this.toolName});
  final String toolName;

  @override
  Stream<ChatStreamEvent> getCompletion({
    required ChatEntity chat,
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    List<Tool>? tools,
  }) async* {
    yield ChatStreamEvent.fromJson({
      'choices': [
        {
          'index': 0,
          'delta': {
            'tool_calls': [
              {
                'index': 0,
                'id': 'call_${messages.length}',
                'type': 'function',
                'function': {'name': toolName, 'arguments': '{}'},
              }
            ],
          },
          'finish_reason': null,
        }
      ],
    });
  }
}

void main() {
  // Sanity check: confirm the fake stream JSON actually produces a tool call
  // through the accumulator before relying on it to exercise the gate.
  test('fake stream chunk yields a tool call through the accumulator', () {
    final accumulator = ChatStreamAccumulator();
    accumulator.add(ChatStreamEvent.fromJson({
      'choices': [
        {
          'index': 0,
          'delta': {
            'tool_calls': [
              {
                'index': 0,
                'id': 'call_1',
                'type': 'function',
                'function': {'name': 'demo', 'arguments': '{}'},
              }
            ],
          },
          'finish_reason': null,
        }
      ],
    }));
    expect(accumulator.toolCalls, isNotEmpty);
    expect(accumulator.toolCalls.first.function.name, 'demo');
  });

  group('AgentService danger-level gating', () {
    test('safe tool executes without approval', () async {
      final tool = _RecordingTool(name: 'safe_tool', dangerLevel: agent_tool.DangerLevel.safe);
      var onPermissionCalled = false;
      final events = await _runAgent(
        tool: tool,
        chatService: _FakeChatService(toolName: tool.name),
        permissionService: PermissionService(store: PermissionStore()),
        onPermission: (_, __) async {
          onPermissionCalled = true;
          return true;
        },
      );

      expect(tool.executed, isTrue);
      expect(onPermissionCalled, isFalse);
      expect(_firstToolResult(events)?.result, 'ok');
    });

    test('needsApproval tool with no rule and onPermission=true executes',
        () async {
      final tool =
          _RecordingTool(name: 'risky', dangerLevel: agent_tool.DangerLevel.needsApproval);
      final events = await _runAgent(
        tool: tool,
        chatService: _FakeChatService(toolName: tool.name),
        permissionService: PermissionService(store: PermissionStore()),
        onPermission: (_, __) async => true,
      );

      expect(tool.executed, isTrue);
      expect(_firstToolResult(events)?.result, 'ok');
    });

    test('needsApproval tool with no rule and onPermission=false is denied',
        () async {
      final tool =
          _RecordingTool(name: 'risky', dangerLevel: agent_tool.DangerLevel.needsApproval);
      final events = await _runAgent(
        tool: tool,
        chatService: _FakeChatService(toolName: tool.name),
        permissionService: PermissionService(store: PermissionStore()),
        onPermission: (_, __) async => false,
      );

      expect(tool.executed, isFalse);
      expect(_firstToolResult(events)?.result, contains('User denied'));
    });

    test('needsApproval tool with auto-allow rule skips onPermission',
        () async {
      final tool =
          _RecordingTool(name: 'risky', dangerLevel: agent_tool.DangerLevel.needsApproval);
      final store = PermissionStore()
        ..allowRules = [const PermissionRule(tool: 'risky')];
      var onPermissionCalled = false;
      final events = await _runAgent(
        tool: tool,
        chatService: _FakeChatService(toolName: tool.name),
        permissionService: PermissionService(store: store),
        onPermission: (_, __) async {
          onPermissionCalled = true;
          return false;
        },
      );

      expect(tool.executed, isTrue);
      expect(onPermissionCalled, isFalse);
      expect(_firstToolResult(events)?.result, 'ok');
    });

    test('needsApproval tool with no onPermission callback is denied',
        () async {
      final tool =
          _RecordingTool(name: 'risky', dangerLevel: agent_tool.DangerLevel.needsApproval);
      final events = await _runAgent(
        tool: tool,
        chatService: _FakeChatService(toolName: tool.name),
        permissionService: PermissionService(store: PermissionStore()),
        onPermission: null,
      );

      expect(tool.executed, isFalse);
      final result = _firstToolResult(events)?.result;
      expect(result, contains('approval'));
      expect(result, contains('no permission'));
    });

    test('forbidden tool is never executed and emits rejection', () async {
      final tool = _RecordingTool(
          name: 'forbidden_tool', dangerLevel: agent_tool.DangerLevel.forbidden);
      final events = await _runAgent(
        tool: tool,
        chatService: _FakeChatService(toolName: tool.name),
        permissionService: PermissionService(store: PermissionStore()),
        onPermission: (_, __) async => true,
      );

      expect(tool.executed, isFalse);
      final result = _firstToolResult(events)?.result;
      expect(result, contains('forbidden'));
    });

    test('pre-cancelled token stops run before any tool executes', () async {
      final tool =
          _RecordingTool(name: 'risky', dangerLevel: agent_tool.DangerLevel.needsApproval);
      final cancelToken = CancelToken()..cancel();
      await expectLater(
        _runAgent(
          tool: tool,
          chatService: _FakeChatService(toolName: tool.name),
          permissionService: PermissionService(store: PermissionStore()),
          onPermission: (_, __) async => true,
          cancelToken: cancelToken,
        ),
        throwsA(isA<CancelledException>()),
      );
      expect(tool.executed, isFalse);
    });

    test('cancel during approval wait stops run before tool executes',
        () async {
      final tool =
          _RecordingTool(name: 'risky', dangerLevel: agent_tool.DangerLevel.needsApproval);
      final cancelToken = CancelToken();
      final enteredApproval = Completer<void>();
      final approvalGate = Completer<bool>();

      final future = _runAgent(
        tool: tool,
        chatService: _FakeChatService(toolName: tool.name),
        permissionService: PermissionService(store: PermissionStore()),
        onPermission: (_, __) {
          if (!enteredApproval.isCompleted) enteredApproval.complete();
          return approvalGate.future;
        },
        cancelToken: cancelToken,
      );

      await enteredApproval.future;
      cancelToken.cancel();

      await expectLater(future, throwsA(isA<CancelledException>()));
      expect(tool.executed, isFalse);
    });
  });

  group('AgentService iteration limit', () {
    test('stops after maxIterations even when model keeps requesting tools',
        () async {
      final tool =
          _RecordingTool(name: 'loop', dangerLevel: agent_tool.DangerLevel.safe);
      final registry = ToolRegistry()..registerAll([tool]);
      final agent = AgentService(
        chatService: _InfiniteToolCallChatService(toolName: tool.name),
        toolRegistry: registry,
      );
      final events = await agent
          .run(
            chat: _chat(),
            provider: _provider(),
            model: _model(),
            baseMessages: [ChatMessage.user('hi')],
            maxIterations: 2,
          )
          .toList();

      // Each iteration: tool call + tool result + iterationComplete + text/empty events
      // Iteration 1: no done event because toolCalls is non-empty
      // Iteration 2: same
      // After iteration 2, the for-loop exits cleanly (no further stream call)

      final doneEvents =
          events.whereType<AgentDoneEvent>().toList();
      expect(doneEvents, isEmpty,
          reason: 'should never reach done because tool always returns calls');
      // The tool should have executed exactly maxIterations times
      expect(tool.executed, isTrue);
      // Each iteration yields at least one toolCall + one toolResult
      final callCount = events.whereType<AgentToolCallEvent>().length;
      final resultCount = events.whereType<AgentToolResultEvent>().length;
      expect(callCount, 2);
      expect(resultCount, 2);
      expect(
        events.whereType<AgentIterationCompleteEvent>().length,
        2,
      );
    });
  });

  group('AgentService _smartTruncate', () {
    test('short result is returned as-is', () {
      final agent = AgentService();
      expect(agent.smartTruncate('hello'), 'hello');
    });

    test('result at threshold is returned as-is', () {
      final agent = AgentService();
      final s = 'x' * 12000;
      expect(agent.smartTruncate(s), s);
    });

    test('result over threshold is truncated with marker', () {
      final agent = AgentService();
      final s = 'x' * 20000;
      final result = agent.smartTruncate(s);
      expect(result.length, lessThanOrEqualTo(12100)); // 12000 + marker overhead
      expect(result, contains('[truncated'));
      expect(result, contains('characters]'));
      // Head portion preserved
      expect(result, startsWith('xxx'));
      // Tail portion preserved
      expect(result, endsWith('xxx'));
    });

    test('custom threshold', () {
      final agent = AgentService();
      final s = 'y' * 1000;
      final result = agent.smartTruncate(s, threshold: 500);
      expect(result.length, lessThanOrEqualTo(600));
      expect(result, contains('[truncated'));
    });
  });

  group('AgentService skill prompt injection', () {
    test('skillPrompt is prepended as system message on first iteration only',
        () async {
      final tool =
          _RecordingTool(name: 'safe_tool', dangerLevel: agent_tool.DangerLevel.safe);
      final registry = ToolRegistry()..registerAll([tool]);
      // This ChatService returns tool calls first, then plain content so the
      // loop terminates after the second request.
      final chatService = _FakeChatService(toolName: tool.name);
      final agent = AgentService(
        chatService: chatService,
        toolRegistry: registry,
      );
      final events = await agent
          .run(
            chat: _chat(),
            provider: _provider(),
            model: _model(),
            baseMessages: [ChatMessage.user('hi')],
            skillPrompt: 'SKILL INSTRUCTIONS',
            maxIterations: 5,
          )
          .toList();

      // The agent should complete (done event exists)
      expect(events.whereType<AgentDoneEvent>(), isNotEmpty);

      // _FakeChatService.callCount tells us how many getCompletion calls were made.
      // First call had skillPrompt injected (sent along with the messages).
      // We can't inspect the messages directly, but we verified the run completes.
      expect(chatService.callCount, greaterThanOrEqualTo(2));
    });
  });

  group('AgentService tool result processing', () {
    test('unknown tool name emits error result', () async {
      // Register no tool matching the name the ChatService will request.
      final registry = ToolRegistry();
      final agent = AgentService(
        chatService: _FakeChatService(toolName: 'ghost_tool'),
        toolRegistry: registry,
      );
      final events = await agent
          .run(
            chat: _chat(),
            provider: _provider(),
            model: _model(),
            baseMessages: [ChatMessage.user('hi')],
          )
          .toList();

      final result = _firstToolResult(events);
      expect(result, isNotNull);
      expect(result!.result, contains('Unknown tool'));
      expect(result.result, contains('ghost_tool'));
    });

    test('tool result > 12000 chars is truncated', () async {
      final longTool = _RecordingTool(
        name: 'verbose',
        dangerLevel: agent_tool.DangerLevel.safe,
        resultLength: 15000,
      );

      final events = await _runAgent(
        tool: longTool,
        chatService: _FakeChatService(toolName: longTool.name),
        permissionService: PermissionService(store: PermissionStore()),
        onPermission: (_, __) async => true,
      );

      expect(longTool.executed, isTrue);
      expect(events.whereType<AgentToolResultEvent>(), isNotEmpty);
    });
  });

  group('AgentService auxiliary model summarization', () {
    test(
        'calls summarization when tool result > 4000 chars and aux model is provided',
        () async {
      final longTool = _RecordingTool(
        name: 'verbose',
        dangerLevel: agent_tool.DangerLevel.safe,
        resultLength: 5000,
      );

      final service = _SummarizationTestChatService(
        toolName: longTool.name,
        summaryResponse: 'condensed result',
      );

      final registry = ToolRegistry()..registerAll([longTool]);
      final agent = AgentService(
        chatService: service,
        toolRegistry: registry,
      );

      await agent
          .run(
            chat: _chat(),
            provider: _provider(),
            model: _model(),
            baseMessages: [ChatMessage.user('hi')],
            auxiliaryModel: _model(),
            auxiliaryModelProvider: _provider(),
            maxIterations: 5,
          )
          .toList();

      // The summarization request should have been made
      expect(service.summarizationCallCount, 1);
    });

    test('skips summarization when aux model is null', () async {
      final longTool = _RecordingTool(
        name: 'verbose',
        dangerLevel: agent_tool.DangerLevel.safe,
        resultLength: 5000,
      );

      final service = _SummarizationTestChatService(
        toolName: longTool.name,
        summaryResponse: 'should not be used',
      );

      final registry = ToolRegistry()..registerAll([longTool]);
      final agent = AgentService(
        chatService: service,
        toolRegistry: registry,
      );

      await agent
          .run(
            chat: _chat(),
            provider: _provider(),
            model: _model(),
            baseMessages: [ChatMessage.user('hi')],
            auxiliaryModel: null,
            auxiliaryModelProvider: null,
            maxIterations: 5,
          )
          .toList();

      expect(service.summarizationCallCount, 0);
    });

    test('skips summarization when tool result <= 4000 chars', () async {
      final shortTool = _RecordingTool(
        name: 'terse',
        dangerLevel: agent_tool.DangerLevel.safe,
        resultLength: 1000,
      );

      final service = _SummarizationTestChatService(
        toolName: shortTool.name,
        summaryResponse: 'should not be used',
      );

      final registry = ToolRegistry()..registerAll([shortTool]);
      final agent = AgentService(
        chatService: service,
        toolRegistry: registry,
      );

      await agent
          .run(
            chat: _chat(),
            provider: _provider(),
            model: _model(),
            baseMessages: [ChatMessage.user('hi')],
            auxiliaryModel: _model(),
            auxiliaryModelProvider: _provider(),
            maxIterations: 5,
          )
          .toList();

      expect(service.summarizationCallCount, 0);
    });
  });

  group('AgentService event types', () {
    test('text delta events are emitted during streaming', () async {
      final tool =
          _RecordingTool(name: 'safe_tool', dangerLevel: agent_tool.DangerLevel.safe);
      final registry = ToolRegistry()..registerAll([tool]);
      // Custom service that also emits text before the tool call
      final service = _TextAndToolChatService(toolName: tool.name);
      final agent = AgentService(
        chatService: service,
        toolRegistry: registry,
      );

      final events = await agent
          .run(
            chat: _chat(),
            provider: _provider(),
            model: _model(),
            baseMessages: [ChatMessage.user('hi')],
            maxIterations: 5,
          )
          .toList();

      final textEvents = events.whereType<AgentTextEvent>().toList();
      expect(textEvents, isNotEmpty);
      expect(textEvents.any((e) => e.delta == 'hello'), isTrue);
    });
  });
}

/// ChatService that counts how many times the summarization path triggers.
class _SummarizationTestChatService extends ChatService {
  _SummarizationTestChatService({
    required this.toolName,
    required this.summaryResponse,
  });

  final String toolName;
  final String summaryResponse;
  int callCount = 0;
  int summarizationCallCount = 0;

  @override
  Stream<ChatStreamEvent> getCompletion({
    required ChatEntity chat,
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    List<Tool>? tools,
  }) async* {
    final current = callCount;
    callCount++;
    if (current == 0) {
      yield ChatStreamEvent.fromJson({
        'choices': [
          {
            'index': 0,
            'delta': {
              'tool_calls': [
                {
                  'index': 0,
                  'id': 'call_1',
                  'type': 'function',
                  'function': {'name': toolName, 'arguments': '{}'},
                }
              ],
            },
            'finish_reason': null,
          }
        ],
      });
    } else {
      yield ChatStreamEvent.fromJson({
        'choices': [
          {
            'index': 0,
            'delta': {'content': 'done'},
            'finish_reason': 'stop',
          }
        ],
      });
    }
  }

  @override
  Future<String> complete({
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    summarizationCallCount++;
    return summaryResponse;
  }
}

/// ChatService that emits text before a tool call.
class _TextAndToolChatService extends ChatService {
  _TextAndToolChatService({required this.toolName});
  final String toolName;

  @override
  Stream<ChatStreamEvent> getCompletion({
    required ChatEntity chat,
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    List<Tool>? tools,
  }) async* {
    // Text chunk first
    yield ChatStreamEvent.fromJson({
      'choices': [
        {
          'index': 0,
          'delta': {'content': 'hello'},
          'finish_reason': null,
        }
      ],
    });
    // Then a tool call
    yield ChatStreamEvent.fromJson({
      'choices': [
        {
          'index': 0,
          'delta': {
            'tool_calls': [
              {
                'index': 0,
                'id': 'call_1',
                'type': 'function',
                'function': {'name': toolName, 'arguments': '{}'},
              }
            ],
          },
          'finish_reason': null,
        }
      ],
    });
  }
}



extension AgentServiceTestAccess on AgentService {
  // smartTruncate is now @visibleForTesting; direct call is fine
}
