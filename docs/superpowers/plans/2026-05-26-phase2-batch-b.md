# Phase 2 Batch B Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 删除 MessageSendService 反向依赖，sendMessage 瘦身到 <50 行，引入 CancelToken 实现真正的流式取消，ChatSupportService 自动刷新 updated_at，删除 ChatManageService 的假 Service 透传方法。

**Architecture:** ChatViewModel 直接消费 AgentService 输出的 AgentEvent 流；ChatManageService 提供 4 个持久化 helper（appendAssistantPlaceholder/finalizeAssistantMessage/recordCancelledOnMessage/recordErrorOnMessage）；CancelToken 在 AgentService 各关键节点检查并通过 Future.any 让权限弹窗可取消。

**Tech Stack:** Flutter 3.x, Dart 3.x, Signals (状态管理), get_it (DI), openai_dart, laconic (ORM)

**Spec:** `docs/superpowers/specs/2026-05-26-phase2-batch-b-design.md`

---

## Task 1: 创建 CancelToken 与单元测试

**Files:**
- Create: `lib/agent/cancel_token.dart`
- Create: `test/agent/cancel_token_test.dart`

- [ ] **Step 1: Write the failing tests**

`test/agent/cancel_token_test.dart`:

```dart
import 'package:athena/agent/cancel_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CancelToken', () {
    test('isCancelled is false initially', () {
      final token = CancelToken();
      expect(token.isCancelled, isFalse);
    });

    test('cancel() flips isCancelled to true', () {
      final token = CancelToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('cancel() completes whenCancelled future', () async {
      final token = CancelToken();
      final future = token.whenCancelled;
      token.cancel();
      await expectLater(future, completes);
    });

    test('cancel() is idempotent', () {
      final token = CancelToken();
      token.cancel();
      token.cancel(); // should not throw
      expect(token.isCancelled, isTrue);
    });

    test('throwIfCancelled() throws when cancelled', () {
      final token = CancelToken();
      token.cancel();
      expect(token.throwIfCancelled, throwsA(isA<CancelledException>()));
    });

    test('throwIfCancelled() is a no-op when not cancelled', () {
      final token = CancelToken();
      expect(token.throwIfCancelled, returnsNormally);
    });

    test('CancelledException.toString includes reason', () {
      const e = CancelledException('user clicked stop');
      expect(e.toString(), contains('user clicked stop'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/agent/cancel_token_test.dart`
Expected: FAIL — Target of URI doesn't exist: 'package:athena/agent/cancel_token.dart'

- [ ] **Step 3: Implement CancelToken**

`lib/agent/cancel_token.dart`:

```dart
import 'dart:async';

class CancelledException implements Exception {
  final String reason;
  const CancelledException([this.reason = 'cancelled']);
  @override
  String toString() => 'CancelledException: $reason';
}

class CancelToken {
  final Completer<void> _completer = Completer<void>();
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _completer.complete();
  }

  void throwIfCancelled() {
    if (_cancelled) throw const CancelledException();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/agent/cancel_token_test.dart`
Expected: PASS, 7 tests

- [ ] **Step 5: Commit**

```bash
git add lib/agent/cancel_token.dart test/agent/cancel_token_test.dart
git commit -m "feat: add CancelToken for stream cancellation"
```

---

## Task 2: AgentService.run 接受 CancelToken

**Files:**
- Modify: `lib/agent/agent_service.dart`

- [ ] **Step 1: 添加 cancelToken 参数**

在 `lib/agent/agent_service.dart` 顶部加 import：

```dart
import 'package:athena/agent/cancel_token.dart';
```

修改 `run` 方法签名（在最后加可选参数）：

```dart
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
}) async* {
```

- [ ] **Step 2: 在 iteration 起始检查**

在 `for (var iteration = ...)` 循环体第一行：

```dart
for (var iteration = 0; iteration < maxIterations; iteration++) {
  cancelToken?.throwIfCancelled();
  if (iteration == 0 && skillPrompt != null && skillPrompt.isNotEmpty) {
```

- [ ] **Step 3: 在 HTTP 流读取过程中检查**

修改 `await for (final chunk in stream)` 循环：

```dart
await for (final chunk in stream) {
  cancelToken?.throwIfCancelled();
  accumulator.add(chunk);

  final delta = chunk.firstChoice?.delta;
  if (delta != null) {
    final reasoningContent =
        delta.reasoningContent ?? delta.reasoning;
    if (reasoningContent != null && reasoningContent.isNotEmpty) {
      yield AgentEvent.reasoning(reasoningContent);
    }
  }

  final textDelta = chunk.textDelta;
  if (textDelta != null && textDelta.isNotEmpty) {
    yield AgentEvent.text(textDelta);
  }
}
```

- [ ] **Step 4: 权限审批节点接入 cancelToken**

定位 `final approved = await onPermission(...)` 这行（约 agent_service.dart:140-142），替换为：

```dart
final approved = cancelToken == null
    ? await onPermission(tc.function.name, tc.function.arguments)
    : await Future.any<bool>([
        onPermission(tc.function.name, tc.function.arguments),
        cancelToken.whenCancelled.then((_) => false),
      ]);
cancelToken?.throwIfCancelled();
if (!approved) {
```

注意：原有 `if (!approved)` 块保持不变。

- [ ] **Step 5: 工具调用前检查**

在 `final result = tool != null` 之前一行加：

