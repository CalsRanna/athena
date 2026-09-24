# AGENTS.md

在本仓库里动手改代码的工程指南：命令、分层、硬约束、约定与常见任务。

阅读前提：

- **代码是唯一真相**。本文是导航与约束清单，与代码冲突时以代码为准，并顺手把这里改对。
- **引用前先确认它存在**。文中每个类名、常量、阈值都应在仓库里 grep 得到；过时的引用比没有引用更坏。
- **改行为就改文档**。行为变化与 README / AGENTS / DESIGN 的对应修改应同一批完成。

---

## 1. 仓库地图

```
packages/
  athena_core/                  # 纯 Dart 引擎：零 Flutter、零 SQL
    lib/agent/
      agent_service.dart        # AgentService.run + _AgentLoop（单 run 生命周期）、AgentEvent
      context_budget.dart       # ContextBudget：估算、输入上限、按用量校准
      context_compaction.dart   # 压缩请求/更新契约
      cancel_token.dart run_outcome.dart runtime_context.dart
      elicit/elicit_prompt.dart # 提问通道（「你要哪个」）
      evolution/                # 进化提示词、记忆目录注入、失败反思、Sentinel 快照
      permission/               # 权限服务、规则与存储、AI 审核
      skill/                    # SkillRegistry（三级加载）+ SkillLoader（SKILL.md 读写）
      tool/                     # 工具接口、注册表、工具集装配、各工具实现、输出存储
    lib/coordinator/
      agent_run_coordinator.dart # UI 无关的 run 编排（落库、流式消费、排队、审批落库）
      run_event.dart             # RunEvent：对外纯数据事件契约
    lib/service/                # LLM 客户端、补全、会话编排、上下文组装、压缩、模型目录/解析
    lib/repository/             # Chat / Message / Model / Provider / Sentinel / Experience 接口
    lib/storage/                # FileStorage 布局、JSONL 会话、JSON 数组、YAML、锁、id 分配
    lib/entity/                 # 领域模型（Chat / Message / Model / Provider / Sentinel / Experience …）
    lib/seed/                   # Athena 预设角色与预设提示词
    lib/util/                   # 平台判定、路径归一化、重试、日志、文本分页读
    tool/bench_message_loading.dart # 只读性能基准脚本（手工跑，不参与 CI）
    test/                       # dart test：storage/、agent/permission/
  athena_gui/                   # Flutter 桌面 / 移动应用
    lib/main.dart               # 入口：单实例 → DI → 存储 → 种子 → 窗口/托盘 → 后台同步模型目录
    lib/di.dart                 # GetIt 装配（GUI 侧唯一依赖注入点）
    lib/page/desktop|mobile/    # 页面（桌面多区工作台 + 设置浮层；移动分段浏览）
    lib/component/ lib/widget/  # 业务组件 / 设计系统控件（widget/settings/ 是设置面板三件套）
    lib/view_model/             # signals 状态 + delegate/（Agent 流、重命名、选择）
    lib/theme/                  # 设计 token 与色板（口径见 DESIGN.md）
    lib/router/                 # auto_route 配置 + 生成产物 router.gr.dart
    lib/util/ lib/service/ lib/storage/
    test/widget/                # flutter_test widget 用例
  athena_tui/                   # nocterm 终端客户端
    bin/athena.dart             # CLI 入口（参数 = 工作区目录；会改 Directory.current）
    lib/di/tui_di.dart          # 手写装配（不用 GetIt），镜像 GUI 的 di.dart
    lib/bridge/ lib/ui/ lib/view_model/
```

依赖方向**严格单向**：`athena_gui` / `athena_tui` → `athena_core`。`athena_core` 不 import Flutter，也不含 SQL；两端共用同一份工具集、权限规则、数据目录与事件契约。

---

## 2. 常用命令

根目录没有 `pubspec.yaml`，三个包各自 `pub get`。CI 与 release 都锁定 Flutter **3.41.4** stable；SDK 约束 `>=3.8.0 <4.0.0`。

```bash
# athena_core
cd packages/athena_core
dart pub get
dart analyze
dart test

# athena_gui（analyze 前必须先生成代码，否则路由/序列化产物缺失直接失败）
cd packages/athena_gui
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run -d macos          # 或 windows / linux / <device id>

# athena_tui
cd packages/athena_tui
dart pub get
dart analyze
dart run bin/athena.dart [工作区目录]     # 无测试目录

# 只读基准（cwd = packages/athena_core）
dart run tool/bench_message_loading.dart time <file.jsonl>
```

