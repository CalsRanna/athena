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
/// [name] and [dangerLevel].
class _RecordingTool implements agent_tool.Tool {
  _RecordingTool({required this.name, required this.dangerLevel});

  @override
  final String name;
  @override
  final agent_tool.DangerLevel dangerLevel;

  bool executed = false;

  @override
  String get description => 'recording test tool';

  @override
  Map<String, dynamic> get parameters => {'type': 'object', 'properties': {}};

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    executed = true;
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
}
