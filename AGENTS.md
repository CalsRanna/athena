# AGENTS.md - Athena 项目编码指南

本文档面向在此项目中工作的 AI Coding Agent，提供项目架构、编码规范、重要约束和常见操作模式的完整说明。

---

## 1. 项目概览

Athena 是一个跨平台（桌面 + 移动）AI Agent 应用，使用 Flutter 构建。核心能力包括：

- **完整 Agent 循环**：推理 -> 工具调用 -> 结果 -> 再推理（最大 100 轮可配置）
- **内置工具系统**：12 个工具实现类（桌面端运行时 11 个，移动端 3 个）
- **Skill 系统**：Claude Code 风格三级渐进式加载（Level 1/2/3）
- **两层权限模型**：用户持久化规则、审批弹窗
- **Agent 自我进化**：Skill 创建/更新、经验学习/回忆、Sentinel 系统提示词优化
- **多模型提供商**：OpenAI API 兼容，预设 DeepSeek、OpenRouter、阿里云百炼、硅基流动、火山方舟、智谱、MiniMax

---

## 2. 项目结构

```
lib/
├── main.dart                    # 应用入口，初始化 DB/DI/Window/Tray
├── di.dart                      # GetIt 依赖注入：注册所有 Repository/Service/ViewModel/Agent
├── agent/                       # Agent 层
│   ├── agent_service.dart       #   核心 Agent 循环（流式推理-工具调用迭代）
│   ├── cancel_token.dart        #   取消令牌（取消流/等待取消）
│   ├── evolution/               #   自我进化提示词
│   ├── permission/              #   权限服务 + 持久化规则
│   ├── skill/                   #   Skill 加载/注册/信任
│   └── tool/                    #   12 个工具实现 + 辅助文件 + 工具注册表
├── page/                        # UI 层（桌面端 DesktopRoute / 移动端 AutoRoute）
│   ├── desktop/                 #   桌面端（多区工作台：侧栏+顶栏context+主内容区+底部composer）
│   └── mobile/                  #   移动端（分段浏览 + Bottom Sheet）
├── view_model/                  # Signals 状态管理 + Delegate 委托
│   ├── delegate/                #   业务逻辑委托（纯逻辑，不持有 Signal）
│   │   ├── agent_stream_delegate.dart
│   │   ├── chat_rename_delegate.dart
│   │   └── chat_selection_delegate.dart
│   ├── chat_view_model.dart     #   ChatViewModel（Signal 持有者 + 跨委托编排）
│   └── ...                      #   其他 ViewModel
├── service/                     # 服务层（网络通信/消息转换/持久化编排/UI辅助操作）
├── repository/                  # 数据访问层（Laconic ORM 封装）
├── entity/                      # 数据库实体（11 个 entity）
├── database/                    # SQLite + Laconic ORM + 迁移
├── router/                      # AutoRoute 路由配置
├── widget/                      # 通用组件（20+ 组件，含设计系统）
├── component/                   # 业务组件（消息列表项、工具卡片、翻译列表项等）
├── util/                        # 工具类（重试、日志、平台检测、颜色等）
├── preset/                      # 预设提示词模板（运行时使用，非 DB 种子数据）
├── extension/                   # Dart 扩展方法
└── model/                       # 普通数据类（TokenUsage 等）
```

---

## 3. 分层架构与数据流

```
UI Layer (page/widget/component)
    ↓ 读取 Signal / 调用 ViewModel 方法
ViewModel Layer (signals 响应式 + 业务逻辑)
    ↓ 编排调用
Service Layer (chat_service / chat_message_service / chat_manage_service / chat_support_service)
    ↓ 调用 Repository 持久化 / 调用 ChatService 网络请求
Repository Layer (Laconic ORM 封装)
    ↓ 直接访问 Database.instance.laconic
Data Layer (Entity / Database / Migration)
```

Agent 层横向穿透各层：AgentService 调用 ChatService（网络）、ToolRegistry（工具）、SkillRegistry（技能）。