CI（`.github/workflows/ci.yml`）只跑 `athena_core` 与 `athena_gui` 两个 job：core 是 `dart analyze` + `dart test`，gui 是 `build_runner` + `flutter analyze` + `flutter test`。两个测试步骤都带 `hashFiles(...)` 守卫（目录为空时跳过）。**`athena_tui` 不在 CI 里**，改它要自己 `dart analyze`。

Release（`.github/workflows/release.yml`）由 `v*` tag 触发，三平台并行出包：`Athena-macOS.zip` / `Athena-Windows.zip` / `Athena-Linux.tar.gz`。发布中转产物在 `packages/athena_gui/dist/`，该目录被 `.gitignore` 忽略、不入库。

---

## 3. 硬约束

1. **`athena_core` 保持零 Flutter、零 SQL**。加入 `package:flutter` 或数据库依赖会同时破坏 GUI/TUI 共用与纯 Dart 可测性。判定：`grep -rn "package:flutter\|sqflite" packages/athena_core/lib` 必须为空。
2. **工具清单只有一处**：`athena_core/lib/agent/tool/tool_set.dart` 的 `buildToolRegistry()`。「有哪些工具、注册顺序、哪个平台注册哪些」是引擎的事实，不是装配层的选择；`di.dart` / `tui_di.dart` 只传自己特有的差异项（`outputStore`、`onSentinelChanged`、`mobileHomeDir`、`defaultWorkdir`）。加工具只改这一处，两端同时生效。
3. **工作文件夹的路径解析必须三处共用**（`applyRunWorkspace`）：执行（`AgentService.executeToolCallInternal`）、并行预检（`selectParallelCalls`）、审批落库（`AgentRunCoordinator._askPermission`）。三处口径不一致会出现「预检放行、执行被拦」或「同一 run 内已批准仍重复弹窗 / 始终允许失效」。
4. **并行组里不得有需要弹窗的调用**。多个审批模态会互相覆盖，所以 `selectParallelCalls` 先用权限预检分级：已有授权或 `bypassPermissions` 下无需审批的调用，才按工具的并行声明分组；deny 不进入并行组。执行路径仍重新检查权限。
5. **权限系统缺席也要收口**。`AgentService._verdictWithoutPermissionService`：无权限服务时，有审批回调就交给宿主，否则拒绝工具调用。提问类工具直接使用提问通道，不能因缺少审批服务而把问题卡住。
6. **会话文件的锁必须在共享实例上**。`JsonlSessionRepository` 按 chatId 缓存 `SessionJsonlStore`——串行锁是实例字段，每次新建实例等于没锁，`update`（整文件重写）与 `append` 交错会丢行。
7. **id 分配不缓存计数**。`IdAllocator` 每次都在跨进程文件锁内「读 meta → 加一 → 原子写回」，因为 GUI 与 TUI 可能同时运行。
8. **所有改文件的写操作走 `atomicWriteString` / 临时文件 + rename**，修改再套 `withFileLock(...)`（`.lock` 文件只做互斥，内容始终为空）。GUI 与 TUI 共享同一目录。
9. **不要用 `Stream.timeout`**：Dart 3.12 里它对「async* 生成器 + await for」不触发。用 `util`/`service/llm_client.dart` 的 `withIdleTimeout`（Timer 手动实现）。
10. **assistant 消息的 `tool_calls` 必须被 tool 结果全覆盖**。取消、异常、流提前结束时都要用 `_closeOpenToolCalls` 合成占位结果，否则下次组装上下文会被 OpenAI 兼容端 400 拒绝，该会话再也发不出消息。空载荷的 assistant 记录（content 与 tool_calls 都为空）同样不能进请求：`ChatMessageConverter.convertMessage` 直接整批丢弃（连带丢弃它的 tool 结果，否则会变成孤立的 tool 消息）。
11. **不要用文件工具去读写 `~/.athena/` 下的应用数据**。那是运行时数据（sentinels / chats / experiences / skills），由工具与仓储管理；文档里的这条要求同样写进了注入模型的运行时提示（`runtime_context.dart`）。
12. **生成的代码不要手改**：`athena_gui/lib/router/router.gr.dart` 由 `build_runner` 产生；改路由后重跑生成命令并把产物一起提交。