```dart
cancelToken?.throwIfCancelled();
final result = tool != null
    ? await tool.execute(args)
    : 'Error: Unknown tool "${tc.function.name}"';
```

- [ ] **Step 6: 验证 flutter analyze 通过**

Run: `flutter analyze lib/agent/agent_service.dart`
Expected: No issues found

- [ ] **Step 7: Commit**

```bash
git add lib/agent/agent_service.dart
git commit -m "feat(agent): thread CancelToken through AgentService.run"
```

---

## Task 3: ChatManageService 新增持久化 helper

**Files:**
- Modify: `lib/service/chat_manage_service.dart`
- Create: `test/service/chat_manage_service_helpers_test.dart`

- [ ] **Step 1: 添加 4 个 helper 方法**

在 `lib/service/chat_manage_service.dart` 末尾（最后一个 `}` 之前）添加：

```dart
/// 创建并落库一条空的 assistant 占位消息，返回带 id 的 entity
Future<MessageEntity> appendAssistantPlaceholder(int chatId) async {
  final placeholder = MessageEntity(
    chatId: chatId,
    role: 'assistant',
    content: '',
  );
  final id = await _messageRepository.storeMessage(placeholder);
  return placeholder.copyWith(id: id);
}

/// 持久化 assistant 消息最终内容（含 toolCalls/toolResults/reasoning）
Future<void> finalizeAssistantMessage(MessageEntity message) async {
  await _messageRepository.updateMessage(message);
}

/// 取消现场：保留所有累积内容，content 末尾追加 [Cancelled]
Future<MessageEntity> recordCancelledOnMessage(MessageEntity message) async {
  final preservedContent = message.content.isEmpty
      ? '[Cancelled]'
      : '${message.content}\n\n[Cancelled]';
  final updated = message.copyWith(
    content: preservedContent,
    reasoning: false,
  );
  await _messageRepository.updateMessage(updated);
  return updated;
}

/// 错误现场：保留所有累积内容，content 末尾追加 [Error: ...]
Future<MessageEntity> recordErrorOnMessage(
  MessageEntity message,
  Object error,
) async {
  final errorText = error.toString();
  final preservedContent = message.content.isEmpty
      ? 'Error: $errorText'
      : '${message.content}\n\n[Error: $errorText]';
  final updated = message.copyWith(
    content: preservedContent,
    reasoning: false,
  );
  await _messageRepository.updateMessage(updated);
  return updated;
}
```

- [ ] **Step 2: 写 helper 测试**

`test/service/chat_manage_service_helpers_test.dart`:

```dart
import 'package:athena/entity/message_entity.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/service/chat_manage_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMessageRepository implements MessageRepository {
  final List<MessageEntity> stored = [];
  final List<MessageEntity> updated = [];
  int nextId = 100;

  @override
  Future<int> storeMessage(MessageEntity message) async {
    final id = nextId++;
    stored.add(message.copyWith(id: id));
    return id;
  }

  @override
  Future<void> updateMessage(MessageEntity message) async {
    updated.add(message);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ChatManageService helpers', () {
    late _FakeMessageRepository fakeRepo;
    late ChatManageService service;

    setUp(() {
      fakeRepo = _FakeMessageRepository();
      service = ChatManageService(messageRepository: fakeRepo);
    });

    test('appendAssistantPlaceholder stores empty assistant and returns id', () async {
      final result = await service.appendAssistantPlaceholder(7);

      expect(result.id, 100);
      expect(result.chatId, 7);
      expect(result.role, 'assistant');
      expect(result.content, '');
      expect(fakeRepo.stored.single.role, 'assistant');
    });

    test('finalizeAssistantMessage forwards to repository', () async {
      final msg = MessageEntity(id: 1, chatId: 1, role: 'assistant', content: 'hi');
      await service.finalizeAssistantMessage(msg);

      expect(fakeRepo.updated.single, msg);
    });

    test('recordCancelledOnMessage appends [Cancelled] and clears reasoning', () async {
      final msg = MessageEntity(
        id: 2,
        chatId: 1,
        role: 'assistant',
        content: 'partial answer',
        reasoning: true,
        reasoningContent: 'thinking...',
        toolCalls: '[]',
      );
      final out = await service.recordCancelledOnMessage(msg);

      expect(out.content, 'partial answer\n\n[Cancelled]');
      expect(out.reasoning, isFalse);
      expect(out.reasoningContent, 'thinking...');
      expect(out.toolCalls, '[]');
    });

    test('recordCancelledOnMessage on empty content yields bare marker', () async {
      final msg = MessageEntity(id: 3, chatId: 1, role: 'assistant', content: '');
      final out = await service.recordCancelledOnMessage(msg);

      expect(out.content, '[Cancelled]');
    });

    test('recordErrorOnMessage appends [Error: ...] and preserves toolCalls', () async {
      final msg = MessageEntity(
        id: 4,
        chatId: 1,
        role: 'assistant',
        content: 'partial',
        toolCalls: '[{"id":"a"}]',
        toolResults: '[{"id":"a","result":"r"}]',
      );
      final out = await service.recordErrorOnMessage(msg, 'boom');

      expect(out.content, 'partial\n\n[Error: boom]');
      expect(out.toolCalls, '[{"id":"a"}]');
      expect(out.toolResults, '[{"id":"a","result":"r"}]');
    });
  });
}
```

- [ ] **Step 3: Run tests**

Run: `flutter test test/service/chat_manage_service_helpers_test.dart`
Expected: PASS, 5 tests

- [ ] **Step 4: Commit**