---

## 4. 依赖注入（DI）

`lib/di.dart` 通过 `GetIt.instance` 按以下顺序注册：

1. **Repository**（无依赖，8 个 LazySingleton）
2. **Service**（依赖 Repository，12 个 LazySingleton）
3. **Agent**（PermissionService → SkillRegistry → ToolRegistry → AgentService）
4. **ViewModel Delegate**（依赖 Service/Agent，3 个 LazySingleton）
5. **ViewModel**（依赖 Delegate 或 Service，8 个 LazySingleton）
6. **ChatViewModel**（最后注册，依赖最多）

**重要规则**：
- 所有注册使用 `registerLazySingleton`（首次访问时才实例化）
- DI 初始化在 `main()` 中调用 `DI.ensureInitialized(dataDirectory: ...)`
- 页面组件通过 `GetIt.instance<ChatViewModel>()` 获取 ViewModel 实例
- 测试中使用 `GetIt.instance.reset()` + `registerSingleton` 替换为 Fake 实现

---

## 5. 状态管理（Signals）

项目使用 `signals` 包（v6.2.0），核心概念：

- `signal<T>(initialValue)` - 可读写响应式值
- `listSignal<T>([])` - 响应式列表
- `setSignal<T>({})` - 响应式集合
- `computed(() => ...)` - 派生信号，依赖其他信号自动更新
- `Watch((context) { ... })` - Flutter Widget 中自动订阅信号变化

ChatViewModel 的主要信号：

```dart
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
final currentRetention = signal(defaultDraftRetention);
final currentTemperature = signal(defaultDraftTemperature);
final currentIteration = signal(0);
final currentToolName = signal<String?>(null);
final currentTokenUsage = signal<TokenUsage?>(null);
final cumulativeTokenTotal = signal(0);
final pendingImages = listSignal<String>([]);
```

**关键模式**：更新列表信号时，不要在原有列表上直接修改，而是创建新列表再赋值：

```dart
// 正确
messages.value = [...messages.value, newMessage];
// 错误 - 不会触发信号更新
messages.value.add(newMessage);
```

---

## 6. 数据库

- **引擎**：SQLite，通过 `laconic` + `laconic_sqlite` 包访问
- **路径**：`{app_support_dir}/athena.db`
- **初始化**：`Database.instance.ensureInitialized()` 在 `main()` 中调用
- **外键**：迁移完成后执行 `PRAGMA foreign_keys = ON`
- **迁移**：按时间顺序执行，每个迁移通过检查 `migrations` 表判断是否已执行
- **预设**：通过 `migrations` 表中的 marker 控制预设数据只插入一次
- **重置**：`Database.instance.reset()` 删除所有表并重新迁移+预设

实体类模式：所有 Entity 都实现 `fromJson(Map)`、`toJson()`、`copyWith(...)`。

---

## 7. Agent 系统详解

### 7.1 Agent 循环流程

`AgentService.run()` 是核心，返回 `Stream<AgentEvent>`：

1. 每轮迭代开始：注入 skill prompt（首轮）和 evolution prompt（始终）
2. 通过 `ChatService.getCompletion()` 流式获取模型响应
3. 解析流中的 text delta 和 reasoning delta
4. 流结束后检查 tool calls：
   - 无 tool call → `AgentDoneEvent`，结束
   - 有 tool call → 依次执行每个工具
5. 执行前检查权限（持久化规则 → 审批弹窗）
6. 工具结果超过 4000 字符时调用辅助模型摘要
7. 工具结果消息加入消息列表，进入下一轮迭代

### 7.2 AgentEvent 类型

```dart
sealed class AgentEvent {
  AgentTextEvent        // 文本 delta（流式）
  AgentReasoningEvent   // 推理过程 delta（流式）
  AgentToolCallEvent    // 工具调用声明（id/name/arguments）
  AgentToolResultEvent  // 工具执行结果（id/name/result）
  AgentIterationCompleteEvent // 一轮迭代完成
  AgentDoneEvent        // Agent 完成（最终 content）
  AgentUsageEvent       // Token 使用量统计
}
```