---

## 4. 分层与数据流

```
page / widget / component          （GUI）或 ui/（TUI）
  ↓ 读 signals、调 ViewModel/Controller
view_model（signals 状态）+ view_model/delegate
  ↓ AgentStreamDelegate（GUI）/ TuiAgentBridge（TUI）：包装协调层、把审批与提问接到本地 UI
coordinator.AgentRunCoordinator    ← UI 无关的 run 编排，产出 RunEvent
  ↓ 驱动 / 消费
agent.AgentService（_AgentLoop）    ← 产出 AgentEvent（流式 token、工具调用、用量…）
  ↓ 调用
service（补全 / 会话编排 / 上下文组装 / 压缩 / 模型目录）
  ↓ 接口
repository（抽象）← storage（文件实现：JSONL / JSON / YAML + 锁）
  ↓
entity + ~/.athena/ 下的文件
```

**一次 send 的完整链路**（`AgentRunCoordinator.send`）：

1. 注册 run（`runId`、取消令牌、工作文件夹、`settled`）；
2. 落库用户消息；标题为默认值时，若是首条用户消息则触发自动命名；
3. 解析模型与 provider，缺任一就发 `RunError` 并结束（用户消息已落库，不能静默无响应）；
4. 计算记忆作用域（`chat.sentinelId` 或直接对话专用的 `direct`），注入 MemoryDigest，组装历史消息；
5. 追加 assistant 占位消息 → 启动 `AgentService.run`；
6. 消费事件流：文本/推理增量写进占位消息、工具调用与结果累积进 JSON 列、用量覆盖写回会话、迭代边界把当前消息落地并开新占位消息；
7. 收尾：`run` 结束（正常/取消/错误）都保证有落库与 outcome；随后取排队输入自动接续成下一个 run，事件流对 UI 连续。

事件契约有两层，别混用：`AgentEvent`（引擎内部，含流式增量）与 `RunEvent`（协调层对外，纯数据，UI 只订阅这一层）。UI 侧因此有两条订阅：`send()` 返回的那条（用户消息触发的 run），以及 `internalEvents`（协调层自己发起的自动汇报 run，带 `chatId`，见下）。

**内部 run（后台任务自动汇报）**：`BackgroundTaskService.completions` → `_onBackgroundTaskCompleted`（非 `completed`/`failed` 直接丢弃）→ 会话空闲则 `_runReport`，正忙则攒进 `_pendingReports`，由 `send` 收尾时的 `_drainPendingReport` 合并成一次汇报。它不走 `send`：不落用户消息、不加 assistant 占位以外的任何消息、不发 `RunAutoRename`。前端把 `InternalRunEvent` 复用同一份事件分发（GUI `_applyRunEvent` / TUI `handleRunEvent`），只有流式指示的收尾各自维护。

---

## 5. 领域模型与存储

`FileStorage`（`lib/storage/file_storage.dart`）定义与装配整个布局，root 默认 `~/.athena/`（移动端由装配层传 Application Support）：

| 路径 | 实现 | 说明 |
|---|---|---|
| `sessions/{chatId}.jsonl` | `JsonlSessionRepository` + `SessionJsonlStore` | 一个对话一个文件；首行 chat 元数据，之后每行一条消息，行序即消息序。同一实例同时实现 `ChatRepository` 与 `MessageRepository`，删对话即删文件 |
| `models.json` / `sentinels.json` | `JsonArrayStore` 系列 | JSON 数组，`id` 为主键；读-改-整文件写 |
| `meta.json` | `IdAllocator` | 自增计数，key 为文件/目录路径（chat id、message id 各自独立计数） |
| `setting.yaml` | `UserSettingsStore` + `YamlProviderRepository` | provider 的**权威**存储（含 API key，可手工编辑），以及 TUI 默认模型（modelId 字符串） |
| `models_dev_cache.json` | `ModelCatalogService` | 目录缓存 |
| `permissions.json` | `PermissionStore`（在 `permission_rule.dart`） | 持久权限规则。注意它的路径由 `HOME` / `USERPROFILE` 直接推导，**不走** `FileStorage.root` |
| `tool_outputs/{sha256}.txt` | `ToolOutputStore` | 内容寻址的长工具输出 |
| `background_tasks/background_tasks.json` | `BackgroundTaskService` | 运行中的后台任务（pid + 命令行），仅用于下次启动清理强杀遗留的孤儿进程 |
| `experiences/shared/`、`experiences/{sentinelId}/` | `ExperienceRepository` | 一条经验一个 JSON，文件名即 id |
| `sentinels/{Uri.encodeComponent(name)}/history/` | `SentinelHistoryStore` | 演进前快照 |
| `skills/{name}/SKILL.md` | `SkillLoader` / `SkillRegistry` | 用户级技能 |
| `kv.json` | `JsonFileKeyValueStore` | TUI 的 `KeyValueStore`；GUI 用 `SharedPreferences` |