```bash
git add lib/service/chat_manage_service.dart test/service/chat_manage_service_helpers_test.dart
git commit -m "feat(chat-manage): add persistence helpers for sendMessage flow"
```

---

## Task 4: 删除 MessageSendService 并切换 VM 到 AgentService

**Files:**
- Delete: `lib/service/message_send_service.dart`
- Modify: `lib/view_model/chat_view_model.dart`
- Modify: `lib/di.dart`

- [ ] **Step 1: 重写 ChatViewModel 的字段与构造器**

在 `lib/view_model/chat_view_model.dart` 顶部 import 区：

将这行：
```dart
import 'package:athena/service/message_send_service.dart';
```

替换为：
```dart
import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/cancel_token.dart';
```

修改字段（约第 30-56 行）替换为：
```dart
final ChatManageService _manage;
final ChatSupportService _support;
final ChatMessageService _chatMessageService;
final ChatSelectionDelegate _selection;
final AgentService _agentService;

CancelToken? _activeCancelToken;

ChatViewModel({
  ChatManageService? manageService,
  ChatSupportService? supportService,
  ChatMessageService? chatMessageService,
  ChatSelectionDelegate? selection,
  AgentService? agentService,
})  : _manage = manageService ?? GetIt.instance<ChatManageService>(),
      _support = supportService ?? GetIt.instance<ChatSupportService>(),
      _chatMessageService =
          chatMessageService ?? GetIt.instance<ChatMessageService>(),
      _selection = selection ?? ChatSelectionDelegate(),
      _agentService = agentService ?? GetIt.instance<AgentService>();
```

- [ ] **Step 2: 在 sendMessage 中替换 _send.sendMessage 调用**

定位 `var agentStream = _send.sendMessage(` 这段（约第 557 行），替换为：

```dart
var agentStream = _agentService.run(
  chat: chat,
  provider: provider,
  model: model,
  baseMessages: wrappedMessages,
  maxIterations: settingVM.maxAgentIterations.value,
  auxiliaryModel: settingVM.auxiliaryModel.value,
  auxiliaryModelProvider: settingVM.auxiliaryModelProvider.value,
  permissionService: permissionService,
  onPermission: (toolName, arguments) async {
    final context = router.navigatorKey.currentContext;
    if (context == null) return false;
    Map<String, dynamic> args;
    try {
      args = jsonDecode(arguments) as Map<String, dynamic>;
    } catch (_) {
      args = {};
    }
    final description = _formatToolArgs(toolName, arguments);
    final ruleDesc = permissionService.generateRuleDescription(
      toolName,
      args,
    );
    final isDangerous = permissionService.isDangerous(toolName, args);
    final isFileRule = const {
      'file_read',
      'file_write',
      'file_update',
      'file_delete',
    }.contains(toolName);
    final result = await showPermissionDialog(
      toolName: toolName,
      description: description,
      ruleDescription: ruleDesc,
      allowPersist: !isDangerous,
      isFileRule: isFileRule,
    );
    if (result.approved && result.persist) {
      final rule = permissionService.generateRule(
        toolName,
        args,
        recursive: result.recursive,
      );
      await permissionService.persistRule(rule);
    }
    return result.approved;
  },
);
```

- [ ] **Step 3: 替换事件 dispatch 中的 SendXxx 为 AgentXxxEvent**

定位 `await for (final event in agentStream)` 块（约第 610-688 行），把所有事件类替换：

| Old | New |
|---|---|
| `event is SendReasoningDelta` | `event is AgentReasoningEvent` |
| `event is SendTextDelta` | `event is AgentTextEvent` |
| `event is SendToolCall` | `event is AgentToolCallEvent` |
| `event is SendToolResult` | `event is AgentToolResultEvent` |
| `event is SendDone` | `event is AgentDoneEvent` |

事件字段名相同（`event.delta` / `event.id` / `event.name` / `event.arguments` / `event.result` / `event.content`），无需调整字段访问。

- [ ] **Step 4: 添加 _formatToolArgs 私有方法**

在 `ChatViewModel` 类末尾（最后一个 `}` 之前）添加：

```dart
String _formatToolArgs(String toolName, String arguments) {
  final buffer = StringBuffer();
  buffer.writeln('Agent wants to use: $toolName');
  try {
    final args = jsonDecode(arguments) as Map<String, dynamic>;
    for (final entry in args.entries) {
      var value = entry.value.toString();
      if (value.length > 120) {
        value = '${value.substring(0, 120)}...';
      }
      buffer.writeln('  ${entry.key}: $value');
    }
  } catch (_) {
    if (arguments.length > 200) {
      buffer.writeln('  ${arguments.substring(0, 200)}...');
    } else {
      buffer.writeln('  $arguments');
    }
  }
  return buffer.toString();
}
```

- [ ] **Step 5: 从 di.dart 注销 MessageSendService**

在 `lib/di.dart` 删除：
- 顶部 `import 'package:athena/service/message_send_service.dart';`
- 底部最后一个 register 块（约第 127-130 行）：

```dart
// MessageSendService 依赖 AgentService（Batch B 会修反向依赖）
getIt.registerLazySingleton(
  () => MessageSendService(agentService: getIt<AgentService>()),
);
```

- [ ] **Step 6: 删除 MessageSendService 源文件**

```bash
rm lib/service/message_send_service.dart
```

- [ ] **Step 7: 验证 flutter analyze 通过**

Run: `flutter analyze`
Expected: No issues found in lib/, no broken imports.