### 7.3 工具系统

所有工具实现 `Tool` 接口：

```dart
abstract class Tool {
  String get name;
  String get description;
  Map<String, dynamic> get parameters; // JSON Schema
  Future<String> execute(Map<String, dynamic> args);
}
```

- `ToolRegistry` 管理所有工具，提供 `register()`、`get()`、`definitions`（OpenAI tool definitions）
- 桌面端注册 11 个工具（bash 与 powershell 按操作系统互斥），移动端仅 3 个（WebFetchTool、WebSearchTool、SkillTool）
- 在 `di.dart` 中按平台注册不同的工具集合

完整的工具实现文件（`lib/agent/tool/`）：

| 文件 | 工具类 | 说明 |
|------|--------|------|
| `bash_shell_tool.dart` | BashShellTool | Linux/macOS Shell 命令执行 |
| `powershell_shell_tool.dart` | PowerShellShellTool | Windows PowerShell 命令执行 |
| `file_read_tool.dart` | FileReadTool | 文件读取，支持 offset/limit 分页 |
| `file_write_tool.dart` | FileWriteTool | 文件创建/覆写 |
| `file_update_tool.dart` | FileUpdateTool | 精确字符串替换，含外部修改检测 |
| `web_fetch_tool.dart` | WebFetchTool | HTTP GET/POST 抓取（200KB 上限） |
| `web_search_tool.dart` | WebSearchTool | Brave Search API 搜索 |
| `skill_tool.dart` | SkillTool | 加载 Skill Level 2 指令 |
| `skill_evolve_tool.dart` | SkillEvolveTool | 创建/更新 Skill |
| `experience_learn_tool.dart` | ExperienceLearnTool, ExperienceRecallTool | 经验学习与回忆 |
| `sentinel_evolve_tool.dart` | SentinelEvolveTool | Sentinel 系统提示词优化 |
| `shell_runner.dart` | (辅助) | Shell 进程启动/管理（超时、kill） |
| `html_to_markdown.dart` | (辅助) | HTML 转 Markdown 工具函数 |
| `tool_interface.dart` | Tool (抽象接口) | 工具接口定义 |
| `tool_registry.dart` | ToolRegistry | 工具注册与查询 |

**已废弃文件**（仅保留注释，未注册）：
| 文件 | 说明 |
|------|------|
| `list_directory_tool.dart` | 已由 bash/powershell 替代 |
| `unix_search_tool.dart` | 已由 bash 替代 |
| `powershell_search_tool.dart` | 已由 powershell 替代 |

### 7.4 权限系统

两层检查（在 `AgentService.run()` 中按顺序）：

1. **用户持久化规则**：`~/.athena/permissions.json` 中的通配符匹配规则，命中直接放行
2. **审批弹窗**：无匹配规则时弹出完整命令预览，用户可选 Allow/Deny + 记忆选项（精确/通配符模式），弹窗不可被空白点击关闭

工具自我保护（在工具 `execute()` 内部，独立于权限系统）：

- bash/powershell：递归删除命令（rm -rf 变体）被检测到时拒绝执行
- file_update：写入前校验文件 mtime，防止覆盖外部并发修改
- web_fetch：仅允许 http/https scheme

### 7.5 Skill 系统

三级加载：

| Level | 内容 | 加载时机 |
|-------|------|---------|
| 1 | name + description | 会话启动时注入系统提示词 |
| 2 | SKILL.md 完整指令 | Agent 调用 `skill(name)` 时 |
| 3 | scripts/references 等资源 | Level 2 指令引用时 |

Skill 文件格式：

```markdown
---
name: my-skill
description: What this skill does
allowed-tools: file_read, web_search
---
## Process
1. Step one
```

