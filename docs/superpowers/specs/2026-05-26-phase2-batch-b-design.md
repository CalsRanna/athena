# Phase 2 Batch B 设计文档

> 配套：[audit-fix-plan-2026-05-25.md](../../audit-fix-plan-2026-05-25.md)
> 基线 commit：`9a358df`
> 编写日期：2026-05-26
> 范围：A6 / A7 / A8 / B5 / B8 五个修复项

## 1. 目标与范围

修复审计中 Phase 2 剩余的 5 个问题：

| 编号 | 问题 | 影响 |
|---|---|---|
| A6 | `MessageSendService` 持有 `AgentService`，Service 反向依赖 Agent | 违反 CLAUDE.md 的分层方向，且中间层仅做 1:1 事件包装 |
| A7 | `ChatViewModel.sendMessage` 210 行未瘦身 | 业务编排/持久化/UI 状态混杂，单元测试困难 |
| A8 | "停止生成"按钮只设 `isStreaming=false`，不打断 HTTP/工具/权限弹窗 | 后台仍在写库/扣 token/弹窗 |
| B5 | `updateModel/Sentinel/Context/Temperature` 不刷新 `updated_at` | chat 列表排序不按预期冒泡 |
| B8 | `ChatManageService` 含 5 个单行透传 Repository 的"假 Service" | 服务边界模糊 |

**不在本批次范围**：
- A4（Skill `allowed-tools` 真正消费）—— 留待后续批次
- `ChatViewModel:78-83` 的 5 个透传 getter（B8 残留清理）—— UI 仍引用，本批次保留，避免改动蔓延
- TRPG 流式取消 —— 不在 Phase 2 范围

## 2. 架构变化

### 当前依赖关系

```
ChatViewModel
  ├─→ MessageSendService ──→ AgentService ──→ ChatService
  ├─→ ChatManageService   ──→ Repository (单行透传 + 复合业务)
  ├─→ ChatSupportService  ──→ Repository
  └─→ ChatMessageService  ──→ MessageRepository
```

问题：`MessageSendService` 是 Service 层却 import Agent，且对 `AgentEvent` 仅做 1:1 重打包；`ChatManageService` 同时承担"业务"与"假 Service"。

### 修复后依赖关系

```
ChatViewModel
  ├─→ AgentService ──→ ChatService                  (Agent 层，业务编排)
  ├─→ ChatManageService                             (Chat 元数据生命周期)
  ├─→ ChatSupportService                            (设置面板支持，内部 _touchChat)
  ├─→ ChatMessageService                            (消息格式转换)
  └─→ MessageRepository / ModelRepository / SentinelRepository
                                                    (VM 直接消费单点 Repository)
```

层级方向：`VM → (Agent | Service) → Repository`，Service 不再 import Agent。

## 3. Step 2.3 — 删除 MessageSendService (A6)

### 文件改动

- **删除**：`lib/service/message_send_service.dart`
- **修改**：`lib/view_model/chat_view_model.dart`
  - 移除字段 `MessageSendService? _sendService`、getter `_send`、构造器参数 `sendService`
  - 新增字段 `final AgentService _agentService`，构造器默认 `GetIt.instance<AgentService>()`
  - 消费 `AgentEvent` 子类替代原 `SendEvent` 子类：
    - `SendReasoningDelta` → `AgentReasoningEvent`
    - `SendTextDelta` → `AgentTextEvent`
    - `SendToolCall` → `AgentToolCallEvent`
    - `SendToolResult` → `AgentToolResultEvent`
    - `SendDone` → `AgentDoneEvent`
  - 将原 `MessageSendService.formatToolArgs` 移入 VM 作为私有方法 `_formatToolArgs`（仅 `onPermission` 回调使用）
- **修改**：`lib/di.dart`
  - 注销 `MessageSendService`（如已注册）
  - 保留 `AgentService` 注册（已存在）

### `SendIterationEnd` 处理

审计文档 C3 提到 `SendIterationEnd` 是死代码，但当前 `lib/service/message_send_service.dart` 中并不存在该定义（已在更早 commit 删除）。Step 2.3 无需额外清理。

## 4. Step 2.4 — sendMessage 瘦身 (A7)

### `ChatManageService` 新增 helper

集中持久化语义，VM 不再触碰具体 Repository 调用：

```dart
class ChatManageService {
  // ... 既有方法

  /// 创建并落库一条空的 assistant 占位消息
  Future<MessageEntity> appendAssistantPlaceholder(int chatId);

  /// 持久化 assistant 消息最终内容（含 toolCalls/toolResults/reasoning）
  Future<void> finalizeAssistantMessage(MessageEntity message);

  /// 取消现场：保留所有累积内容，content 末尾追加 [Cancelled] 标记
  Future<MessageEntity> recordCancelledOnMessage(MessageEntity message);

  /// 错误现场：保留所有累积内容，content 末尾追加 [Error: ...] 标记
  Future<MessageEntity> recordErrorOnMessage(MessageEntity message, Object error);
}
```

