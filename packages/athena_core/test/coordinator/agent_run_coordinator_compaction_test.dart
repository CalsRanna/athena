import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/permission/permission_prompt.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/runtime_context.dart';
import 'package:athena_core/agent/tool/tool_interface.dart' as athena;
import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/coordinator/agent_run_coordinator.dart';
import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/conversation_summary.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_core/service/chat_store_service.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

final _now = DateTime(2026, 9, 14);
String _payload(List<ChatMessage> messages) =>
    jsonEncode(messages.map((m) => m.toJson()).toList());
MessageEntity _user(String content) =>
    MessageEntity(chatId: 1, role: 'user', content: content);

class _Repository implements MessageRepository, ChatRepository {
  ChatEntity chat = ChatEntity(
    id: 1,
    title: 'Compaction test',
    modelId: 1,
    sentinelId: ChatEntity.noSentinelId,
    createdAt: _now,
    updatedAt: _now,
  );
  final records = <MessageEntity>[];
  final marked = <Set<int>>[];
  bool failMarking = false;
  bool failCommit = false;
  bool failAssistantAppend = false;
  void Function()? onSummaryStored;
  Future<void> Function()? onRead;
  int _nextId = 1;

  @override
  Future<List<MessageEntity>> getMessagesByChatId(
    int chatId, {
    bool includeCompacted = true,
  }) async {
    final hook = onRead;
    onRead = null;
    await hook?.call();
    return records.where((m) => includeCompacted || !m.compacted).toList();
  }

  @override
  Future<int> storeMessage(MessageEntity message) async {
    if (failAssistantAppend && message.role == 'assistant') {
      throw StateError('assistant append failed');
    }
    final id = _nextId++;
    records.add(message.copyWith(id: id));
    if (message.role == 'summary') onSummaryStored?.call();
    return id;
  }

  @override
  Future<void> updateMessage(MessageEntity message) async {
    if (failCommit &&
        message.role == 'compaction' &&
        CompactionStep.fromMessage(message).phase ==
            CompactionPhase.completed) {
      throw StateError('summary commit failed');
    }
    records[records.indexWhere((m) => m.id == message.id)] = message;
    if (message.role == 'compaction' &&
        CompactionStep.fromMessage(message).phase ==
            CompactionPhase.completed) {
      onSummaryStored?.call();
    }
  }

  @override
  Future<void> markAsCompacted(Set<int> ids) async {
    if (failMarking) throw StateError('marking failed');
    marked.add(ids);
    for (var i = 0; i < records.length; i++) {
      if (ids.contains(records[i].id)) {
        records[i] = records[i].copyWith(compacted: true);
      }
    }
  }