约定：

- **文件永远是唯一真相**，索引/缓存必须可删除可重建，不反向持有数据。
- 损坏容错：坏行/坏规则单条跳过并记日志，不能一坏就炸掉整个会话或所有工具调用。
- 会话消息的窗口化：`RecentMessageRepository.loadInitialMessages` / `loadRecentMessages` 只读尾部窗口（GUI 每页 50），轮次总数靠 `getTurnStartIds` 的整文件扫描。

---

## 6. 上下文预算与压缩

`ContextBudget`（`lib/agent/context_budget.dart`）：

- 输入上限 `inputLimit = contextWindow - min(8192, max(256, contextWindow ~/ 5))`（给输出留空）；
- 估算 = `utf8(JSON(messages+tools)).length / 2`，每张图片额外 4096，估算值再乘 `_usageScale`（由真实 `prompt_tokens` 向上校准，只增不减）；
- 触发压缩的条件：`contextWindow > 0 && estimate >= min(窗口 80%, inputLimit)`；
- 仍超限时 `prepare()` 把较旧的长工具结果替换成 `tool_output_read` 引用，**最新一批工具结果始终保留**（可能正是刚分页读出来的内容）；无法压缩到上限内就抛 `StateError` 而不是静默截断。

`retention` 语义（`ChatEntity`）：`0` = 每次只带当前用户消息；`-1` = 全量历史 + 自动压缩。压缩回调只在 `retention == -1 && onCompact != null` 时进入。

压缩落库形态：`CompactionStep` 用**同一条消息 id** 逐阶段更新（triggered → summarizing → persisting → completed/failed/cancelled），完成后其内容即摘要，覆盖范围写在 `reference` 里；被覆盖的原始消息标 `compacted`（保留可回溯，但不参与上下文）。组装历史统一走 `ConversationSummary.activeHistory()`，不要自己过滤 `compacted`。

---

## 7. 权限系统

`PermissionVerdict` 三态与判定顺序见 `PermissionService.check`：deny 规则 → 会话缓存（按 `runId` 隔离）→ 持久 allow 规则 → 按审批模式处理。工具不声明风险等级，读取与写入统一进入审批流程；shell 规则只匹配整条命令，不分析动作、子命令或只读性。

- Shell 调用统一串行，包括看似只读的命令与后台启动调用；后台命令启动后仍可继续运行。不再通过静态命令分析决定免审批或并行资格。
- `ElicitChannelAware` 工具直接进入提问通道，不叠加 AI 审核或人工审批；显式 deny 优先。
- 规则形态（`PermissionRule.forToolCall`）：shell 落 `RuleKind.exact`（整条命令精确匹配）、文件工具落 `RuleKind.path`、`web_fetch` 落 `RuleKind.origin`（`scheme://host[:port]`）、其余工具落空 pattern 的 `exact`（整工具放行）。旧 `action` 规则在读取时跳过（allow / deny 均停止生效）；原有授权需重新审批，禁止项需改为整条命令的 `exact` 规则。复合命令不会复用单个子命令的 allow / deny。
- 会话缓存键 = 工具名 + 规范化后的完整参数（排序、剥离三个展示/建议元数据字段）：换个参数就是另一次授权。
- `ApprovalMode`：`manual` / `ai_review`（默认）/ `bypass`，存 `KeyValueStore`（键 `approval_mode`，旧布尔键 `ai_approval_enabled` 只做一次性迁移），改动下一轮 run 生效。三档都越过不了 deny。
- AI 审核（`AiPermissionReviewer`）：独立提示词、无工具、20s 超时、单次调用有效，输入是**原始用户/助手对话**（摘要、技能、记忆、工具输出都不构成授权）；非法输出、超时、异常一律降级为「问人」。审核通过后要**重新检查 deny 规则**。
- `bypass` 只有 `bypassPermissions` 一条开关路径（`AgentRunCoordinator` 由 `approvalMode == ApprovalMode.bypass` 传入），不要在各工具里另加旁路。