- [ ] **Step 8: Run 现有测试确保未引入回归**

Run: `flutter test`
Expected: PASS（含 CancelToken / helpers 新测试）

- [ ] **Step 9: Commit**

```bash
git add -u lib/ test/
git rm lib/service/message_send_service.dart
git commit -m "refactor: drop MessageSendService, consume AgentEvent directly in VM"
```

注意：第 6 步已通过 `rm` 删除文件，`git add -u` 会捕获删除；`git rm` 是兜底，若 `git add -u` 已 stage 则 `git rm` 报"already staged"可忽略。如果 git add -u 报 "no changes added"，改用 `git rm lib/service/message_send_service.dart`。

---

## Task 5: 抽出 _prepareSendContext 私有 helper

**Files:**
- Modify: `lib/view_model/chat_view_model.dart`

- [ ] **Step 1: 定义 _SendContext 内部类**

在 `ChatViewModel` 类末尾（最后一个 `}` 之前，但在 `_formatToolArgs` 之前）添加：

```dart
class _SendContext {
  final ModelEntity model;
  final ProviderEntity provider;
  final SentinelEntity? sentinel;
  final List<ChatMessage> wrappedMessages;

  _SendContext({
    required this.model,
    required this.provider,
    required this.sentinel,
    required this.wrappedMessages,
  });
}
```

注意：`_SendContext` 是 file-private 类（下划线开头），需放在 file 末尾，**类外部**。

import 区添加（如尚未存在）：
```dart
import 'package:openai_dart/openai_dart.dart';
```

- [ ] **Step 2: 添加 _prepareSendContext 方法**

在 `ChatViewModel` 内部、`_formatToolArgs` 之前添加：

```dart
Future<_SendContext?> _prepareSendContext(
  MessageEntity message,
  ChatEntity chat,
) async {
  // 1. 保存用户消息
  final id = await _manage.storeMessage(message);
  final userMessage = message.copyWith(id: id);
  messages.value = [...messages.value, userMessage];

  // 首条用户消息入库后立即异步触发自动命名
  final isDefaultTitle = chat.title.isEmpty || chat.title == 'New Chat';
  if (isDefaultTitle) {
    if (await _chatMessageService.isFirstUserMessage(chat.id!)) {
      unawaited(renameChat(chat));
    }
  }

  // 2. 获取 model / provider / sentinel
  final model = await _manage.getModel(chat.modelId);
  if (model == null) {
    error.value = 'Model not found';
    return null;
  }
  final provider = await _support.getProviderForModel(model.providerId);
  if (provider == null) {
    error.value = 'Provider not found';
    return null;
  }
  final sentinel = await _manage.getSentinel(chat.sentinelId);

  // 3. 构建消息上下文
  final wrappedMessages = await _chatMessageService.buildMessages(
    chat: chat,
    sentinel: sentinel,
  );

  return _SendContext(
    model: model,
    provider: provider,
    sentinel: sentinel,
    wrappedMessages: wrappedMessages,
  );
}
```

- [ ] **Step 3: 验证 flutter analyze 通过**

Run: `flutter analyze lib/view_model/chat_view_model.dart`
Expected: No issues. 现在 sendMessage 还未调用 _prepareSendContext，但 helper 本身合法。

- [ ] **Step 4: Commit**

```bash
git add lib/view_model/chat_view_model.dart
git commit -m "refactor(chat-vm): extract _prepareSendContext helper"
```

---

## Task 6: 抽出 _consumeAgentStream 与 _advanceIteration helpers

**Files:**
- Modify: `lib/view_model/chat_view_model.dart`

- [ ] **Step 1: 添加 _advanceIteration 方法**

在 `ChatViewModel` 内部、`_prepareSendContext` 之前添加：

```dart
/// 推进到下一轮 iteration：finalize 上一条 assistant，append 新占位
Future<MessageEntity> _advanceIteration(
  ChatEntity chat,
  MessageEntity current,
) async {
  await _manage.finalizeAssistantMessage(current);
  final next = await _manage.appendAssistantPlaceholder(chat.id!);
  messages.value = [...messages.value, next];
  return next;
}
```

- [ ] **Step 2: 添加 _consumeAgentStream 方法**

在 `ChatViewModel` 内部、`_advanceIteration` 之前添加：