放置位置：
- `~/.athena/skills/` - 用户级（始终信任）
- `.athena/skills/` - 项目级（需用户确认信任）

内置 `self-evolve` Skill 提供完整的自我进化指导。

---

## 8. 实体与数据模型

| Entity | 关键字段 | 说明 |
|--------|---------|------|
| ChatEntity | title, modelId, sentinelId, temperature, retention, pinned, tokenTotal, contextTokens, cachedTokens | 聊天会话 |
| ChatHistoryEntity | chat, lastMessageContent | 会话列表项（含最后消息） |
| MessageEntity | chatId, role, content, reasoningContent, toolCalls, toolResults, compacted | 聊天消息 |
| ModelEntity | name, modelId, providerId, reasoning, vision, isPreset | AI 模型 |
| ProviderEntity | name, baseUrl, apiKey, enabled, isPreset | AI 提供商 |
| SentinelEntity | name, avatar, description, prompt, tags, isPreset | Agent 角色 |
| ExperienceEntity | name, description, tags, context, scope | Agent 经验记忆 |
| TranslationEntity | source, sourceLang, targetLang, result | 翻译记录 |
| SummaryEntity | url, content, summary, modelId | 网页摘要记录 |
| TRPGGameEntity | name, systemPrompt, modelId | TRPG 游戏 |
| TRPGMessageEntity | gameId, role, content, suggestions | TRPG 消息 |

所有实体使用 `copyWith()` 进行不可变更新，布尔值在数据库中存储为 0/1。

---

## 9. 服务层详解

### 服务概览

| 服务 | 文件 | 职责 |
|------|------|------|
| ChatService | `chat_service.dart` | AI 网络请求（流式/非流式/标题生成/连接测试），封装 OpenAI 客户端生命周期 |
| ChatMessageService | `chat_message_service.dart` | 消息格式转换（Entity → ChatMessage），含 system prompt 注入、上下文截断、图片处理 |
| ChatManageService | `chat_manage_service.dart` | 会话 CRUD、消息删除/占位/最终化、取消/错误标记 |
| ChatSupportService | `chat_support_service.dart` | UI 辅助：重命名、配置更新、Provider 解析、消息折叠、图片导出 |
| LlmClient | `llm_client.dart` | 统一 LLM API 客户端，封装 OpenAIClient 创建/请求/重试/关闭 |
| DataMigrationService | `data_migration_service.dart` | 数据导入/导出（JSON）、数据库重置、悬空引用重整 |
| ModelResolver | `model_resolver.dart` | 模型/Provider 解析 + fallback 逻辑（优先指定模型 → 回退第一个可用） |
| SentinelService | `sentinel_service.dart` | Sentinel 元数据 AI 生成（名称、描述、标签、头像） |
| SummaryService | `summary_service.dart` | 网页摘要 AI 生成 |
| TranslationService | `translation_service.dart` | 文本翻译 |
| TRPGService | `trpg_service.dart` | TRPG 游戏 AI 逻辑 |
| TokenUsageService | `token_usage_service.dart` | Token 用量追踪（原子累加 + 快照覆盖写） |

### ChatService
- 封装 `openai_dart` 包的 `OpenAIClient` 生命周期
- 提供 `getCompletion()`（流式）、`complete()`（非流式）、`getTitle()`（标题生成）、`connect()`（测试连接）
- 每次调用创建新客户端，完成后 `close()`
- 内建重试：`retry()` / `retryStream()`，指数退避 + 随机抖动

### ChatMessageService
- `MessageEntity` 列表转 `ChatMessage` 列表（OpenAI 格式）
- 负责系统提示词注入（Sentinel prompt）、上下文截断、tool_calls/tool_results JSON 展开、图片 ContentPart 处理
- 处理三种 retention 模式：0=零上下文、正数=手动截断、-1=自动 compact

### ChatManageService
- 会话/消息持久化编排：创建/删除/更新/选择会话
- 消息占位创建、最终化、取消/错误标记
- 所有写操作直接落库

