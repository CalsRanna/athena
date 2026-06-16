# CLAUDE.md

此文件为 Claude Code 提供本仓库的上下文指引。

## 项目概述

Athena 是一个跨平台 AI Agent 应用，使用 Flutter 构建，版本 3.2.0。支持桌面端（macOS、Linux、Windows）和移动端（iOS、Android）。Athena 具备完整的 Agent 循环（推理 → 工具调用 → 结果 → 再推理）、12 个内置工具、可自我进化的 Skill 系统、以及严谨的三层权限与安全模型。

## 开发环境设置

### 依赖管理
```bash
flutter pub get                                    # 安装依赖
flutter pub run build_runner build                 # 代码生成（路由等）
flutter pub run build_runner build --delete-conflicting-outputs  # 清理后重新生成
```

### 测试和验证
```bash
flutter test                                       # 运行全部测试
flutter test test/agent/tool/bash_shell_tool_test.dart  # 运行单个测试
flutter analyze                                    # 静态代码分析
```

### 运行应用
```bash
flutter devices                                    # 查看可用设备
flutter run -d <device-id>                         # 运行
flutter run --debug                                # 调试模式
flutter run --release                              # 发布模式
```

## 架构设计

### 分层架构

1. **UI 层** (`lib/page/`)
   - `desktop/`: 桌面端页面（多区工作台：顶栏 context strip → 左栏列表 → 主内容区 → 底部 composer）
   - `mobile/`: 移动端页面（分段浏览，bottom sheet 代替模态弹窗）
   - 根据平台自动选择路由入口（`lib/router/router.dart` 中 `isDesktop` 判断）
   - 通用 widget 组件在 `lib/widget/`（20+ 组件），业务组件在 `lib/component/`

2. **视图模型层** (`lib/view_model/`)
   - 使用 Signals 库（Signal、Computed、listSignal）实现响应式状态管理
   - 通过 GetIt 进行依赖注入（`lib/di.dart`，全部 LazySingleton）
   - 所有 ViewModel 的构造参数接受可选注入（测试时可传 fake）
   - 核心 ViewModels：
     - `ChatViewModel`: 聊天会话管理，集成 Agent 编排、流式消费、取消/错误处理、图片管理、多选/批量操作
     - `ModelViewModel`: AI 模型管理与默认模型解析（enabledModels 来自已启用的 provider）
     - `ProviderViewModel`: AI 提供商管理，启用/禁用联动模型加载
     - `SentinelViewModel`: Sentinel（系统提示词角色）管理，AI 元数据生成
     - `SettingViewModel`: 应用设置管理（SharedPreferences），含窗口尺寸、模型 ID 映射、数据导入/导出
     - `SummaryViewModel`: 网页摘要功能
     - `TranslationViewModel`: 翻译功能
     - `TRPGViewModel`: TRPG 游戏功能
     - `MemoryViewModel`: 用户记忆管理（批次分析 + 合成）

3. **Agent 层** (`lib/agent/`)
   - `AgentService`: Agent 循环编排 —— 推理 → 工具调用 → 权限检查 → 执行 → 结果 → 再推理，最大 100 轮（可配置）
     - 首次迭代注入 skillPrompt 和 evolutionPrompt
     - 工具结果 >4000 字符时调用辅助模型摘要压缩
     - 支持 CancelToken 随时中断，保留已生成内容
   - `agent/tool/`: 14 个内置工具（部分按平台提供不同实现）
     - 工具接口：`Tool` abstract class（name, description, parameters JSON Schema, execute）
     - 移动端仅注册 4 个：web_fetch, web_search, skill, skill_evolve
     - 桌面端注册全部 14 个
   - `agent/permission/`: 三层权限模型
     - `PermissionService`: 编排检查（Skill 白名单 → 持久化规则 → 审批弹窗）
     - `PermissionRule`: 通配符匹配规则（支持 `*` 和 `?`），持久化到 `~/.athena/permissions.json`
   - `agent/skill/`: Skill 系统
     - `SkillLoader`: 解析 SKILL.md（YAML front matter + Markdown body）
     - `SkillRegistry`: 三级渐进式加载、Level 1 提示词生成（最多 20 个按访问时间排序）、allowed-tools 白名单
     - `SkillTrustStore`: 项目级 Skill 信任持久化到 `~/.athena/trusted_skill_dirs.json`
   - `agent/evolution/`: 自我进化提示词（hint ~30 token 始终注入 + fullBody 作为内置 self-evolve Skill）

