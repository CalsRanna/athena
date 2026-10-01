import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/context_budget.dart';
import 'package:athena_core/agent/context_compaction.dart';
import 'package:athena_core/agent/tool/tool_output_store.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_core/service/conversation_compactor.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// 摘要调用只在这一层被替换：压缩的其它部分（存储、覆盖范围、提交守卫）
/// 都是真的，所以用例能覆盖"摘要比被替换内容还长 → 压缩被拒绝"这类路径。
class _FakeSummaryService implements ChatCompletionsService {
  _FakeSummaryService(this.summary);

  final String summary;
  final requests = <List<ChatMessage>>[];

  @override
  Future<String> complete({
    required List<ChatMessage> messages,
    required ProviderEntity provider,
    required ModelEntity model,
    Future<void>? cancelSignal,
  }) async {
    requests.add(messages);
    return summary;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 摘要提示词里声明的目标长度。
int _targetTokensOf(List<ChatMessage> request) {
  final system = request.first as SystemMessage;
  final match = RegExp(r'不超过 (\d+) 个 token').firstMatch(system.content)!;
  return int.parse(match.group(1)!);
}

void main() {
  late Directory tmp;
  late FileStorage storage;
  late ChatMessageConverter converter;
  late String chatId;
  final now = DateTime.now();

  const window = 65536;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('athena_compact_');
    storage = FileStorage(root: Directory(p.join(tmp.path, '.athena')));
    await storage.load();
    converter = ChatMessageConverter(
      messageRepository: storage.sessionRepository,
    );
    // 会话行必须先写：消息行依赖它定位文件与 seq。
    chatId = await storage.sessionRepository.createChat(
      ChatEntity(
        title: 'compact',
        modelId: 'm',
        sentinelId: null,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  Future<MessageEntity> store(String role, String content) =>
      storage.sessionRepository.storeMessage(
        MessageEntity(chatId: chatId, role: role, content: content),
      );

  Future<List<ContextCompactionUpdate>> compactUpdates(
    List<ChatMessage> messages, {
    required ContextBudget budget,
    required _FakeSummaryService service,
    required MessageEntity placeholder,
  }) async {
    final compactor = ConversationCompactor(
      repository: storage.sessionRepository,
      converter: converter,
      chatService: service,
    );
    final updates = <ContextCompactionUpdate>[];
    await for (final update in compactor.compact(
      request: ContextCompactionRequest(
        messages: messages,
        tools: null,
        budget: budget,
        outputs: ToolOutputStore(),
        cancelToken: CancelToken(),
      ),
      chatId: chatId,
      runId: 1,
      beforeMessageId: placeholder.id!,
      beforeSeq: placeholder.seq,
      excludedMessageIds: const {},
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
    )) {
      updates.add(update);
    }
    return updates;
  }

  Future<List<CompactionStep>> compact(
    List<ChatMessage> messages, {
    required ContextBudget budget,
    required _FakeSummaryService service,
    required MessageEntity placeholder,
  }) async => [
    for (final update in await compactUpdates(
      messages,
      budget: budget,
      service: service,
      placeholder: placeholder,
    ))
      update.step,
  ];

  test('短历史：摘要预算随覆盖内容收缩，压缩仍然减少上下文', () async {
    // 前缀（工具 schema、注入的系统块）已经吃掉大半窗口，真正的历史很短——
    // 这正是"第一次压缩必定失败"的现场：历史的估算还不到模型给的摘要上限。
    final budget = ContextBudget(window);
    const marker = '详述本仓库的上下文压缩机制：';
    final history = '$marker${'a' * 8000}';
    await store('user', history);
    final placeholder = await store('assistant', '');

    // 前缀长到刚好越过触发线：压缩就是在这一步真会发生的。
    var prefixChars = 96000;
    List<ChatMessage> withPrefix() => [
      ChatMessage.system('s' * prefixChars),
      ChatMessage.user(history),
    ];
    while (!budget.shouldCompact(withPrefix(), null)) {
      prefixChars += 1000;
    }

    final coveredTokens = budget.estimate([ChatMessage.user(history)], null);
    final expectedTarget = coveredTokens ~/ 4;
    expect(expectedTarget, lessThan(4096), reason: '该场景下历史比绝对上限小');

    // 摘要按收缩后的预算写：略小于目标，确保提交守卫放行。
    final service = _FakeSummaryService('b' * (expectedTarget - 20));
    final steps = await compact(
      withPrefix(),
      budget: budget,
      service: service,
      placeholder: placeholder,
    );

    expect(service.requests, hasLength(1));
    expect(_targetTokensOf(service.requests.single), expectedTarget);
    expect(steps.last.phase, CompactionPhase.completed);
    expect(steps.last.afterTokens, lessThan(steps.last.beforeTokens));
  });

  test('长历史：摘要预算仍是模型的绝对上限', () async {
    final budget = ContextBudget(window);
    // 每条记录都要放得进摘要输入预算，否则压缩本来就该失败（另有一条限制）。
    for (var i = 0; i < 3; i++) {
      await store('user', 'a' * 60000);
    }
    final placeholder = await store('assistant', '');
    final messages = [
      ChatMessage.system('s' * 1000),
      ChatMessage.user('a' * 60000),
    ];

    final service = _FakeSummaryService('b' * 1000);
    final steps = await compact(
      messages,
      budget: budget,
      service: service,
      placeholder: placeholder,
    );

    expect(service.requests, isNotEmpty);
    for (final request in service.requests) {
      expect(
        _targetTokensOf(request),
        4096,
        reason: '历史远大于 4 倍上限时，1/4 的缩放不该生效',
      );
    }
    expect(steps.last.phase, CompactionPhase.completed);
  });

  test('尾部原文保留：最新记录留在上下文里，只有更早的部分被摘要', () async {
    final budget = ContextBudget(window);
    // 更早的记录约 10000 token，超出尾部预算；最新的约 2000 token 放得下。
    final older = 'a' * 20000;
    final newer = 'b' * 4000;
    final olderRecord = await store('user', older);
    final newerRecord = await store('user', newer);
    final placeholder = await store('assistant', '');

    final service = _FakeSummaryService('c' * 1000);
    final updates = await compactUpdates(
      [
        ChatMessage.system('s' * 60000),
        ChatMessage.user(older),
        ChatMessage.user(newer),
      ],
      budget: budget,
      service: service,
      placeholder: placeholder,
    );
    final last = updates.last;

    expect(last.step.phase, CompactionPhase.completed);
    expect(last.step.coveredMessageIds, [olderRecord.id]);
    expect(last.step.messageCount, 1);
    // 最新一条原样留在请求里：说明它没有被摘要替换掉。
    expect(
      ((last.messages!.last as UserMessage).content as UserTextContent).text,
      newer,
    );
    final sent = jsonEncode(
      service.requests.single.map((message) => message.toJson()).toList(),
    );
    expect(sent.contains(older.substring(0, 200)), isTrue);
    expect(sent.contains(newer.substring(0, 200)), isFalse);

    // 只有被覆盖的记录标记为已压缩：尾部还要参与后续组装。
    final stored = await storage.sessionRepository.getMessagesByChatId(
      chatId,
      includeCompacted: true,
    );
    expect(stored.firstWhere((m) => m.id == olderRecord.id).compacted, isTrue);
    expect(stored.firstWhere((m) => m.id == newerRecord.id).compacted, isFalse);
  });

  test('尾部预算装得下全部历史时，只留到被覆盖部分仍够长', () async {
    final budget = ContextBudget(window);
    // 三条各约 1000 token，合计小于尾部预算（窗口 1/10）：全留会让覆盖为空，
    // 摘要预算的下限（max(128, …)）就不再收缩，压缩会入不敷出。
    final first = await store('user', 'd' * 2000);
    await store('user', 'e' * 2000);
    await store('user', 'f' * 2000);
    final placeholder = await store('assistant', '');

    final service = _FakeSummaryService('c' * 300);
    final updates = await compactUpdates(
      [
        ChatMessage.system('s' * 60000),
        ChatMessage.user('d' * 2000),
        ChatMessage.user('e' * 2000),
        ChatMessage.user('f' * 2000),
      ],
      budget: budget,
      service: service,
      placeholder: placeholder,
    );
    final last = updates.last;

    expect(last.step.phase, CompactionPhase.completed);
    expect(last.step.coveredMessageIds, [first.id]);
    expect(last.messages, hasLength(4), reason: '系统块 + 摘要 + 两条尾部原文');
    expect(
      ((last.messages![2] as UserMessage).content as UserTextContent).text,
      'e' * 2000,
    );
    expect(
      ((last.messages![3] as UserMessage).content as UserTextContent).text,
      'f' * 2000,
    );
  });

  test('历史整体都很短时退回全量摘要：覆盖为空比保留尾部更糟', () async {
    final budget = ContextBudget(window);
    final only = await store('user', 'g' * 900);
    final placeholder = await store('assistant', '');

    final service = _FakeSummaryService('c' * 60);
    final updates = await compactUpdates(
      [ChatMessage.system('s' * 60000), ChatMessage.user('g' * 900)],
      budget: budget,
      service: service,
      placeholder: placeholder,
    );
    final last = updates.last;

    expect(last.step.phase, CompactionPhase.completed);
    expect(last.step.coveredMessageIds, [only.id]);
    expect(last.messages, hasLength(2), reason: '系统块 + 摘要，没有尾部原文');
  });
}
