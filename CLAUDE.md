# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Athena 是一个跨平台的 AI Agent 应用，使用 Flutter 构建，支持桌面端（macOS、Linux、Windows）和移动端（iOS、Android）。Athena 具备内置工具调用能力，可执行 Shell 命令、读写文件、搜索代码库，并支持通过 Skill 系统扩展能力。

## 开发环境设置

### 依赖管理
```bash
# 安装依赖
flutter pub get

# 代码生成（路由和数据库迁移）
flutter pub run build_runner build

# 清理并重新生成
flutter pub run build_runner build --delete-conflicting-outputs
```

### 测试和验证
```bash
# 运行测试
flutter test

# 分析代码
flutter analyze

# 运行单个测试文件
flutter test test/widget_test.dart
```

### 运行应用
```bash
# 查看可用设备
flutter devices

# 运行应用（指定设备）
flutter run -d <device-id>

# 调试模式运行
flutter run --debug

# 发布模式运行
flutter run --release
```

## 架构设计

### 分层架构

项目采用清晰的分层架构：

1. **UI 层** (`lib/page/`)
   - `desktop/`: 桌面端页面
   - `mobile/`: 移动端页面
   - 根据平台自动选择对应的路由入口（见 `lib/router/router.dart`）

2. **视图模型层** (`lib/view_model/`)
   - 使用 Signals 库实现响应式状态管理
   - 通过 GetIt 进行依赖注入（见 `lib/di.dart`）
   - 核心 ViewModels：
     - `ChatViewModel`: 聊天会话管理，集成 Agent 编排
     - `ModelViewModel`: AI 模型管理与默认模型解析
     - `ProviderViewModel`: AI 提供商（如 OpenAI）管理
     - `SentinelViewModel`: 系统提示词（角色）管理
     - `SettingViewModel`: 应用设置管理
     - `SummaryViewModel`: 网页摘要功能
     - `TranslationViewModel`: 翻译功能
     - `TRPGViewModel`: TRPG 游戏功能
     - `MemoryViewModel`: 用户记忆管理

3. **Agent 层** (`lib/agent/`)
   - `AgentService`: Agent 循环编排（推理 → 工具调用 → 结果 → 再推理）
   - `tool/`: 内置工具实现（共 11 个工具，部分按平台二选一）
     - `tool_interface.dart`: 工具抽象接口与 DangerLevel 枚举（safe / needsApproval / forbidden）
     - `tool_registry.dart`: 工具注册表
     - `unix_search_tool.dart` / `powershell_search_tool.dart`: grep/find 代码搜索（按平台）
     - `file_read_tool.dart`: 读取文件，支持 offset/limit
     - `file_write_tool.dart`: 创建或覆写文件
     - `file_update_tool.dart`: 精确字符串替换编辑文件
     - `file_delete_tool.dart`: 删除文件
     - `list_directory_tool.dart`: 列出目录内容
     - `bash_shell_tool.dart` / `powershell_shell_tool.dart`: Shell 命令执行（按平台）
     - `web_fetch_tool.dart`: HTTP GET 抓取网页（含 SSRF 防护）
     - `web_search_tool.dart`: Brave Search API 网络搜索
     - `skill_tool.dart`: 加载 Skill 完整指令
   - `permission/`: 权限与沙箱
     - `permission_service.dart`: 三层权限模型（工具等级 × Skill 硬下限 × 用户规则）
     - `permission_rule.dart`: 路径前缀匹配与持久化规则存储
     - `sandbox.dart`: 路径沙箱（黑名单模型）
   - `skill/`: Skill 系统
     - `skill_loader.dart`: 解析 SKILL.md 文件
     - `skill_registry.dart`: Skill 注册与三级渐进式加载、allowed-tools 降权 + 危险工具硬下限
     - `skill_trust_store.dart`: 项目级 Skill 信任状态持久化

