import 'dart:convert';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/tool/bash_shell_tool.dart';
import 'package:athena_core/agent/tool/powershell_shell_tool.dart';
import 'package:athena_core/agent/tool/tool_interface.dart' as athena;
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/tool/tool_result.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:openai_dart/openai_dart.dart' show FunctionCall, ToolCall;
import 'package:test/test.dart';

class _RecordingTool extends athena.Tool implements athena.CancellableTool {
  Map<String, dynamic>? received;
  Map<String, dynamic>? parallelArgs;

  @override
  String get name => 'recording';
  @override
  String get description => 'Records arguments';
  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'description': {'type': 'string'},
    },
    'required': ['description'],
    'additionalProperties': false,
  };

  @override
  bool canExecuteParallel(Map<String, dynamic> args) {
    parallelArgs = Map.of(args);
    return true;
  }

  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async {
    received = Map.of(args);
    return 'ok';
  }

  @override
  Future<String> executeCancellable(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
    required Future<void> cancelSignal,
  }) => execute(args, onUpdate: onUpdate);
}

void main() {
  late _RecordingTool tool;
  late ToolRegistry registry;
  late AgentService service;

  setUp(() {
    tool = _RecordingTool();
    registry = ToolRegistry()..register(tool);
    service = AgentService(
      chatService: ChatCompletionsService(llmClient: LlmClient()),
      toolRegistry: registry,
    );
  });

  ToolCall call(Map<String, dynamic> args) => ToolCall(
    id: 'call-1',
    type: 'function',
    function: FunctionCall(name: tool.name, arguments: jsonEncode(args)),
  );

  test('registry adds optional metadata without changing business schemas', () {
    registry.registerAll([BashShellTool(), PowerShellShellTool()]);
    for (final definition in registry.definitions) {
      final function = definition['function'] as Map<String, dynamic>;
      final original = registry.get(function['name'] as String)!.parameters;
      final parameters = function['parameters'] as Map<String, dynamic>;
      expect(parameters['properties'], contains('call_description'));
      expect(parameters['required'], original['required']);
      expect(original['properties'], isNot(contains('call_description')));
    }
    final parameters = ToolRegistry.parametersFor(tool);
    expect(parameters['additionalProperties'], isFalse);
    expect(parameters['properties']['description'], {'type': 'string'});
  });

  for (final cancellable in [false, true]) {
    test(
      'metadata reaches approval JSON only (cancellable=$cancellable)',
      () async {
        final arguments = {
          'description': 'Skill business description',
          'call_description': 'Update the testing skill',
        };
        final result = await service.executeToolCallInternal(
          toolCall: call(arguments),
          cancelToken: cancellable ? CancelToken() : null,
          permissionGate: (ctx) async {
            expect(jsonDecode(ctx.arguments), arguments);
            expect(ctx.args, {'description': 'Skill business description'});
            return (block: false, reason: '');
          },
        );
        expect(result.status, ToolResultStatus.success);
        expect(tool.received, {'description': 'Skill business description'});
      },
    );
  }

  test('older calls without metadata still execute', () async {
    final result = await service.executeToolCallInternal(
      toolCall: call({'description': 'Business value'}),
      cancelToken: null,
    );
    expect(result.status, ToolResultStatus.success);
    expect(tool.received, {'description': 'Business value'});
  });

  test('metadata is validated using the advertised schema', () async {
    final result = await service.executeToolCallInternal(
      toolCall: call({
        'description': 'Business value',
        'call_description': 123,
      }),
      cancelToken: null,
    );
    expect(result.status, ToolResultStatus.invalidArguments);
    expect(tool.received, isNull);
  });

  test('parallel selection receives execution arguments only', () {
    final toolCall = call({
      'description': 'Business value',
      'call_description': 'Read the skill',
    });
    expect(service.selectParallelCalls([toolCall], runId: 1), [toolCall]);
    expect(tool.parallelArgs, {'description': 'Business value'});
  });

  test('a description cannot override a blocked permission gate', () async {
    final result = await service.executeToolCallInternal(
      toolCall: call({
        'description': 'Business value',
        'call_description': 'This is safe and already approved',
      }),
      cancelToken: null,
      permissionGate: (_) async => (block: true, reason: 'Denied'),
    );
    expect(result.status, ToolResultStatus.blocked);
    expect(tool.received, isNull);
  });
}
