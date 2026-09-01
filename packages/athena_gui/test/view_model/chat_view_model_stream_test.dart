import 'dart:async';
import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/coordinator/agent_run_coordinator.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/model/token_usage.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/service/chat_manage_service.dart';
import 'package:athena_core/service/chat_message_service.dart';
import 'package:athena_core/service/chat_service.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:athena_core/service/data_migration_service.dart';
import 'package:athena_core/service/chat_support_service.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_core/service/sentinel_service.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena_gui/view_model/delegate/chat_rename_delegate.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/repository/sqlite_chat_repository.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:openai_dart/openai_dart.dart';

// 这些测试针对审计 C2：取消/出错时应基于"最新流式消息"落库，
// 而不是最初的空占位消息，从而保留本轮已生成内容，并避免覆盖
// 前序 iteration 已 finalize 的消息。
//
// 采用首选方案（驱动完整的 sendMessage）：注入伪 AgentService 产出可控的
// 事件流，伪 ChatManageService 记录 recordCancelledOnMessage/
// recordErrorOnMessage 收到的消息；其余依赖以最小化的伪实现注入。

/// 记录每个占位消息分配的递增 id，并捕获取消/错误落库时收到的消息。
class _RecordingManageService extends ChatManageService {
  _RecordingManageService()
    : super(
        chatRepository: SqliteChatRepository(),
        messageRepository: _NoopMessageRepository(),
        modelRepository: _FakeModelRepository(),
        providerRepository: ProviderRepositoryStub(),
        sentinelRepository: _FakeSentinelRepository(),
      );

  int _nextId = 1000;
  MessageEntity? cancelledArg;
  MessageEntity? erroredArg;

  /// 记录关键操作的发生顺序，用于断言删除等待了流 settle。
  final List<String> events = [];
  bool deleteChatCalled = false;
  bool deleteChatsCalled = false;

  @override
  Future<MessageEntity> appendAssistantPlaceholder(int chatId) async {
    final id = _nextId++;
    return MessageEntity(
      id: id,
      chatId: chatId,
      role: 'assistant',
      content: '',
    );
  }

  @override
  Future<void> finalizeAssistantMessage(MessageEntity message) async {}

  @override
  Future<void> updateChatTimestamp(ChatEntity chat) async {}

  @override
  Future<(List<ChatEntity>, List<ChatHistoryEntity>)> getChats() async =>
      (<ChatEntity>[], <ChatHistoryEntity>[]);

  @override
  Future<void> deleteChat(int chatId) async {
    deleteChatCalled = true;
    events.add('delete');
  }

  @override
  Future<void> deleteChats(Set<int> ids) async {
    deleteChatsCalled = true;
    events.add('delete');
  }

  @override
  Future<MessageEntity> recordCancelledOnMessage(MessageEntity message) async {
    cancelledArg = message;
    events.add('cancel-persist');
    // 复用真实实现（super 经 _NoopMessageRepository，updateMessage 为空操作），
    // 避免重复保留逻辑与真实行为漂移。
    return super.recordCancelledOnMessage(message);
  }

  @override
  Future<MessageEntity> recordErrorOnMessage(
    MessageEntity message,
    Object error,
  ) async {
    erroredArg = message;
    return super.recordErrorOnMessage(message, error);
  }
}

class _NoopMessageRepository extends MessageRepository {
  int _nextId = 1;
  @override
  Future<int> storeMessage(MessageEntity message) async => _nextId++;
  @override
  Future<void> updateMessage(MessageEntity message) async {
    // ignore: avoid_print
  }
  @override
  Future<void> markAsCompacted(Set<int> ids) async {}
  @override
  Future<List<MessageEntity>> getMessagesByChatId(
    int chatId, {
    bool includeCompacted = true,
  }) async => [
    MessageEntity(id: 1, chatId: chatId, role: 'user', content: 'hello'),
  ];

  @override
  Future<MessageEntity?> getMessageById(int id) async => null;

  @override
  Future<void> deleteMessage(int id) async {}

  @override
  Future<void> deleteMessagesByChatId(int chatId) async {}

  @override
  Future<int> getMessagesCount(int chatId) async => 0;

  @override
  Future<MessageEntity?> getLatestMessageByChatId(int chatId) async => null;
}

class _PagedMessageRepository extends MessageRepository
    implements RecentMessageRepository {
  final Map<int, List<MessageEntity>> messagesByChat;
  final Map<int, Completer<void>> gates;

  _PagedMessageRepository(this.messagesByChat, {this.gates = const {}});

  int fullLoadCount = 0;
  int recentLoadCount = 0;

  @override
  Future<List<MessageEntity>> loadRecentMessages(
    int chatId, {
    required int count,
    int? beforeId,
  }) async {
    recentLoadCount++;
    final gate = gates[chatId];
    if (gate != null) await gate.future;
    final eligible = (messagesByChat[chatId] ?? const <MessageEntity>[])
        .where((message) => beforeId == null || message.id! < beforeId)
        .toList();
    if (eligible.length <= count) return eligible;
    return eligible.sublist(eligible.length - count);
  }

  @override
  Future<List<MessageEntity>> getMessagesByChatId(
    int chatId, {
    bool includeCompacted = true,
  }) async {
    fullLoadCount++;
    return messagesByChat[chatId] ?? [];
  }

  @override
  Future<int> storeMessage(MessageEntity message) async => message.id ?? 0;

  @override
  Future<void> updateMessage(MessageEntity message) async {}

  @override
  Future<void> markAsCompacted(Set<int> ids) async {}

  @override
  Future<MessageEntity?> getMessageById(int id) async => null;

  @override
  Future<void> deleteMessage(int id) async {}

  @override
  Future<void> deleteMessagesByChatId(int chatId) async {}

  @override
  Future<int> getMessagesCount(int chatId) async =>
      messagesByChat[chatId]?.length ?? 0;

  @override
  Future<MessageEntity?> getLatestMessageByChatId(int chatId) async {
    final messages = messagesByChat[chatId];
    return messages == null || messages.isEmpty ? null : messages.last;
  }
}