```dart
Future<MessageEntity> _consumeAgentStream({
  required ChatEntity chat,
  required _SendContext ctx,
  required MessageEntity assistantMessage,
  required CancelToken cancelToken,
  required Stream<AgentEvent> agentStream,
}) async {
  var current = assistantMessage;
  var contentBuffer = StringBuffer();
  var reasoningBuffer = StringBuffer();
  var toolCallsJson = <Map<String, dynamic>>[];
  var toolResultsJson = <Map<String, dynamic>>[];
  var hasCompletedIteration = false;

  await for (final event in agentStream) {
    cancelToken.throwIfCancelled();

    if (event is AgentReasoningEvent) {
      if (hasCompletedIteration) {
        current = await _advanceIteration(chat, current);
        contentBuffer = StringBuffer();
        reasoningBuffer = StringBuffer();
        toolCallsJson = [];
        toolResultsJson = [];
        hasCompletedIteration = false;
      }
      reasoningBuffer.write(event.delta);
      current = current.copyWith(
        reasoningContent: reasoningBuffer.toString(),
        reasoning: true,
        reasoningUpdatedAt: DateTime.now(),
      );
      _updateMessageInList(current.id, current);
    } else if (event is AgentTextEvent) {
      if (hasCompletedIteration) {
        current = await _advanceIteration(chat, current);
        contentBuffer = StringBuffer();
        reasoningBuffer = StringBuffer();
        toolCallsJson = [];
        toolResultsJson = [];
        hasCompletedIteration = false;
      }
      contentBuffer.write(event.delta);
      current = current.copyWith(content: contentBuffer.toString());
      _updateMessageInList(current.id, current);
    } else if (event is AgentToolCallEvent) {
      toolCallsJson.add({
        'id': event.id,
        'name': event.name,
        'arguments': event.arguments,
      });
      current = current.copyWith(toolCalls: jsonEncode(toolCallsJson));
      _updateMessageInList(current.id, current);
    } else if (event is AgentToolResultEvent) {
      toolResultsJson.add({
        'id': event.id,
        'name': event.name,
        'result': event.result,
      });
      current = current.copyWith(toolResults: jsonEncode(toolResultsJson));
      _updateMessageInList(current.id, current);
      hasCompletedIteration = true;
    } else if (event is AgentDoneEvent) {
      current = current.copyWith(content: event.content);
      _updateMessageInList(current.id, current);
    }
  }

  if (reasoningBuffer.isNotEmpty) {
    current = current.copyWith(reasoning: false);
    _updateMessageInList(current.id, current);
  }

  return current;
}
```

- [ ] **Step 3: 验证 flutter analyze 通过**

Run: `flutter analyze lib/view_model/chat_view_model.dart`
Expected: 可能出现 `_consumeAgentStream is unused` warning，因为 sendMessage 还没改造。这是预期的，下一步会消化。

- [ ] **Step 4: Commit**

```bash
git add lib/view_model/chat_view_model.dart
git commit -m "refactor(chat-vm): extract _consumeAgentStream and _advanceIteration helpers"
```

---

## Task 7: 重写 sendMessage 主体使用新 helpers

**Files:**
- Modify: `lib/view_model/chat_view_model.dart`

- [ ] **Step 1: 替换 sendMessage 主体**

定位 `Future<void> sendMessage(...) async {` 方法（约第 494 行），把整个函数体（从 `async {` 后到对应 `}`）替换为以下骨架：

```dart
Future<void> sendMessage(
  MessageEntity message, {
  required ChatEntity chat,
}) async {
  if (isStreaming.value) return;

  final cancelToken = CancelToken();
  _activeCancelToken = cancelToken;
  isStreaming.value = true;
  error.value = null;
  MessageEntity? assistantMessage;

  try {
    final ctx = await _prepareSendContext(message, chat);
    if (ctx == null) return;

    assistantMessage = await _manage.appendAssistantPlaceholder(chat.id!);
    messages.value = [...messages.value, assistantMessage];

    final settingVM = GetIt.instance<SettingViewModel>();
    final permissionService = GetIt.instance<PermissionService>();

    final agentStream = _agentService.run(
      chat: chat,
      provider: ctx.provider,
      model: ctx.model,
      baseMessages: ctx.wrappedMessages,
      maxIterations: settingVM.maxAgentIterations.value,
      auxiliaryModel: settingVM.auxiliaryModel.value,
      auxiliaryModelProvider: settingVM.auxiliaryModelProvider.value,
      permissionService: permissionService,
      cancelToken: cancelToken,
      onPermission: (toolName, arguments) =>
          _askPermission(toolName, arguments, permissionService, cancelToken),
    );

    assistantMessage = await _consumeAgentStream(
      chat: chat,
      ctx: ctx,
      assistantMessage: assistantMessage,
      cancelToken: cancelToken,
      agentStream: agentStream,
    );

    await _manage.finalizeAssistantMessage(assistantMessage);
    await _manage.updateChatTimestamp(chat);
    await getChats();
  } on CancelledException {
    if (assistantMessage != null) {
      final cancelled =
          await _manage.recordCancelledOnMessage(assistantMessage);
      _updateMessageInList(cancelled.id, cancelled);
    }
  } catch (e) {
    error.value = e.toString();
    if (assistantMessage != null) {
      final errored = await _manage.recordErrorOnMessage(assistantMessage, e);
      _updateMessageInList(errored.id, errored);
    }
  } finally {
    isStreaming.value = false;
    _activeCancelToken = null;
  }
}
```

- [ ] **Step 2: 抽出 _askPermission 私有方法**

在 `_formatToolArgs` 之前添加：

```dart
Future<bool> _askPermission(
  String toolName,
  String arguments,
  PermissionService permissionService,
  CancelToken cancelToken,
) async {
  if (cancelToken.isCancelled) return false;
  Map<String, dynamic> args;
  try {
    args = jsonDecode(arguments) as Map<String, dynamic>;
  } catch (_) {
    args = {};
  }
  final description = _formatToolArgs(toolName, arguments);
  final ruleDesc = permissionService.generateRuleDescription(toolName, args);
  final isDangerous = permissionService.isDangerous(toolName, args);
  final isFileRule = const {
    'file_read',
    'file_write',
    'file_update',
    'file_delete',
  }.contains(toolName);

  final dialogFuture = showPermissionDialog(
    toolName: toolName,
    description: description,
    ruleDescription: ruleDesc,
    allowPersist: !isDangerous,
    isFileRule: isFileRule,
  );

  final result = await Future.any<PermissionDialogResult>([
    dialogFuture,
    cancelToken.whenCancelled.then((_) {
      final nav = router.navigatorKey.currentState;
      if (nav?.canPop() ?? false) nav!.pop();
      return const PermissionDialogResult(approved: false, persist: false);
    }),
  ]);

  if (result.approved && result.persist) {
    final rule = permissionService.generateRule(
      toolName,
      args,
      recursive: result.recursive,
    );
    await permissionService.persistRule(rule);
  }
  return result.approved;
}
```

