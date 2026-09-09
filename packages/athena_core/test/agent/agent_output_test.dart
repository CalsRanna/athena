import 'dart:convert';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/run_outcome.dart';
import 'package:athena_core/agent/tool/tool_interface.dart' as athena;
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

class _OutputTool extends athena.Tool {
  _OutputTool(this.output);
  final String output;
  int executions = 0;
  @override
  String get name => 'output';
  @override
  String get description => 'Return test output';
  @override
  Map<String, dynamic> get parameters => {'type': 'object'};
  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async {
    executions++;
    return output;
  }
}

typedef _Script = List<ChatStreamEvent> Function(List<ChatMessage> messages);

class _ChatService extends ChatCompletionsService {
  _ChatService(this.scripts) : super(llmClient: LlmClient());
  final List<_Script> scripts;
  final List<List<ChatMessage>> requests = [];
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
    requests.add(List.of(messages));
    yield* Stream.fromIterable(scripts[requests.length - 1](messages));
  }
}

ChatStreamEvent _call(
  String id, {
  String name = 'output',
  Map<String, dynamic> args = const {},
}) => ChatStreamEvent(
  choices: [
    ChatStreamChoice(
      index: 0,
      delta: ChatDelta(
        toolCalls: [
          ToolCallDelta(
            index: 0,
            id: id,
            type: 'function',
            function: FunctionCallDelta(
              name: name,
              arguments: jsonEncode(args),
            ),
          ),
        ],
      ),
      finishReason: FinishReason.toolCalls,
    ),
  ],
);

final _chat = ChatEntity(
  id: 1,
  title: 'Test',
  modelId: 1,
  sentinelId: 1,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
final _provider = ProviderEntity(
  name: 'test',
  baseUrl: 'http://localhost',
  apiKey: '',
  createdAt: DateTime(2026),
);
ModelEntity _model([int window = 0]) => ModelEntity(
  name: 'test',
  modelId: 'test',
  providerId: 1,
  contextWindow: window,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test(
    'large output survives events, model requests and follow-up reads without re-execution',
    () async {
      final raw = '${'start' * 5000}MIDDLE${'end' * 5000}';
      final tool = _OutputTool(raw);
      final registry = ToolRegistry()..register(tool);
      String? outputId;
      final chatService = _ChatService([
        (_) => [_call('original')],
        (messages) {
          final preview = messages.whereType<ToolMessage>().single.content;
          outputId = RegExp(r'id=([a-f0-9]{64})').firstMatch(preview)!.group(1);
          expect(preview, isNot(contains('MIDDLE')));
          return [
            _call(
              'page',
              name: 'tool_output_read',
              args: {'output_id': outputId, 'offset': 25000, 'limit': 6},
            ),
          ];
        },
        (messages) {
          expect(
            messages.whereType<ToolMessage>().last.content,
            endsWith('MIDDLE'),
          );
          return [];
        },
      ]);
      final service = AgentService(
        chatService: chatService,
        toolRegistry: registry,
      );
      final events = await service
          .run(
            runId: 1,
            chat: _chat,
            provider: _provider,
            model: _model(),
            baseMessages: [ChatMessage.user('inspect the middle')],
          )
          .toList();
      final original = events.whereType<AgentToolResultEvent>().first;
      expect(original.result, raw);
      expect(original.outputId, outputId);
      expect(
        original.modelResult,
        chatService.requests[1].whereType<ToolMessage>().single.content,
      );
      final record = events
          .whereType<AgentIterationCompleteEvent>()
          .first
          .toolCalls
          .single;
      expect(record['result'], raw);
      expect(record['modelResult'], original.modelResult);
      expect(record['outputId'], outputId);
      expect(tool.executions, 1);
      expect(
        events.whereType<AgentRunOutcomeEvent>().single.outcome.termination,
        AgentRunTermination.completed,
      );
    },
  );

  test('22KB tool output reaches the model without a second cut', () async {
    final raw = 'x' * 22196;
    final chatService = _ChatService([
      (_) => [_call('original')],
      (messages) {
        expect(messages.whereType<ToolMessage>().single.content, raw);
        return [];
      },
    ]);
    await AgentService(
          chatService: chatService,
          toolRegistry: ToolRegistry()..register(_OutputTool(raw)),
        )
        .run(
          runId: 1,
          chat: _chat,
          provider: _provider,
          model: _model(),
          baseMessages: [ChatMessage.user('read')],
        )
        .toList();
  });

  test(
    'date remains stable within a day and refreshes across midnight',
    () async {
      var now = DateTime(2026, 9, 9, 10);
      final chatService = _ChatService([
        (_) {
          now = DateTime(2026, 9, 9, 23, 59);
          return [_call('one')];
        },
        (_) {
          now = DateTime(2026, 9, 10);
          return [_call('two')];
        },
        (_) => [],
        (_) => [],
      ]);
      final service = AgentService(
        chatService: chatService,
        toolRegistry: ToolRegistry()..register(_OutputTool('ok')),
        now: () => now,
      );
      final base = [ChatMessage.system('SENTINEL'), ChatMessage.user('task')];
      await service
          .run(
            runId: 1,
            chat: _chat,
            provider: _provider,
            model: _model(),
            baseMessages: base,
          )
          .toList();
      now = DateTime(2026, 9, 11);
      await service
          .run(
            runId: 2,
            chat: _chat,
            provider: _provider,
            model: _model(),
            baseMessages: base,
          )
          .toList();
      final dates = chatService.requests.map((request) {
        expect((request.first as SystemMessage).content, 'SENTINEL');
        return request.whereType<SystemMessage>().last.content;
      }).toList();
      expect(dates, [
        'Current date: 2026-09-09.',
        'Current date: 2026-09-09.',
        'Current date: 2026-09-10.',
        'Current date: 2026-09-11.',
      ]);
      expect(
        base,
        hasLength(2),
        reason: 'date does not mutate persisted history',
      );
    },
  );

  test(
    'context is rechecked during the run and older results remain readable',
    () async {
      final raw = 'x' * 3000;
      final chatService = _ChatService([
        (_) => [_call('one')],
        (_) => [_call('two')],
        (_) => [_call('three')],
        (messages) {
          expect(
            messages.whereType<ToolMessage>().first.content,
            contains('tool_output_read'),
          );
          expect(messages.whereType<ToolMessage>().last.content, raw);
          return [];
        },
      ]);
      await AgentService(
            chatService: chatService,
            toolRegistry: ToolRegistry()..register(_OutputTool(raw)),
          )
          .run(
            runId: 1,
            chat: _chat,
            provider: _provider,
            model: _model(6000),
            baseMessages: [ChatMessage.user('read')],
          )
          .toList();
      expect(chatService.requests, hasLength(4));
    },
  );

  test(
    'oversized initial context is rejected before a network request',
    () async {
      final chatService = _ChatService([]);
      await expectLater(
        AgentService(chatService: chatService, toolRegistry: ToolRegistry())
            .run(
              runId: 1,
              chat: _chat,
              provider: _provider,
              model: _model(4000),
              baseMessages: [ChatMessage.user('x' * 10000)],
            )
            .toList(),
        throwsA(isA<StateError>()),
      );
      expect(chatService.requests, isEmpty);
    },
  );
}