---

## 8. 工具

`Tool` 接口（`lib/agent/tool/tool_interface.dart`）：`name` / `description` / `parameters`（JSON Schema）/ `executionMode` / `canExecuteParallel(args)`。可选实现 `CancellableTool`（长阻塞工具接取消信号）与 `ElicitChannelAware`（提问类工具）。

| 工具 | 并行 |
|---|---|
| `file_read` `web_fetch` `web_search` `tool_output_read` `sentinel_list` `sentinel_get` | 是 |
| `ask_user_question` `background_task` `experience_recall` | 否 |
| `file_write` `file_update` `bash` / `powershell` `skill` `skill_evolve` `experience_learn` `sentinel_evolve` `sentinel_revert` | 否 |

其它要点：

- 每个工具的 model-facing schema 由 `ToolRegistry.parametersFor` 注入三个元数据字段：`call_description`（必填，缺失即判参数非法并要求模型重发）、`approval_recommendation`、`approval_reason`。三者在权限匹配与执行前由 `toolExecutionArguments` 剥离——**别把它们算进参数或权限判断**。
- 引擎还会在执行前注入两个隐藏键（`tool_interface.dart`，同样不进展示 JSON、不参与规则匹配）：`_chat_id`（会话归属，后台任务用）与 `_background_disabled`（本轮禁止启动后台任务，自动汇报回合用）。
- 审批与并行资格分开：读取、搜索等操作也按当前模式审批，不根据工具类型自动放行。
- 移动端只注册 11 个工具（不注册文件、shell、提问、后台任务）；新增工具时先想清楚移动端是否可用，再决定放在哪个分支。
- `ToolOutputStore`：超过 24000 字符才落盘（内存实例用于测试），预览 2000 字符，单次回读上限 12000 字符，按内容哈希寻址（同内容重跑不会重复落盘）。
- shell 超时策略在 `ShellTimeoutPolicy`：默认 120s，上限 3600s（环境变量 `ATHENA_SHELL_MAX_TIMEOUT` 可抬高，低于默认值视为非法并回退）。

### 后台任务（桌面端）

`bash` / `powershell` 的 `background: true` 走 `BackgroundTaskService`（`lib/agent/task/background_task.dart`）：**启动即返回**任务 id（`bg-1`…），命令继续跑，输出持续累积在任务对象里，用 `background_task(action="list"|"read"|"stop")` 查看与停止。归属与生命周期是这套能力的关键，改动前先读懂这几条：

- **归属会话，不归属 run**。登记表按 `chatId` 分组，`_chat_id` 由引擎注入；工具自己不知道会话，也不允许模型指定。
- **run 正常结束不杀任务**（这正是后台化的意义）；**用户取消 run 时杀该会话全部后台任务**（`AgentRunCoordinator.stop`），保留已产生输出、状态记为 `cancelled`；会话删除、优雅退出（托盘退出 / TUI `runApp` 返回）同样杀。
- **停止 ≠ 失败**：`cancelled` 与 `failed` 分开记账，用户要能区分「我停的」和「它自己挂了」，且 `cancelled` 不触发自动汇报（`shouldReportTaskCompletion`）。
- **强杀留孤儿**：进程被 kill -9 / 崩溃时没有任何钩子可挂，子进程会被 reparent 继续跑。启动时 `recoverOrphans()` 按 `background_tasks.json` 核对「pid 存活 + 命令行匹配」后清理——只凭 pid 杀是错的（pid 会复用）。这是已知残余：崩溃期间的副作用窗口消不掉，只能事后发现。
- **自动汇报回合**（任务完成后自动起，可在设置里关）：不落用户消息（任务输出是外部文本，以 user 角色进历史会成为 AI 审批的授权依据），继续通过 `background_task` 分页读取输出，使用相同工具集与当前审批模式。AI 审核只读取原始用户/助手对话，手动模式或 AI 无法确认时走原有审批回调；`allowBackgroundTasks: false` 避免「任务→汇报→任务」无限链，`allowReflection: false` 跳过失败反思，迭代上限 3。
- **取消即杀是本设计的取舍**：进程树加上新建的进程都属于被杀范围，用户按停止的意思是「这个会话先停下」。长构建跑到一半被取消就是白跑，代价已接受。

