import 'dart:async';

import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/cancel_token.dart';
import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/agent/tool/tool_registry.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/service/chat_manage_service.dart';
import 'package:athena/service/chat_message_service.dart';
import 'package:athena/service/chat_service.dart';
import 'package:athena/service/chat_support_service.dart';
import 'package:athena/service/sentinel_service.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena/view_model/delegate/chat_config_delegate.dart';
import 'package:athena/view_model/delegate/chat_list_delegate.dart';
import 'package:athena/view_model/delegate/chat_rename_delegate.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
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
          chatRepository: ChatRepository(),
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
    return MessageEntity(id: id, chatId: chatId, role: 'assistant', content: '');
  }

  @override
  Future<void> finalizeAssistantMessage(MessageEntity message) async {}

  @override
  Future<void> updateChatTimestamp(ChatEntity chat) async {}

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
  Future<void> updateMessage(MessageEntity message) async {}
  @override
  Future<List<MessageEntity>> getMessagesByChatId(int chatId) async =>
      [MessageEntity(id: 1, chatId: chatId, role: 'user', content: 'hello')];
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
}

class _FakeSentinelRepository extends SentinelRepository {
  @override
  Future<SentinelEntity?> getSentinelById(int id) async => null;
}

class _FakeSupportService extends ChatSupportService {
  _FakeSupportService({this.renameStream})
      : super(
          chatRepository: ChatRepository(),
          messageRepository: _NoopMessageRepository(),
          providerRepository: ProviderRepositoryStub(),
          chatService: ChatService(),
        );

  /// 可选的伪标题流；为 null 时回退到空流。
  final Stream<String>? renameStream;

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
    return chat.copyWith(title: title);
  }
}

class _FakeChatMessageService extends ChatMessageService {
  _FakeChatMessageService() : super(messageRepository: _NoopMessageRepository());

  @override
  Future<List<ChatMessage>> buildMessages({
    required ChatEntity chat,
    SentinelEntity? sentinel,
  }) async =>
      [ChatMessage.user('hi')];

  @override
  Future<bool> isFirstUserMessage(int chatId) async => false;
}

/// 伪 AgentService：把外部提供的 [stream] 原样返回，便于测试控制事件时序。
class _FakeAgentService extends AgentService {
  _FakeAgentService(this.stream)
      : super(chatService: ChatService(), toolRegistry: ToolRegistry());

  final Stream<AgentEvent> stream;

  @override
  Stream<AgentEvent> run({
    required ChatEntity chat,
    required ProviderEntity provider,
    required ModelEntity model,
    required List<ChatMessage> baseMessages,
    String? skillPrompt,
    String? evolutionPrompt,
    String? sentinelId,
    PermissionCallback? onPermission,
    PermissionService? permissionService,
    int maxIterations = 100,
    ModelEntity? auxiliaryModel,
    ProviderEntity? auxiliaryModelProvider,
    CancelToken? cancelToken,
  }) =>
      stream;
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
}) {
  final svc = support ?? _FakeSupportService();
  return ChatViewModel(
    listDelegate: ChatListDelegate(
      manageService: manage,
      supportService: svc,
    ),
    configDelegate: ChatConfigDelegate(supportService: svc),
    streamDelegate: AgentStreamDelegate(
      agentService: agent,
      manageService: manage,
      messageService: _FakeChatMessageService(),
      messageRepo: _NoopMessageRepository(),
      modelRepo: _FakeModelRepository(),
      sentinelRepo: _FakeSentinelRepository(),
      supportService: svc,
      settingViewModel: GetIt.instance<SettingViewModel>(),
      permissionService: GetIt.instance<PermissionService>(),
      skillRegistry: GetIt.instance<SkillRegistry>(),
    ),
    renameDelegate: ChatRenameDelegate(
      messageRepo: _NoopMessageRepository(),
      modelRepo: _FakeModelRepository(),
      supportService: svc,
    ),
    supportService: svc,
    settingViewModel: GetIt.instance<SettingViewModel>(),
    modelViewModel: GetIt.instance<ModelViewModel>(),
    sentinelViewModel: GetIt.instance<SentinelViewModel>(),
  );
}

void main() {
  setUp(() {
    final getIt = GetIt.instance;
    getIt.registerSingleton<ChatService>(ChatService());
    getIt.registerSingleton<SentinelService>(SentinelService());
    getIt.registerSingleton<SkillRegistry>(SkillRegistry());
    getIt.registerSingleton<PermissionService>(
      PermissionService(store: PermissionStore()),
    );
    getIt.registerSingleton<SettingViewModel>(
      SettingViewModel(
        modelRepository: _FakeModelRepository(),
        providerRepository: ProviderRepositoryStub(),
        sentinelRepository: _FakeSentinelRepository(),
        chatRepository: ChatRepository(),
        chatService: getIt<ChatService>(),
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

  test(
      'C2: 单轮流式中途取消，落库的是携带已生成内容的最新消息（非空占位）',
      () async {
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

    final future = vm.sendMessage(_userMessage(), chat: _chat());

    // 等待前两段文本被消费后再取消。
    await emittedSome.future;
    vm.stopGenerating();
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

  test(
      'C2: 多轮流式中途取消，落库目标是进行中的第二轮消息（非首轮占位 id）',
      () async {
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
    vm.stopGenerating();
    gate.complete();

    await future;

    final cancelled = manage.cancelledArg;
    expect(cancelled, isNotNull);
    // 第一个占位 id 是 1000；_advanceIteration 创建的第二轮占位 id 是 1001。
    expect(cancelled!.id, 1001,
        reason: '取消应作用于进行中的第二轮消息，而非首轮占位');
    expect(cancelled.content, 'iter2-content');
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

  test(
      'C12: 删除正在流式输出的 chat，删除会等待流 settle（取消落库先于删除完成）',
      () async {
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

  test('C12: 删除 chat 取消其后台自动重命名流，不再写入 renameChatManually',
      () async {
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
    expect(support.renameChatManuallyCalled, isFalse,
        reason: '删除后不应再写入已删除 chat 的标题');
    expect(manage.deleteChatCalled, isTrue);
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
    vm.stopGenerating();
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
    expect(manage.events, ['cancel-persist', 'delete'],
        reason: '删除应等待流 settle，取消落库先于删除');
  });
}

/// ProviderRepository 的最小桩；SettingViewModel 仅在构造时持有引用，
/// 本测试不触发其方法，故无需覆写。
class ProviderRepositoryStub extends ProviderRepository {}
