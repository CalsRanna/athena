# AGENTS.md - Athena 项目编码指南

本文档面向在此项目中工作的 AI Coding Agent，提供项目架构、编码规范、重要约束和常见操作模式的完整说明。

---

## 1. 项目概览

Athena 是一个跨平台（桌面 + 移动）AI Agent 应用，使用 Flutter 构建。核心能力包括：

- **完整 Agent 循环**：推理 -> 工具调用 -> 结果 -> 再推理（最大 100 轮可配置），支持**并行工具执行**
- **Monorepo 三包结构**：`athena_core`（纯 Dart Agent 引擎，零 Flutter / 零 SQL）+ `athena_gui`（Flutter 桌面/移动应用，含 GUI 专有业务：TRPG/翻译/摘要/Shortcut/Sentinel 表单生成/数据迁移）+ `athena_tui`（nocterm 终端客户端），依赖方向严格单向 `gui/tui → core`，三个客户端共用同一套 Agent 引擎
- **内置工具系统**：桌面端注册 14 个工具、移动端 10 个，带危险等级（readOnly/dangerous）与执行模式（串行/并行）
- **Skill 系统**：Claude Code 风格三级渐进式加载（Level 1/2/3），用户级存储（`~/.athena/skills/`）
- **三层权限模型**：只读短路 → 会话级缓存 → 用户持久化规则 + 审批弹窗
- **Agent 自我进化**：Skill 创建/更新、经验学习/回忆、失败反思、Sentinel 系统提示词优化
- **Shortcut 快捷入口系统**：绑定额外 Sentinel 的一等公民实体，支持场景级 JSON 输出模式
- **自动上下文压缩**：上下文占用超过窗口 80% 时自动将早期对话压缩为摘要（`retention == -1`）
- **模型目录同步**：启动时后台从 models.dev 同步预设 provider 的模型元数据（7 天 TTL 缓存）
- **多模型提供商**：OpenAI API 兼容，预设 DeepSeek、OpenRouter、阿里云百炼、硅基流动、火山方舟、智谱、MiniMax

---

## 2. 仓库结构（Monorepo）

```
athena/
├── AGENTS.md / README.md / DESIGN.md
├── .github/workflows/          # ci + release（tag v* 触发的三平台构建）
└── packages/
    ├── athena_core/             # ★ 纯 Dart 核心（零 Flutter / 零 SQL 依赖）
    │   ├── lib/
    │   │   ├── agent/
    │   │   │   ├── agent_service.dart        # 核心 Agent 循环 + AgentEvent sealed class
    │   │   │   ├── cancel_token.dart         # 取消令牌
    │   │   │   ├── evolution/                # 自我进化提示词（hint + fullBody）
    │   │   │   ├── permission/               # permission_service / permission_rule / command_analyzer
    │   │   │   ├── skill/                    # skill_loader / skill_registry
    │   │   │   └── tool/                     # 13 个工具 + tool_interface + tool_registry + schema_validator + shell_runner + html_to_markdown
    │   │   ├── coordinator/
    │   │   │   ├── agent_run_coordinator.dart # AgentRunCoordinator：UI 无关的 run 编排层
    │   │   │   └── run_event.dart             # RunEvent sealed class（纯数据事件流）
    │   │   ├── entity/          # 8 个实体（纯数据类，含 TokenUsage）
    │   │   ├── preset/          # prompt.dart（运行时模板，非 DB 种子）
    │   │   ├── repository/      # 7 个存储接口（抽象，GUI 用 SQLite 实现）
    │   │   ├── service/         # LlmClient / ChatCompletions / ChatStore / ChatMessageConverter / ChatUpdate / ModelCatalog 等
    │   │   ├── storage/         # KeyValueStore 接口 + AgentSettings
    │   │   ├── extension/       # json_map_extension
    │   │   └── util/            # platform_util / retry / logger_util / tool_args_formatter
    │   └── test/                # dart test（Agent 引擎 / 工具 / 权限 / Skill / 服务）
    ├── athena_gui/              # ★ Flutter 桌面/移动应用
    │   ├── lib/
    │   │   ├── main.dart        # 入口：DB 初始化 → Window/Tray → DI → 后台同步模型目录
    │   │   ├── di.dart          # GetIt 装配层（唯一依赖注入点）
    │   │   ├── database/        # SQLite + Laconic ORM + 26 个迁移
    │   │   ├── repository/      # 8 个 SqliteXxxRepository（引擎接口的 SQLite 实现）+ GUI 业务接口（shortcut/trpg）
    │   │   ├── storage/         # SharedPrefsKeyValueStore（KeyValueStore 实现）
    │   │   ├── view_model/      # 9 个 ViewModel（Signals）+ delegate/（3 个委托）
    │   │   ├── page/            # desktop/（多区工作台 + 设置）+ mobile/（分段浏览）
    │   │   ├── router/          # auto_route 配置 + 生成代码 router.gr.dart
    │   │   ├── widget/          # 设计系统组件（20+）
    │   │   ├── component/       # 业务组件（消息列表项、工具卡片等）
    │   │   └── util/            # color_util / window_util / system_tray_util / shared_preference_util
    │   └── test/                # flutter test（页面 / ViewModel / 数据库迁移）
    └── athena_tui/              # nocterm 终端客户端
        ├── bin/athena.dart      # CLI 入口
        ├── lib/
        │   ├── bridge/          # tui_agent_bridge.dart（Agent 引擎 → TUI 状态桥）
        │   ├── di/              # tui_di.dart（GetIt 手动装配）
        │   ├── seed/            # sentinel_seed.dart（首次运行植入）
        │   ├── storage/         # JSONL/JSON 文件存储（会话 / 模型 / 角色）
        │   ├── ui/              # nocterm 终端组件
        │   └── view_model/      # 终端响应式层
        └── test/
```

> 根目录无 pubspec；三个 package 各自独立 `pub get`。