- [ ] **Step 3: 添加 stopGenerating 公开方法**

在 `sendMessage` 紧邻位置（或 `addPendingImage` 附近）添加：

```dart
/// 停止当前流式生成
void stopGenerating() {
  _activeCancelToken?.cancel();
}
```

- [ ] **Step 4: 验证 flutter analyze 通过**

Run: `flutter analyze lib/view_model/chat_view_model.dart`
Expected: No issues found.

- [ ] **Step 5: 跑全套测试**

Run: `flutter test`
Expected: PASS, 既有测试通过

- [ ] **Step 6: Commit**

```bash
git add lib/view_model/chat_view_model.dart
git commit -m "refactor(chat-vm): slim sendMessage with CancelToken and helpers"
```

---

## Task 8: UI 调用点切换到 stopGenerating

**Files:**
- Modify: `lib/page/desktop/home/home_page.dart:193`
- Modify: `lib/page/mobile/chat/chat.dart:358`

- [ ] **Step 1: 修改 desktop home_page**

在 `lib/page/desktop/home/home_page.dart` 第 193 行附近，定位：

```dart
chatViewModel.isStreaming.value = false;
```

替换为：

```dart
chatViewModel.stopGenerating();
```

- [ ] **Step 2: 修改 mobile chat**

在 `lib/page/mobile/chat/chat.dart` 第 358 行附近，定位：

```dart
viewModel.isStreaming.value = false;
```

（这里的 `viewModel` 实际上就是 ChatViewModel 实例。）替换为：

```dart
viewModel.stopGenerating();
```

注意：TRPG 相关的 `isStreaming.value = false` 不动（trpg_page.dart:594, trpg_view_model.dart:239/244）。

- [ ] **Step 3: 验证 flutter analyze 通过**

Run: `flutter analyze lib/page/`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/page/desktop/home/home_page.dart lib/page/mobile/chat/chat.dart
git commit -m "feat(ui): wire stop button to ChatViewModel.stopGenerating"
```

---

## Task 9: ChatSupportService 自动刷新 updated_at (B5)

**Files:**
- Modify: `lib/service/chat_support_service.dart`
- Create: `test/service/chat_support_service_touch_test.dart`

- [ ] **Step 1: 添加 _touchChat 私有方法**

在 `lib/service/chat_support_service.dart` 类末尾（最后一个 `}` 之前）添加：

```dart
Future<ChatEntity> _touchChat(ChatEntity updated) async {
  final touched = updated.copyWith(updatedAt: DateTime.now());
  await _chatRepository.updateChat(touched);
  return touched;
}
```

- [ ] **Step 2: 改造 updateModel/Sentinel/Context/Temperature/renameChatManually**

替换以下 5 个方法（位置约第 46-91 行）：

```dart
Future<ChatEntity> renameChatManually(ChatEntity chat, String title) {
  return _touchChat(chat.copyWith(title: title));
}

Future<ChatEntity> updateModel(ChatEntity chat, int modelId) {
  return _touchChat(chat.copyWith(modelId: modelId));
}

Future<ChatEntity> updateSentinel(ChatEntity chat, int sentinelId) {
  return _touchChat(chat.copyWith(sentinelId: sentinelId));
}

Future<ChatEntity> updateContext(ChatEntity chat, int context) {
  return _touchChat(chat.copyWith(context: context));
}

Future<ChatEntity> updateTemperature(ChatEntity chat, double temperature) {
  return _touchChat(chat.copyWith(temperature: temperature));
}
```

- [ ] **Step 3: 写测试验证 updated_at 被刷新**

`test/service/chat_support_service_touch_test.dart`:

```dart
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/service/chat_support_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChatRepository implements ChatRepository {
  final List<ChatEntity> updates = [];

  @override
  Future<void> updateChat(ChatEntity chat) async {
    updates.add(chat);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ChatSupportService touches updated_at', () {
    late _FakeChatRepository fakeRepo;
    late ChatSupportService service;
    late ChatEntity original;

    setUp(() {
      fakeRepo = _FakeChatRepository();
      service = ChatSupportService(chatRepository: fakeRepo);
      original = ChatEntity(
        id: 1,
        title: 'old',
        modelId: 10,
        sentinelId: 20,
        temperature: 1.0,
        context: 0,
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      );
    });

    test('updateModel touches updatedAt', () async {
      final out = await service.updateModel(original, 99);
      expect(out.modelId, 99);
      expect(out.updatedAt.isAfter(original.updatedAt), isTrue);
      expect(fakeRepo.updates.single.modelId, 99);
    });

    test('updateSentinel touches updatedAt', () async {
      final out = await service.updateSentinel(original, 88);
      expect(out.sentinelId, 88);
      expect(out.updatedAt.isAfter(original.updatedAt), isTrue);
    });

    test('updateContext touches updatedAt', () async {
      final out = await service.updateContext(original, 5);
      expect(out.context, 5);
      expect(out.updatedAt.isAfter(original.updatedAt), isTrue);
    });

    test('updateTemperature touches updatedAt', () async {
      final out = await service.updateTemperature(original, 0.5);
      expect(out.temperature, 0.5);
      expect(out.updatedAt.isAfter(original.updatedAt), isTrue);
    });

    test('renameChatManually touches updatedAt', () async {
      final out = await service.renameChatManually(original, 'new');
      expect(out.title, 'new');
      expect(out.updatedAt.isAfter(original.updatedAt), isTrue);
    });
  });
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/service/chat_support_service_touch_test.dart`
Expected: PASS, 5 tests

- [ ] **Step 5: 验证 flutter analyze**

Run: `flutter analyze lib/service/chat_support_service.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/service/chat_support_service.dart test/service/chat_support_service_touch_test.dart
git commit -m "fix(chat-support): touch updated_at on all chat field updates"
```

---

## Task 10: ChatManageService 删除假 Service 透传方法 (B8)

**Files:**
- Modify: `lib/service/chat_manage_service.dart`
- Modify: `lib/view_model/chat_view_model.dart`

- [ ] **Step 1: ChatViewModel 注入 3 个 Repository**

在 `lib/view_model/chat_view_model.dart` import 区添加：

```dart
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
```

修改字段 & 构造器：

```dart
final ChatManageService _manage;
final ChatSupportService _support;
final ChatMessageService _chatMessageService;
final ChatSelectionDelegate _selection;
final AgentService _agentService;
final MessageRepository _messageRepository;
final ModelRepository _modelRepository;
final SentinelRepository _sentinelRepository;