4. **服务层** (`lib/service/`)
   - `ChatService`: AI 提供商网络通信（OpenAIClient 生命周期、重试、流式/非流式请求）
   - `ChatMessageService`: 消息格式转换（Entity → OpenAI ChatMessage，含 system prompt、截断、tool_calls/tool_results 展开、图片处理）
   - `ChatManageService`: 会话与消息持久化编排（CRUD、占位/最终化、取消/错误标记）
   - `ChatSupportService`: UI 辅助操作（重命名、模型/哨兵/上下文字段更新、图片保存）
   - `MemoryService`: 用户记忆管理
   - `SentinelService`: Sentinel 元数据 AI 生成
   - `SummaryService`: 网页摘要
   - `TranslationService`: 文本翻译
   - `TRPGService`: TRPG 游戏逻辑

5. **数据层**
   - `lib/repository/`: 数据访问层，封装数据库操作
   - `lib/entity/`: 数据库实体定义（MessageEntity 含 tool_calls/tool_results 字段）
   - `lib/database/`: 数据库管理和迁移

### 数据库系统

使用 Laconic ORM 管理 SQLite 数据库：

- 数据库文件位置：Application Support 目录下的 `athena.db`
- 迁移文件命名规范：`migration_YYYYMMDDNNNN_description.dart`
- 迁移按时间顺序执行（见 `lib/database/database.dart`）
- Laconic 使用单一持久连接，`PRAGMA foreign_keys = ON` 一次设置全程生效，CASCADE 可靠
- 首次启动时会自动预设默认的 AI 提供商和模型

**添加新迁移的步骤**：
1. 在 `lib/database/migration/` 创建新迁移文件
2. 在 `Database._migrate()` 方法中按顺序添加迁移调用
3. 运行应用以应用迁移

### 路由系统

使用 AutoRoute 进行声明式路由：

- 路由配置：`lib/router/router.dart`
- 生成的路由代码：`lib/router/router.gr.dart`
- 桌面端使用无过渡动画的 `DesktopRoute`
- 移动端使用标准的 `AutoRoute`
- 根据平台（`Platform.isMacOS || Platform.isLinux || Platform.isWindows`）自动选择初始路由

**修改路由后需要运行代码生成**：
```bash
flutter pub run build_runner build
```

### 依赖注入

使用 GetIt 进行依赖注入：

- 配置文件：`lib/di.dart`
- 所有 ViewModels、Services、Agent 组件注册为 `LazySingleton`
- ViewModels 的构造参数均接受可选注入（测试时可传 fake），生产路径通过 GetIt 回退解析
- 在 `main.dart` 的 `main()` 函数中初始化

### 状态管理

使用 Signals 库实现细粒度响应式状态管理：

- ViewModels 中的状态使用 `Signal`、`Computed` 等
- UI 通过 `Watch` widget 自动响应状态变化
- 在 `main.dart` 中设置 `SignalsObserver.instance = null` 以避免不必要的日志

## Agent 系统

### 内置工具

Athena 内置 11 个工具（部分按平台提供不同实现），Agent 可自主决定调用时机：

| 工具 | 危险等级 | 说明 |
|---|---|---|
| `search` | needsApproval | grep 搜索文件内容 / find 搜索文件名 |
| `file_read` | needsApproval | 读取文件，支持 offset/limit |
| `file_write` | needsApproval | 创建或覆写文件 |
| `file_update` | needsApproval | 精确字符串替换编辑文件 |
| `file_delete` | needsApproval | 删除文件 |
| `list_directory` | needsApproval | 列出目录内容 |
| `bash` / `powershell` | needsApproval | 执行终端命令，按平台二选一 |
| `web_fetch` | needsApproval | HTTP GET 抓取网页（含 SSRF 硬拦截 + 内网告警） |
| `web_search` | safe | Brave Search API 网络搜索 |
| `skill` | safe | 加载 Skill 的完整指令 |

### 权限模型

三层权限判定：
1. **工具默认危险等级**：safe 自动执行，needsApproval 弹窗确认，forbidden 拒绝执行
2. **Skill 硬下限**：危险工具集（bash/powershell/file_write/file_update/file_delete/web_fetch）永不被 Skill 的 `allowed-tools` 降为 safe
3. **用户规则**：`~/.athena/permissions.json` 可配置路径/命令持久化允许规则

审批流程：
- `needsApproval` 工具进入审批弹窗（完整命令展示、支持滚动）
- 危险操作（`isDangerous` 返回 true）不可持久化允许
- web_fetch 内网 URL 标红警告但可单次审批，链路本地/云元数据硬拦截
- 取消令牌在等待审批时可中断并返回拒绝