---

## 3. 分层架构与数据流

```
UI Layer (page/widget/component)
    ↓ 读取 Signal / 调用 ViewModel 方法
ViewModel Layer (signals 响应式 + 业务逻辑 + UI 状态)
    ↓ 编排调用（委托）
Coordinator Layer (athena_core/coordinator)  ← AgentRunCoordinator：UI 无关的 run 编排
    ↓ 消费/驱动
Service Layer (chat_completions_service / chat_store_service / chat_message_converter / ...)
    ↓ 调用 Repository 接口
Repository Layer (引擎存储接口在 athena_core，实现为 athena_gui 的 SqliteXxxRepository；GUI 业务接口如 shortcut/trpg 随业务在 athena_gui)
    ↓ 直接访问 Database.instance.laconic
Data Layer (Entity / Database / Migration)
```

Agent 层横向穿透各层：AgentService 调用 ChatCompletionsService（网络）、ToolRegistry（工具）、SkillRegistry（技能）。

**核心解耦原则**：athena_core 通过**存储接口**（`repository/` 抽象类）与**注入回调**（权限审批 `PermissionPrompt`）与持久化策略/UI 解耦。GUI 用 SQLite + SharedPreferences；TUI 已实现同一组接口的 JSONL/JSON 文件存储（`athena_tui/lib/storage/`，如 `jsonl_session_repository.dart`）。**athena_core 中严禁出现 Flutter 或 SQL 依赖**（`flutter_lints` 与代码评审共同保证）。

**athena_core 准入标准**（判定"新代码放 core 还是 GUI"）：文件必须满足"TUI 也会用"或"属于 Agent 引擎/领域模型/存储接口"之一；GUI 专有业务（TRPG/翻译/摘要/Shortcut/Sentinel 名称描述生成/数据导入导出/模型字段展示兼容等）一律放 athena_gui。引擎与 GUI 共享的提示词常量可以留在 core（如 `preset/prompt.dart`），但纯 GUI 业务提示词随业务文件走。

---

## 4. 依赖注入（DI）

`packages/athena_gui/lib/di.dart` 通过 `GetIt.instance` 按以下顺序注册：

1. **Repository**（9 个 LazySingleton：8 个 Sqlite 实现 + ExperienceRepository）
2. **Service**（LlmClient → ChatCompletionsService / ChatMessageConverter / ChatStoreService / ChatUpdateService / SentinelService / SummaryService / TranslationService / TRPGService / DataMigrationService / ModelCatalogService）
3. **ViewModel Delegate**（ChatRenameDelegate、AgentStreamDelegate——后者通过 `AgentServiceCoordinatorDeps` 聚合 12 个依赖注入 AgentRunCoordinator）
4. **ViewModel**（ModelViewModel、SentinelViewModel、SettingViewModel、ProviderViewModel、ShortcutViewModel、ModelResolver、SummaryViewModel、TranslationViewModel、TRPGViewModel）
5. **Agent 栈**（PermissionStore → PermissionService → KeyValueStore(SharedPrefs) → AgentSettings → SkillRegistry(loadAll + 注册内置 self-evolve) → ToolRegistry(按平台注册工具) → AgentService）
6. **ChatViewModel**（最后注册，依赖最多）

> 所有注册使用 `registerLazySingleton`（首次访问时才实例化），声明顺序不影响运行时依赖解析。**注意**：DI 是 GUI 独有的装配层——athena_core 无任何 GetIt 引用，测试中构造服务时直接 `new` 并注入 Fake Repository。

---

## 5. 状态管理（Signals）

项目使用 `signals` 包（v6.2.0），核心概念：