4. **服务层** (`lib/service/`)
   - `ChatService`: AI 提供商网络通信（OpenAIClient 生命周期管理：每次请求创建，finally close()；流式/非流式；重试配置；自定义 Referer/X-Title headers；辅助模型完成）
   - `ChatMessageService`: 消息格式转换（Entity → OpenAI ChatMessage，含 system prompt 注入、上下文截断、tool_calls/tool_results 展开、图片 ContentPart 处理）
   - `ChatManageService`: 会话与消息持久化编排（CRUD、占位/最终化、取消/错误标记保留已有内容）
   - `ChatSupportService`: UI 辅助操作（重命名、模型/哨兵/上下文字段更新、图片保存、消息折叠）
   - `MemoryService`: 用户记忆批次分析与合成
   - `SentinelService`: Sentinel 元数据 AI 生成（名称、描述、标签、头像）
   - `SummaryService`: 网页摘要
   - `TranslationService`: 文本翻译
   - `TRPGService`: TRPG 游戏逻辑（含行动建议生成）

5. **数据层**
   - `lib/entity/`: 数据库实体（10 个 entity，全部使用 copyWith 不可变模式）：
     - ChatEntity, MessageEntity (含 toolCalls/toolResults/reasoningContent/reasoning 字段), ModelEntity, ProviderEntity, SentinelEntity, MemoryEntity, ChatHistoryEntity, SummaryEntity, TranslationEntity, TRPGGameEntity, TRPGMessageEntity
   - `lib/repository/`: 数据访问层（9 个 repository），封装 Laconic ORM 操作
   - `lib/database/`: 数据库管理和迁移（9 次迁移，按时间排序）

6. **其他**
   - `lib/preset/`: 预设数据（AI 提示词模板、提供商预设、Sentinel 预设）
   - `lib/util/`: 工具类（LoggerUtil、RetryConfig、PlatformUtil、CancelToken、tool_args_formatter 等）
   - `lib/extension/`: JSON Map 安全读取扩展

### 数据库系统

使用 Laconic ORM 管理 SQLite 数据库：

- 数据库文件：Application Support 目录下的 `athena.db`
- 迁移文件命名：`migration_YYYYMMDDNNNN_description.dart`，共 9 次迁移
- 迁移按时间顺序在 `Database._migrate()` 中调用
- Laconic 使用单一持久连接，`PRAGMA foreign_keys = ON` 在所有迁移后执行一次
- 首次启动通过 `_preset()` 方法预设默认的 AI 提供商、模型和 Sentinel

**添加新迁移**：
1. 在 `lib/database/migration/` 创建新迁移文件
2. 实现 `migrate()` 方法（先检查迁移是否已执行，再执行 DDL）
3. 在 `lib/database/database.dart` 的 `_migrate()` 中按顺序添加调用

### 路由系统

使用 AutoRoute 进行声明式路由：

- 路由配置：`lib/router/router.dart`（`@AutoRouterConfig` 注解）
- 生成的路由代码：`lib/router/router.gr.dart`（由 build_runner 生成）
- `DesktopRoute`：自定义路由，使用 `TransitionsBuilders.noTransition`，0ms 过渡时长
- 移动端使用标准 `AutoRoute`（带过渡动画）
- 初始路由由 `PlatformUtil.isDesktop` 决定

**修改路由后必须运行**：`flutter pub run build_runner build`

### 依赖注入

使用 GetIt 进行依赖注入（`lib/di.dart`）：

- 全部组件注册为 `LazySingleton`
- 注册顺序：Repository → Service → ViewModel → Agent 组件
- ViewModel 的构造参数均接受可选注入（测试可传 fake）
- Agent 组件（ToolRegistry、SkillRegistry、AgentService）在 DI 中组装
- 移动端在 ToolRegistry 中仅注册 4 个工具

### 状态管理

使用 Signals 库实现细粒度响应式：

- ViewModel 中的状态使用 `Signal<T>`、`listSignal<T>`、`Computed<T>`
- UI 通过 `Watch` widget 自动响应状态变化
- `main.dart` 中 `SignalsObserver.instance = null` 以避免不必要的日志
- 禁止在页面层混用 `setState` 和 signals