### 沙箱

PathSandbox 提供**黑名单模型**的路径隔离：

- 默认黑名单：`~/.ssh`、`~/.aws`、`/etc`、`/System`、应用数据目录（含 `athena.db`）
- 工作区为黑名单外的整台电脑，文件操作由审批兜底
- `canRead`/`canWrite` 在文件操作前校验路径
- `canExecute` 对 shell 命令做静态 deny 检查（危险命令如 `rm -rf` 变体、重定向、管道等）
- 路径在权限检查与规则匹配前统一 canonical 化（解析 `~`、`..`、symlink）

## Skill 系统

采用 Claude Code 风格的三级渐进式加载：

| 层级 | 内容 | 加载时机 |
|---|---|---|
| Level 1 | name + description | 会话启动时全量加载，~100 token/skill |
| Level 2 | SKILL.md 完整指令 | Agent 调用 `Skill("name")` 时 |
| Level 3 | scripts/references 等资源 | Level 2 指令引用时 |

### 信任模型

- **用户级 Skills**（`~/.athena/skills/`）：始终信任
- **项目级 Skills**（`.athena/skills/`）：首次加载需用户确认信任，未信任前不注入 Level 1 提示词、不生效 allowed-tools 降权
- 信任状态持久化到 `~/.athena/trusted_skill_dirs.json`
- 项目级 Skill 优先级覆盖用户级同名 Skill（仅在已信任时）

### Skill 文件格式

Skill 是以 `SKILL.md` 为入口的目录：

```
~/.athena/skills/          # 用户级
└── code-reviewer/
    └── SKILL.md

.athena/skills/             # 项目级（版本控制，需信任）
└── migration-review/
    ├── SKILL.md
    └── references/
```

SKILL.md 格式：

```markdown
---
name: code-reviewer
description: Review code for bugs and style issues
allowed-tools: Read, Grep, Glob
---
## Process
1. Read changed files
2. Report issues by severity
```

Agent 主动调用 `Skill("code-reviewer")` 加载 Level 2 完整指令。

## AI 提供商集成

使用 openai_dart v5.0.0 进行 API 调用：

- 支持流式响应与工具调用
- 兼容 OpenAI API 格式的各类提供商
- 自定义 HTTP headers（Referer 和 X-Title）
- 每次请求创建 OpenAIClient，finally 中 close() 确保释放
- 重试机制基于异常类型判定（ConnectionException/Timeout/RateLimit/5xx 可重试，4xx/解析错误不重试）
- 提供商和模型信息存储在数据库中

## 关键组件

- **Sentinels（哨兵）**: 预定义的系统提示词和角色设定，支持 AI 元数据生成
- **Agent**: 具备工具调用能力的 AI Agent，可执行搜索、文件操作、Shell 命令
- **Skills**: Claude Code 风格的可扩展能力模块
- **TRPG**: 桌面角色扮演游戏功能，包含游戏状态和消息管理

## 平台特定功能

### 桌面端
- 窗口管理（`window_manager`）
- 系统托盘（`tray_manager`）
- Windows 上使用微软雅黑字体

### 移动端
- 标准 Flutter 移动端 UI 模式
- 触摸优化的交互

## 开发注意事项

1. **代码生成依赖**：修改路由配置或添加数据库迁移后，务必运行 `flutter pub run build_runner build`
2. **数据库迁移**：按时间顺序创建迁移文件，避免跳过序号
3. **平台判断**：使用 `Platform.isMacOS || Platform.isLinux || Platform.isWindows` 判断桌面端
4. **状态管理**：ViewModel 中的响应式状态使用 Signals，页面 UI 统一用信号避免 setState/signals 混用
5. **依赖注入**：新增 ViewModel 或 Agent 组件需要在 `lib/di.dart` 中注册；构造参数接受可选注入以支持测试
6. **日志输出**：使用 `LoggerUtil` 而不是 `print()`
7. **工具开发**：新增内置工具实现 `Tool` 接口并在 ToolRegistry 注册
8. **Skill 开发**：创建 `SKILL.md` 文件放入 `.athena/skills/` 或 `~/.athena/skills/`