实现要点：
- `appendAssistantPlaceholder` 内部直接 `_messageRepository.storeMessage(empty)`，返回带 id 的 entity
- `recordCancelledOnMessage` / `recordErrorOnMessage`：参考 B6 修复模式，`copyWith(content: ..., reasoning: false)`，**不动 toolCalls/toolResults/reasoningContent**

### `ChatViewModel.sendMessage` 重构

目标 < 50 行 + 3 个私有 helper。骨架：

```dart
Future<void> sendMessage(MessageEntity message, {required ChatEntity chat}) async {
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

    assistantMessage = await _consumeAgentStream(
      chat: chat,
      ctx: ctx,
      assistantMessage: assistantMessage,
      cancelToken: cancelToken,
    );

    await _manage.finalizeAssistantMessage(assistantMessage);
    await _manage.updateChatTimestamp(chat);
    await getChats();
  } on CancelledException {
    if (assistantMessage != null) {
      final cancelled = await _manage.recordCancelledOnMessage(assistantMessage);
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

私有 helper：

| 方法 | 职责 |
|---|---|
| `_prepareSendContext(message, chat)` | 用户消息落库 + 首条用户消息时触发自动重命名 + 取 model/provider/sentinel + 构建 wrappedMessages，返回上下文记录或 null |
| `_consumeAgentStream(...)` | 接 `AgentEvent` 流，处理 iteration 边界切分（reasoning/text delta 触发时若 `hasCompletedIteration` 则 finalize 旧消息、appendAssistantPlaceholder 新消息）、buffers 累积、signal 更新；遇 `cancelToken.throwIfCancelled()` 抛 `CancelledException` |
| `_formatToolArgs(toolName, arguments)` | 原 `MessageSendService.formatToolArgs`，仅 onPermission 回调使用 |

### 死方法处理

`ChatMessageService.getCompletionStream` 已在 commit c60dabe 删除（Batch A），本批次无需再处理。

## 5. Step 2.5 — CancelToken 流式取消 (A8)

### 新文件 `lib/agent/cancel_token.dart`

```dart
import 'dart:async';

class CancelledException implements Exception {
  final String reason;
  const CancelledException([this.reason = 'cancelled']);
  @override
  String toString() => 'CancelledException: $reason';
}