CancelToken? _activeCancelToken;

ChatViewModel({
  ChatManageService? manageService,
  ChatSupportService? supportService,
  ChatMessageService? chatMessageService,
  ChatSelectionDelegate? selection,
  AgentService? agentService,
  MessageRepository? messageRepository,
  ModelRepository? modelRepository,
  SentinelRepository? sentinelRepository,
})  : _manage = manageService ?? GetIt.instance<ChatManageService>(),
      _support = supportService ?? GetIt.instance<ChatSupportService>(),
      _chatMessageService =
          chatMessageService ?? GetIt.instance<ChatMessageService>(),
      _selection = selection ?? ChatSelectionDelegate(),
      _agentService = agentService ?? GetIt.instance<AgentService>(),
      _messageRepository =
          messageRepository ?? GetIt.instance<MessageRepository>(),
      _modelRepository = modelRepository ?? GetIt.instance<ModelRepository>(),
      _sentinelRepository =
          sentinelRepository ?? GetIt.instance<SentinelRepository>();
```

- [ ] **Step 2: ChatViewModel 调用点切换到 Repository**

替换以下调用：

| 旧调用 | 新调用 |
|---|---|
| `_manage.getModel(chat.modelId)` | `_modelRepository.getModelById(chat.modelId)` |
| `_manage.getSentinel(chat.sentinelId)` | `_sentinelRepository.getSentinelById(chat.sentinelId)` |
| `_manage.storeMessage(message)` | `_messageRepository.storeMessage(message)` |
| `_manage.updateMessage(...)` | `_messageRepository.updateMessage(...)` |
| `_manage.refreshMessages(chatId)` | `_messageRepository.getMessagesByChatId(chatId)` |

使用 grep 定位所有出现：
```bash
grep -n "_manage\.\(getModel\|getSentinel\|storeMessage\|updateMessage\|refreshMessages\)" lib/view_model/chat_view_model.dart
```

注意：
- `_prepareSendContext` 中 `_manage.storeMessage(message)` 和 `_manage.getModel(...)` `_manage.getSentinel(...)` 调用替换
- `deleteMessage` 中 `_manage.refreshMessages` 替换
- `renameChat` 中 `_manage.refreshMessages` 和 `_manage.getModel` 替换
- 保留 `_manage.updateChatTimestamp(chat)` —— 这是复合业务，不删

- [ ] **Step 3: 在 ChatManageService 删除假 Service 方法**

在 `lib/service/chat_manage_service.dart` 删除以下 5 个方法（保留 helper 与复合业务）：

```dart
// 删除以下方法：
Future<List<MessageEntity>> refreshMessages(int chatId) async {
  return _messageRepository.getMessagesByChatId(chatId);
}

Future<ModelEntity?> getModel(int modelId) async {
  return _modelRepository.getModelById(modelId);
}

Future<SentinelEntity?> getSentinel(int sentinelId) async {
  return _sentinelRepository.getSentinelById(sentinelId);
}

Future<int> storeMessage(MessageEntity message) async {
  return _messageRepository.storeMessage(message);
}