## Agent 系统

### 内置工具一览

| 工具 | 说明 | 平台 |
|------|------|------|
| `bash` | 执行 bash 命令（超时管理、递归删除拦截、输出截断） | 桌面非 Windows |
| `powershell` | 执行 PowerShell 命令（同上） | 桌面 Windows |
| `file_read` | 读取文件，支持 offset/limit，行号输出 | 桌面 |
| `file_write` | 创建或覆写文件，自动递归创建父目录 | 桌面 |
| `file_update` | 精确字符串替换编辑文件（replace_all、行号去除、引号归一化、mtime 并发检测） | 桌面 |
| `web_fetch` | HTTP GET/POST 抓取网页（1MB 上限，SSRF 防护理） | 全平台 |
| `web_search` | Brave Search API 网络搜索 | 全平台 |
| `skill` | 加载 Skill 完整指令（Level 2），触发 allowed-tools 白名单 | 全平台 |
| `skill_evolve` | 创建或更新 Skill（SKILL.md），Agent 自我进化 | 全平台 |
| `experience_learn` | 记录经验教训到文件系统（`~/.athena/experiences/`） | 桌面 |
| `experience_recall` | 检索过往经验 | 桌面 |
| `sentinel_evolve` | 优化当前 Sentinel（系统提示词），内置 Sentinel 不可改名 | 桌面 |

### Shell 工具配置

- 默认超时：120s，最小 1s，最大 600s
- 超时主动 kill：SIGTERM → 1s → SIGKILL（防止孤儿进程）
- 递归删除命令（rm -rf 变体）在执行前拦截
- 输出截断：最多 200 行 / 10000 字符（保留头尾）

### 权限系统

**权限检查优先级**（`AgentService.run()` 中的顺序）：
1. **Skill allowed-tools 白名单**：当前 Skill 上下文声明了 allowed-tools 且匹配 → 自动放行
2. **用户持久化规则**：`PermissionService.check()` 匹配 `~/.athena/permissions.json` 中的规则 → 自动放行
3. **审批弹窗**：不匹配任何规则 → 弹出 `PermissionDialog`，完整显示命令（shell 命令不截断）

**持久化规则存储**：`~/.athena/permissions.json`，支持通配符 `*` 和 `?`，路径工具支持目录前缀匹配。

### SSRF 防护

- 链路本地地址（169.254.0.0/16）和云元数据地址 → 硬拦截，审批无法覆盖
- 内网地址（回环、私有网段）→ 弹窗显示红色警告但可审批放行
- IPv4 映射 IPv6（`::ffff:`）正确识别，防止绕过
- 主机名 `localhost` 和 `*.localhost` 识别为回环

## Skill 系统

### 三级渐进式加载

| 层级 | 内容 | 加载时机 | Token 消耗 |
|------|------|---------|-----------|
| Level 1 | name + description | 会话启动时注入系统提示词，最多 20 个（按最近访问排序） | ~100 token/skill |
| Level 2 | SKILL.md 完整 body | Agent 调用 `skill("name")` 时加载 | 按需 |
| Level 3 | scripts/references 等资源 | Level 2 指令引用时加载 | 按需 |

### Skill 文件格式

```markdown
---
name: skill-name           # kebab-case, max 64 chars
description: Description   # 何时使用此 Skill
allowed-tools: file_read, web_search  # 可选：白名单工具列表
disable-model-invocation: true/false  # 可选
---
## Process
...
```

### 信任模型

- **用户级 Skills**（`~/.athena/skills/`）：始终信任
- **项目级 Skills**（`.athena/skills/`）：首次加载需用户确认信任弹窗
- 未信任时项目级 Skill 处于 INERT 状态：不注入提示词、不可加载、不覆盖用户级 Skill
- 信任状态持久化：`~/.athena/trusted_skill_dirs.json`
- 每次会话最多提示一次信任弹窗
- 项目级 Skill 在信任后可覆盖同名用户级 Skill

### 内置 Skill

- `self-evolve`：Agent 自我进化完整指南，通过 DI 注册为内置 Skill

## AI 提供商集成

使用 openai_dart v5.0.0 进行 API 调用：