### ChatSupportService
- UI 辅助操作：重命名、模型/哨兵/上下文/温度更新、图片保存、消息折叠
- 是 ViewModel 与 Repository/网络层之间的薄胶水层

---

## 10. ViewModel 详解

### 架构模式：ViewModel + Delegate

ChatViewModel 采用委托模式拆分。当前实现有 3 个 Delegate：

```
ChatViewModel（Signal 唯一持有者 + 编排层，~612 行）
├── AgentStreamDelegate   — Agent 流式交互（~526 行）
├── ChatRenameDelegate    — 自动/手动重命名（~92 行）
└── ChatSelectionDelegate — 多选 UI 交互状态（~99 行）
```

> **注意**：AGENTS.md 此前描述的 `ChatListDelegate` 和 `ChatConfigDelegate` 尚未实现。会话列表 CRUD 和配置更新逻辑当前直接写在 `ChatViewModel` 中。

### AgentStreamDelegate

最复杂的委托（~526 行），封装完整的 sendMessage 流程：准备上下文 → 启动 Agent → 消费流 → 落库。

```dart
class AgentStreamDelegate {
  int? get streamingChatId;
  Future<void>? get settled;

  Stream<AgentStreamEvent> send({
    required MessageEntity message,
    required ChatEntity chat,
  });
  void stop();
}
```

AgentStreamEvent 类型（ViewModel 层事件，与 Agent 层的 AgentEvent 对应）：

| 事件 | 说明 |
|------|------|
| StreamMessageStored | 用户消息已落库 |
| StreamAssistantAppended | Assistant 占位消息已追加 |
| StreamMessageUpdated | 消息内容增量更新 |
| StreamIterationChanged | 迭代轮次变化 |
| StreamToolNameChanged | 当前工具名称变化 |
| StreamUsageChanged | Token 使用量更新 |
| StreamAutoRename | 触发自动重命名 |
| StreamListReload | 触发会话列表刷新 |
| StreamError | 错误事件 |

内部状态（每次 `send` 调用时创建，结束后清理）：`_cancelToken`、`_streamingChatId`、`_settled`、`_skillTrustPrompted`。

依赖：`AgentService`、`ChatManageService`、`ChatMessageService`、`ChatService`、`MessageRepository`、`ModelRepository`、`SentinelRepository`、`ChatSupportService`、`TokenUsageService`、`SettingViewModel`、`PermissionService`、`SkillRegistry`。

### ChatRenameDelegate

```dart
class ChatRenameDelegate {
  Future<ChatEntity?> rename({
    required ChatEntity chat,
    required void Function(String title) onTitle,
  });
  Future<ChatEntity> renameManually({required ChatEntity chat, required String title});
  void cancel(int chatId);
}
```

依赖：`MessageRepository`、`ModelRepository`、`ChatSupportService`。

内部状态：`_tokens: Map<int, CancelToken>`（管理进行中的重命名流，供 deleteChat 取消）。

### ChatSelectionDelegate

```dart
class ChatSelectionDelegate {
  final selectedChatIds = setSignal<int>({});
  final lastSelectedIndex = signal<int?>(null);
  final renamingChatIds = setSignal<int>({});
  final renamingTitle = signal<String>('');

  void clearSelection();
  void toggleChatSelection(int chatId, int index);
  void rangeSelectChats(int endIndex, List<ChatEntity> chats);
  void initLastSelectedIndex(ChatEntity? currentChat, List<ChatEntity> chats);
  void startRenaming(int chatId);
  void stopRenaming(int chatId);
}
```

仅管理 UI 交互状态，不涉及数据访问。

### ChatViewModel 作为编排层

ChatViewModel 不是纯编排层——它直接处理部分 CRUD（createChat、deleteChat、selectChat、updateModel 等），同时将流式和重命名委托出去。