  @override
  Future<ChatEntity?> getChatById(int id) async => chat;
  @override
  Future<void> updateChat(ChatEntity value) async => chat = value;
  @override
  Future<int> recordUsage(int id, int delta, int prompt, int cached) async {
    chat = chat.copyWith(contextTokens: prompt);
    return delta;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Models implements ModelRepository {
  _Models(this.window);
  final int window;
  @override
  Future<ModelEntity?> getModelById(int id) async => ModelEntity(
    id: id,
    name: 'test',
    modelId: 'test',
    providerId: 1,
    contextWindow: window,
    createdAt: _now,
    updatedAt: _now,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Providers implements ProviderRepository {
  @override
  Future<ProviderEntity?> getProviderById(int id) async => ProviderEntity(
    id: id,
    name: 'test',
    baseUrl: 'http://unused.invalid',
    apiKey: '',
    createdAt: _now,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sentinels implements SentinelRepository {
  @override
  Future<SentinelEntity?> getSentinelById(int id) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OutputTool extends athena.Tool {
  _OutputTool(this.size);
  final int size;
  @override
  String get name => 'output';
  @override
  String get description => 'Return an observation';
  @override
  athena.ToolRisk get risk => athena.ToolRisk.readOnly;
  @override
  Map<String, dynamic> get parameters => {'type': 'object'};
  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async => 'OBSERVATION_${args['step']}:${'x' * size}';
}

class _Llm extends ChatCompletionsService {
  _Llm() : super(llmClient: LlmClient());
  final summaries = <List<ChatMessage>>[];
  final requests = <List<ChatMessage>>[];
  final callsAtSummary = <int>[];
  int toolTurns = 0;
  Future<String> Function()? summarize;
  Future<void> Function(int)? beforeResponse;

  @override
  Future<String> complete({
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    Future<void>? cancelSignal,
  }) async {
    summaries.add(List.of(messages));
    callsAtSummary.add(requests.length);
    return summarize == null
        ? 'SUMMARY_${summaries.length}'
        : await summarize!();
  }

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
    final step = requests.length;
    await beforeResponse?.call(step);
    yield ChatStreamEvent(
      choices: [
        ChatStreamChoice(
          index: 0,
          delta: step <= toolTurns
              ? ChatDelta(
                  toolCalls: [
                    ToolCallDelta(
                      index: 0,
                      id: 'call_$step',
                      type: 'function',
                      function: FunctionCallDelta(
                        name: 'output',
                        arguments: jsonEncode({'step': step}),
                      ),
                    ),
                  ],
                )
              : const ChatDelta(content: 'DONE'),
          finishReason: step <= toolTurns
              ? FinishReason.toolCalls
              : FinishReason.stop,
        ),
      ],
    );
  }
}

class _Fixture {
  final repo = _Repository();
  final llm = _Llm();
  late ChatMessageConverter converter;
  late ToolOutputStore outputs;
  late AgentRunCoordinator coordinator;

  static Future<_Fixture> create({
    int window = 16000,
    int retention = -1,
    int outputSize = 8000,
    DateTime Function()? now,
    List<MessageEntity> seeds = const [],
  }) async {
    final fixture = _Fixture();
    final repo = fixture.repo;
    repo.chat = repo.chat.copyWith(retention: retention);
    for (final seed in seeds) {
      await repo.storeMessage(seed);
    }
    final directory = await Directory.systemTemp.createTemp('athena-compact-');
    addTearDown(() => directory.delete(recursive: true));
    final models = _Models(window);
    final providers = _Providers();
    final sentinels = _Sentinels();
    final outputs = ToolOutputStore(
      directory: Directory('${directory.path}/outputs'),
    );
    fixture.outputs = outputs;
    final settings = AgentSettings();
    await settings.updateAiApprovalEnabled(false);
    fixture.converter = ChatMessageConverter(
      messageRepository: repo,
      outputStore: outputs,
    );
    fixture.coordinator = AgentRunCoordinator(
      agentService: AgentService(
        chatService: fixture.llm,
        toolRegistry: ToolRegistry(outputStore: outputs)
          ..register(_OutputTool(outputSize)),
        now: now ?? () => _now,
      ),
      manageService: ChatStoreService(
        chatRepository: repo,
        messageRepository: repo,
        modelRepository: models,
        providerRepository: providers,
        sentinelRepository: sentinels,
      ),
      messageService: fixture.converter,
      chatService: fixture.llm,
      messageRepo: repo,
      modelRepo: models,
      sentinelRepo: sentinels,
      chatRepo: repo,
      supportService: ChatUpdateService(
        chatRepository: repo,
        messageRepository: repo,
        providerRepository: providers,
        chatService: fixture.llm,
      ),
      agentSettings: settings,
      permissionService: PermissionService(store: PermissionStore()),
      permissionPrompt: (_, _, _, _) async =>
          const PermissionDecision(approved: false),
      experienceRepository: ExperienceRepository(homeDir: directory.path),
      runtimeEnvironment: RuntimeEnvironment.tui,
    );
    return fixture;
  }

  Future<List<RunEvent>> send(String text) =>
      coordinator.send(message: _user(text), chat: repo.chat).toList();

  Future<List<ChatMessage>> replay() =>
      converter.buildMessages(chat: repo.chat, sentinel: null);
}

void _expectPaired(List<ChatMessage> messages) {
  final pending = <String>{};
  for (final message in messages) {
    if (message is ToolMessage) {
      expect(pending.remove(message.toolCallId), isTrue);
    } else {
      expect(pending, isEmpty);
      if (message is AssistantMessage) {
        pending.addAll((message.toolCalls ?? []).map((call) => call.id));
      }
    }
  }
  expect(pending, isEmpty);
}

void main() {
  test(
    'all phases update one durable step before the next model request',
    () async {
      final f = await _Fixture.create();
      f.llm.toolTurns = 3;
      f.llm.beforeResponse = (turn) async {
        if (turn == 4) {
          final step = CompactionStep.fromMessage(
            f.repo.records.singleWhere((m) => m.role == 'compaction'),
          );
          expect(step.phase, CompactionPhase.completed);
          expect(step.summary, isNotEmpty);
          expect(_payload(f.llm.requests.last), contains(step.summary));
          expect(f.repo.records.last.id, greaterThan(step.messageId));
        }
      };
      final events = await f.send('CURRENT');
      final changes = events
          .whereType<RunCompactionChanged>()
          .map((e) => e.step)
          .toList();
      expect(changes.map((s) => s.phase), [
        CompactionPhase.triggered,
        CompactionPhase.summarizing,
        CompactionPhase.persisting,
        CompactionPhase.completed,
      ]);
      expect(changes.map((s) => s.compactionId).toSet(), hasLength(1));
      expect(changes.where((s) => s.isTerminal), hasLength(1));
      expect(f.repo.records.where((m) => m.role == 'compaction'), hasLength(1));
      expect(changes.last.coveredMessageIds, [1, 2, 3, 4]);
      expect(changes.last.afterTokens, lessThan(changes.first.beforeTokens));
      expect(changes.last.finishedAt, isNotNull);
    },
  );

  for (final phase in [
    CompactionPhase.triggered,
    CompactionPhase.summarizing,
    CompactionPhase.persisting,
  ]) {
    test('stop during $phase emits one cancelled terminal state', () async {
      final f = await _Fixture.create(window: 8192, outputSize: 23000);
      f.llm.toolTurns = 1;
      final changes = <CompactionStep>[];
      await for (final event in f.coordinator.send(
        message: _user('CURRENT'),
        chat: f.repo.chat,
      )) {
        if (event is RunCompactionChanged) {
          changes.add(event.step);
          if (event.step.phase == phase) f.coordinator.stop(1);
        }
      }
      expect(changes.last.phase, CompactionPhase.cancelled);
      expect(changes.where((s) => s.isTerminal), hasLength(1));
      expect(changes.map((s) => s.compactionId).toSet(), hasLength(1));
      expect(f.repo.marked, isEmpty);
      expect(f.llm.requests, hasLength(1));
      final stored = f.repo.records.singleWhere((m) => m.role == 'compaction');
      expect(
        CompactionStep.fromMessage(stored).phase,
        CompactionPhase.cancelled,
      );
      expect(_payload(await f.replay()), isNot(contains('compactionId')));
    });
  }

  test(
    'failed summary commit retains history and persists failed status',
    () async {
      final f = await _Fixture.create();
      f.llm.toolTurns = 3;
      f.repo.failCommit = true;
      final events = await f.send('CURRENT');
      final steps = events
          .whereType<RunCompactionChanged>()
          .map((e) => e.step)
          .toList();
      expect(steps.last.phase, CompactionPhase.failed);
      expect(steps.last.afterTokens, isNull);
      expect(steps.where((s) => s.isTerminal), hasLength(1));
      expect(f.repo.marked, isEmpty);
      expect(
        ConversationSummary.activeHistory(
          f.repo.records,
        ).every((m) => m.role != 'compaction'),
        isTrue,
      );
      expect(_payload(await f.replay()), contains('CURRENT'));
      expect(_payload(await f.replay()), contains('OBSERVATION_1'));
    },
  );

  test(
    'failed answer append does not overwrite the committed summary',
    () async {
      final f = await _Fixture.create();
      f.llm.toolTurns = 3;
      f.repo.onSummaryStored = () => f.repo.failAssistantAppend = true;
      final events = await f.send('CURRENT');
      final completed = events
          .whereType<RunCompactionChanged>()
          .singleWhere((e) => e.step.phase == CompactionPhase.completed)
          .step;
      final stored = f.repo.records.singleWhere((m) => m.role == 'compaction');
      expect(stored.content, completed.summary);
      expect(
        CompactionStep.fromMessage(stored).phase,
        CompactionPhase.completed,
      );
      expect(events.whereType<RunError>(), hasLength(1));
      expect(
        _payload(await f.replay()),
        isNot(contains('assistant append failed')),
      );
    },
  );

  test('date refreshes if summarization crosses midnight', () async {
    var now = _now;
    final f = await _Fixture.create(
      window: 8192,
      outputSize: 23000,
      now: () => now,
    );
    f.llm.toolTurns = 1;
    f.llm.summarize = () async {
      now = DateTime(2026, 9, 15);
      return 'SUMMARY';
    };
    expect((await f.send('CURRENT')).whereType<RunError>(), isEmpty);
    expect(
      f.llm.requests.first.whereType<SystemMessage>().last.content,
      contains('2026-09-14'),
    );
    expect(
      f.llm.requests.last.whereType<SystemMessage>().last.content,
      contains('2026-09-15'),
    );
  });

  test(
    'an input queued during the compaction read stays out of that run',
    () async {
      final f = await _Fixture.create();
      f.llm.toolTurns = 4;
      f.llm.beforeResponse = (step) async {
        if (step == 3) {
          f.repo.onRead = () async {
            await f.coordinator.queueInput(1, _user('QUEUED_DURING_READ'));
          };
        }
      };
      expect((await f.send('CURRENT')).whereType<RunError>(), isEmpty);
      expect(f.llm.requests, hasLength(6));
      for (final request in f.llm.requests.take(5)) {
        expect(_payload(request), isNot(contains('QUEUED_DURING_READ')));
      }
      expect(
        _payload(f.llm.summaries.first),
        isNot(contains('QUEUED_DURING_READ')),
      );
      expect(_payload(f.llm.requests.last), contains('QUEUED_DURING_READ'));
    },
  );

  test(
    'one oversized tool batch is summarized through a recoverable output',
    () async {
      final f = await _Fixture.create(window: 8192, outputSize: 23000);
      f.llm.toolTurns = 1;
      expect((await f.send('CURRENT')).whereType<RunError>(), isEmpty);
      expect(f.llm.requests, hasLength(2));
      final input = _payload(f.llm.summaries.single);
      final id = RegExp(
        r'\[tool_output id=([a-f0-9]{64})\]',
      ).firstMatch(input)!.group(1)!;
      expect((await f.outputs.read(id)).text, startsWith('OBSERVATION_1:'));
      expect(input, contains('output'));
      expect(input, contains('step'));
      expect(_payload(await f.replay()), contains('SUMMARY_1'));
    },
  );

  test(
    'a record with multiple tool calls is summarized and marked as one batch',
    () async {
      final batch = MessageEntity(
        chatId: 1,
        role: 'assistant',
        toolCalls: jsonEncode([
          for (var i = 0; i < 4; i++)
            {
              'id': 'batch_$i',
              'name': 'inspect',
              'arguments': jsonEncode({'path': 'PATH_$i'}),
            },
        ]),
        toolResults: jsonEncode([
          for (var i = 0; i < 4; i++)
            {
              'id': 'batch_$i',
              'name': 'inspect',
              'result': 'RESULT_$i:${'x' * 2500}',
            },
        ]),
      );
      final f = await _Fixture.create(
        window: 8192,
        seeds: [_user('OLD'), batch, _user('USER_DECISION')],
      );
      expect((await f.send('CURRENT')).whereType<RunError>(), isEmpty);
      expect(f.repo.marked.single, {1, 2, 3, 4});
      final input = _payload(f.llm.summaries.single);
      for (var i = 0; i < 4; i++) {
        expect(input, contains('PATH_$i'));
        expect(input, contains('RESULT_$i'));
      }
      expect(input, contains('USER_DECISION'));
      expect(input, contains('CURRENT'));
      expect(_payload(await f.replay()), contains('SUMMARY_1'));
      _expectPaired(f.llm.requests.single);
      _expectPaired(await f.replay());
    },
  );

  test(
    'tool growth compacts repeatedly within one send and replays in order',
    () async {
      final f = await _Fixture.create();
      f.llm.toolTurns = 7;
      final events = await f.send('CURRENT_USER_REQUEST');
      final finishedSteps = events
          .whereType<RunCompactionChanged>()
          .map((e) => e.step)
          .where((s) => s.phase == CompactionPhase.completed)
          .toList();
      expect(finishedSteps.length, greaterThanOrEqualTo(2));
      expect(
        finishedSteps.map((s) => s.compactionId).toSet().length,
        finishedSteps.length,
      );
      expect(
        f.repo.records.where((m) => m.role == 'compaction').length,
        finishedSteps.length,
      );
      expect(events.whereType<RunError>(), isEmpty);
      expect(f.llm.requests, hasLength(8));
      expect(f.llm.summaries.length, greaterThanOrEqualTo(2));
      expect(f.llm.callsAtSummary.first, greaterThan(0));
      expect(
        f.llm.summaries.skip(1).map(_payload).join(),
        contains('SUMMARY_1'),
      );
      expect(_payload(f.llm.summaries.first), contains('OBSERVATION_1'));
      expect(_payload(f.llm.summaries.first), contains('output'));
      expect(_payload(f.llm.summaries.first), contains('step'));
      expect(_payload(f.llm.summaries.first), contains('CURRENT_USER_REQUEST'));
      for (final request in f.llm.requests) {
        _expectPaired(request);
        final systems = request.whereType<SystemMessage>().toList();
        expect(systems.last.content, contains('2026-09-14'));
        expect(
          request.take(systems.length).every((m) => m is SystemMessage),
          isTrue,
        );
        expect(_payload(systems), isNot(contains('SUMMARY_')));
        expect(
          _payload(request),
          anyOf(contains('CURRENT_USER_REQUEST'), contains('SUMMARY_')),
        );
      }
      final active = ConversationSummary.activeHistory(f.repo.records);
      expect(active.where(ConversationSummary.isSummary), hasLength(1));
      expect(active.first.role, 'compaction');
      expect(active.last.content, 'DONE');
      final replay = await f.replay();
      _expectPaired(replay);
      // Reopening adds only the final answer to the exact history used by the
      // final model call, even though a summary was stored after its placeholder.
      expect(replay.map((m) => m.toJson()).toList(), [
        ...f.llm.requests.last
            .where((m) => m is! SystemMessage)
            .map((m) => m.toJson()),
        ChatMessage.assistant(content: 'DONE').toJson(),
      ]);
    },
  );

  test(
    'fresh input triggers compression without previous API token usage',
    () async {
      final f = await _Fixture.create(
        window: 8192,
        seeds: [
          _user('OLD_${'a' * 6000}'),
          MessageEntity(
            chatId: 1,
            role: 'assistant',
            content: 'ANSWER_${'b' * 6000}',
          ),
        ],
      );
      final events = await f.send('NEW_${'c' * 1500}');
      expect(events.whereType<RunError>(), isEmpty);
      expect(f.llm.callsAtSummary, everyElement(0));
      expect(f.repo.marked.single, {1, 2, 3});
      expect(f.llm.summaries.map(_payload).join(), contains('OLD_'));
      expect(f.llm.summaries.map(_payload).join(), contains('ANSWER_'));
      expect(f.llm.summaries.map(_payload).join(), contains('NEW_'));
      expect(_payload(f.llm.requests.single), isNot(contains('OLD_')));
      expect(
        _payload(await f.replay()),
        contains('SUMMARY_${f.llm.summaries.length}'),
      );
      expect(
        f.repo.records
            .singleWhere((m) => m.content.startsWith('NEW_'))
            .compacted,
        isTrue,
      );
    },
  );

  test('coverage survives a failed mark and JSON round trip', () async {
    final f = await _Fixture.create(
      window: 8192,
      seeds: [
        _user('OLD_${'a' * 6000}'),
        MessageEntity(
          chatId: 1,
          role: 'assistant',
          content: 'ANSWER_${'b' * 6000}',
        ),
      ],
    );
    f.repo.failMarking = true;
    expect((await f.send('CURRENT')).whereType<RunError>(), isEmpty);
    expect(f.repo.marked, isEmpty);
    final saved = f.repo.records
        .map(
          (m) => MessageEntity.fromJson(
            jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>,
          ),
        )
        .toList();
    f.repo.records
      ..clear()
      ..addAll(saved);
    final replay = _payload(await f.replay());
    expect(replay, contains('SUMMARY_${f.llm.summaries.length}'));
    expect(replay, isNot(contains('OLD_')));
    expect(replay, isNot(contains('ANSWER_')));
  });

  for (final failure in ['throw', 'empty', 'oversized']) {
    test('summary $failure preserves original records', () async {
      final f = await _Fixture.create();
      f.llm.toolTurns = 3;
      f.llm.summarize = () async {
        if (failure == 'throw') throw StateError('summary failed');
        return failure == 'empty' ? ' ' : 'z' * 40000;
      };
      await f.send('CURRENT');
      expect(f.llm.summaries, isNotEmpty);
      expect(f.repo.marked, isEmpty);
      expect(f.repo.records.where((m) => m.role == 'summary'), isEmpty);
      expect(
        f.repo.records.where((m) => m.toolResults.isNotEmpty),
        hasLength(3),
      );
      _expectPaired(await f.replay());
    });
  }

  test(
    'cancel during summarization stores no summary and sends no next request',
    () async {
      final f = await _Fixture.create();
      f.llm.toolTurns = 4;
      final started = Completer<void>();
      final release = Completer<String>();
      f.llm.summarize = () {
        started.complete();
        return release.future;
      };
      final sending = f.send('CURRENT');
      await started.future;
      final calls = f.llm.requests.length;
      f.coordinator.stop(1);
      release.complete('CANCELLED_SUMMARY');
      await sending;
      expect(f.llm.requests, hasLength(calls));
      expect(f.repo.marked, isEmpty);
      expect(f.repo.records.where((m) => m.role == 'summary'), isEmpty);
      expect(f.repo.records.last.content, contains('[Cancelled]'));
    },
  );

  test(
    'cancel after summary commit leaves replay coverage consistent',
    () async {
      final f = await _Fixture.create();
      f.llm.toolTurns = 4;
      f.repo.onSummaryStored = () => f.coordinator.stop(1);
      await f.send('CURRENT');
      expect(f.repo.marked, isEmpty);
      expect(f.repo.records.where((m) => m.role == 'compaction'), hasLength(1));
      expect(
        _payload(await f.replay()),
        contains('SUMMARY_${f.llm.summaries.length}'),
      );
      expect(_payload(await f.replay()), isNot(contains('OBSERVATION_1')));
      _expectPaired(await f.replay());
    },
  );

  test(
    'queued input does not enter the current compaction or request',
    () async {
      final f = await _Fixture.create();
      f.llm.toolTurns = 4;
      f.llm.beforeResponse = (step) async {
        if (step == 1) {
          await f.coordinator.queueInput(1, _user('QUEUED_INPUT'));
        }
      };
      final events = await f.send('CURRENT');
      expect(events.whereType<RunError>(), isEmpty);
      expect(f.llm.requests, hasLength(6));
      for (final request in f.llm.requests.take(5)) {
        expect(_payload(request), isNot(contains('QUEUED_INPUT')));
      }
      expect(_payload(f.llm.summaries.first), isNot(contains('QUEUED_INPUT')));
      expect(_payload(f.llm.requests.last), contains('QUEUED_INPUT'));
    },
  );

  for (final retention in [0, 1]) {
    test(
      'retention $retention disables automatic compression within the loop',
      () async {
        final f = await _Fixture.create(retention: retention);
        f.llm.toolTurns = 3;
        await f.send('CURRENT');
        expect(f.llm.summaries, isEmpty);
        expect(f.repo.marked, isEmpty);
      },
    );
  }

  test('unknown context window does not trigger compression', () async {
    final f = await _Fixture.create(window: 0);
    f.llm.toolTurns = 4;
    expect((await f.send('CURRENT')).whereType<RunError>(), isEmpty);
    expect(f.llm.summaries, isEmpty);
    expect(f.llm.requests, hasLength(5));
  });
}