---

## 9. 自我进化与记忆

- 注入顺序（`AgentService._injectPrompts`）：`[sentinel] → evolution hint → skill 目录 → MemoryDigest → runtime+日期 → 历史`。runtime 与日期合成同一条 system 消息（一天内内容稳定，跨午夜会在请求前刷新）。
- `EvolutionPrompt.hint` 是每次注入的极简提示；完整指南是内置 `self-evolve` Skill 的 body，按需加载。两端装配都要 `registerBuiltin(kSelfEvolveSkill)`。
- `SkillRegistry`：Level 1 目录上限 20 条、按最近访问倒序；`loadAll({homeDir})` 决定用户级根目录（`{homeDir}/.athena/skills`），移动端传沙盒目录——**写入端（`skill_evolve`）必须与读取端同目录**。`deleteSkill` 只允许删用户级 Skill。
- `MemoryDigest`：每次 run 注入当前 Sentinel 的**全部 active** 经验目录（lesson 一行一条，`shared` / `private` 标注 + 创建日期），顺序稳定（按创建时间倒序、同时间按 id）以便复用 prompt cache；没有经验时不注入空段。`context` / `tags` 由 `experience_recall` 按需取。
- 失败反思（`ReflectionPolicy.shouldReflect`）：`maxIterations` 结束且失败不全是权限拒绝，或 `completed` 且同一工具失败 ≥2 次才触发。反思只做一次 LLM 提案调用，经验写入完全复用 `experience_learn` 的标准工具路径（校验/审批/执行），**不要直接写 `ExperienceRepository`**。
- 经验长度上限 `ExperienceEntity.maxLessonLength = 500`；lesson 是给上下文直接用的精炼摘要，详细背景放 `context`。反思提案的置信度门槛 0.7。
- Sentinel 演进前必写快照（`SentinelHistoryStore`），`sentinel_revert` 本身也可回滚。

---

## 10. 客户端约定

**GUI（`athena_gui`）**

- 依赖注入唯一入口是 `lib/di.dart`（GetIt）；新增 ViewModel/Service 在那里注册，别在页面里自行 new。
- 状态用 `signals`（`Watch` 包裹订阅），跨 ViewModel 通信用 signal，异步 Agent 交互走 `AgentStreamDelegate`。
- 视觉只能取 `theme/athena_tokens.dart`（几何/排版）与 `theme/athena_colors.dart`（颜色，挂 `ThemeExtension`）；具体口径见 DESIGN.md。设置面板用 `widget/settings/` 三件套（panel / row / control），改动即存、没有页面级 Save。
- 桌面、移动与通用组件的界面图标统一使用 `lucide_icons_flutter` 的 `LucideIcons`，通过 Flutter `Icon` 渲染；新增图标沿用默认线条字重、既有尺寸与语义色，不混用其他图标库。同类功能保持同一字形，工具与审批卡共用 `StepCard.toolIcon` 映射。
- 桌面 composer 的 `DesktopContextSelector` 只设置聊天历史保留策略（`-1` 携带 / `0` 不携带），读取 `currentRetention`，草稿与已有会话共用。入口用 Lucide `clock4` / `clockFading` 和 `Context on / Context off`，无下拉箭头；复用 `DesktopContextMenu` 向上、右对齐展开，选择后关闭并经既有回调保存，不提供温度入口。
- 桌面与移动是两套页面（`page/desktop/`、`page/mobile/`），路由在 `router/router.dart`，桌面路由是 0 时长无过渡，桌面设置路由 `opaque: false`（面板浮在应用之上）。
- 平台判定统一用 `PlatformUtil`（`isDesktop` / `isMobile`），不要散落 `Platform.isXxx`。
- 页级快捷键挂页面（首页的 ⌘N / Ctrl+N 新建对话在 `page/desktop/home/component/home_shortcuts.dart`），不要塞进 `main.dart` 的全局 `HardwareKeyboard` 处理器——那条只服务窗口级动作（如 ⌘W 隐藏窗口）。路由是天然的生效边界：设置页/对话框压上来时焦点整体搬进新路由的 FocusScope，快捷键自动失效、关掉即恢复，不需要查路由名；页面自己再带一层 `FocusScope(autofocus: true)`，保证点画布失焦后焦点落回页面内部而不是路由 scope。
- 新对话的草稿参数（`ChatViewModel.prepareNewChatDraft`）：模型/保留策略/温度/推理强度一律回默认；**角色与工作文件夹从 `inheritFrom` 继承**——桌面点 New chat 传当前选中对话的快照，移动端传最近打开的对话但 `inheritWorkspace: false`（那边不注册 shell / 文件工具）。启动落草稿、删掉当前对话不传来源，回默认角色 + 不指定文件夹。**删除对话的视图落点**（`ChatViewModel.deleteChat` / `deleteChats`）：删的不是正在看的那条就停在原处（当前对话与消息都不动）；删的正是当前这条则回草稿态，**不自动落到邻居**。继承值只是草稿初值，composer 上仍可改，`createChat` 落库读的就是这些 `current*` 信号。
- composer 里没发出去的内容（文字 + 待发图片）**按对话分开存**，切走时存回原对话、切回来时取出：文字由页面在切换点存取（`DesktopHomePage._restoreComposerDraft`，槽位 key = chatId，`null` 是还没落盘的"新对话"），待发图片由 ViewModel 存（`ChatViewModel._retargetPendingImages`，`pendingImages` 始终只是当前那一槽）。槽位只活在内存里；空内容不留条目；取出即删，避免旧副本把改过的内容顶回去。**新增任何会换 `currentChat` 的入口，都要在同一帧内调一次 `_restoreComposerDraft`**（等 IO 回来再换会覆盖用户在这段延迟里敲的字），否则 A 里打的字会跟着串进 B。桌面 composer 只有一个 `TextEditingController` 跨对话复用，别指望它自己按对话隔离。
- widget 测试要挂真实页面时，用 `DI.ensureInitialized(homeDirOverride: 临时目录)` 装依赖图：数据根整体指到临时目录，不碰真实的 `~/.athena`（例见 `test/widget/home_page_new_chat_test.dart`）。注意页面 `_initState` 是一串串行的真实文件 I/O，测试里要交替「`runAsync` 真实异步窗口 + `pump`」才能把它推完——单放一次 `runAsync` 只够第一段 I/O。

