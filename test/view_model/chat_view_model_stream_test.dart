import 'dart:async';

import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/cancel_token.dart';
import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/agent/skill/skill_registry.dart';
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
import 'package:athena/view_model/chat_view_model.dart';
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
  Future<MessageEntity> recordCancelledOnMessage(MessageEntity message) async {
    cancelledArg = message;
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
  _FakeSupportService()
      : super(
          chatRepository: ChatRepository(),
          messageRepository: _NoopMessageRepository(),
          providerRepository: ProviderRepositoryStub(),
          chatService: ChatService(),
        );

  @override
  Future<ProviderEntity?> getProviderForModel(int providerId) async =>
      ProviderEntity(
        id: providerId,
        name: 'p',
        baseUrl: 'http://localhost',
        apiKey: 'k',
        createdAt: DateTime(2024),
      );
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
  _FakeAgentService(this.stream);

  final Stream<AgentEvent> stream;

  @override
  Stream<AgentEvent> run({
    required ChatEntity chat,
    required ProviderEntity provider,
    required ModelEntity model,
    required List<ChatMessage> baseMessages,
    String? skillPrompt,
    PermissionCallback? onPermission,
    PermissionService? permissionService,
    int maxIterations = 100,
    ModelEntity? auxiliaryModel,
    ProviderEntity? auxiliaryModelProvider,
    CancelToken? cancelToken,
  }) =>
      stream;
}

ChatEntity _chat() => ChatEntity(
      id: 1,
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
}) {
  return ChatViewModel(
    manageService: manage,
    supportService: _FakeSupportService(),
    chatMessageService: _FakeChatMessageService(),
    agentService: agent,
    messageRepository: _NoopMessageRepository(),
    modelRepository: _FakeModelRepository(),
    sentinelRepository: _FakeSentinelRepository(),
  );
}

void main() {
  setUp(() {
    final getIt = GetIt.instance;
    // sendMessage 体内会直接通过 GetIt 解析这三者。
    getIt.registerSingleton<SkillRegistry>(SkillRegistry());
    getIt.registerSingleton<PermissionService>(
      PermissionService(store: PermissionStore()),
    );
    getIt.registerSingleton<SettingViewModel>(
      SettingViewModel(
        modelRepository: _FakeModelRepository(),
        providerRepository: ProviderRepositoryStub(),
        sentinelRepository: _FakeSentinelRepository(),
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
}

/// ProviderRepository 的最小桩；SettingViewModel 仅在构造时持有引用，
/// 本测试不触发其方法，故无需覆写。
class ProviderRepositoryStub extends ProviderRepository {}