- 每次请求创建新的 `OpenAIClient`，`finally` 中 `close()` 确保释放
- 自定义 HTTP headers：`HTTP-Referer` 和 `X-Title`
- 支持流式响应 + 工具调用 + 推理内容（reasoningContent）
- 重试机制（`lib/util/retry.dart`）：指数退避 + 随机抖动
  - 可重试：ConnectionException、Timeout、RateLimitException、5xx、SocketException、HandshakeException
  - 不重试：4xx、FormatException、已开始流式传输后失败不重试

## 关键组件

### Sentinels（哨兵）

- 预定义的系统提示词角色，用户可自定义
- AI 元数据生成：通过 SentinelService/MetadataGenerationPrompt 生成名称、描述、标签、Emoji 头像
- 内置默认 "Athena" Sentinel
- `ChatMessageService.buildMessages()` 将其作为 system prompt 注入消息列表头部
- Sentinel 支持按名称查找（先查内存信号，再查数据库）

### Agent 循环（AgentService.run）

```
for iteration in 0..maxIterations:
  首次迭代：注入 evolutionPrompt + skillPrompt (system 消息)
  调用 AI (流式) → 累积文本和 tool_calls
  if 无 tool_calls → done (返回最终内容)
  for each tool_call:
    权限检查: Skill allowed-tools? → 持久化规则? → 审批弹窗?
    if 拒绝 → tool_result = "User denied"
    else → 执行工具 → 结果 >4000 字符? → 辅助模型摘要压缩
  yield iterationComplete → 下一轮
```

### ChatViewModel

最复杂的 ViewModel，管理完整的聊天生命周期：

- 发送流程：保存用户消息 → 首条消息触发自动命名 → 构建上下文 → 启动 Agent 流 → 消费 AgentEvent（reasoning/text/toolCall/toolResult/done）
- 多轮迭代：每个 AgentIterationCompleteEvent 后 finalize 当前 assistant，append 新占位
- 取消/错误处理：`_latestStreamedMessage` 保证丢失前内容不丢失
- 流式冲突保护：删除正在流式输出的 chat 时先停流并等待 settle；后台重命名流有独立 CancelToken
- 批量操作支持：多选聊天（Cmd/Ctrl + Click / Shift + Click）+ 批量删除

### 平台判断

使用 `PlatformUtil`（`lib/util/platform_util.dart`）而非原始 `Platform`：
- `PlatformUtil.isDesktop` = macOS || Linux || Windows
- `PlatformUtil.isMobile` = iOS || Android
- 桌面端标题栏使用 `Microsoft YaHei`（Windows）/ 系统默认（macOS/Linux）
- Windows 上使用 `Platform.resolvedExecutable` 而非 `Process.runSync('which')`

## 开发注意事项

1. **代码生成依赖**：修改路由配置（`lib/router/router.dart`）后必须运行 `flutter pub run build_runner build`
2. **数据库迁移**：按时间顺序创建迁移文件，在 `Database._migrate()` 中按顺序调用
3. **平台判断**：使用 `PlatformUtil.isDesktop` / `isMobile` 而非原始 `Platform` 检查
4. **状态管理**：ViewModel 全部用 signals；UI 用 `Watch` widget；禁止混用 `setState`
5. **依赖注入**：新增 ViewModel 或 Agent 组件需在 `lib/di.dart` 注册 LazySingleton；构造参数接受可选注入以支持测试
6. **日志输出**：使用 `LoggerUtil.d/i/w/e()` 而非 `print()`
7. **工具开发**：实现 `Tool` 接口并在 `ToolRegistry` 注册
8. **Skill 开发**：创建 `SKILL.md` 文件放入 `.athena/skills/` 或 `~/.athena/skills/`
9. **AI 客户端生命周期**：每次请求创建 OpenAIClient，finally 中 close()；测试中通过 clientFactory 注入确保可验证
10. **数据实体**：所有 entity 使用不可变模式 + `copyWith` 方法；`fromJson`/`toJson` 通过 `JsonMapExtension` 安全读写
11. **测试**：Widget 测试使用 `test/test_utils/fakes.dart` 中的内存 fake repository；setupMobileTestDI() 注册最小化 DI
12. **取消令牌**：长时间操作使用 `CancelToken`（支持 `throwIfCancelled()` 和 `whenCancelled` 竞态）