```dart
class ChatViewModel {
  // 全部 Signal（16 个）
  final chats = listSignal<ChatEntity>([]);
  // ...

  // 委托（3 个）
  final AgentStreamDelegate _stream;
  final ChatRenameDelegate _rename;
  final ChatSelectionDelegate _selection;

  // 直接操作（未委托部分）
  Future<ChatEntity?> createChat() { /* ... */ }
  Future<void> deleteChat(ChatEntity chat) { /* ... */ }
  Future<void> selectChat(ChatEntity chat) { /* ... */ }
  Future<void> updateModel(...) { /* ... */ }
  // ...
}
```

流式处理的核心约束由 `AgentStreamDelegate` 统一管理：

1. **取消安全性**：`AgentStreamDelegate._cancelToken` 控制流取消；`ChatViewModel.deleteChat` 通过 `_stream.settled` 等待流完全 settle 后再删除数据
2. **竞态保护**：`ChatRenameDelegate._tokens` 用 CancelToken 防止重命名流在 chat 已被删除后写入
3. **迭代管理**：每轮 tool result 后 `_consumeStream` 最终化上一条 assistant 消息并 append 新占位消息
4. **Skill 信任弹窗**：`AgentStreamDelegate._skillTrustPrompted` 守卫确保每会话只弹一次

### 其他 ViewModel

| ViewModel | 文件 | 说明 |
|-----------|------|------|
| ModelViewModel | `model_view_model.dart` | 管理模型列表、启用/禁用、连接测试 |
| ProviderViewModel | `provider_view_model.dart` | 管理提供商列表、启用/禁用 |
| SentinelViewModel | `sentinel_view_model.dart` | 管理 Sentinel 列表、默认选择、元数据生成 |
| SettingViewModel | `setting_view_model.dart` | 全局设置（默认模型、最大迭代、辅助模型、窗口尺寸等） |
| SummaryViewModel | `summary_view_model.dart` | 网页摘要功能 |
| TranslationViewModel | `translation_view_model.dart` | 翻译功能 |
| TRPGViewModel | `trpg_view_model.dart` | TRPG 游戏功能 |

---

## 11. 设计系统

详见 `DESIGN.md`。关键元素：

### 颜色系统

```dart
// ColorUtil 中定义
FF282828  // 桌面主背景
FF282F32  // 移动端背景 / 对话框背景
FF161616  // 深层容器 / Tag 未选中
FFFFFFFF  // 主文字 / 主按钮
FF6ABEB9  // Athena Teal 品牌色
FFCED2C7  // CTA 光晕基色
FFEAEAEA  // Tag 渐变边框起点
FFE0E0E0  // Tag 选中背景
```

### 核心组件（lib/widget/）

| 组件 | 用途 |
|------|------|
| `AthenaTag` / `AthenaTagButton` | 渐变边框 pill 标签（品牌签名） |
| `AthenaPrimaryButton` | 白色 CTA 按钮，带柔光阴影 |
| `AthenaSecondaryButton` | 透明底 + 灰色描边按钮 |
| `AthenaIconButton` | 白色圆形图标按钮 |
| `AthenaTextButton` | 透明文本按钮 |
| `AthenaInput` | 半透明深色输入框 |
| `AthenaScaffold` | 深色背景页面骨架 |
| `AthenaDialog` | 对话框系统（桌面居中 Dialog / 移动 Bottom Sheet） |
| `AthenaSwitch` | 自定义开关 |

### 桌面布局约定

- 左侧栏宽 240px
- 工作区内边距：horizontal 32, vertical 12
- 结构：导航/列表 → 顶栏 context strip → 主内容区 → 底部 composer

---

## 12. 路由

使用 `auto_route` 包，配置在 `lib/router/router.dart`：

- 桌面端使用 `DesktopRoute(CustomRoute)`，过渡时间为 0（无动画）
- 移动端使用标准 `AutoRoute`，带过渡动画
- 全局 `scaffoldMessengerKey` 用于 SnackBar 显示
- `router.navigatorKey.currentContext` 用于不依赖 Widget 树的全局导航

---