class _FakeModelRepository extends ModelRepository {
  @override
  Future<ModelEntity?> getModelById(int id) async => ModelEntity(
    id: id,
    name: 'm',
    modelId: 'm',
    providerId: 1,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  @override
  Future<int> createModel(ModelEntity model) async => 0;

  @override
  Future<void> updateModel(ModelEntity model) async {}

  @override
  Future<void> deleteModel(int id) async {}

  @override
  Future<void> deleteModelsByProviderId(int providerId) async {}

  @override
  Future<int> getModelsCount() async => 0;

  @override
  Future<void> batchCreateModels(List<ModelEntity> models) async {}

  @override
  Future<ModelEntity?> getModelByNameAndProviderId(String name,
    int providerId,) async => null;

  @override
  Future<ModelEntity?> getModelByModelIdAndProviderId(String modelId,
    int providerId,) async => null;

  @override
  Future<void> deleteAllModels() async {}

  @override
  Future<void> importModels(List<ModelEntity> models) async {}

  @override
  Future<List<ModelEntity>> getAllModels() async => [];

  @override
  Future<List<ModelEntity>> getModelsByProviderId(int providerId) async => [];
}

class _FakeSentinelRepository extends SentinelRepository {
  @override
  Future<SentinelEntity?> getSentinelById(int id) async => null;

  @override
  Future<int> createSentinel(SentinelEntity sentinel) async => 0;

  @override
  Future<void> updateSentinel(SentinelEntity sentinel) async {}

  @override
  Future<void> deleteSentinel(int id) async {}

  @override
  Future<int> getSentinelsCount() async => 0;

  @override
  Future<void> batchCreateSentinels(List<SentinelEntity> sentinels) async {}

  @override
  Future<SentinelEntity?> getSentinelByName(String name) async => null;

  @override
  Future<void> importSentinels(List<SentinelEntity> sentinels) async {}

  @override
  Future<List<SentinelEntity>> getAllSentinels() async => [];
}

class _FakeSupportService extends ChatSupportService {
  _FakeSupportService({this.renameStream, this.tokenUsage})
    : super(
        chatRepository: SqliteChatRepository(),
        messageRepository: _NoopMessageRepository(),
        providerRepository: ProviderRepositoryStub(),
        chatService: ChatService(llmClient: LlmClient()),
      );

  /// 可选的伪标题流；为 null 时回退到空流。
  final Stream<String>? renameStream;
  _FakeTokenTrackingChatRepo? tokenUsage;

  /// 记录 renameChatManually 是否被调用（用于断言删除后不再写入）。
  bool renameChatManuallyCalled = false;

  @override
  Future<ProviderEntity?> getProviderForModel(int providerId) async =>
      ProviderEntity(
        id: providerId,
        name: 'p',
        baseUrl: 'http://localhost',
        apiKey: 'k',
        createdAt: DateTime(2024),
      );

  @override
  Stream<String> renameChat(
    String firstUserMessage, {
    required ProviderEntity provider,
    required ModelEntity model,
  }) {
    final s = renameStream;
    if (s != null) return s;
    return const Stream<String>.empty();
  }

  @override
  Future<ChatEntity> renameChatManually(ChatEntity chat, String title) async {
    renameChatManuallyCalled = true;
    final existing = tokenUsage?.chats[chat.id];
    final merged = (existing ?? chat).copyWith(title: title);
    if (chat.id != null && tokenUsage != null) {
      tokenUsage!.chats[chat.id!] = merged;
    }
    return merged;
  }
}

/// 内存态 ChatRepository，捕获 recordUsage 写入供测试验证 token 累计与竞态。
class _FakeTokenTrackingChatRepo extends ChatRepository {
  final Map<int, ChatEntity> chats = {};

  @override
  Future<int> recordUsage(
    int chatId,
    int tokenDelta,
    int contextTokens,
    int cachedTokens,
  ) async {
    final existing = chats[chatId] ?? ChatEntity(
      id: chatId,
      title: '',
      modelId: 1,
      sentinelId: 1,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
    final next = existing.copyWith(
      tokenTotal: existing.tokenTotal + tokenDelta,
      contextTokens: contextTokens,
      cachedTokens: cachedTokens,
    );
    chats[chatId] = next;
    return next.tokenTotal;
  }

  @override
  Future<ChatEntity?> getChatById(int id) async => chats[id];

  @override
  Future<int> createChat(ChatEntity chat) async => 0;

  @override
  Future<void> updateChat(ChatEntity chat) async {}

  @override
  Future<void> deleteChat(int id) async {}

  @override
  Future<int> getChatsCount() async => 0;

  @override
  Future<int> getChatCountByModelId(int modelId) async => 0;

  @override
  Future<List<ChatEntity>> getAllChats() async => [];

  @override
  Future<List<ChatEntity>> getRecentChats({int limit = 10}) async => [];

  @override
  Future<List<ChatEntity>> getChatsAfterId(int chatId, {int limit = 10}) async => [];

  @override
  Future<List<ChatHistoryEntity>> getAllChatsWithLastMessage() async => [];
}

class _FakeChatMessageService extends ChatMessageService {
  _FakeChatMessageService({this.firstUserMessage = false})
    : super(messageRepository: _NoopMessageRepository());

  final bool firstUserMessage;

  @override
  Future<List<ChatMessage>> buildMessages({
    required ChatEntity chat,
    SentinelEntity? sentinel,
    bool includeReasoning = false,
  }) async => [ChatMessage.user('hi')];

  @override
  Future<bool> isFirstUserMessage(int chatId) async => firstUserMessage;
}

/// 伪 AgentService：把外部提供的 [stream] 原样返回，便于测试控制事件时序。
///
/// 自包含的 per-run 状态（取消令牌/落定 Future），模拟多 run 并发语义。
class _FakeAgentService extends AgentService {
  _FakeAgentService(this.stream, {this.streamForChat})
    : super(
        chatService: ChatService(llmClient: LlmClient()),
        toolRegistry: ToolRegistry(),
      );

  final Stream<AgentEvent> stream;

  /// 按对话分发事件流（并发测试用）；[onPermission] 供测试直接触发
  /// 权限审批链路（模拟 agent 等待用户审批）。
  final Stream<AgentEvent> Function(
    ChatEntity chat,
    PermissionCallback? onPermission,
  )? streamForChat;

  final Map<int, CancelToken> _tokens = {};
  final Map<int, Completer<void>> _settled = {};

  @override
  CancelToken? cancelTokenOf(int runId) => _tokens[runId];

  @override
  Future<void>? settledOf(int runId) => _settled[runId]?.future;

  @override
  void abort(int runId) {
    _tokens[runId]?.cancel();
  }

