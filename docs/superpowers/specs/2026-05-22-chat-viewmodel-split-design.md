# ChatViewModel 拆分设计

## 背景

ChatViewModel (`lib/view_model/chat_view_model.dart`) 当前 1008 行，包含聊天 CRUD、消息发送与 Agent 编排、聊天属性更新、重命名、图片导出等多类职责，已成为上帝类，难以维护。

## 目标

将 ChatViewModel 拆分为多个文件，每个文件 < 350 行，同时保持 UI 层零改动。

## 架构

```
Service 层（纯 Dart，无状态，可单测）
  → 接收数据参数，执行业务逻辑，返回结果值 / Stream

ChatViewModel（唯一写 signals 的地方）
  → 持有所有 signals，调用 Service，根据返回值更新 signals
  → 保持现有 API 签名不变
```

### 分层关系

```
ChatViewModel
  ├── signals (chats, messages, currentChat, isStreaming, error, ...)
  ├── ChatSelectionDelegate (已有，不变)
  │
  ├── ChatManageService        → 聊天 CRUD + 列表管理
  ├── MessageSendService       → Agent 编排 + 流事件处理 + 权限交互
  └── ChatSupportService       → 属性更新 + 重命名 + 导出
```

## 新增文件

### `lib/service/chat_manage_service.dart` (~180 行)

聊天生命周期管理。所有方法返回结果值，不写 signals。

| 方法 | 返回值 | 说明 |
|---|---|---|
| `getChats()` | `(List<ChatEntity>, List<ChatHistoryEntity>)` | 加载聊天列表和历史 |
| `createChat()` | `CreateChatResult` | 创建新聊天（含默认 model/provider/sentinel 选择） |
| `deleteChat(int chatId)` | `void` | 删除聊天及其消息 |
| `deleteChats(Set<int> ids)` | `void` | 批量删除 |
| `getFirstChat()` | `ChatEntity?` | 获取第一个聊天，不存在则创建 |
| `selectChat(ChatEntity chat)` | `SelectChatResult` | 加载聊天关联的 messages/model/provider/sentinel |
| `initSignals()` | `InitResult?` | 初始化时加载状态，无聊天时返回 null |
| `prepareNewChatDraft()` | `DraftDefaults` | 返回草稿默认值 |
| `togglePin(ChatEntity chat)` | `void` | 切换置顶（写 DB） |
| `refreshMessages(int chatId)` | `List<MessageEntity>` | 按 chatId 重新加载消息 |

### `lib/service/message_send_service.dart` (~250 行)

消息发送与 Agent 编排。返回 Stream 事件。

```dart
sealed class SendEvent {}
class SendTextDelta extends SendEvent { final String delta; }
class SendReasoningDelta extends SendEvent { final String delta; }
class SendToolCall extends SendEvent { final String id, name, arguments; }
class SendToolResult extends SendEvent { final String id, name, result; }
class SendIterationEnd extends SendEvent {}
class SendDone extends SendEvent { final String content; }
class SendError extends SendEvent { final String error; }
```

| 方法 | 返回值 | 说明 |
|---|---|---|
| `sendMessage({...})` | `Stream<SendEvent>` | Agent 编排 + 流式响应 |
| `formatToolArgs(...)` | `String` | 格式化工具参数为可读文本 |

### `lib/service/chat_support_service.dart` (~150 行)

辅助功能。返回 Stream 或值。

| 方法 | 返回值 | 说明 |
|---|---|---|
| `renameChat(ChatEntity)` | `Stream<String>` | AI 自动重命名流 |
| `renameChatManually(ChatEntity, String)` | `void` | 手动重命名（写 DB） |
| `exportImage(GlobalKey)` | `Uint8List` | 导出聊天为 PNG |
| `updateModel(ModelEntity, ChatEntity)` | `ChatEntity` | 更新模型（返回更新后的 chat） |
| `updateSentinel(SentinelEntity, ChatEntity)` | `ChatEntity` | 更新哨兵 |
| `updateContext(int, ChatEntity)` | `ChatEntity` | 更新上下文轮数 |
| `updateTemperature(double, ChatEntity)` | `ChatEntity` | 更新温度 |
| `updateCurrentModel(ModelEntity)` | `ProviderEntity?` | 查询模型关联的 provider |
| `updateExpanded(MessageEntity)` | `MessageEntity` | 更新消息展开状态 |

### `lib/view_model/chat_view_model.dart` (~350 行)

```dart
class ChatViewModel {
  // ===== Signals =====
  final chats = listSignal<ChatEntity>([]);
  final chatHistories = listSignal<ChatHistoryEntity>([]);
  final currentChat = signal<ChatEntity?>(null);
  final messages = listSignal<MessageEntity>([]);
  final isLoading = signal(false);
  final isStreaming = signal(false);
  final error = signal<String?>(null);
  final currentModel = signal<ModelEntity?>(null);
  final currentProvider = signal<ProviderEntity?>(null);
  final currentSentinel = signal<SentinelEntity?>(null);
  final currentContext = signal(defaultDraftContext);
  final currentTemperature = signal(defaultDraftTemperature);
  final pendingImages = listSignal<String>([]);

  // ===== Services =====
  final _manage = ChatManageService(...);
  final _send = MessageSendService(...);
  final _support = ChatSupportService(...);

  // ===== API — 委托给 Service，负责更新 signals =====
  // 每个公开方法 pattern:
  //   1. 设置 loading/error 初始状态
  //   2. 调用 Service 方法
  //   3. 根据返回值更新 signals
  //   4. catch 异常设置 error
}
```

## 保持不变

- `ChatSelectionDelegate` — 已经是独立文件，不改
- `_updateChatInLists` / `_updateMessageInList` — 内部辅助方法保留在 ChatViewModel
- 所有 UI 引用 `GetIt.instance<ChatViewModel>()` 不变
- 所有信号访问模式不变

## 依赖注入

ChatManageService 和 ChatSupportService 通过 ChatViewModel 构造函数注入（保持可选参数默认实例的模式）。MessageSendService 涉及 AgentService 和 PermissionService，也从 GetIt 获取。

不改 `lib/di.dart`，ChatViewModel 构造函数内部创建 Service 实例。

## 行数预估

| 文件 | 当前 (行) | 目标 (行) |
|---|---|---|
| `chat_view_model.dart` | 1008 | ~350 |
| `chat_manage_service.dart` | — | ~180 |
| `message_send_service.dart` | — | ~250 |
| `chat_support_service.dart` | — | ~150 |
| `chat_selection_delegate.dart` | 99 | 99 (不变) |