## 13. 测试

### 测试结构（`test/` 目录，约 30 个测试文件）

- `test/agent/` - Agent 层单元测试（工具、权限、Skill）
- `test/service/` - 服务层单元测试（消息转换、聊天服务）
- `test/view_model/` - ViewModel 测试（聊天流、设置、摘要、翻译）
- `test/page/mobile/` - 移动端 widget 测试
- `test/database/` - 数据库迁移和级联行为测试
- `test/widget/` - 自定义 widget 测试
- `test/util/` - 工具函数测试

### 测试模式

- 使用 `test/test_utils/fakes.dart` 中的 Fake Repository（内存实现）
- `setupMobileTestDI()` 注册最小化 DI 依赖，不访问真实数据库
- Widget 测试使用 `Watch` 包裹以支持 Signals
- Agent 层测试直接实例化工具类进行单元测试

### 运行测试

```bash
flutter test                          # 全部测试
flutter test test/agent/tool/         # Agent 工具测试
flutter test test/service/            # 服务层测试
```

---

## 14. 开发约定

### 代码风格

- Dart 3.8+，使用 `flutter_lints` 默认规则
- 分析选项：`analysis_options.yaml`（基于 `flutter_lints/flutter.yaml`）
- 优先使用 `const` 构造函数
- 实体类使用 `copyWith()` 模式
- 变量声明优先使用 `final`，确实需要重新赋值才用 `var`

### 平台检测

使用 `PlatformUtil` 而非直接使用 `dart:io` 的 `Platform`：

```dart
PlatformUtil.isDesktop  // macOS || Linux || Windows
PlatformUtil.isMobile   // iOS || Android
PlatformUtil.isWindows  // 特定平台
```

### 颜色使用

使用 `ColorUtil` 中的预定义常量，不要直接写 `Color(0xFF...)`。

### 对话框

桌面端使用 `AthenaDialog` 静态方法或 `showDialog()`，移动端使用 `showModalBottomSheet()`。平台判断已封装在 `AthenaDialog` 内部。

### 消息提示

使用 `AthenaDialog.message()` / `.info()` / `.success()` / `.warning()` / `.error()`，桌面端显示 Overlay 消息（3 秒自动消失），移动端显示 SnackBar。

---

## 15. 重要约束与注意事项

1. **DI 初始化顺序**：Repository → Service → Agent → ViewModel Delegate → ViewModel，ChatViewModel 必须在 AgentService 和 SkillRegistry 注册之后

2. **数据库单例**：`Database.instance` 是全局单例，所有 Repository 直接访问 `.instance.laconic`

3. **外键级联**：`PRAGMA foreign_keys = ON` 在所有迁移之后执行（确保孤儿数据已清理）

4. **OpenAI Client 生命周期**：每次 API 调用创建新的 `OpenAIClient`，`finally` 块中 `close()`

5. **流取消**：`CancelToken.throwIfCancelled()` 在流的多个关键点调用，确保取消即时响应

6. **消息持久化时机**：流式过程中 assistant 消息逐段累积更新（reasoning/content/toolCalls/toolResults），流结束后调用 `finalizeAssistantMessage()` 最终落库

7. **上下文截断**：`chat.retention` 为 0 时仅保留最后一条用户消息；正数时保留对应轮数；-1 时由 compact 自动管理

8. **移动端工具精简**：移动端仅注册 WebFetchTool、WebSearchTool、SkillTool 三个工具

9. **预设数据完全走 migration 机制**：首次安装由 `migration_202606240005_seed_presets` 插入初始数据（provider/model/sentinel）；后续每次修改预设数据都新增一条幂等 migration，不再使用独立的 preset 数据文件

10. **权限弹窗不可绕过**：`showPermissionDialog()` 设置 `barrierDismissible: false` / `isDismissible: false`

11. **Token 写入**：`ChatRepository.updateChat()` 显式排除 `token_total`、`context_tokens`、`cached_tokens`，这些值由独立的增量写入路径（`recordUsage`）管理，防止并发覆盖

