# Athena

<div align="center">

一个跨平台 AI Agent 应用，使用 Flutter 构建。Athena 具备完整的 Agent 循环（推理 → 工具调用 → 结果 → 再推理）、内置 13 个工具实现类（桌面端注册 13 个、移动端 9 个）、可自我进化的 Skill 系统、以及严谨的权限与安全模型。桌面端（GUI）、移动端（GUI）与终端（TUI）三种客户端共用同一套 Agent 引擎。

![Version](https://img.shields.io/badge/version-3.6.1-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.8.0+-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-lightgrey)

</div>

## 核心能力

### Agent 系统

Athena 内置完整的 AI Agent，可自主调用工具完成复杂任务：

- **推理-工具循环**：Agent 在每轮迭代中进行推理、调用工具、获取结果、再推理，最大 100 轮可配置
- **并行工具执行**：同一轮内可并行的工具调用（只读/已放行）自动分组并发执行，最多 8 个并发，信号量限流，取消优先响应
- **流式响应**：文本和推理过程（reasoning）实时流式呈现，工具调用卡片随流实时产出（参数增量逐片追加）
- **参数校验**：工具调用参数在执行前经过 JSON Schema 校验，非法参数直接拒绝并返回错误信息
- **截断保护**：响应被输出 token 上限切断时拒绝执行工具调用，防止截断参数被误执行
- **工具输出保护**：工具结果超过 12000 字符时自动保留头尾、截断中间，防止过长输出挤占上下文
- **取消令牌**：支持随时中断 Agent 运行，取消时保留已生成内容并标记 `[Cancelled]`
- **自动压缩**：上下文占用超过窗口 80% 时自动将早期对话压缩为摘要（`retention = -1` 模式），保持长对话可继续
- **消息注入**：支持运行时注入 steering 消息（当前轮工具执行后、下一轮推理前）与 followUp 消息（Agent 停止后继续运行）

#### 内置工具（桌面端 14 个，移动端 10 个）

| 工具 | 说明 |
|------|------|
| `bash` / `powershell` | 执行终端命令，支持自定义工作目录和超时（默认上限 3600s，可用环境变量 `ATHENA_SHELL_MAX_TIMEOUT` 覆盖），超时自动 kill 进程 |
| `file_read` | 读取文件，支持 offset/limit 分段读取和行号输出 |
| `file_write` | 创建或覆写文件，自动递归创建父目录 |
| `file_update` | 精确字符串替换编辑文件，支持 replace_all、自动去除行号前缀、智能引号归一化、外部修改检测 |
| `web_fetch` | HTTP GET/POST 抓取网页（200KB 上限），支持自定义 headers 和 body，自动 HTML→Markdown 转换 |
| `web_search` | Brave Search API 网络搜索，为 Agent 提供实时信息 |
| `skill` | 加载 Skill 的完整 Level 2 指令到当前上下文 |
| `skill_evolve` | Agent 自我进化：创建/更新 Skill（SKILL.md），扩展未来能力 |
| `experience_learn` | 经现有危险工具审批后记录/更新/归档长期经验，支持 Sentinel 私有或全局共享 |
| `experience_recall` | 检索过往经验以指导当前任务 |
| `sentinel_list` / `sentinel_get` | 列出 Sentinel 或读取完整角色配置 |
| `sentinel_evolve` | 改进当前角色（系统提示词），支持重命名、原地更新，内置 Sentinel 不可改名 |
| `sentinel_revert` | 回滚 Sentinel 最近一次演进，恢复历史快照 |

#### 权限模型

三层决策，自动放行绝大多数调用：

1. **只读短路**：只读工具（file_read、web_fetch、web_search）和只读 shell 命令（ls、git status 等）永不弹窗
2. **会话级缓存**：当前对话中已批准过的调用直接放行，同一轮内不再重复弹窗
3. **用户持久化规则**：`~/.athena/permissions.json` 存储匹配规则，支持 `*` 和 `?` 通配符；shell 命令可记忆为动作级规则（如 `git push*`）。命中则直接放行，不弹窗。

未命中时弹出完整命令预览弹窗（shell 命令全文展示不截断），用户可选 Allow/Deny，并可将本次批准记忆为会话级或持久化规则。弹窗不可被空白点击关闭。

#### 工具自我保护

独立于权限系统，在工具内部执行的安全检查：

- **递归删除拦截**：bash/powershell 检测到 `rm -rf`、`del /s` 等模式时拒绝执行
- **Shell 进程管理**：超时主动 SIGTERM → SIGKILL 杀死进程，防止孤儿进程泄漏
- **文件修改检测**：`file_update` 在写入前校验 mtime，防止覆盖外部并发修改

### Skill 系统

采用 Claude Code 风格的三级渐进式加载：

| 层级 | 内容 | 加载时机 | Token 消耗 |
|------|------|---------|-----------|
| Level 1 | name + description（最近使用 Top 20，按访问时间排序） | 由 `skill` 工具按名加载时提示可用技能清单（当前版本未在会话启动时自动注入） | 按需 |
| Level 2 | SKILL.md 完整指令 | Agent 调用 `skill("name")` 时按需加载 | 按需 |
| Level 3 | scripts/references 等资源 | Level 2 指令引用时加载 | 按需 |

最多展示最近使用的 20 个 Skill（按访问时间排序），其余需显式调用。

#### Skill 文件格式

```markdown
---
name: my-skill
description: What this skill does and when to use it
allowed-tools: file_read, web_search
---
## Process
1. Step one
2. Step two
```

#### 放置位置

- `~/.athena/skills/` — 用户级（移动端为应用沙盒内目录），对所有对话可用

Skill 指令会注入系统提示词，但工具调用仍需经过权限检查。内置 `self-evolve` Skill 提供完整的自我进化指导。

### Agent 自我进化

Agent 可通过以下机制持续改进自身：

- **Skill Evolution**（`skill_evolve`）：创建或改进 Skill，扩展未来能力
- **Experience Learning**（`experience_learn` / `experience_recall`）：经现有权限审批构建长期经验记忆，存储在 `~/.athena/experiences/`
- **Failure Reflection**：最大迭代或同一工具重复失败时生成候选经验；候选仍以普通 `experience_learn` 调用进入现有审批和执行管线
- **Sentinel Optimization**（`sentinel_evolve`）：基于使用反馈优化系统提示词
- **Sentinel Revert**（`sentinel_revert`）：回滚最近一次演进（`.athena` 沙盒内的历史快照）

每次任务都会临时注入当前 Sentinel 可见的全部 active Memory lesson（不写入消息历史、不按当前任务动态筛选）；只有经验新增、更新或归档时目录才变化。`context` 与标签通过 `experience_recall` 按需读取，同时注入极简进化提示；完整指南通过内置 `self-evolve` Skill 按需加载。

### 核心功能

- **Sentinel 系统**：预定义角色和系统提示词，支持 AI 元数据生成（名称、描述、标签、头像 Emoji），内置默认 "Athena" Sentinel
- **多 AI 提供商管理**：支持 OpenAI API 兼容的任何提供商，预设 DeepSeek、OpenRouter、阿里云百炼、硅基流动、火山方舟、智谱、MiniMax；启动时后台自动从 models.dev 同步模型元数据（7 天缓存，失败降级）
- **重试机制**：指数退避 + 随机抖动，可重试网络错误（连接异常、超时、限流、5xx），不重试业务错误（4xx、解析错误）
- **聊天管理**：会话置顶、批量删除、AI 自动命名、上下文管理（零上下文 / 自动压缩 / 全量）、温度参数调整、Token 用量追踪
- **视觉与推理**：支持视觉模型（图片附件）和推理模型（DeepSeek-R1 等 reasoning 展示）
- **数据导入/导出**：JSON 格式完整数据迁移，自动重整悬空引用

### 快捷入口（Shortcut）

内置 5 个场景化快捷入口（Translation、Summary、Food、Code、TRPG），每个绑定独立的专属 Sentinel（能力配置）：

- 点击后以其绑定 Sentinel 身份发起对话，支持**场景级 JSON 输出模式**（模型直接产出结构化 JSON）
- Translation / Summary / TRPG 快捷入口直接打开对应的定制功能页，Food / Code 进入默认聊天页

### 扩展功能

- **网页摘要**：AI 解析网页内容，生成结构化摘要
- **文本翻译**：AI 多语言翻译
- **网络搜索**：Brave Search 集成
- **TRPG 游戏**：AI 驱动的桌面角色扮演游戏，含行动建议和状态面板

### 平台支持

- **桌面端**：macOS、Windows、Linux。窗口管理、系统托盘、全局快捷键（Meta+W 隐藏）
- **移动端**：iOS、Android。触摸优化界面
- **终端**：athena_tui（nocterm），数据独立存储于 `~/.athena/tui/`（JSONL），与 GUI 的 SQLite 互不干扰

## 快速开始

### 环境要求

- Flutter SDK >= 3.8.0
- Dart SDK >= 3.8.0

### 安装与运行

项目为 monorepo 多包结构：`athena_core`（纯 Dart 核心）、`athena_gui`（Flutter 桌面/移动应用）与 `athena_tui`（终端客户端）。

```bash
# GUI（桌面 / 移动）
git clone https://github.com/CalsRanna/athena.git
cd athena/packages/athena_gui
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d <device>

# TUI（终端）
cd ../athena_tui
dart pub get
dart run bin/athena.dart
```

### 开发命令

```bash
# GUI（Flutter 应用）
cd packages/athena_gui
flutter analyze       # 静态代码分析
flutter test          # 运行 GUI 测试

# 核心（纯 Dart，无 Flutter 依赖）
cd packages/athena_core
dart analyze
dart test             # 运行核心测试（Agent 引擎、服务、工具等）
```

## 架构

项目拆分为三个 package，依赖方向严格单向：`athena_gui → athena_core`、`athena_tui → athena_core`。

```
packages/
├── athena_core/         # ★ 纯 Dart 核心，零 Flutter / 零 SQL 依赖
│   ├── agent/           #   Agent 引擎：工具、权限、Skill、进化、取消令牌
│   ├── coordinator/     #   AgentRunCoordinator：UI 无关的 run 编排层（RunEvent 流）
│   ├── service/         #   LlmClient、Chat、Summary、Translation、TRPG 等
│   ├── repository/      #   存储接口（Chat/Message/Model/Provider/...）
│   ├── entity/ model/ preset/ extension/ util/
│   └── storage/         #   KeyValueStore 接口 + AgentSettings
├── athena_gui/          # ★ Flutter 桌面/移动应用
│   ├── page/            #   UI 层（desktop 多区工作台 / mobile 分段浏览）
│   ├── view_model/      #   Signals 状态管理
│   │   └── delegate/    #   AgentStreamDelegate：包装核心协调层 + 对话框注入
│   ├── repository/      #   SQLite 实现（SqliteChatRepository 等）
│   ├── database/        #   SQLite + Laconic ORM + 迁移
│   ├── router/ widget/ component/ util/
│   └── storage/         #   KeyValueStore 的 SharedPreferences 实现
└── athena_tui/          # ★ 终端客户端（nocterm）
    ├── bin/athena.dart  #   CLI 入口
    ├── bridge/          #   tui_agent_bridge：Agent 引擎 → TUI 状态桥
    ├── ui/ view_model/  #   终端 UI 与响应式层
    └── storage/         #   JSONL/JSON 文件存储（会话 / 模型 / 角色）
```

核心通过**存储接口**（`repository/`）与**注入回调**（权限审批）
与持久化策略解耦：GUI 用 SQLite + SharedPreferences；TUI 已实现同一组
接口的 JSONL/JSON 文件存储（`athena_tui/lib/storage/`，如 `jsonl_session_repository.dart`）。

### 技术栈

| 层 | 技术 |
|----|------|
| UI | Flutter（athena_gui）/ nocterm（athena_tui） |
| 核心 | 纯 Dart（athena_core，零 Flutter 依赖） |
| 状态管理 | Signals（Computed、Signal、listSignal、setSignal） |
| 依赖注入 | GetIt（LazySingleton，仅客户端装配层） |
| 路由 | AutoRoute（桌面无过渡，移动标准过渡） |
| 数据库 | SQLite + Laconic ORM（GUI 侧实现，PRAGMA foreign_keys = ON） |
| AI API | openai_dart ^8.1.0（流式 + 工具调用 + 推理） |
| HTTP | http v1.x（web_fetch、web_search） |
| 测试 | athena_core：`dart test`；athena_gui：`flutter test` |

### 分层架构

```
┌─────────────────────────────────────────────┐
│            athena_gui（Flutter）             │
│  UI Layer（page / widget / component）      │
│  ViewModel Layer（signals + Delegate 委托） │
│  SQLite 实现（repository / database）       │
├─────────────────────────────────────────────┤
│            athena_core（纯 Dart）            │
│  AgentRunCoordinator（run 编排层，RunEvent）│
│  Service Layer（LLM 通信 / 数据转换 / 编排）│
│  Repository 接口（存储抽象，port）          │
│  Agent Layer（Agent Service / Tool /        │
│              Permission / Skill）           │
│  Entity / Storage / Util                    │
└─────────────────────────────────────────────┘
   GUI 通过 GetIt 装配：注入 SQLite 实现 + 权限弹窗；
   TUI 注入 JSONL/文件存储 + stdin 权限审批
```

## 配置

### AI 提供商

在应用内设置页面添加 OpenAI API 兼容的提供商。预设包括：

| 提供商 | 内置模型示例 |
|--------|---------|
| DeepSeek | deepseek-chat, deepseek-reasoner |
| OpenRouter | Claude 系列、Gemini 系列、GPT-5 / o3 / o4 系列、DeepSeek、Qwen3、Grok、MiniMax（按家族保留最新版） |
| 阿里云百炼 | 通义千问系列, DeepSeek 系列 |
| 硅基流动 | DeepSeek 系列 |
| 火山方舟 | 豆包系列, DeepSeek 系列 |
| 智谱 | GLM 系列 |
| MiniMax | MiniMax-Text-01 |

> 模型元数据（名称、上下文窗口、价格、reasoning/vision 标志）由应用启动时后台从 [models.dev](https://models.dev) 自动同步，预设模型列表随上游更新，无需手工维护。

### Skill 开发

1. 创建 `SKILL.md` 文件，包含 YAML front matter 和 Markdown body
2. 放入 `~/.athena/skills/<skill-name>/`（移动端为应用沙盒内目录）
3. 重启应用或新开会话即可发现

### 权限管理

用户持久化规则存储在 `~/.athena/permissions.json`，格式：
```json
{
  "rules": [
    {"tool": "bash", "action": "git", "pattern": "push*"},
    {"tool": "bash", "pattern": "ls *"},
    {"tool": "file_read", "pattern": "/home/user/projects/*"},
    {"tool": "web_fetch", "pattern": "https://example.com"}
  ]
}
```

- 文件类工具（file_read / file_write / file_update）：pattern 为路径，支持 `*` / `?` 通配符
- Shell 工具（bash / powershell）：action 为命令动作（git、ls、npm…），pattern 为参数模式；不加通配符时按前缀匹配
- web_fetch：pattern 为 URL origin（scheme://host[:port]）
- pattern 为空表示允许该工具（及 action，若指定）的所有调用

## 测试

项目为三包结构，测试覆盖：

- **Agent 层**（athena_core）：工具执行、并行执行分组、权限规则、Skill 加载、Shell 进程管理、Schema 校验
- **Service 层**（athena_core）：消息转换、聊天服务、会话管理、模型目录同步
- **ViewModel 层**（athena_gui）：聊天流、设置、摘要、翻译、TRPG
- **UI 层**（athena_gui）：移动端主页和聊天页 widget 测试
- **数据库**（athena_gui）：迁移、CASCADE 行为验证

```bash
# 核心包（纯 Dart）
cd packages/athena_core && dart test

# GUI 包（Flutter）
cd packages/athena_gui && flutter test

# TUI 包
cd packages/athena_tui && dart test
```

## 贡献

1. Fork 仓库
2. 创建功能分支 (`git checkout -b feature/xxx`)
3. 提交更改 (`git commit -m 'Add xxx'`)
4. 推送 (`git push origin feature/xxx`)
5. 创建 Pull Request

## 许可证

MIT License

---

<div align="center">

**[报告问题](https://github.com/CalsRanna/athena/issues)**

</div>
