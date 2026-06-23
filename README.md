# Athena

<div align="center">

一个跨平台 AI Agent 应用，使用 Flutter 构建。Athena 具备完整的 Agent 循环（推理 → 工具调用 → 结果 → 再推理）、内置 11 个工具（桌面端）、可自我进化的 Skill 系统、以及严谨的权限与安全模型。

![Version](https://img.shields.io/badge/version-3.3.0-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.8.0+-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-lightgrey)

</div>

## 核心能力

### Agent 系统

Athena 内置完整的 AI Agent，可自主调用工具完成复杂任务：

- **推理-工具循环**：Agent 在每轮迭代中进行推理、调用工具、获取结果、再推理，最大 100 轮可配置
- **流式响应**：文本和推理过程（reasoning）实时流式呈现
- **辅助模型摘要**：当工具结果超过 4000 字符时，自动调用辅助模型进行摘要压缩，节省上下文
- **取消令牌**：支持随时中断 Agent 运行，取消时保留已生成内容并标记 `[Cancelled]`
- **自动压缩**：上下文接近窗口上限时自动压缩早期对话为摘要，保持长对话可继续

#### 内置工具（桌面端 11 个，移动端 3 个）

| 工具 | 说明 |
|------|------|
| `bash` / `powershell` | 执行终端命令，支持自定义工作目录和超时（最高 600s），超时自动 kill 进程 |
| `file_read` | 读取文件，支持 offset/limit 分段读取和行号输出 |
| `file_write` | 创建或覆写文件，自动递归创建父目录 |
| `file_update` | 精确字符串替换编辑文件，支持 replace_all、自动去除行号前缀、智能引号归一化、外部修改检测 |
| `web_fetch` | HTTP GET/POST 抓取网页（200KB 上限），支持自定义 headers 和 body，自动 HTML→Markdown 转换 |
| `web_search` | Brave Search API 网络搜索，为 Agent 提供实时信息 |
| `skill` | 加载 Skill 的完整 Level 2 指令到当前上下文 |
| `skill_evolve` | Agent 自我进化：创建/更新 Skill（SKILL.md），扩展未来能力 |
| `experience_learn` | 记录经验教训到长期记忆，支持标签和上下文、Sentinel 私有或全局共享 |
| `experience_recall` | 检索过往经验以指导当前任务 |
| `sentinel_evolve` | 改进当前角色（系统提示词），支持重命名、原地更新，内置 Sentinel 不可改名 |

#### 权限模型

两层决策，简洁明了：

1. **用户持久化规则**：`~/.athena/permissions.json` 存储路径/命令前缀匹配规则，支持 `*` 和 `?` 通配符。命中则直接放行，不弹窗。
2. **审批弹窗**：无匹配规则时弹出完整命令预览弹窗（shell 命令全文展示不截断），用户可选 Allow/Deny 并决定是否记忆为持久化规则。弹窗不可被空白点击关闭。

#### 工具自我保护

独立于权限系统，在工具内部执行的安全检查：

- **递归删除拦截**：bash/powershell 检测到 `rm -rf`、`del /s` 等模式时拒绝执行
- **Shell 进程管理**：超时主动 SIGTERM → SIGKILL 杀死进程，防止孤儿进程泄漏
- **文件修改检测**：`file_update` 在写入前校验 mtime，防止覆盖外部并发修改

### Skill 系统

采用 Claude Code 风格的三级渐进式加载：

| 层级 | 内容 | 加载时机 | Token 消耗 |
|------|------|---------|-----------|
| Level 1 | name + description | 会话启动时全量注入系统提示词 | ~100 token/skill |
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

- `~/.athena/skills/` — 用户级（始终信任，所有项目可用）
- `.athena/skills/` — 项目级（可随版本控制，首次加载需用户确认信任）

项目级 Skill 在信任后可覆盖同名用户级 Skill。内置 `self-evolve` Skill 提供完整的自我进化指导。

#### 信任模型

- 未信任的项目级 Skill 不出现在 Level 1 列表，不可通过 `skill` 工具加载
- 信任状态持久化到 `~/.athena/trusted_skill_dirs.json`
- 每次会话仅提示一次信任弹窗
- 信任后 Skill 指令会注入系统提示词，但工具调用仍需经过权限检查

### Agent 自我进化

Agent 可通过三个机制持续改进自身：

- **Skill Evolution**（`skill_evolve`）：创建或改进 Skill，扩展未来能力
- **Experience Learning**（`experience_learn` / `experience_recall`）：构建长期经验记忆，存储在 `~/.athena/experiences/`
- **Sentinel Optimization**（`sentinel_evolve`）：基于使用反馈优化系统提示词

每次对话自动注入极简进化提示（~30 token），完整指南通过内置 `self-evolve` Skill 按需加载。

### 核心功能

- **Sentinel 系统**：预定义角色和系统提示词，支持 AI 元数据生成（名称、描述、标签、头像 Emoji），内置默认 "Athena" Sentinel
- **多 AI 提供商管理**：支持 OpenAI API 兼容的任何提供商，预设 DeepSeek、OpenRouter、阿里云百炼、硅基流动、火山方舟、智谱、MiniMax
- **重试机制**：指数退避 + 随机抖动，可重试网络错误（连接异常、超时、限流、5xx），不重试业务错误（4xx、解析错误）
- **聊天管理**：会话置顶、批量删除、AI 自动命名、上下文截断、温度参数调整、Token 用量追踪
- **视觉与推理**：支持视觉模型（图片附件）和推理模型（DeepSeek-R1 等 reasoning 展示）
- **数据导入/导出**：JSON 格式完整数据迁移，自动重整悬空引用

### 扩展功能

- **网页摘要**：AI 解析网页内容，生成结构化摘要
- **文本翻译**：AI 多语言翻译
- **网络搜索**：Brave Search 集成
- **TRPG 游戏**：AI 驱动的桌面角色扮演游戏，含行动建议和状态面板

### 平台支持

- **桌面端**：macOS、Windows、Linux。窗口管理、系统托盘、全局快捷键（Meta+W 隐藏）
- **移动端**：iOS、Android。触摸优化界面

## 快速开始

### 环境要求

- Flutter SDK >= 3.8.0
- Dart SDK >= 3.8.0

### 安装与运行

```bash
git clone https://github.com/CalsRanna/athena.git
cd athena
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run -d <device>
```

### 开发命令

```bash
flutter analyze       # 静态代码分析
flutter test          # 运行全部测试
flutter test test/agent/tool/  # 运行 Agent 工具测试
```

## 架构

```
lib/
├── agent/               # Agent 层
│   ├── tool/            #   12 个工具实现文件（11 个工具类 + 辅助文件）
│   ├── permission/      #   权限服务 + 持久化规则
│   ├── skill/           #   Skill 加载、注册、信任
│   └── evolution/       #   自我进化提示词
├── page/                # UI 层
│   ├── desktop/         #   桌面端页面（多区工作台）
│   └── mobile/          #   移动端页面（分段浏览）
├── view_model/          # 视图模型层（Signals 状态管理 + Delegate 委托）
│   └── delegate/        #   业务逻辑委托（3 个：流式、重命名、多选）
├── service/             # 服务层（12 个服务）
│   ├── chat_service.dart         # AI 网络通信（OpenAI 客户端生命周期 + 重试）
│   ├── llm_client.dart           # 统一 LLM API 客户端封装
│   ├── chat_message_service.dart # 消息格式转换（Entity → ChatMessage）
│   ├── chat_manage_service.dart  # 会话/消息持久化编排
│   ├── chat_support_service.dart  # UI 辅助操作（重命名、配置更新、图片导出）
│   ├── token_usage_service.dart  # Token 用量追踪（原子累加 + 快照覆盖写）
│   ├── data_migration_service.dart # 数据导入/导出、数据库重置
│   ├── model_resolver.dart       # 模型/Provider 解析 + fallback 逻辑
│   ├── sentinel_service.dart     # Sentinel 元数据 AI 生成
│   ├── summary_service.dart      # 网页摘要
│   ├── translation_service.dart  # 翻译
│   └── trpg_service.dart         # TRPG 游戏
├── repository/          # 数据访问层（8 个 repository）
├── entity/              # 数据库实体（11 个 entity）
├── database/            # SQLite + Laconic ORM + 迁移
├── router/              # AutoRoute 路由配置
├── widget/              # 可复用组件（20+ 组件，含设计系统）
├── component/           # 业务组件
├── util/                # 工具类（重试、日志、平台检测等）
├── extension/           # Dart 扩展方法
├── preset/              # 预设提示词模板（运行时使用）
└── model/               # 普通数据类（TokenUsage 等）
```

### 技术栈

| 层 | 技术 |
|----|------|
| UI | Flutter |
| 状态管理 | Signals（Computed、Signal、listSignal、setSignal） |
| 依赖注入 | GetIt（LazySingleton） |
| 路由 | AutoRoute（桌面无过渡，移动标准过渡） |
| 数据库 | SQLite + Laconic ORM（单一持久连接，PRAGMA foreign_keys = ON） |
| AI API | openai_dart v5.0.0（流式 + 工具调用 + 推理） |
| HTTP | http v1.x（web_fetch、web_search） |
| 测试 | flutter_test + 内存 fake repository |

### 分层架构

```
┌─────────────────────────────────────┐
│               UI Layer               │
│   page/desktop/    page/mobile/      │
│   widget/          component/        │
├─────────────────────────────────────┤
│          ViewModel Layer             │
│   signals (响应式) + Delegate 委托  │
├─────────────────────────────────────┤
│           Service Layer              │
│   网络通信 / 数据转换 / 持久化编排   │
├─────────────────────────────────────┤
│          Repository Layer            │
│   数据库访问封装（Laconic ORM）      │
├─────────────────────────────────────┤
│            Data Layer                │
│   Entity / Database / Migration      │
└─────────────────────────────────────┘
         ↕（通过 GetIt DI 垂直穿透）
   Agent Layer（Agent Service / Tool / Permission / Skill）
```

## 配置

### AI 提供商

在应用内设置页面添加 OpenAI API 兼容的提供商。预设包括：

| 提供商 | 内置模型示例 |
|--------|---------|
| DeepSeek | deepseek-chat, deepseek-reasoner |
| OpenRouter | Claude 3.5 Sonnet, GPT-4o, Gemini 2.0 Flash, Llama 3.3 等 |
| 阿里云百炼 | 通义千问系列, DeepSeek 系列 |
| 硅基流动 | DeepSeek 系列 |
| 火山方舟 | 豆包系列, DeepSeek 系列 |
| 智谱 | GLM 系列 |
| MiniMax | MiniMax-Text-01 |

### Skill 开发

1. 创建 `SKILL.md` 文件，包含 YAML front matter 和 Markdown body
2. 放入 `~/.athena/skills/<skill-name>/`（用户级）或 `.athena/skills/<skill-name>/`（项目级）
3. 重启应用或新开会话即可发现

### 权限管理

用户持久化规则存储在 `~/.athena/permissions.json`，格式：
```json
{
  "rules": [
    {"tool": "bash", "pattern": "git *"},
    {"tool": "file_read", "pattern": "/home/user/projects/*"}
  ]
}
```

## 测试

项目包含约 30 个测试文件，覆盖：

- **Agent 层**：工具执行、权限规则、Skill 加载与信任、Shell 进程管理
- **Service 层**：消息转换、聊天服务、会话管理
- **ViewModel 层**：聊天流、设置、摘要、翻译、TRPG
- **UI 层**：移动端主页和聊天页 widget 测试
- **数据库**：迁移、CASCADE 行为验证

```bash
flutter test  # 运行全部测试
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