**TUI（`athena_tui`）**

- 组合根是 `lib/di/tui_di.dart`（手写装配，镜像 GUI 但不引入 GetIt）；数据目录、工具集、权限规则与 GUI 相同。
- 启动会把 `Directory.current` 改成工作区目录——核心层（shell 默认 workdir、文件工具相对路径）都按 `Directory.current` 解析。
- `ChatController` 不依赖 nocterm，保持纯 Dart 可测；UI 状态全在 signals 里。

---

## 11. 代码与文档约定

- **注释与文档用中文**；面向模型的文本（工具描述、系统提示、回给模型的错误）用英文，与既有实现保持一致。注释解释「为什么」——现状为什么是这样、当初避开什么坑，而不是复述代码。
- **格式化**：仓库**不是 format-clean**（`dart format` 会改写约四分之一既有文件）。新建文件保持 `dart format` 结果；既有文件按原风格手改，**不要**对既有文件跑 `dart format`，那会产出满屏无关重排。
- **导入**：跨目录引用普遍用 `package:athena_core/...` 绝对导入，同一目录内部也有相对导入（如 `tool/` 内）。改动沿用所在文件既有风格即可。
- **测试**：`athena_core/test` 用 `package:test`，GUI 用 `flutter_test`。用例要断言可观察的行为或量出来的几何（`.expect(..., reason: ...)`），不是「调用了哪个方法」；交互/动画类断言需要多帧 `pump` 才能拿到过渡终态（单次 `pump(200ms)` 可能仍是起点值）。写完顺手确认它真的会因为回归而失败。
- **文档同步**：改行为时同步 README（用户可见能力）、AGENTS（本文件）、DESIGN（视觉口径），并核对文中引用的常量仍存在。
- 文档与代码注释不使用 emoji（仓库现有文档与注释均无 emoji；角色头像里的 emoji 是产品数据，不在此列）。

---

## 12. 常见任务

**加一个工具**

1. 在 `lib/agent/tool/` 新建实现（给出 `name` / `description` / `parameters` / `canExecuteParallel`），需要取消能力就实现 `CancellableTool`；
2. 在 `tool_set.dart` 注册：判断移动端是否可用，决定放进移动分支、桌面分支还是两者；
3. 若需要持久化，走已有 repository（新增仓储要同时在 `FileStorage` 里装配）；
4. 在 README 的工具表里补一行。