Future<void> updateMessage(MessageEntity message) async {
  await _messageRepository.updateMessage(message);
}
```

注意：`ChatManageService` 内部使用的 `_modelRepository`/`_sentinelRepository`/`_messageRepository`/`_providerRepository` 字段保留（因为 selectChat、deleteChat 等仍需要）。

- [ ] **Step 4: 验证 flutter analyze**

Run: `flutter analyze`
Expected: 整个 lib/ 无错误，重点检查 chat_view_model.dart 没有遗漏的 `_manage.getModel` / `_manage.refreshMessages` 等调用。

- [ ] **Step 5: Run 全量测试**

Run: `flutter test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/view_model/chat_view_model.dart lib/service/chat_manage_service.dart
git commit -m "refactor(chat-manage): drop pass-through methods, route VM to repos"
```

---

## Task 11: 反向依赖回归检查与 layering 自检

**Files:**
- 验证（无文件改动）

- [ ] **Step 1: 验证 lib/service/ 不 import lib/agent/**

Run: `grep -rn "import 'package:athena/agent/" lib/service/`
Expected: 无输出（空）

- [ ] **Step 2: 验证 lib/agent/ 不 import lib/service/**

Run: `grep -rn "import 'package:athena/service/" lib/agent/`
Expected: 仅一行（`chat_service.dart` 的合法依赖；如果 grep 输出此行外的内容则失败）

实际上 chat_service.dart 是 Service 层，AgentService 依赖它是 Agent → Service 方向，符合层级。如果输出只有 `import 'package:athena/service/chat_service.dart';`，说明 OK。

- [ ] **Step 3: 验证 grep 假 Service 调用残余**

Run: `grep -rn "_manage\.\(getModel\|getSentinel\|storeMessage\|refreshMessages\)\b" lib/`
Expected: 无输出

- [ ] **Step 4: 验证 sendMessage 行数 < 50**

Run: `awk '/^  Future<void> sendMessage\(/,/^  }$/' lib/view_model/chat_view_model.dart | wc -l`
Expected: 输出 < 50（含签名行和闭合行）

- [ ] **Step 5: 跑全套 flutter analyze + test**

Run: `flutter analyze && flutter test`
Expected: No issues + 全部测试 PASS

- [ ] **Step 6: 此 Task 无 commit（纯验证）**

如果以上检查均通过，进入手动验收。如果某一项失败，回到对应 Task 修复后再来。

---

## Task 12: 手动验收 6 个场景

**Files:**
- 无（手工测试）

- [ ] **Step 1: 启动应用**

Run: `flutter run -d <device>`（用户当前可用设备）

- [ ] **Step 2: 场景 1 — 单轮对话**

操作：新建 chat，发送 "hi"，等待回复完成。
预期：assistant 消息完整、落库、UI 显示正常。

- [ ] **Step 3: 场景 2 — 多轮 tool call**

操作：发送 "读取 README.md 然后总结" 或类似 prompt，触发 file_read 工具调用。
预期：每次工具调用前弹审批，approve 后继续；多轮 content 切分到独立 assistant 消息。

- [ ] **Step 4: 场景 3 — 流式中途取消（text delta 阶段）**

操作：发送一个产生长回复的 prompt，在 text 流出中点"停止生成"。
预期：3 秒内停止；最后一条 assistant 消息 content 末尾出现 `[Cancelled]`；toolCalls/toolResults 不变。

- [ ] **Step 5: 场景 4 — 权限弹窗中取消**

操作：发送会触发 bash 工具的 prompt（比如 "list current dir"），在弹窗出现时不点按钮，直接点"停止生成"。
预期：弹窗自动关闭，Agent 退出；UI isStreaming = false。

- [ ] **Step 6: 场景 5 — HTTP 失败保留 partial（回归 B6）**

操作：发送一个会触发若干工具调用的 prompt 后，断开网络让 HTTP 抛错。
预期：catch 分支保留前几轮 toolCalls/toolResults；content 末尾追加 `[Error: ...]`。

- [ ] **Step 7: 场景 6 — 设置面板修改后冒泡（B5）**

操作：在 chat 列表中找一个不是顶部的 chat，进入设置面板修改温度。
预期：chat 列表中该 chat 立即冒泡到顶部（按 updated_at 排序）。

- [ ] **Step 8: 全部通过后，无 commit**

手动验收无文件改动；可选：在某文档或 audit 文件中标记问题修复状态。

---

## Task 13: 更新 audit 状态并合并

**Files:**
- Modify: `docs/audit-2026-05-25.md`

- [ ] **Step 1: 把 A6/A7/A8/B5/B8 状态改为 ✅**

在 `docs/audit-2026-05-25.md` 中定位每个问题的"状态"行：

- A6 (line ≈73)：`- **状态**：未修复` → `- **状态**：✅ 已修复（Phase 2 Batch B，删除 MessageSendService，VM 直接消费 AgentEvent）`
- A7 (line ≈79)：`- **状态**：未修复` → `- **状态**：✅ 已修复（Phase 2 Batch B，sendMessage 瘦身到 <50 行 + helpers）`
- A8 (line ≈90)：`- **状态**：未修复` → `- **状态**：✅ 已修复（Phase 2 Batch B，CancelToken 接入 AgentService 与权限弹窗）`
- B5 (line ≈147)：`- **状态**：未修复` → `- **状态**：✅ 已修复（Phase 2 Batch B，ChatSupportService 内部 _touchChat 统一刷新 updated_at）`
- B8 (line ≈171)：`- **状态**：未修复` → `- **状态**：✅ 已修复（Phase 2 Batch B，删除 5 个假 Service 方法，VM 直走 Repository）`

- [ ] **Step 2: Commit**

```bash
git add docs/audit-2026-05-25.md
git commit -m "docs: mark A6/A7/A8/B5/B8 fixed in Phase 2 Batch B"
```

---

## 验收清单

实施完成后：

- [ ] `flutter analyze` 无新增警告
- [ ] `flutter test` 全部通过（含 CancelToken / chat_manage_service_helpers / chat_support_service_touch）
- [ ] `grep "import 'package:athena/agent/" lib/service/` 无输出
- [ ] sendMessage 主体行数 < 50
- [ ] 手动 6 个验收场景全部通过
- [ ] audit-2026-05-25.md 中 A6/A7/A8/B5/B8 标记为 ✅