  @override
  Stream<AgentEvent> run({
    required int runId,
    required ChatEntity chat,
    required ProviderEntity provider,
    required ModelEntity model,
    required List<ChatMessage> baseMessages,
    String? skillPrompt,
    String? evolutionPrompt,
    String? runtimePrompt,
    String? sentinelId,
    bool hasSentinelPrompt = true,
    PermissionCallback? onPermission,
    PermissionService? permissionService,
    int maxIterations = 100,
    CancelToken? cancelToken,
    BeforeToolCallHook? beforeToolCall,
    AfterToolCallHook? afterToolCall,
    bool jsonMode = false,
  }) async* {
    final token = cancelToken ?? CancelToken();
    _tokens[runId] = token;
    final settled = Completer<void>();
    _settled[runId] = settled;
    try {
      final s = streamForChat?.call(chat, onPermission) ?? stream;
      yield* s;
    } finally {
      _tokens.remove(runId);
      if (!settled.isCompleted) settled.complete();
      _settled.remove(runId);
    }
  }
}

ChatEntity _chat({int id = 1}) => ChatEntity(
  id: id,
  title: 'New Chat',
  modelId: 1,
  sentinelId: 1,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

MessageEntity _userMessage() =>
    MessageEntity(chatId: 1, role: 'user', content: 'hello');

ChatViewModel _buildViewModel({
  required _RecordingManageService manage,
  required _FakeAgentService agent,
  _FakeSupportService? support,
  ChatMessageService? messageService,
  _FakeTokenTrackingChatRepo? tokenUsage,
  MessageRepository? messageRepository,
}) {
  final tUsage = tokenUsage ?? _FakeTokenTrackingChatRepo();
  final svc = support;
  // 确保外部传入的 support 也能访问 token 累积状态
  if (svc != null && svc.tokenUsage == null) {
    svc.tokenUsage = tUsage;
  }
  final effectiveSvc = svc ?? _FakeSupportService(tokenUsage: tUsage);
  final messages = messageService ?? _FakeChatMessageService();
  final messageRepo = messageRepository ?? _NoopMessageRepository();
  return ChatViewModel(
    manageService: manage,
    streamDelegate: AgentStreamDelegate(
      deps: AgentServiceCoordinatorDeps(
        agentService: agent,
        manageService: manage,
        messageService: messages,
        chatService: ChatService(llmClient: LlmClient()),
        chatRepo: tUsage,
        messageRepo: messageRepo,
        modelRepo: _FakeModelRepository(),
        sentinelRepo: _FakeSentinelRepository(),
        supportService: effectiveSvc,
        agentSettings: GetIt.instance<AgentSettings>(),
        permissionService: GetIt.instance<PermissionService>(),
        experienceRepository: GetIt.instance<ExperienceRepository>(),
      ),
    ),
    renameDelegate: ChatRenameDelegate(
      messageRepo: messageRepo,
      modelRepo: _FakeModelRepository(),
      supportService: effectiveSvc,
    ),
    supportService: effectiveSvc,
    messageRepo: messageRepo,
    modelResolver: ModelResolver(
      modelRepo: _FakeModelRepository(),
      providerRepo: ProviderRepositoryStub(),
    ),
    settingViewModel: GetIt.instance<SettingViewModel>(),
    modelViewModel: GetIt.instance<ModelViewModel>(),
    sentinelViewModel: GetIt.instance<SentinelViewModel>(),
    // 零窗口：仍走真实的合并缓冲路径，但断言前只需让出一次事件循环，
    // 不必为每个中途断言等 100ms。
    streamFlushInterval: Duration.zero,
  );
}

/// 让流式合并缓冲完成一次 flush（零窗口下 Timer 在下一个事件循环触发）。
Future<void> _settleFlush() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() {
    final getIt = GetIt.instance;
    getIt.registerSingleton<LlmClient>(LlmClient());
    getIt.registerSingleton<ChatService>(
      ChatService(llmClient: getIt<LlmClient>()),
    );
    getIt.registerSingleton<SentinelService>(
      SentinelService(llmClient: getIt<LlmClient>()),
    );
    getIt.registerSingleton<SkillRegistry>(SkillRegistry());
    getIt.registerSingleton<PermissionService>(
      PermissionService(store: PermissionStore()),
    );
    getIt.registerSingleton<AgentSettings>(AgentSettings());
    getIt.registerSingleton<ExperienceRepository>(
      ExperienceRepository(
        homeDir: Directory.systemTemp.createTempSync('athena-test-exp').path,
      ),
    );
    getIt.registerSingleton<SettingViewModel>(
      SettingViewModel(
        modelRepository: _FakeModelRepository(),
        providerRepository: ProviderRepositoryStub(),
        llmClient: getIt<LlmClient>(),
        dataMigrationService: DataMigrationService(
          providerRepo: ProviderRepositoryStub(),
          modelRepo: _FakeModelRepository(),
          sentinelRepo: _FakeSentinelRepository(),
          chatRepo: SqliteChatRepository(),
        ),
        agentSettings: getIt<AgentSettings>(),
      ),
    );
    getIt.registerSingleton<ModelViewModel>(
      ModelViewModel(
        repository: _FakeModelRepository(),
        providerRepository: ProviderRepositoryStub(),
        chatService: getIt<ChatService>(),
      ),
    );
    getIt.registerSingleton<SentinelViewModel>(
      SentinelViewModel(
        sentinelRepository: _FakeSentinelRepository(),
        providerRepository: ProviderRepositoryStub(),
        modelRepository: _FakeModelRepository(),
        sentinelService: getIt<SentinelService>(),
      ),
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  test('长对话首次只加载最新一页，向上滚动按游标补齐更早消息', () async {
    final stored = List.generate(
      125,
      (index) => MessageEntity(
        id: index + 1,
        chatId: 1,
        role: index.isEven ? 'user' : 'assistant',
        content: 'message ${index + 1}',
      ),
    );
    final repository = _PagedMessageRepository({1: stored});
    final vm = _buildViewModel(
      manage: _RecordingManageService(),
      agent: _FakeAgentService(const Stream<AgentEvent>.empty()),
      messageRepository: repository,
    );

    await vm.selectChat(_chat());

    expect(vm.messages.value, hasLength(ChatViewModel.messagePageSize));
    expect(vm.messages.value.first.id, 76);
    expect(vm.messages.value.last.id, 125);
    expect(vm.hasOlderMessages, isTrue);
    expect(vm.isLoadingMessages.value, isFalse);
    expect(repository.fullLoadCount, 0, reason: '选择对话不应再全量读取历史消息');

    expect(await vm.loadOlderMessages(), ChatViewModel.messagePageSize);
    expect(vm.messages.value, hasLength(100));
    expect(vm.messages.value.first.id, 26);
    expect(vm.messages.value[49].id, 75);
    expect(vm.messages.value[50].id, 76);
    expect(vm.hasOlderMessages, isTrue);

    expect(await vm.loadOlderMessages(), 25);
    expect(vm.messages.value, hasLength(125));
    expect(vm.messages.value.first.id, 1);
    expect(vm.hasOlderMessages, isFalse);
    expect(await vm.loadOlderMessages(), 0);
  });

  test('切换长对话时先卸载旧消息，较早请求不会覆盖后来选择', () async {
    final firstGate = Completer<void>();
    final firstMessages = [
      MessageEntity(id: 1, chatId: 1, role: 'user', content: 'first'),
    ];
    final secondMessages = [
      MessageEntity(id: 2, chatId: 2, role: 'user', content: 'second'),
    ];
    final repository = _PagedMessageRepository(
      {1: firstMessages, 2: secondMessages},
      gates: {1: firstGate},
    );
    final vm = _buildViewModel(
      manage: _RecordingManageService(),
      agent: _FakeAgentService(const Stream<AgentEvent>.empty()),
      messageRepository: repository,
    );
    vm.messages.value = [
      MessageEntity(id: 99, chatId: 99, role: 'user', content: 'old'),
    ];

    final firstSelection = vm.selectChat(_chat(id: 1));
    expect(vm.currentChat.value?.id, 1);
    expect(vm.isLoadingMessages.value, isTrue);
    expect(vm.messages.value, isEmpty, reason: '等待 IO 时不应重建旧长列表');

    final secondSelection = vm.selectChat(_chat(id: 2));
    expect(vm.currentChat.value?.id, 2, reason: '选中态应在历史 IO 完成前更新');
    expect(vm.isLoadingMessages.value, isTrue);
    await secondSelection;
    expect(vm.messages.value.single.content, 'second');
    expect(vm.isLoadingMessages.value, isFalse);

    firstGate.complete();
    await firstSelection;
    expect(vm.currentChat.value?.id, 2);
    expect(vm.messages.value.single.content, 'second');
    expect(vm.isLoadingMessages.value, isFalse, reason: '过期请求不能改写新会话的加载状态');
  });

  test('C2: 单轮流式中途取消，落库的是携带已生成内容的最新消息（非空占位）', () async {
    // 事件流：先发两段文本，再 await gate；gate 完成后再发一个事件以触发
    // 循环顶部的 throwIfCancelled。测试在收到文本后取消并打开 gate。
    final gate = Completer<void>();
    final emittedSome = Completer<void>();

    Stream<AgentEvent> events() async* {
      yield const AgentTextEvent('Hello');
      yield const AgentTextEvent(', world');
      if (!emittedSome.isCompleted) emittedSome.complete();
      await gate.future;
      // 这个事件不会被处理：循环顶部 throwIfCancelled 会先抛出。
      yield const AgentTextEvent('!!!');
    }

    final manage = _RecordingManageService();
    final agent = _FakeAgentService(events());
    final vm = _buildViewModel(manage: manage, agent: agent);
    // 事件只渲染到当前显示的对话；模拟用户在选中对话中发送消息
    vm.currentChat.value = _chat();

    final future = vm.sendMessage(_userMessage(), chat: _chat());

    // 等待前两段文本被消费后再取消。
    await emittedSome.future;
    vm.stopGenerating(1);
    gate.complete();

    await future;

    // 取消时落库的消息必须携带已累积内容，而不是空占位。
    final cancelled = manage.cancelledArg;
    expect(cancelled, isNotNull);
    expect(cancelled!.content, 'Hello, world');
    expect(manage.erroredArg, isNull);

    // UI 列表里对应消息已追加 [Cancelled] 且保留了内容。
    final shown = vm.messages.value.lastWhere((m) => m.role == 'assistant');
    expect(shown.content, contains('Hello, world'));
    expect(shown.content, contains('[Cancelled]'));
  });

  test('C2: 多轮流式中途取消，落库目标是进行中的第二轮消息（非首轮占位 id）', () async {
    // 第一轮：文本 + 工具调用 + 工具结果（触发 hasCompletedIteration）。
    // 第二轮：文本，随后取消。验证落库消息 id 是第二轮的新占位 id，
    // 且携带第二轮内容（确保不会覆盖已 finalize 的第一轮）。
    final gate = Completer<void>();
    final reachedSecond = Completer<void>();

    Stream<AgentEvent> events() async* {
      yield const AgentTextEvent('iter1');
      yield const AgentToolCallEvent(id: 'c1', name: 'search', arguments: '{}');
      yield const AgentToolResultEvent(id: 'c1', name: 'search', result: 'ok');
      // 下一段文本会触发 _advanceIteration，创建第二轮占位。
      yield const AgentTextEvent('iter2-content');
      if (!reachedSecond.isCompleted) reachedSecond.complete();
      await gate.future;
      yield const AgentTextEvent('never');
    }

    final manage = _RecordingManageService();
    final agent = _FakeAgentService(events());
    final vm = _buildViewModel(manage: manage, agent: agent);

    final future = vm.sendMessage(_userMessage(), chat: _chat());

    await reachedSecond.future;
    vm.stopGenerating(1);
    gate.complete();

    await future;

    final cancelled = manage.cancelledArg;
    expect(cancelled, isNotNull);
    // 第一个占位 id 是 1000；_advanceIteration 创建的第二轮占位 id 是 1001。
    expect(cancelled!.id, 1001, reason: '取消应作用于进行中的第二轮消息，而非首轮占位');
    expect(cancelled.content, 'iter2-content');
  });

  // 回归：工具调用后进入下一轮时，beginNewIteration 创建的新占位消息必须通过
  // StreamAssistantAppended 加入 UI 列表；否则 StreamMessageUpdated 走
  // replaceWhere 因找不到新 id 而静默丢弃，第二轮输出在 UI 上完全不可见。
  test('多轮工具调用后第二轮输出在 UI 上以新消息卡片展示', () async {
    Stream<AgentEvent> events() async* {
      yield const AgentTextEvent('iter1');
      yield const AgentToolCallEvent(id: 'c1', name: 'search', arguments: '{}');
      yield const AgentToolResultEvent(id: 'c1', name: 'search', result: 'ok');
      yield const AgentTextEvent('iter2-content');
      yield const AgentDoneEvent(content: 'iter2-content');
    }

    final manage = _RecordingManageService();
    final agent = _FakeAgentService(events());
    final vm = _buildViewModel(manage: manage, agent: agent);
    // 事件只渲染到当前显示的对话；模拟用户在选中对话中发送消息
    vm.currentChat.value = _chat();

    await vm.sendMessage(_userMessage(), chat: _chat());

    final assistants =
        vm.messages.value.where((m) => m.role == 'assistant').toList();
    expect(assistants.length, 2, reason: '应有两张 assistant 卡片（首轮与第二轮）');
    expect(assistants[0].id, 1000);
    expect(assistants[0].content, 'iter1');
    expect(assistants[1].id, 1001, reason: '第二轮应是新占位 id，而非继续写到首轮');
    expect(assistants[1].content, 'iter2-content');
  });

  // 回归：多轮推理+工具调用后，前一轮消息 finalize 时必须清除 reasoning
  // 标记（流式期间一直为 true），否则该卡片在 UI 上永久显示 Thinking。
  test('多轮推理后前一轮卡片不再显示 Thinking', () async {
    Stream<AgentEvent> events() async* {
      yield const AgentReasoningEvent('think1');
      yield const AgentToolCallEvent(id: 'c1', name: 'search', arguments: '{}');
      yield const AgentToolResultEvent(id: 'c1', name: 'search', result: 'ok');
      // 下一段推理触发 beginNewIteration，finalize 首轮消息
      yield const AgentReasoningEvent('think2');
      yield const AgentTextEvent('final answer');
      yield const AgentDoneEvent(content: 'final answer');
    }

    final manage = _RecordingManageService();
    final agent = _FakeAgentService(events());
    final vm = _buildViewModel(manage: manage, agent: agent);
    // 事件只渲染到当前显示的对话；模拟用户在选中对话中发送消息
    vm.currentChat.value = _chat();

    await vm.sendMessage(_userMessage(), chat: _chat());

    final assistants =
        vm.messages.value.where((m) => m.role == 'assistant').toList();
    expect(assistants.length, 2);
    expect(
      assistants[0].reasoning,
      isFalse,
      reason: '已 finalize 的首轮卡片不应永久显示 Thinking',
    );
    expect(assistants[0].reasoningContent, 'think1');
    expect(assistants[1].reasoning, isFalse);
    expect(assistants[1].reasoningContent, 'think2');
  });

  // 回归：思考未结束时展开卡片，后续推理增量不得把展开状态重新折叠
  // （delegate 的 copyWith 链基于本地缓存，必须应用用户最新的展开选择）。
  test('思考期间展开卡片，后续推理增量不折叠', () async {
    final gate = Completer<void>();
    final expanded = Completer<void>();

    Stream<AgentEvent> events() async* {
      yield const AgentReasoningEvent('think ');
      yield const AgentReasoningEvent('more ');
      if (!expanded.isCompleted) expanded.complete();
      await gate.future;
      yield const AgentReasoningEvent('after-expand');
    }

    final manage = _RecordingManageService();
    final agent = _FakeAgentService(events());
    final vm = _buildViewModel(manage: manage, agent: agent);
    // 事件只渲染到当前显示的对话；模拟用户在选中对话中发送消息
    vm.currentChat.value = _chat();

    final future = vm.sendMessage(_userMessage(), chat: _chat());

    await expanded.future;
    await _settleFlush();
    // 找到正在思考的卡片并展开
    final thinking =
        vm.messages.value.lastWhere((m) => m.role == 'assistant');
    expect(thinking.reasoning, isTrue);
    await vm.updateExpanded(thinking);
    expect(
      vm.messages.value.lastWhere((m) => m.id == thinking.id).expanded,
      isTrue,
    );

    gate.complete();
    await future;

    final shown = vm.messages.value.lastWhere((m) => m.role == 'assistant');
    expect(
      shown.expanded,
      isTrue,
      reason: '思考期间展开的卡片不应被流式增量重新折叠',
    );
    expect(shown.reasoningContent, contains('after-expand'));
  });

  test('C2: 流式中途抛错，落库的是携带已生成内容的最新消息', () async {
    Stream<AgentEvent> events() async* {
      yield const AgentTextEvent('partial');
      throw StateError('boom');
    }

    final manage = _RecordingManageService();
    final agent = _FakeAgentService(events());
    final vm = _buildViewModel(manage: manage, agent: agent);

    await vm.sendMessage(_userMessage(), chat: _chat());

    final errored = manage.erroredArg;
    expect(errored, isNotNull);
    expect(errored!.content, 'partial');
    expect(manage.cancelledArg, isNull);
    expect(vm.error.value, contains('boom'));
  });

  test('C12: 删除正在流式输出的 chat，删除会等待流 settle（取消落库先于删除完成）', () async {
    // 事件流：发两段文本后 await gate；测试在文本到达后发起删除（删除内部
    // 会 stopGenerating 并 await 流 settle），随后打开 gate 让流抛出取消。
    final gate = Completer<void>();
    final emittedSome = Completer<void>();

    Stream<AgentEvent> events() async* {
      yield const AgentTextEvent('Hello');
      yield const AgentTextEvent(', world');
      if (!emittedSome.isCompleted) emittedSome.complete();
      await gate.future;
      yield const AgentTextEvent('!!!');
    }

    final manage = _RecordingManageService();
    final agent = _FakeAgentService(events());
    final vm = _buildViewModel(manage: manage, agent: agent);

    final chat = _chat();
    final sendFuture = vm.sendMessage(_userMessage(), chat: chat);

    await emittedSome.future;
    expect(vm.isStreaming.value, isTrue);

    // 删除正在流式输出的 chat：内部应 stopGenerating 并等待流 settle。
    final deleteFuture = vm.deleteChat(chat);
    // 打开 gate，让流到达循环顶部的 throwIfCancelled 后抛出取消。
    gate.complete();

    await Future.wait([sendFuture, deleteFuture]);

    // 删除已完成，且确实调用了底层删除。
    expect(manage.deleteChatCalled, isTrue);
    // 删除完成时流已 settle，isStreaming 复位。
    expect(vm.isStreaming.value, isFalse);
    // 取消落库发生在删除之前——证明 deleteChat 等待了流 settle。
    expect(manage.cancelledArg, isNotNull);
    expect(manage.events, ['cancel-persist', 'delete']);
  });

  test('C12: 删除 chat 取消其后台自动重命名流，不再写入 renameChatManually', () async {
    // 伪标题流：先发一段标题片段，然后 await gate；测试在片段到达后删除该
    // chat（应取消重命名令牌），再打开 gate 让流结束。删除后不应写入标题。
    final gate = Completer<void>();
    final emittedChunk = Completer<void>();

    Stream<String> titleStream() async* {
      yield 'My Title';
      if (!emittedChunk.isCompleted) emittedChunk.complete();
      await gate.future;
      yield ' More';
    }

    final manage = _RecordingManageService();
    final support = _FakeSupportService(renameStream: titleStream());
    // sendMessage 不参与本用例，给一个空事件流即可。
    final agent = _FakeAgentService(const Stream<AgentEvent>.empty());
    final vm = _buildViewModel(manage: manage, agent: agent, support: support);

    final chat = _chat();
    // 直接驱动后台重命名流（fire-and-forget）。
    final renameFuture = vm.renameChat(chat);

    await emittedChunk.future;
    // 删除该 chat：应取消重命名令牌。
    await vm.deleteChat(chat);
    // 放行剩余流；renameChat 应在写入前检测到取消并提前返回 null。
    gate.complete();

    final result = await renameFuture;

    expect(result, isNull, reason: '取消后 renameChat 应返回 null');
    expect(
      support.renameChatManuallyCalled,
      isFalse,
      reason: '删除后不应再写入已删除 chat 的标题',
    );
    expect(manage.deleteChatCalled, isTrue);
  });

  test('删除当前 chat 后选择列表中的上一条，而不是第一条', () async {
    final manage = _RecordingManageService();
    final agent = _FakeAgentService(const Stream<AgentEvent>.empty());
    final vm = _buildViewModel(manage: manage, agent: agent);
    final chatList = [_chat(id: 1), _chat(id: 2), _chat(id: 3), _chat(id: 4)];
    vm.chats.value = chatList;
    vm.currentChat.value = chatList[2];

    await vm.deleteChat(chatList[2]);

    expect(vm.chats.value.map((chat) => chat.id), [1, 2, 4]);
    expect(vm.currentChat.value?.id, 2);
    expect(vm.selection.lastSelectedIndex.value, 1);
  });

  test('批量删除当前 chat 及其相邻上一条后，选择再上一条', () async {
    final manage = _RecordingManageService();
    final agent = _FakeAgentService(const Stream<AgentEvent>.empty());
    final vm = _buildViewModel(manage: manage, agent: agent);
    final chatList = [
      _chat(id: 1),
      _chat(id: 2),
      _chat(id: 3),
      _chat(id: 4),
      _chat(id: 5),
    ];
    vm.chats.value = chatList;
    vm.currentChat.value = chatList[3];

    await vm.deleteChats([chatList[2], chatList[3]]);

    expect(vm.chats.value.map((chat) => chat.id), [1, 2, 5]);
    expect(vm.currentChat.value?.id, 2);
    expect(vm.selection.lastSelectedIndex.value, 1);
  });

  test('删除第一条当前 chat 时选择删除后的第一条', () async {
    final manage = _RecordingManageService();
    final agent = _FakeAgentService(const Stream<AgentEvent>.empty());
    final vm = _buildViewModel(manage: manage, agent: agent);
    final chatList = [_chat(id: 1), _chat(id: 2), _chat(id: 3)];
    vm.chats.value = chatList;
    vm.currentChat.value = chatList.first;

    await vm.deleteChat(chatList.first);

    expect(vm.currentChat.value?.id, 2);
    expect(vm.selection.lastSelectedIndex.value, 0);
  });

  test('C12: 删除非流式 chat 不会阻塞等待进行中的其他流', () async {
    // chat A(id=1) 正在流式且不结束（gate 不打开）；删除另一个 chat B(id=2)
    // 不应等待 A 的流 settle，应立即完成且不触发 A 的取消落库。
    final gate = Completer<void>();
    final emittedSome = Completer<void>();

    Stream<AgentEvent> events() async* {
      yield const AgentTextEvent('streaming A');
      if (!emittedSome.isCompleted) emittedSome.complete();
      await gate.future;
      yield const AgentTextEvent('more');
    }

    final manage = _RecordingManageService();
    final agent = _FakeAgentService(events());
    final vm = _buildViewModel(manage: manage, agent: agent);

    final sendFuture = vm.sendMessage(_userMessage(), chat: _chat(id: 1));
    await emittedSome.future;
    expect(vm.isStreaming.value, isTrue);

    // 删除不同的 chat B(id=2)：守卫 _streamingChatId == chat.id 不成立，
    // 应立即完成而不等待 A 的流。
    await vm.deleteChat(_chat(id: 2));
    expect(manage.deleteChatCalled, isTrue);
    expect(manage.events, ['delete'], reason: '不应发生 A 的取消落库');
    expect(vm.isStreaming.value, isTrue, reason: 'A 仍在流式');

    // 清理：结束 A 的流。
    vm.stopGenerating(1);
    gate.complete();
    await sendFuture;
  });

  test('C12: deleteChats 集合含流式 chat 时先停流再删', () async {
    final gate = Completer<void>();
    final emittedSome = Completer<void>();

    Stream<AgentEvent> events() async* {
      yield const AgentTextEvent('Hello');
      if (!emittedSome.isCompleted) emittedSome.complete();
      await gate.future;
      yield const AgentTextEvent('!!!');
    }

    final manage = _RecordingManageService();
    final agent = _FakeAgentService(events());
    final vm = _buildViewModel(manage: manage, agent: agent);

    final streamingChat = _chat(id: 1);
    final sendFuture = vm.sendMessage(_userMessage(), chat: streamingChat);
    await emittedSome.future;

    // 删除集合同时包含正在流式的 chat 1 与另一个 chat 2。
    final deleteFuture = vm.deleteChats([streamingChat, _chat(id: 2)]);
    gate.complete();

    await Future.wait([sendFuture, deleteFuture]);

    expect(manage.deleteChatsCalled, isTrue);
    expect(vm.isStreaming.value, isFalse);
    expect(manage.cancelledArg, isNotNull);
    expect(manage.events, [
      'cancel-persist',
      'delete',
    ], reason: '删除应等待流 settle，取消落库先于删除');
  });

  test('token usage: AgentUsageEvent 会写入 currentTokenUsage 信号', () async {
    final gate = Completer<void>();
    final emittedUsage = Completer<void>();

    Stream<AgentEvent> events() async* {
      yield const AgentTextEvent('partial');
      if (!emittedUsage.isCompleted) emittedUsage.complete();
      await gate.future;
      yield const AgentUsageEvent(
        TokenUsage(
          promptTokens: 100,
          completionTokens: 3,
          totalTokens: 5,
          reasoningTokens: 1,
          cachedTokens: 40,
        ),
      );
      yield const AgentDoneEvent(content: 'partial');
    }

    final manage = _RecordingManageService();
    final agent = _FakeAgentService(events());
    final vm = _buildViewModel(manage: manage, agent: agent);
    vm.currentChat.value = _chat();

    expect(vm.currentTokenUsage.value, isNull);
    final sendFuture = vm.sendMessage(_userMessage(), chat: _chat());
    await emittedUsage.future;
    gate.complete();
    await sendFuture;

    expect(vm.currentTokenUsage.value, isNotNull);
    expect(vm.currentTokenUsage.value!.totalTokens, 5);
    expect(vm.currentTokenUsage.value!.promptTokens, 100);
    expect(vm.currentTokenUsage.value!.completionTokens, 3);
    expect(vm.currentTokenUsage.value!.reasoningTokens, 1);
    expect(vm.currentTokenUsage.value!.cachedTokens, 40);
    // 会话累计等于本轮 totalTokens。
    expect(vm.cumulativeTokenTotal.value, 5);
  });

  test('token usage: 多个 usage 事件会累计到 cumulativeTokenTotal', () async {
    final gate = Completer<void>();
    final emittedFirst = Completer<void>();

    Stream<AgentEvent> events() async* {
      yield const AgentTextEvent('partial');
      yield const AgentUsageEvent(
        TokenUsage(promptTokens: 10, completionTokens: 20, totalTokens: 30),
      );
      yield const AgentUsageEvent(
        TokenUsage(promptTokens: 40, completionTokens: 50, totalTokens: 90),
      );
      if (!emittedFirst.isCompleted) emittedFirst.complete();
      await gate.future;
      yield const AgentDoneEvent(content: 'partial');
    }

    final manage = _RecordingManageService();
    final agent = _FakeAgentService(events());
    final vm = _buildViewModel(manage: manage, agent: agent);
    vm.currentChat.value = _chat();

    final sendFuture = vm.sendMessage(_userMessage(), chat: _chat());
    await emittedFirst.future;
    gate.complete();
    await sendFuture;

    // currentTokenUsage 保留最近一次，累计为两次之和。
    expect(vm.currentTokenUsage.value!.totalTokens, 90);
    expect(vm.cumulativeTokenTotal.value, 120);
  });

  // P0 回归：autoRename (旧快照整行覆盖) 与 usage 累加竞态不再丢失 token。
  // A) 修复后：rename 跟在 usage 之后落库，token_total 仍保留、title 也保留。
  test(
    'token race: usage 后 autoRename 整行写不回退 token_total，且保留新 title',
    () async {
      // 重命名流：发出一个完整标题后结束。
      final support = _FakeSupportService(
        renameStream: Stream.value('New Title'),
      );
      final messages = _FakeChatMessageService(firstUserMessage: true);
      // 主流：先发文本。发出 usage=N 之后 await gate。test 在 usage 落库后
      // 让标题流恰好结束（即命名写库发生在 usage 之后），再打开 gate 让主流结束。
      final gate = Completer<void>();
      final emittedUsage = Completer<void>();

      Stream<AgentEvent> events() async* {
        yield const AgentTextEvent('partial');
        if (!emittedUsage.isCompleted) emittedUsage.complete();
        yield const AgentUsageEvent(
          TokenUsage(promptTokens: 10, completionTokens: 20, totalTokens: 30),
        );
        await gate.future;
        yield const AgentDoneEvent(content: 'partial');
      }

      final manage = _RecordingManageService();
      final agent = _FakeAgentService(events());
      final vm = _buildViewModel(
        manage: manage,
        agent: agent,
        support: support,
        messageService: messages,
      );
      vm.currentChat.value = _chat();

      final sendFuture = vm.sendMessage(_userMessage(), chat: _chat());
      await emittedUsage.future;
      // 此时 usage 已落库，token_total=30。autoRename (unawaited) 启动后命名
      // 流是同步 Stream.value，会很快走完并调用 renameChatManually ——
      // 我们切到事件循环让命名写库执行。
      await Future.microtask(() {});
      await Future.delayed(Duration.zero);
      gate.complete();
      await sendFuture;
      // 让最终的 autoRename future 也 settle 以防迟到。
      await Future.delayed(Duration.zero);

      // token 不能被旧快照整行覆盖回退。
      expect(
        vm.cumulativeTokenTotal.value,
        30,
        reason: 'autoRename 不应回退已累加的 token_total',
      );
      expect(support.renameChatManuallyCalled, isTrue);
      // autoRename 的新 title 也应保留。
      expect(
        vm.currentChat.value!.title,
        'New Title',
        reason: 'usage 回调用最新行不应回滚 autoRename 的新 title',
      );
    },
  );

  // 后台运行：流式中途切换到其他对话，事件不得污染新对话的列表；
  // 切回原对话时通过 coordinator 的内存快照恢复实时进度。
  test('流式中途切换对话：事件不污染新对话，切回时快照恢复实时进度', () async {
    final gate = Completer<void>();
    final emittedSome = Completer<void>();

    Stream<AgentEvent> events() async* {
      yield const AgentTextEvent('Hello');
      yield const AgentTextEvent(', world');
      if (!emittedSome.isCompleted) emittedSome.complete();
      await gate.future;
      yield const AgentTextEvent(' more');
    }

    final manage = _RecordingManageService();
    final agent = _FakeAgentService(events());
    final vm = _buildViewModel(manage: manage, agent: agent);
    final chatA = _chat(id: 1);

    // 用户当前在对话 A 中发送消息
    vm.currentChat.value = chatA;
    final sendFuture = vm.sendMessage(_userMessage(), chat: chatA);

    // 前两段文本已消费并实时渲染到 A
    await emittedSome.future;
    await _settleFlush();
    expect(
      vm.messages.value
          .any((m) => m.role == 'assistant' && m.content == 'Hello, world'),
      isTrue,
      reason: 'A 的流式内容应实时渲染到当前列表',
    );
    expect(vm.isCurrentChatStreaming.value, isTrue);
    expect(vm.streamingChatIds.value, [chatA.id]);

    // 流式期间切换到对话 B：加载 B 的消息，A 的事件不得写入
    final chatB = _chat(id: 2);
    await vm.selectChat(chatB);
    expect(vm.isCurrentChatStreaming.value, isFalse,
        reason: 'B 不在流式中，输入框不应显示 Stop');
    expect(
      vm.messages.value.every((m) => m.role != 'assistant'),
      isTrue,
      reason: '切换到 B 后 B 的列表不应出现 A 的 assistant 卡片',
    );

    // 切回 A：DB 里无 finalize 的 assistant 消息（伪 manage 空实现），
    // 实时内容唯一来源是 coordinator 的内存快照
    await vm.selectChat(chatA);
    expect(vm.isCurrentChatStreaming.value, isTrue);
    expect(
      vm.messages.value.lastWhere((m) => m.role == 'assistant').content,
      'Hello, world',
      reason: '切回运行中的对话应通过快照恢复实时进度',
    );

    // 放行流：后续事件继续实时渲染到 A（已回到当前显示）
    gate.complete();
    await sendFuture;
    expect(vm.isStreaming.value, isFalse);
    expect(vm.streamingChatIds.value, isEmpty);
    expect(
      vm.messages.value.lastWhere((m) => m.role == 'assistant').content,
      'Hello, world more',
      reason: '切回后事件应继续实时更新',
    );
  });

  // 第二步：多对话并发运行，两个 Agent 同时流式互不干扰，取消各自独立。
  test('并发：两个对话同时运行，各自取消互不影响', () async {
    final gateA = Completer<void>();
    final gateB = Completer<void>();
    final emittedA = Completer<void>();
    final emittedB = Completer<void>();

    Stream<AgentEvent> streamA() async* {
      yield const AgentTextEvent('reply-A');
      if (!emittedA.isCompleted) emittedA.complete();
      await gateA.future;
      yield const AgentTextEvent('-more');
    }

    Stream<AgentEvent> streamB() async* {
      yield const AgentTextEvent('reply-B');
      if (!emittedB.isCompleted) emittedB.complete();
      await gateB.future;
      yield const AgentTextEvent('-more');
    }

    final manage = _RecordingManageService();
    final agent = _FakeAgentService(
      const Stream<AgentEvent>.empty(),
      streamForChat: (chat, onPermission) =>
          chat.id == 1 ? streamA() : streamB(),
    );
    final vm = _buildViewModel(manage: manage, agent: agent);
    final chatA = _chat(id: 1);
    final chatB = _chat(id: 2);

    // 对话 A 开始流式
    vm.currentChat.value = chatA;
    final sendFutureA = vm.sendMessage(
      MessageEntity(chatId: 1, role: 'user', content: 'a'),
      chat: chatA,
    );
    await emittedA.future;
    expect(vm.isStreamingChat(1), isTrue);

    // 切换到 B 并发起第二个任务（此前被全局锁禁止，现在允许）
    await vm.selectChat(chatB);
    final sendFutureB = vm.sendMessage(
      MessageEntity(chatId: 2, role: 'user', content: 'b'),
      chat: chatB,
    );
    await emittedB.future;
    expect(vm.isStreamingChat(1), isTrue, reason: 'A 仍在运行');
    expect(vm.isStreamingChat(2), isTrue, reason: 'B 同时运行');
    expect(vm.isCurrentChatStreaming.value, isTrue, reason: '当前显示 B');

    // 取消 B：A 不受影响
    vm.stopGenerating(2);
    gateB.complete();
    await sendFutureB;
    expect(vm.isStreamingChat(1), isTrue, reason: 'A 不受 B 取消影响');
    expect(vm.isStreamingChat(2), isFalse);
    // B 的取消落库携带 B 的内容（而非 A 的）
    expect(manage.cancelledArg, isNotNull);
    expect(manage.cancelledArg!.content, contains('reply-B'));

    // 清理：结束 A
    vm.stopGenerating(1);
    gateA.complete();
    await sendFutureA;
    expect(vm.isStreaming.value, isFalse);
    expect(vm.streamingChatIds.value, isEmpty);
  });

  // 第二步：审批请求发布到对应会话的卡片列表，决策后 run 继续。
  test('审批请求按会话发布，Allow 决策后 Agent 继续', () async {
    var approvedResult = false;

    Stream<AgentEvent> events(ChatEntity chat, PermissionCallback? onPermission) async* {
      yield const AgentTextEvent('before');
      // 模拟 agent 等待权限审批（触发 coordinator → delegate 的审批链路）。
      // onPermission 在用户决策（或 run 取消）前不会返回——fake 在此挂起。
      approvedResult = await onPermission?.call(
            'bash',
            '{"command": "git push"}',
          ) ??
          false;
      yield const AgentTextEvent('after');
    }

    final manage = _RecordingManageService();
    final agent = _FakeAgentService(
      const Stream<AgentEvent>.empty(),
      streamForChat: (chat, onPermission) => events(chat, onPermission),
    );
    final vm = _buildViewModel(manage: manage, agent: agent);
    vm.currentChat.value = _chat();

    final sendFuture = vm.sendMessage(_userMessage(), chat: _chat());
    await _waitFor(() => vm.pendingApprovals.value.isNotEmpty);

    // 审批请求已发布到对应会话（chatId=1），Agent 停在等待审批
    final approvals =
        vm.pendingApprovals.value.where((r) => r.chatId == 1).toList();
    expect(approvals, hasLength(1));
    expect(approvals.first.toolName, 'bash');
    expect(approvals.first.arguments, contains('git push'));

    // 用户 Allow Once
    vm.respondApproval(
      approvals.first,
      const PermissionDecision(approved: true),
    );
    await _waitFor(() => vm.pendingApprovals.value.isEmpty);
    expect(approvedResult, isTrue, reason: 'Agent 收到批准后继续执行');

    await sendFuture;
  });

  // 第二步：审批挂起时取消 run，审批被自动拒绝并从卡片列表移除。
  test('审批挂起时取消 run：自动拒绝并移除卡片', () async {
    var approvedResult = true;

    Stream<AgentEvent> events(ChatEntity chat, PermissionCallback? onPermission) async* {
      yield const AgentTextEvent('before');
      approvedResult = await onPermission?.call(
            'bash',
            '{"command": "git push"}',
          ) ??
          false;
      yield const AgentTextEvent('after');
    }

    final manage = _RecordingManageService();
    final agent = _FakeAgentService(
      const Stream<AgentEvent>.empty(),
      streamForChat: (chat, onPermission) => events(chat, onPermission),
    );
    final vm = _buildViewModel(manage: manage, agent: agent);
    vm.currentChat.value = _chat();

    final sendFuture = vm.sendMessage(_userMessage(), chat: _chat());
    await _waitFor(() => vm.pendingApprovals.value.isNotEmpty);

    // 用户没有决策，直接取消 run：审批自动拒绝并移除卡片
    vm.stopGenerating(1);
    await sendFuture;
    expect(approvedResult, isFalse, reason: '取消时审批被自动拒绝');
    await _waitFor(() => vm.pendingApprovals.value.isEmpty);
    expect(manage.cancelledArg, isNotNull);
  });
}

/// 轮询等待条件成立（审批卡片经 broadcast controller → VM 订阅的异步链发布）。
Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// ProviderRepository 的最小桩；SettingViewModel 仅在构造时持有引用，
/// 本测试不触发其方法，故无需覆写。
class ProviderRepositoryStub extends ProviderRepository {
  @override
  Future<ProviderEntity?> getProviderById(int id) async => null;

  @override
  Future<int> storeProvider(ProviderEntity provider) async => 0;

  @override
  Future<void> updateProvider(ProviderEntity provider) async {}

  @override
  Future<void> deleteProvider(int id) async {}

  @override
  Future<int> getProvidersCount() async => 0;

  @override
  Future<void> batchStoreProviders(List<ProviderEntity> providers) async {}

  @override
  Future<ProviderEntity?> getProviderByName(String name) async => null;

  @override
  Future<ProviderEntity?> getPresetProviderByName(String name) async => null;

  @override
  Future<void> deleteAllProviders() async {}

  @override
  Future<void> importProviders(List<ProviderEntity> providers) async {}

  @override
  Future<List<ProviderEntity>> getAllProviders() async => [];

  @override
  Future<List<ProviderEntity>> getEnabledProviders() async => [];
}