**加一个页面 / 路由（GUI）**

1. 建页面并加 `@RoutePage()`；
2. 在 `router/router.dart` 注册（桌面页面用 `DesktopRoute`）；
3. 跑 `dart run build_runner build --delete-conflicting-outputs`，把 `router.gr.dart` 一起提交。

**加一个设置项**

1. 值放 `AgentSettings`（核心，被协调层消费）或 `SettingViewModel`（GUI 本地偏好，走 SharedPreferences）；
2. 两端的入口都要接上（GUI 设置面板行、TUI 斜杠命令或启动导入），否则同一份设置在不同端行为不一致；
3. 旧键迁移只做一次：读不到新键时读旧键，写入后不再看旧键。

**改存储格式**

1. 只动 `storage/`（或 repository 实现），并在 `FileStorage` 的布局注释里同步；
2. 保证向后兼容或提供迁移；损坏数据按容错处理（跳过 + 记日志）；
3. 补 `athena_core/test/storage/` 用例（并发写、损坏文件、原子写至少覆盖一个）。

**加一个 ViewModel / Service（GUI）**

1. 在 `di.dart` 注册（lazy singleton）；
2. 需要 Agent 事件的走 `AgentStreamDelegate`，不要自己 new `AgentRunCoordinator`。

---

## 13. 易错点（都踩过）

- **并行组的审批弹窗**：需要弹窗的调用放进并行组 → 多个模态互相覆盖。用 `selectParallelCalls` 的预检分级。
- **路径口径三处不一致**：审批按相对路径落规则、执行按绝对路径匹配 → 「已批准仍重复弹窗」和「始终允许」失效。三处必须共用 `applyRunWorkspace`。
- **会话锁形同虚设**：每次新建 `SessionJsonlStore` → 流式期间的整文件重写与 append 交错丢行。
- **`Stream.timeout` 不触发**：改用 `withIdleTimeout`。
- **tool_calls 未闭合**：取消/异常路径漏合成 tool 结果 → 该会话后续请求被 400 拒绝。
- **空 assistant 记录进上下文**：进程被强杀 / 崩溃 / 断电时迭代占位没走完收尾，或思考模式只输出 reasoning 就被截断 → 组装出 `AssistantMessage(content: null, toolCalls: null)`，兼容端报 `Invalid assistant message: content or tool_calls must be set`，该会话此后每次请求都被拒（用户看到"中断后再也继续不了"）。空记录在 UI 上不渲染（`buildAssistantMessageLayouts` 跳过无片段的布局），所以肉眼看不到是哪条坏。会话重新加载后由 `ChatMessageConverter` 自动丢弃即可恢复。
- **截断的 tool_calls 直接执行**：参数半截就写文件/跑命令 → 撞输出上限时一律不执行。
- **展示元数据混进参数**：`call_description` / `approval_recommendation` / `approval_reason` 必须剥离后再匹配规则与执行。
- **读写应用数据目录**：`~/.athena/` 只能经仓储与工具访问，不要用文件工具直接改。
- **移动端的 `$HOME`**：移动端没有可靠的 `HOME`，用户级目录（Skill、经验、Sentinel 历史）与 `FileStorage` 根必须同为装配层传入的沙盒目录。
- **忘记生成代码**：GUI 改了路由不跑 `build_runner` → analyze 直接失败。
- **对既有文件跑 `dart format`**：产出大面积无关改动，评审无法看。
- **用索引当下标口径**：UI 里的「第几轮 / 第几项」有窗口内相对下标与整段会话绝对下标两套（见 `util/chat_turn_util.dart` 与 `TurnIndicator` 的分页），传参前先核对。

---

## 14. 交付前检查

1. `dart analyze` / `flutter analyze` 干净（至少不新增问题）；
2. `dart test` / `flutter test` 通过：改了 `athena_core` 就跑 `athena_core` 的，改了 GUI 就跑 GUI 的，两端都涉及就跑两遍；
3. 改 GUI 前先 `build_runner`；
4. `git diff` 复核：无调试残留、无无关文件、无大范围重排；
5. 行为变化已在 README / AGENTS / DESIGN 中同步，且文中引用的常量仍存在。
