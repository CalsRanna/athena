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
     - `ModelViewModel`: AI 模型管理
     - `ProviderViewModel`: AI 提供商（如 OpenAI）管理
     - `SentinelViewModel`: 系统提示词（角色）管理
     - `SettingViewModel`: 应用设置管理
     - `TRPGViewModel`: TRPG 游戏功能
     - `MemoryViewModel`: 用户记忆管理

3. **Agent 层** (`lib/agent/`) — 新增
   - `AgentService`: Agent 循环编排（推理 → 工具调用 → 结果 → 再推理）
   - `tool/`: 内置工具实现
     - `tool_interface.dart`: 工具抽象接口与危险等级定义
     - `tool_registry.dart`: 工具注册表
     - `search_tool.dart`: grep/find 代码搜索
     - `file_read_tool.dart`: 文件读取
     - `file_write_tool.dart`: 文件写入
     - `file_delete_tool.dart`: 文件删除
     - `shell_tool.dart`: Shell 命令执行
     - `skill_tool.dart`: Skill 加载
   - `permission/`: 权限与沙箱
     - `permission_service.dart`: 三层权限模型（工具等级 × Skill 覆盖 × 用户规则）
     - `sandbox.dart`: 路径沙箱
   - `skill/`: Skill 系统
     - `skill_loader.dart`: 解析 SKILL.md 文件
     - `skill_registry.dart`: Skill 注册与三级渐进式加载

4. **服务层** (`lib/service/`)
   - `ChatService`: 处理与 AI 提供商的聊天 API 请求（支持 tools 参数）
   - `ChatMessageService`: 消息格式转换与流式处理
   - `SearchService`: Tavily 搜索集成
   - `TranslationService`: 翻译功能
   - `SummaryService`: 文本摘要功能
   - `TRPGService`: TRPG 游戏逻辑
   - `MemoryService`: 用户记忆管理

5. **数据层**
   - `lib/repository/`: 数据访问层，封装数据库操作
   - `lib/entity/`: 数据库实体定义（MessageEntity 含 tool_calls/tool_results 字段）
   - `lib/database/`: 数据库管理和迁移

### 数据库系统

使用 Laconic ORM 管理 SQLite 数据库：

- 数据库文件位置：Application Support 目录下的 `athena.db`
- 迁移文件命名规范：`migration_YYYYMMDDNNNN_description.dart`
- 迁移按时间顺序执行（见 `lib/database/database.dart`）
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

使用 GetIt 进行服务定位：

- 配置文件：`lib/di.dart`
- 所有 ViewModels、Agent 组件注册为 `LazySingleton`
- 在 `main.dart` 的 `main()` 函数中初始化

### 状态管理

使用 Signals 库实现细粒度响应式状态管理：

- ViewModels 中的状态使用 `Signal`、`Computed`、`Effect` 等
- UI 自动响应状态变化
- 在 `main.dart` 中设置 `SignalsObserver.instance = null` 以避免不必要的日志

## Agent 系统

### 内置工具

Athena 内置 6 个工具，Agent 可自主决定调用时机：

| 工具 | 危险等级 | 说明 |
|---|---|---|
| `search` | safe | grep 搜索文件内容 / find 搜索文件名 |
| `file_read` | safe | 读取文件，支持 offset/limit |
| `file_write` | needsApproval | 创建或覆写文件 |
| `file_delete` | needsApproval | 删除文件 |
| `shell` | needsApproval | 执行终端命令，支持超时和工作目录 |
| `skill` | safe | 加载 Skill 的完整指令 |

### 权限模型

三层权限判定：
1. **工具默认危险等级**：safe 自动执行，needsApproval 弹窗确认，forbidden 拒绝
2. **Skill 覆盖**：Skill 的 `allowed-tools` 字段可声明免审批工具
3. **用户规则**：`~/.athena/permissions.json` 可配置路径/命令白名单

### 沙箱

PathSandbox 提供路径级隔离：
- 默认白名单：当前项目目录
- 默认黑名单：`~/.ssh`、`~/.aws`、`/etc`、`/System`
- 文件操作前校验，shell 命令基础防护

## Skill 系统

采用 Claude Code 风格的三级渐进式加载：

| 层级 | 内容 | 加载时机 |
|---|---|---|
| Level 1 | name + description | 会话启动时全量加载，~100 token/skill |
| Level 2 | SKILL.md 完整指令 | Agent 调用 `Skill("name")` 时 |
| Level 3 | scripts/references 等资源 | Level 2 指令引用时 |

### Skill 文件格式

Skill 是以 `SKILL.md` 为入口的目录：

```
~/.athena/skills/          # 用户级
└── code-reviewer/
    └── SKILL.md

.athena/skills/             # 项目级（版本控制）
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
- 提供商和模型信息存储在数据库中

## 关键组件

- **Sentinels（哨兵）**: 预定义的系统提示词和角色设定
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
4. **状态管理**：ViewModel 中的响应式状态使用 Signals，避免手动 setState
5. **依赖注入**：新增 ViewModel 或 Agent 组件需要在 `lib/di.dart` 中注册
6. **日志输出**：使用 `LoggerUtil` 而不是 `print()`
7. **工具开发**：新增内置工具实现 `Tool` 接口并在 ToolRegistry 注册
8. **Skill 开发**：创建 `SKILL.md` 文件放入 `.athena/skills/` 或 `~/.athena/skills/`