- `signal<T>(initialValue)` - 可读写响应式值
- `listSignal<T>([])` - 响应式列表
- `computed(() => ...)` - 派生信号
- `Watch((context) { ... })` - Flutter Widget 中自动订阅信号变化
- `athena_gui` 提供 `list_signal_extension.dart`：`replaceWhere` 等便捷方法（ViewModel 消息/会话更新使用）

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
final currentRetention = signal(defaultDraftRetention);   // -1 = 自动管理
final currentTemperature = signal(defaultDraftTemperature); // 1.0
final currentIteration = signal(0);
final currentToolName = signal<String?>(null);
final currentTokenUsage = signal<TokenUsage?>(null);
final cumulativeTokenTotal = signal(0);
final pendingImages = listSignal<String>([]);
// Computed
final recentChats = computed(() => chats.value.take(10).toList());
final pinnedChats = computed(() => chats.value.where((c) => c.pinned).toList());
```

**关键模式**：更新列表信号时，不要在原有列表上直接修改，而是创建新列表再赋值（或使用 `replaceWhere` 扩展）：

```dart
// 正确
messages.value = [...messages.value, newMessage];
// 错误 - 不会触发信号更新
messages.value.add(newMessage);
```

---

## 6. 数据库

- **引擎**：SQLite，通过 `laconic` + `laconic_sqlite` 包访问（非 sqlite3 原生绑定）
- **路径**：`{app_support_dir}/athena.db`
- **初始化**：`Database.instance.ensureInitialized()` 在 `main()` 中调用
- **外键**：迁移全部完成后执行 `PRAGMA foreign_keys = ON`（确保孤儿数据已清理）
- **迁移**：按时间顺序执行（当前 26 个），每个迁移通过 `migrations` 表判断是否已执行；预设数据用独立 marker（如 `preset_shortcuts_v1`）控制只插入一次
- **重置**：`Database.instance.reset()` DROP 所有表（不含 `sqlite_%`）后重新迁移+预设

实体类模式：所有 Entity 实现 `fromJson(Map)`、`toJson()`、`copyWith(...)`；布尔值存储为 0/1。

---

## 7. Agent 系统详解

### 7.1 Agent 循环流程

`AgentService.run()` 是核心，返回 `Stream<AgentEvent>`：

1. **双层循环**：内层是工具调用迭代（`maxIterations` 轮，默认 100，来自 `AgentSettings.maxAgentIterations`）；外层检查 `_followUpQueue`——有 followUp 消息则注入并重启内层循环
2. 每轮迭代开始注入 `EvolutionPrompt.hint`（~30 token）；`_steerQueue` 中的 steering 消息在当前轮工具执行完后、下一轮 LLM 调用前插入
3. 通过 `ChatCompletionsService.getCompletion()` 流式获取模型响应（`streamOptions.includeUsage: true`）
4. 流式解析 text / reasoning / tool_calls（**工具卡片实时产出**：id+name 齐备即发 `AgentToolCallEvent`，后续参数分片发 `AgentToolCallArgsEvent`）
5. 流结束后检查 tool calls：
   - 无 tool call → `AgentDoneEvent`，结束
   - 有 tool call → 先做**截断保护**：`finishReason == length`（输出被 token 限制切断）时拒绝执行所有工具并提示重新调用
6. **串行 + 并行混合执行**：`selectParallelCalls()` 预检分级——参数可解析、工具存在、`canExecuteParallel(args)` 且权限预检通过（`check() == true`，即不需要弹窗）的调用进并行组，其余进串行组。并行组用信号量限流（最多 8 个并发），`Future.any` 优先响应取消信号，结果渐进式产出
7. 每个工具调用前先发 `AgentToolExecutionStartEvent`；执行流程：JSON 参数解析 → `SchemaValidator` 参数校验 → `beforeToolCall` hook → 权限检查 → 执行 → `afterToolCall` hook → `smartTruncate`（超 12000 字符保留头尾截断中间）
8. 工具结果消息加入消息列表，进入下一轮迭代；`jsonMode` 时请求携带 `responseFormat: ResponseFormat.jsonObject()`

### 7.2 AgentEvent 类型

```dart
sealed class AgentEvent {
  AgentTextEvent               // 文本 delta（流式）
  AgentReasoningEvent          // 推理过程 delta（流式）
  AgentToolCallEvent           // 工具调用声明（id+name 齐备即产出，arguments 为首片）
  AgentToolCallArgsEvent       // 工具调用参数增量（按 id 追加）
  AgentToolResultEvent         // 工具执行结果（id/name/result）
  AgentIterationCompleteEvent  // 一轮迭代完成（含全部 toolCalls 记录）
  AgentDoneEvent               // Agent 完成（最终 content）
  AgentTurnStartEvent          // 每轮迭代开始
  AgentToolExecutionStartEvent // 单个工具开始执行（串行/并行均发）
  AgentToolExecutionUpdateEvent// 工具部分结果进度（预留，shell 实时 stdout）
  AgentUsageEvent              // Token 使用量统计
  AgentRunOutcomeEvent         // 结构化终止原因、迭代数与工具失败证据
}
```

### 7.3 工具系统

`Tool` 抽象接口（`tool_interface.dart`）：

```dart
abstract class Tool {
  String get name;
  String get description;
  Map<String, dynamic> get parameters; // JSON Schema

  ExecutionMode get executionMode => ExecutionMode.sequential;
  bool canExecuteParallel(Map<String, dynamic> args) =>
      executionMode == ExecutionMode.parallel;
  ToolRisk get risk => ToolRisk.dangerous; // 默认保守

  Future<String> execute(Map<String, dynamic> args,
      {void Function(String partialResult)? onUpdate});
}