class CancelToken {
  final _completer = Completer<void>();
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

### `AgentService.run` 改造

- 新增可选参数 `CancelToken? cancelToken`
- 在以下节点插入 `cancelToken?.throwIfCancelled()`：
  1. 每个 iteration 起始
  2. HTTP 流 `await for` 内部，每次 yield 之前
  3. 每次工具调用前
  4. 权限审批结果返回后

- 权限审批节点改造为可被取消：

```dart
final approved = cancelToken == null
    ? await onPermission(tc.function.name, tc.function.arguments)
    : await Future.any<bool>([
        onPermission(tc.function.name, tc.function.arguments),
        cancelToken.whenCancelled.then((_) => false),
      ]);
cancelToken?.throwIfCancelled();
```

注：弹窗的实际关闭由 `ChatViewModel.stopGenerating` 触发（通过 router pop），`Future.any` 保证 await 不会无限挂起。

### `ChatViewModel` 改造

`stopGenerating()` 仅触发取消信号，弹窗关闭由 `onPermission` 回调内部 `Future.any` 配合 Navigator.pop 实现：

```dart
class ChatViewModel {
  CancelToken? _activeCancelToken;

  void stopGenerating() {
    _activeCancelToken?.cancel();
  }
}
```

`onPermission` 回调中包裹 `showPermissionDialog`，在取消时主动关闭弹窗：

```dart
onPermission: (toolName, arguments) async {
  if (cancelToken.isCancelled) return false;
  // ... 准备 args / description / ruleDesc / isDangerous / isFileRule

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
    // ... persistRule
  }
  return result.approved;
}
```

关键点：
- `Future.any` 取较早 settle 的一个；用户先点按钮则取该结果，取消先到则触发 `Navigator.pop` 顺便关掉弹窗
- 取消信号回到 `AgentService` 后立即 `throwIfCancelled()` 抛 `CancelledException`，不再执行工具
- 无需修改 `showPermissionDialog` 签名，回归现有 dialog 实现

### UI 调用方改造

- `lib/page/desktop/home/home_page.dart:193`：`chatViewModel.isStreaming.value = false` → `chatViewModel.stopGenerating()`
- `lib/page/mobile/chat/chat.dart:358`：同上
- TRPG 相关调用点（trpg_view_model / trpg_page）**不改动**，不在 Batch B 范围

### 取消现场

`_consumeAgentStream` 捕获 `CancelledException` 时不在内部处理，重新抛出。`sendMessage` 主体的 `on CancelledException` 分支调用 `_manage.recordCancelledOnMessage(...)` —— content 末尾追加 `[Cancelled]`，保留 toolCalls/toolResults/reasoningContent。与 B6 错误现场处理保持一致。

## 6. Step 2.7 — Service 边界重划 (B5/B8)

### B5：ChatSupportService 自动刷新 updated_at

新增私有方法：

```dart
Future<ChatEntity> _touchChat(ChatEntity updated) async {
  final touched = updated.copyWith(updatedAt: DateTime.now());
  await _chatRepository.updateChat(touched);
  return touched;
}
```

改造所有 update* 方法：

```dart
Future<ChatEntity> updateModel(ChatEntity chat, int modelId) =>
    _touchChat(chat.copyWith(modelId: modelId));

Future<ChatEntity> updateSentinel(ChatEntity chat, int sentinelId) =>
    _touchChat(chat.copyWith(sentinelId: sentinelId));

Future<ChatEntity> updateContext(ChatEntity chat, int context) =>
    _touchChat(chat.copyWith(context: context));

Future<ChatEntity> updateTemperature(ChatEntity chat, double temperature) =>
    _touchChat(chat.copyWith(temperature: temperature));

Future<ChatEntity> renameChatManually(ChatEntity chat, String title) =>
    _touchChat(chat.copyWith(title: title));
```

### B8：删除 ChatManageService 假 Service 方法

| 方法 | 处理 |
|---|---|
| `getModel(int)` | 删除 → VM 用 `_modelRepository.getModelById(...)` |
| `getSentinel(int)` | 删除 → VM 用 `_sentinelRepository.getSentinelById(...)` |
| `storeMessage(MessageEntity)` | 删除 → 用户消息落库 VM 直接 `_messageRepository.storeMessage(...)`；assistant 占位走 `appendAssistantPlaceholder` |
| `updateMessage(MessageEntity)` | 删除 → 改用 `finalizeAssistantMessage`/`recordErrorOnMessage`/`recordCancelledOnMessage`；其他 VM 直接 `_messageRepository.updateMessage(...)` |
| `refreshMessages(int)` | 删除 → VM 直接 `_messageRepository.getMessagesByChatId(...)` |

保留（复合业务）：
- `getChats` / `createChat` / `deleteChat` / `deleteChats` / `selectChat`
- `togglePin` / `updateChatTimestamp` / `deleteMessagesFromIndex`
- 新增的 4 个 helper

### VM 注入新 Repository

`ChatViewModel` 构造器新增三个可选参数（与现有 Service 同模式）：

```dart
ChatViewModel({
  // ... 现有参数
  MessageRepository? messageRepository,
  ModelRepository? modelRepository,
  SentinelRepository? sentinelRepository,
}) : _messageRepository = messageRepository ?? GetIt.instance<MessageRepository>(),
     _modelRepository = modelRepository ?? GetIt.instance<ModelRepository>(),
     _sentinelRepository = sentinelRepository ?? GetIt.instance<SentinelRepository>(),
     // ...
```

## 7. 测试与验收

### `flutter analyze`

无新增警告/错误。

### 手动验收场景

1. **单轮对话** — 发送 "hi"，收到完整回复，落库正确
2. **多轮 tool call** — 触发 file_read + bash 多轮调用，每次审批通过，content 正确切分到多条 assistant 消息
3. **流式中途取消** — text delta 期间点"停止生成"，3 秒内停止；assistant 消息保留 partial content + 追加 `[Cancelled]`；toolCalls/toolResults 保留
4. **权限弹窗中取消** — 弹窗出现时点"停止生成"，弹窗自动关闭，Agent 立即退出，UI 状态干净
5. **HTTP 失败** — 断网模拟，catch 分支保留 partial + 追加 `[Error]`；toolCalls/toolResults 保留（B6 已修，回归验证）
6. **设置面板 update** — 修改聊天模型/温度/上下文，chat 列表立即按 updatedAt 冒泡到顶（B5 修复验证）

### 反向依赖回归

- `grep -rn "import 'package:athena/agent/" lib/service/` 应无结果
- `grep -rn "import 'package:athena/service/" lib/agent/` 应无结果

## 8. 后续遗留

以下项不在 Batch B 范围，留待后续：

- **A4**：Skill `allowed-tools` 真正消费 + currentSkillContext 栈
- **ChatViewModel:78-83 透传 getter** 清理（UI 仍依赖，需联动改 page 层）
- **TRPG 流式取消** 改造（独立 VM，独立批次处理）