---

## 16. 常见任务模式

### 添加新工具

1. 创建 `lib/agent/tool/xxx_tool.dart`，实现 `Tool` 接口
2. 在 `lib/di.dart` 的 `ToolRegistry` 注册中添加到合适的平台列表
3. 如需权限控制，在 `PermissionService._primaryArg()` 和 `PermissionRule._isFilePathTool()` 中添加模式
4. 添加单元测试 `test/agent/tool/xxx_tool_test.dart`

### 添加新 Entity

1. 创建 `lib/entity/xxx_entity.dart`（包含 fromJson/toJson/copyWith）
2. 创建 `lib/repository/xxx_repository.dart`
3. 创建数据库迁移 `lib/database/migration/migration_YYYYMMDD001_xxx.dart`
4. 在 `lib/database/database.dart` 的 `_migrate()` 中添加迁移调用
5. 在 `lib/di.dart` 中注册 Repository LazySingleton

### 添加新 Service

1. 创建 Service 类，通过构造函数注入依赖的 Repository
2. 在 `lib/di.dart` 中注册为 LazySingleton
3. 如需在 ViewModel 中使用，在 ViewModel 构造函数中注入

### 修改预设数据（Provider / Model / Sentinel）

1. 修改数据（新增模型、更新定价/上下文窗口、新增/废弃提供商、更新 Sentinel prompt 等）
2. 创建数据库迁移 `lib/database/migration/migration_YYYYMMDD001_xxx.dart`
3. 在 `lib/database/database.dart` 的 `_migrate()` 中注册迁移（**排在 seed migration 之后**）
4. 迁移规则：
   - **幂等**：INSERT 使用 `WHERE NOT EXISTS` 防重复；UPDATE 无条件执行
   - **不删除**：废弃 preset 条目时用 `UPDATE ... SET is_preset = 0`，保留数据供已有 chat 引用
   - **保留用户字段**：provider 的 `api_key`、`enabled` 不覆盖
   - **模型关联**：新增模型时通过 provider name 查找正确的 `provider_id`
5. 无论新安装还是老用户升级，迁移都必须能正确处理（幂等保证）
6. 添加单元测试 `test/database/migration/xxx_test.dart`

### 修改设计系统组件

1. 所有组件在 `lib/widget/` 目录
2. 颜色从 `ColorUtil` 获取，不要硬编码
3. 遵循 `DESIGN.md` 中的组件规范（Tag 渐变边框、CTA 光晕等）
4. 确保桌面和移动端视觉一致（弹窗形式可不同，但视觉语言一致）

---

## 17. 依赖包说明

| 包 | 用途 |
|----|------|
| `openai_dart` v5.0.0 | OpenAI API 客户端（流式 + 工具调用 + 推理） |
| `signals` / `signals_flutter` v6.2.0 | 响应式状态管理 |
| `get_it` v8.0.3 | 依赖注入 |
| `auto_route` v9.2.2 | 路由管理 + 代码生成 |
| `laconic` / `laconic_sqlite` | SQLite ORM（非 sqlite3 原生绑定） |
| `yaml` v3.1.2 | Skill 文件 YAML Front Matter 解析 |
| `hugeicons` | 图标库 |
| `google_fonts` | 等宽字体（Fira Code） |
| `flutter_markdown` + `gpt_markdown` | Markdown 渲染 |
| `window_manager` + `tray_manager` | 桌面窗口和系统托盘 |
| `http` v1.x | web_fetch/web_search 的 HTTP 客户端 |
| `process` v5.0.3 | Shell 工具进程管理 |
| `shared_preferences` | 用户设置持久化 |
| `file_picker` | 数据导入文件选择 |

---

## 18. 版本信息

- 当前版本：3.3.0+732
- Flutter SDK：>= 3.8.0
- Dart SDK：>= 3.8.0
- 平台：iOS / Android / macOS / Windows / Linux