enum ExecutionMode { sequential, parallel }
enum ToolRisk { readOnly, dangerous }
```

- `ToolRegistry` 管理所有工具：`registerAll()`、`get()`、`definitions`（OpenAI tool definitions）
- `SchemaValidator.validate(parameters, args)` 在工具执行前做 JSON Schema 参数校验
- 桌面端注册 14 个工具（bash 与 powershell 按操作系统互斥），移动端注册 10 个（无本地文件与进程工具）
- 注册在 `di.dart` 的 ToolRegistry 工厂中按 `PlatformUtil.isMobile` 分支完成

工具实现文件（`packages/athena_core/lib/agent/tool/`）：

| 文件 | 工具类 | 风险/模式 | 说明 |
|------|--------|----------|------|
| `bash_shell_tool.dart` | BashShellTool | dangerous/串行 | Linux/macOS Shell 命令，超时默认上限 3600s（`ATHENA_SHELL_MAX_TIMEOUT` 可覆盖），超时 SIGTERM→SIGKILL |
| `powershell_shell_tool.dart` | PowerShellShellTool | dangerous/串行 | Windows PowerShell 命令 |
| `file_read_tool.dart` | FileReadTool | **readOnly/并行** | 文件读取，offset/limit 分页 + 行号 |
| `file_write_tool.dart` | FileWriteTool | dangerous/串行 | 创建/覆写，递归建父目录 |
| `file_update_tool.dart` | FileUpdateTool | dangerous/串行 | 精确字符串替换，mtime 外部修改检测，replace_all、行号前缀剥离 |
| `web_fetch_tool.dart` | WebFetchTool | **readOnly/并行** | HTTP GET/POST（200KB 上限，仅 http/https），HTML→Markdown |
| `web_search_tool.dart` | WebSearchTool | **readOnly/并行** | Brave Search API（API key 存 KeyValueStore，key: `brave_api_key`） |
| `skill_tool.dart` | SkillTool | dangerous/串行 | 加载 Skill Level 2 指令，校验 allowed-tools |
| `skill_evolve_tool.dart` | SkillEvolveTool | dangerous/串行 | 创建/更新 Skill（SKILL.md） |
| `experience_learn_tool.dart` | ExperienceLearnTool | dangerous/串行 | 经验学习（`~/.athena/experiences/`，Sentinel 私有或共享） |
| `experience_learn_tool.dart` | ExperienceRecallTool | **readOnly/串行** | 经验检索 |
| `sentinel_list_tool.dart` | SentinelListTool | **readOnly/串行** | 列出 Sentinel 摘要 |
| `sentinel_get_tool.dart` | SentinelGetTool | **readOnly/串行** | 获取 Sentinel 完整配置 |
| `sentinel_evolve_tool.dart` | SentinelEvolveTool | dangerous/串行 | 改进 Sentinel 提示词（内置 Sentinel 不可改名），onChanged 回调刷新列表 |
| `sentinel_revert_tool.dart` | SentinelRevertTool | dangerous/串行 | 从本地快照回滚 Sentinel |
| `shell_runner.dart` | (辅助) | - | Shell 进程启动/管理（超时、kill） |
| `html_to_markdown.dart` | (辅助) | - | HTML 转 Markdown |
| `schema_validator.dart` | (辅助) | - | JSON Schema 参数校验（类型/必填/枚举/数值范围） |

### 7.4 权限系统

`PermissionService.check()` 三层判定（返回 `true` = 放行，`null` = 需要弹窗）：

1. **readOnly 短路**：工具 `risk == readOnly` 永不弹窗；shell 工具中只读命令（`CommandAnalyzer.isReadOnlyCommand`：ls、git status 等）也不弹窗
2. **会话级缓存**：当前 run 内已批准的调用直接放行（`approveForSession`，run 开始时 `resetSession()`）
3. **持久化规则**：`~/.athena/permissions.json` 中的 `PermissionRule`（tool + action + pattern，支持 `*`/`?` 通配符，无通配符时按前缀匹配）命中则放行

未命中 → 调用方通过 `PermissionPrompt` 回调弹窗（GUI 对话框 / TUI stdin 输入）。用户选择：
- **Allow**：写会话级缓存（同一 run 内不再弹）
- **Always Allow**：持久化规则——shell 命令用 `CommandAnalyzer.parseRulePattern` 解析为 **动作级规则**（action=git, pattern=push*），非 shell 存 keyArg（文件路径 / URL origin）
- 弹窗不可被空白点击关闭（`barrierDismissible: false`）

工具自我保护（在工具 `execute()` 内部，独立于权限系统）：
- bash/powershell：递归删除命令（rm -rf 变体 / del /s）被检测到拒绝执行
- file_update：写入前校验文件 mtime，防止覆盖外部并发修改
- web_fetch：仅允许 http/https scheme

### 7.5 Skill 系统

三级渐进式加载：

| Level | 内容 | 加载时机 |
|-------|------|---------|
| 1 | name + description（最多最近使用的 20 个，按访问时间排序） | `SkillRegistry.level1Prompt` 已实现，**但当前 run 流程未注入**（AgentRunCoordinator 只注入 sentinel prompt + evolution hint） |
| 2 | SKILL.md 完整指令 | Agent 调用 `skill("name")` 时按需加载 |
| 3 | scripts/references 等资源 | Level 2 指令引用时加载 |

Skill 文件格式（YAML front matter + Markdown body）：

```markdown
---
name: my-skill
description: What this skill does and when to use it
allowed-tools: file_read, web_search
disable-model-invocation: false
---
## Process
1. Step one
```

放置位置：
- `~/.athena/skills/` - 用户级（移动端为应用沙盒内目录），对所有对话可用
- 内置 `self-evolve` Skill（代码注册，`sourcePath: '(builtin)'`）提供完整的自我进化指导
- Skill 指令会注入系统提示词，但工具调用仍需经过权限检查

### 7.6 自我进化

- **Sentinel 优化**（`sentinel_evolve`）：基于使用反馈优化系统提示词
- **Skill Evolution**（`skill_evolve`）：创建/改进 Skill 扩展能力
- **Experience Learning**（`experience_learn` / `experience_recall`）：长期经验记忆（`~/.athena/experiences/`），写入走 dangerous 权限审批，支持 update/archive、Sentinel 私有或全局共享
- **Failure Reflection**：最大迭代或同工具重复失败时生成候选经验，并转成标准 `experience_learn` 调用复用原参数校验、权限审批和执行路径
- **Memory Digest**：每次顶层 send 临时注入当前 Sentinel 可见的全部 active lesson；目录不依赖当前任务，经验库不变时内容逐字稳定，context/tags 由 `experience_recall` 按需读取
- 每次 run 自动注入 `EvolutionPrompt.hint`（~30 token）；完整指南在 `EvolutionPrompt.fullBody`，作为 self-evolve Skill 按需加载

### 7.7 Shortcut 系统（v3.4.4 新增）

- `Shortcut`（`athena_gui/lib/model/shortcut.dart`）：name/description/icon/pageTarget/sentinelId；绑定一个 `is_preset` 的专属 Sentinel
- 迁移 `202608040001_create_shortcuts` + `202608040002_seed_shortcuts` 播种 5 个内置 Shortcut（Translation/Summary/Food/Code/TRPG），每个带专属 preset Sentinel
- 点击 Shortcut → 以其绑定 Sentinel 身份发起 run，`jsonMode: true`（ResponseFormat jsonObject）用于场景页
- `pageTarget` 通过 `ShortcutPageRegistry`（纯查找表，非插件机制）映射到移动端路由（translation/summary/trpg；Food/Code 无目标页走默认聊天页）

---

## 8. Coordinator 层（run 编排）

`AgentRunCoordinator`（athena_core，UI 无关）是 **AgentStreamDelegate 的实际实现体**。职责：

1. 用户消息落库 → 2. 自动重命名触发判断（首条用户消息）→ 3. 解析 model/provider/sentinel → 4. 构建上下文（`ChatMessageConverter.buildMessages`）→ 5. **自动压缩**（`retention == -1` 且 `contextTokens/contextWindow > 80%` 时：前 60% 消息由辅助模型压缩为 system summary 消息，原消息 `markAsCompacted`，压缩失败降级全量）→ 6. 追加 assistant 占位消息 → 7. 启动 AgentService.run → 8. 消费事件流落库 → 9. 用量 `recordUsage` + 刷新会话 → 10. 收尾/取消/错误落库

产出 `RunEvent` 纯数据流（无 UI 类型）：

```dart
sealed class RunEvent {
  RunMessageStored      // 用户消息已落库
  RunAssistantAppended  // Assistant 占位消息已追加（含新迭代消息）
  RunMessageUpdated     // 消息增量更新
  RunIterationChanged   // 迭代轮次变化
  RunToolNameChanged    // 当前工具名称变化
  RunUsageChanged       // Token 使用量 + 最新 ChatEntity
  RunOutcomeChanged     // 结构化运行结果（completed/maxIterations/cancelled/error）
  RunAutoRename         // 触发自动重命名
  RunListReload         // 触发会话列表刷新
  RunError              // 错误
}
```

关键实现细节：
- **思考卡片展开状态保留**：`updateExpanded(messageId, expanded)` 记录用户展开选择，`_consumeStream` 的 copyWith 链应用 override，防止流式增量把刚展开的卡片重新折叠
- **迭代切换**：`AgentToolResultEvent` 后 `hasCompletedIteration = true`，下一条 text/reasoning 事件触发 `beginNewIteration()`——finalize 上一条消息、追加新占位、清空 buffer；新消息通过 `RunAssistantAppended` 先入 UI 列表，否则 `RunMessageUpdated` 的 replaceWhere 找不到目标会丢弃更新
- **取消**：`CancelledException` 在内部捕获并落库（`recordCancelledOnMessage`，标记 `[Cancelled]`），流正常结束不向外抛
- **错误**：`recordErrorOnMessage` 把错误写进消息内容，再发 `RunError`

GUI 侧 `AgentStreamDelegate` 只是薄桥：通过 `AgentServiceCoordinatorDeps`（11 个依赖）构造 Coordinator，注入 `showPermissionDialog` 实现，事件原样转发。权限弹窗与取消令牌用 `Future.any` 竞速——取消时自动 pop 对话框。

---

## 9. 实体与数据模型

| Entity | 关键字段 | 说明 |
|--------|---------|------|
| ChatEntity | title, modelId, sentinelId, temperature, retention, pinned, tokenTotal, contextTokens, cachedTokens, createdAt, updatedAt | 聊天会话 |
| ChatHistoryEntity | chat, lastMessageContent | 会话列表项（含最后消息） |
| MessageEntity | chatId, role, content, reasoningContent, reasoning, expanded, imageUrls, reference, toolCalls, toolResults, compacted, reasoningStartedAt, reasoningUpdatedAt | 聊天消息（toolCalls/toolResults 为 JSON 字符串） |
| ModelEntity | name, modelId, providerId, reasoning, vision, contextWindow, isPreset | AI 模型 |
| ProviderEntity | name, baseUrl, apiKey, enabled, isPreset | AI 提供商 |
| SentinelEntity | name, avatar, description, prompt, tags, isPreset | Agent 角色 |
| ExperienceEntity | name, description, tags, context, scope | Agent 经验记忆 |
| TranslationEntity | source, sourceLang, targetLang, result | 翻译记录 |
| SummaryEntity | url, content, summary, modelId | 网页摘要记录 |
| TRPGGameEntity | name, systemPrompt, modelId | TRPG 游戏 |
| TRPGMessageEntity | gameId, role, content, suggestions | TRPG 消息 |
| Shortcut（在 `model/` 而非 `entity/`） | name, description, icon, pageTarget, sentinelId | 快捷入口 |

所有实体使用 `copyWith()` 进行不可变更新；布尔值存储为 0/1。`MessageEntity.toolCalls` / `toolResults` 是 JSON 编码字符串，转换在 `ChatMessageConverter._convertMessages` 展开为 OpenAI `ToolCall` / tool 消息。

---

## 10. 服务层详解

### 服务概览

| 服务 | 文件 | 职责 |
|------|------|------|
| LlmClient | `service/llm_client.dart` | 统一 LLM API 客户端：每次调用创建 OpenAIClient → 请求 → `close()`；内建重试（`retry()` / `retryStream()`，指数退避 + 随机抖动） |
| ChatCompletionsService | `service/chat_completions_service.dart` | AI 网络请求：`getCompletion()`（流式，含 includeUsage）、`complete()`（非流式，辅助模型摘要用）、`connect()`（测试连接）、`getTitle()`（标题生成） |
| ChatMessageConverter | `service/chat_message_converter.dart` | Entity → OpenAI ChatMessage 转换、system prompt 注入、tool_calls/tool_results 展开、图片 ContentPart（base64）、retention 处理 |
| ChatStoreService | `service/chat_store_service.dart` | 会话/消息持久化编排：CRUD、占位消息、finalize、`recordCancelledOnMessage`、`recordErrorOnMessage`、`deleteMessagesFromIndex` |
| ChatUpdateService | `service/chat_update_service.dart` | UI 辅助：重命名、模型/哨兵/上下文/温度更新、图片保存、`getProviderForModel`、`updateExpanded` 落库 |
| DataMigrationService | `service/data_migration_service.dart` | 数据导入/导出（JSON）、数据库重置、悬空引用重整 |
| ModelResolver | `service/model_resolver.dart` | 模型/Provider 解析 + fallback（优先指定模型 → 回退第一个可用） |
| ModelCatalogService | `service/model_catalog_service.dart` | 从 models.dev/api.json 同步模型元数据（TTL 7 天缓存、失败降级缓存、只删除未被 chat 引用的 preset 模型） |
| SentinelService | `service/sentinel_service.dart` | Sentinel 元数据 AI 生成 |
| SummaryService / TranslationService / TRPGService | 各自文件 | 网页摘要 / 翻译 / TRPG（均走 LlmClient） |

### Retention 语义（ChatMessageConverter + Coordinator）

- `retention == 0`：零上下文模式，只携带最后一条用户消息（+ sentinel prompt）
- `retention == -1`：自动管理——返回全部消息，Coordinator 在占用 >80% 窗口时自动 compact
- `retention > 0`：当前实现**不截断**，返回全部消息（旧的手动轮数截断已移除，正数语义等同全量）

### Token 用量

`ChatRepository.recordUsage(chatId, total, prompt, cached)` 独立增量写入路径；`ChatRepository.updateChat()` 显式排除 `token_total` / `context_tokens` / `cached_tokens` 字段，防止并发覆盖。旧的 TokenUsageService 已移除。

---

## 11. ViewModel 与 Delegate

### 架构模式：ViewModel + Delegate

```
ChatViewModel（Signal 唯一持有者 + 编排层）
├── AgentStreamDelegate    — 薄桥包装 AgentRunCoordinator（真实逻辑在 core）
├── ChatRenameDelegate     — 自动/手动重命名（CancelToken 防写入已删会话）
└── ChatSelectionDelegate  — 多选/重命名 UI 交互状态（纯信号，无数据访问）
```

### ChatViewModel 直接操作（未委托部分）

`createChat` / `deleteChat` / `deleteChats` / `selectChat` / `togglePin` / `updateModel` / `updateSentinel` / `updateRetention` / `updateTemperature` / `updateExpanded` / `sendMessage` / `stopGenerating` / `deleteMessage` / `renameChat` / `exportImage` / `addPendingImage` / `prepareNewChatDraft` / `_syncDraftDefaults` 等。

流式约束：
1. **取消安全性**：`AgentStreamDelegate.settled`（实为 `AgentService.settled`）等待流完全 settle 后再删除数据
2. **竞态保护**：`ChatRenameDelegate._tokens` 用 CancelToken 防止重命名流在 chat 删除后写入

### 其他 ViewModel

| ViewModel | 说明 |
|-----------|------|
| ModelViewModel | 模型列表、启用/禁用、连接测试 |
| ProviderViewModel | 提供商列表、启用/禁用 |
| SentinelViewModel | Sentinel 列表、默认选择、元数据生成 |
| SettingViewModel | 全局设置（默认模型、最大迭代、辅助模型、窗口尺寸、数据迁移） |
| ShortcutViewModel | Shortcut 列表 CRUD（v3.4.4 新增） |
| SummaryViewModel / TranslationViewModel | 摘要 / 翻译功能（可注入 agentService） |
| TRPGViewModel | TRPG 游戏功能 |

---

## 12. 设计系统

详见 `DESIGN.md`。关键元素：

### 颜色系统

品牌语义色定义在 `athena_gui/lib/theme/athena_colors.dart`：

```dart
// AthenaColors extends ThemeExtension，挂载于 ThemeData.extensions
surface          // 桌面主背景
surfaceMobile    // 移动端背景 / 对话框 / sheet
surfaceDeep      // 深层容器 / Tag 未选中内层
surfaceRaised    // 白卡 / 白色按钮底（深浅同值）
textPrimary      // 主文字 / 关键图标
textInput        // 输入框文字
textSecondary    // 次级辅助文字
textWeak         // 弱文字 / 时间戳
textOnRaised     // 白卡 / 白按钮上的深色文字（深浅同值）
textSelected     // 选中态文字（Tag 选中反转）
border / borderStrong / divider / inputBackground
teal / sage / slate / ctaGlow
tagBorderStart / tagSelectedBackground / cardHeader / codeBackground
checkboxOff / iconSecondary / iconOnRaised
cardPrimaryBackground / cardPrimaryText
```

字段按**语义角色**划分（一个角色一个字段，避免一个色值多角色冲突）。
深/浅两套值（`AthenaColors.dark` / `AthenaColors.light`），浅色值从现有 token
按角色推导（灰阶镜像 / 透明度变体），不新增品牌色。主题切换入口在
设置 → Advanced → Appearance（`ThemeMode`，默认深色）。

### 核心组件（athena_gui/lib/widget/）

| 组件 | 用途 |
|------|------|
| `AthenaTag` / `AthenaTagButton` | 渐变边框 pill 标签（品牌签名） |
| `AthenaPrimaryButton` / `AthenaSecondaryButton` / `AthenaIconButton` / `AthenaTextButton` | 按钮体系 |
| `AthenaInput` | 半透明深色输入框 |
| `AthenaScaffold` | 深色背景页面骨架 |
| `AthenaDialog` | 对话框系统（桌面居中 Dialog / 移动 Bottom Sheet，内部自动判断） |
| `AthenaSwitch` / `Checkbox` / `ContextMenu` / `Menu` / `Tile` / `Divider` / `AppBar` / `WindowButton` | 通用组件 |
| `PermissionDialog` | 权限审批弹窗（不可空白点击关闭） |
| `ErrorBoundary` | 错误边界 |

### 桌面布局约定

- 左侧栏宽 240px
- 工作区内边距：horizontal 32, vertical 12
- 结构：导航/列表 → 顶栏 context strip → 主内容区 → 底部 composer

---

## 13. 路由

使用 `auto_route` 包，配置在 `athena_gui/lib/router/router.dart`：

- 桌面端使用 `DesktopRoute(CustomRoute)`，过渡时间为 0（无动画）；`initial: isDesktop`
- 移动端使用标准 `AutoRoute`，带过渡动画
- **路由代码生成**：`router.gr.dart` 由 build_runner 生成，修改 router.dart 后需运行 `flutter pub run build_runner build --delete-conflicting-outputs`
- 全局 `scaffoldMessengerKey` 用于 SnackBar；`router.navigatorKey.currentContext` 用于不依赖 Widget 树的全局导航（如取消时 pop 权限弹窗）

---

## 14. 测试

### 测试结构

- `packages/athena_core/test/`（纯 Dart，`dart test`）
  - `agent/` - AgentService 循环、cancel_token、**parallel_execution**、permission/（analyzer/rule/service）、skill/（loader/registry）、tool/（bash/powershell/file_update/shell_runner/web_fetch/schema_validator）
  - `service/` - chat_manage_helpers、chat_message_service、chat_service、chat_support_touch、model_catalog_service
  - `util/` - retry、tool_args_formatter；`extension/` - json_map_extension
- `packages/athena_gui/test/`（Flutter，`flutter test`）
  - `database/` - migration_test、cascade_characterization_test
  - `view_model/` - chat_view_model_stream_test、setting/summary/translation/trpg、view_model_defaults_test
  - `page/mobile/` - chat_page_test、home_page_test
  - `repository/` - trpg_message_repository_test
  - `test_utils/fakes.dart` - `setupMobileTestDI()`：注册最小化 DI（内存 Fake Repository，不访问真实数据库），service/viewModel 用真实实例、信号初始为空，测试中直接设置 signal 值模拟数据

### 测试模式

- GUI 使用 `GetIt.instance.reset()` + `registerSingleton` 替换为 Fake 实现
- Widget 测试使用 `Watch` 包裹以支持 Signals
- Agent 层测试（athena_core）直接实例化工具类/服务进行单元测试（无 DI）
- AgentService 暴露 `@visibleForTesting` 成员：`selectParallelCalls`、`ToolCallResultInternal`、`currentCancelTokenInternal` 等

### 运行测试

```bash
# 核心包（Agent 引擎、服务、工具——纯 Dart）
cd packages/athena_core
dart test                          # 全部核心测试
dart test test/agent/tool/         # Agent 工具测试

# GUI 包（Flutter）
cd packages/athena_gui
flutter test                       # GUI 测试（页面/ViewModel/数据库）
flutter analyze                    # 静态分析
```

---

## 15. 开发约定

### 代码风格

- Dart 3.8+；athena_core 用 `lints`，athena_gui 用 `flutter_lints`
- 优先使用 `const` 构造函数；变量声明优先 `final`
- 实体类使用 `copyWith()` 模式
- 注释语言：中文/英文混合（历史代码中文居多，新代码趋向英文）；代码标识符一律英文

### 平台检测

使用 `PlatformUtil`（athena_core）而非直接使用 `dart:io` 的 `Platform`：

```dart
PlatformUtil.isDesktop  // macOS || Linux || Windows
PlatformUtil.isMobile   // iOS || Android
PlatformUtil.isWindows  // 特定平台
```

### 颜色使用

从 ThemeExtension 取色，不要直接写 `Color(0xFF...)`：

```dart
final colors = Theme.of(context).extension<AthenaColors>()!;
Text('x', style: TextStyle(color: colors.textPrimary));
```

无 `BuildContext` 的辅助方法：加 `BuildContext context` 参数并在调用处传参；
顶层/静态方法用 `router.navigatorKey.currentContext!`（参考 `widget/dialog.dart`
的 `_colors` getter）。新增颜色时在 `theme/athena_colors.dart` 的**深/浅两套
值同时定义**（浅色值从现有 token 推导），并确认该字段只承担一个语义角色。
含 `colors.xxx` 的表达式不能使用 `const`。

### 对话框与消息提示

- 桌面端 `AthenaDialog` 静态方法或 `showDialog()`，移动端 `showModalBottomSheet()`，平台判断已封装在 `AthenaDialog` 内部
- 消息提示：`AthenaDialog.message()` / `.info()` / `.success()` / `.warning()` / `.error()`（桌面 Overlay 3 秒自动消失，移动 SnackBar）

---

## 16. 重要约束与注意事项

1. **包依赖方向**：`athena_gui → athena_core` 单向；**athena_core 禁止引入 Flutter / SQL / GetIt**（它是 TUI 与 GUI 共用的核心）。**GUI 专有业务不进 core**（见"核心解耦原则"后的准入标准）
2. **DI 初始化顺序**：Repository → Service → Delegate → ViewModel → Agent → ChatViewModel；ChatViewModel 必须在 AgentService 和 SkillRegistry 之后注册；全部 `registerLazySingleton`
3. **数据库单例**：`Database.instance` 全局单例，所有 Sqlite Repository 直接访问 `.instance.laconic`
4. **外键级联**：`PRAGMA foreign_keys = ON` 必须在所有迁移之后执行
5. **OpenAI Client 生命周期**：每次 API 调用创建新 `OpenAIClient`，`finally` 中 `close()`；重试只覆盖网络错误（连接/超时/限流/5xx），不重试业务错误（4xx/解析）
6. **流取消**：`CancelToken.throwIfCancelled()` 在流的多个关键点调用；权限弹窗与取消用 `Future.any` 竞速
7. **消息持久化时机**：流式过程中 assistant 消息逐段累积更新（reasoning/content/toolCalls/toolResults），迭代结束/流结束时 `finalizeAssistantMessage()` 落库；取消标 `[Cancelled]`，错误写进消息内容
8. **Context 语义**：`retention` 0 = 零上下文（仅最后用户消息）、-1 = 自动 compact（>80% 窗口触发）、正数 = 当前不截断
9. **移动端工具精简**：移动端仅注册 WebFetchTool、WebSearchTool、SkillTool 三个工具
10. **预设数据完全走 migration 机制**：新预设修改 = 新增幂等迁移（INSERT 用 `WHERE NOT EXISTS` / marker 去重，UPDATE 无条件执行，不删除条目只用 `is_preset = 0`，不覆盖用户 api_key/enabled）
11. **权限弹窗不可绕过**：`showPermissionDialog()` 设置 `barrierDismissible: false`
12. **Token 写入**：`ChatRepository.updateChat()` 显式排除 token 字段，只能走 `recordUsage()` 增量路径
13. **列表信号更新**：赋值新列表或 `replaceWhere`，禁止原地 `add()` 修改
14. **AgentService 单实例运行**：`run()` 已运行时再次调用抛 `StateError`，需先 `abort()` / 等待 `settled`
15. **思考卡片展开状态**：流式更新时显式传 `expanded: current.expanded` 并通过 Coordinator 的 override 机制保留用户选择

---

## 17. 常见任务模式

### 添加新工具

1. 创建 `packages/athena_core/lib/agent/tool/xxx_tool.dart`，实现 `Tool` 接口（声明 `executionMode`、`risk`，只读/并行能力按需覆写 `canExecuteParallel`）
2. 在 `di.dart` 的 ToolRegistry 注册中添加到合适的平台列表
3. 权限相关：`PermissionRule._isFilePathTool()` 与 `PermissionService.primaryArg()` 中按需添加模式
4. 添加单元测试 `packages/athena_core/test/agent/tool/xxx_tool_test.dart`，运行 `dart test`

### 添加新 Entity（含新表）

1. 创建 `packages/athena_core/lib/entity/xxx_entity.dart`（fromJson/toJson/copyWith）或 `model/`（非 DB 数据类）
2. 创建 `packages/athena_core/lib/repository/xxx_repository.dart`（存储接口，纯抽象）
3. 在 `packages/athena_gui/lib/repository/` 添加 SQLite 实现类
4. 创建迁移 `packages/athena_gui/lib/database/migration/migration_YYYYMMDDNNN_xxx.dart`
5. 在 `database.dart` 的 `_migrate()` 中追加迁移调用
6. 在 `di.dart` 注册 Repository LazySingleton

### 添加新 Service

1. 核心逻辑放 `packages/athena_core/lib/service/`，构造函数注入 Repository 接口
2. 在 `di.dart` 注册为 LazySingleton
3. ViewModel 中通过构造函数注入使用

### 修改预设数据（Provider / Model / Sentinel / Shortcut）

1. 修改数据（新增模型、更新上下文窗口、新增/废弃提供商、更新 Sentinel prompt 等）
2. 创建幂等迁移并注册到 `_migrate()`（排在 seed migration 之后）
3. 规则：幂等（marker 或 `WHERE NOT EXISTS`）、不删除（`is_preset = 0`）、保留用户字段、模型通过 provider name 关联 `provider_id`
4. 模型元数据（名称/窗口/价格/reasoning/vision）**优先考虑走 ModelCatalogService 的 models.dev 同步**，手工迁移只用于 models.dev 没有的 provider
5. 添加单元测试 `test/database/migration/xxx_test.dart`

### 修改设计系统组件

1. 组件在 `athena_gui/lib/widget/`
2. 颜色从 `ColorUtil` 获取，不要硬编码
3. 遵循 `DESIGN.md` 规范（Tag 渐变边框、CTA 光晕等），桌面/移动视觉一致

---

## 18. 依赖包说明

### athena_core（纯 Dart）

| 包 | 用途 |
|----|------|
| `openai_dart` ^8.1.0 | OpenAI API 客户端（流式 + 工具调用 + 推理），三包共用 |
| `signals` v6.2.0 | 响应式状态管理（AgentSettings 等） |
| `http` v1.x | web_fetch/web_search 的 HTTP 客户端 + models.dev 同步 |
| `yaml` v3.1.2 | Skill 文件 front matter 解析 |
| `html` | HTML→Markdown 转换 |
| `logger` | LoggerUtil 封装 |

### athena_gui（Flutter）

| 包 | 用途 |
|----|------|
| `athena_core`（path 依赖） | 核心包 |
| `signals_flutter` v6.2.0 | Widget 响应式订阅（Watch） |
| `get_it` v8.0.3 | 依赖注入 |
| `auto_route` v9.2.2 | 路由 + 代码生成 |
| `laconic` / `laconic_sqlite` | SQLite ORM |
| `hugeicons` | 图标库 |
| `google_fonts` | 字体 |
| `flutter_markdown` + `flutter_markdown_latex` | Markdown/LaTeX 渲染 |
| `window_manager` + `tray_manager` | 桌面窗口和系统托盘 |
| `process` v5.0.3 | Shell 工具进程管理 |
| `shared_preferences` | KeyValueStore 实现 |
| `html` / `html_parser_plus` / `markdown` | 网页摘要、HTML→Markdown |
| `file_picker` / `image_gallery_saver_plus` | 数据导入 / 图片保存 |
| `path_provider` / `stream_channel` | 沙盒路径解析 / 进程流 |
| `cached_network_image` / `flutter_slidable` / `flutter_staggered_grid_view` / `visibility_detector` / `device_info_plus` / `package_info_plus` / `url_launcher` / `uuid` / `synchronized` | UI 辅助 |

### athena_tui（nocterm 终端客户端）

| 包 | 用途 |
|----|------|
| `athena_core`（path 依赖） | 核心包 |
| `nocterm` ^0.8.0 | 终端 UI（TUI 运行时） |
| `openai_dart` ^8.1.0 | 与 core 同源 |
| `signals` / `yaml` | 响应式状态 / 配置解析 |

---

## 19. 版本信息

- 当前版本：**3.6.1+864**（`athena_gui/pubspec.yaml`）
- Flutter SDK：>= 3.8.0；Dart SDK：>= 3.8.0
- 平台：iOS / Android / macOS / Windows / Linux
- 近期架构里程碑（git log）：core/gui 拆分（d4c9147 → 5b03e94）、并行工具执行与权限控制（6c68941）、工具 hooks + Schema 校验 + 执行模式（711a851）、流式工具卡片（43f9e1c）、Shortcut 系统 + JSON 模式（fcc0968 → 5e3ae04）、跨平台运行加固（cbec2be）、athena_tui 终端客户端（f65e8a7）、Sentinel 进化/回滚 + 经验回顾与记忆消化（886e0b5）、移动端沙盒进化工具（f28d6f8）
