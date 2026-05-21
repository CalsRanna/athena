# Athena

<div align="center">

一个跨平台 AI Agent 应用，使用 Flutter 构建，具备内置工具调用能力和可扩展的 Skill 系统。

![Version](https://img.shields.io/badge/version-2.2.12-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.8.0+-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-lightgrey)

</div>

## 功能特性

### Agent 系统

- **内置工具**：Agent 可自主调用 Shell、文件读写、代码搜索等工具完成任务
- **权限控制**：三层权限模型（工具危险等级 × Skill 覆盖 × 用户规则），危险操作需用户确认
- **沙箱隔离**：路径级沙箱，防止 Agent 访问敏感目录
- **流式推理**：支持推理模型的思考过程实时展示

### Skill 系统

- **渐进式加载**：三级加载机制，只在使用时消耗上下文
- **自动匹配**：Agent 根据任务自主判断何时调用 Skill
- **可扩展**：用户可编写自定义 Skill（Markdown 格式），放入 `~/.athena/skills/`
- **项目级共享**：`.athena/skills/` 中 Skill 可随项目版本控制

### 核心功能

- **AI 聊天对话**：流式响应，多轮上下文管理，聊天历史保存
- **Sentinel 系统**：预定义角色和系统提示词，自定义 AI 助手人格
- **多 AI 提供商**：DeepSeek、OpenRouter、阿里云百炼、硅基流动、火山方舟等
- **视觉与推理**：支持视觉模型和推理模型（DeepSeek-R1 等）

### 扩展功能

- **网页摘要**：自动解析网页内容生成智能摘要
- **文本翻译**：AI 驱动的多语言翻译
- **网络搜索**：集成 Tavily 搜索，为 AI 提供实时信息
- **TRPG 游戏**：AI 驱动的桌面角色扮演游戏

### 平台

- **桌面端**：macOS、Windows、Linux，支持窗口管理和系统托盘
- **移动端**：iOS、Android，触摸优化

## 快速开始

### 环境要求

- Flutter SDK >= 3.8.0
- Dart SDK >= 3.8.0

### 安装

```bash
git clone https://github.com/CalsRanna/athena.git
cd athena
flutter pub get
flutter pub run build_runner build
```

### 运行

```bash
flutter devices          # 查看可用设备
flutter run -d <device>  # 运行
```

### 开发

```bash
flutter analyze  # 代码分析
flutter test     # 运行测试
```

## 架构

```
lib/
├── agent/          # Agent 层 — 工具、权限、Skill
│   ├── tool/       #   内置工具（search, file_read/write/delete, shell, skill）
│   ├── permission/ #   权限服务与沙箱
│   └── skill/      #   Skill 加载与注册
├── page/           # UI 层
│   ├── desktop/    #   桌面端页面
│   └── mobile/     #   移动端页面
├── view_model/     # 视图模型层（Signals 状态管理）
├── service/        # 服务层（ChatService, ChatMessageService 等）
├── repository/     # 数据访问层
├── entity/         # 数据库实体
├── database/       # 数据库管理和迁移
├── router/         # 路由配置（AutoRoute）
├── widget/         # 可复用组件
└── component/      # 业务组件
```

### 技术栈

- **UI**: Flutter
- **状态管理**: Signals
- **依赖注入**: GetIt
- **路由**: AutoRoute
- **数据库**: SQLite + Laconic ORM
- **API**: openai_dart v5.0.0（支持工具调用）

## 配置

### Skill 配置

Skill 是以 `SKILL.md` 为入口的目录：

```markdown
---
name: my-skill
description: What this skill does and when to use it
allowed-tools: Read, Grep
---
## Process
1. Step one
2. Step two
```

放置位置：
- `~/.athena/skills/` — 用户级（个人用）
- `.athena/skills/` — 项目级（版本控制）

Agent 会在推理时自主判断是否需要调用某个 Skill，通过内置的 `skill` 工具加载完整指令。

### AI 提供商配置

在设置中添加提供商，填写 API 地址和 Key。内置预设：

| 提供商 | 模型 |
|--------|------|
| DeepSeek | R1, V3 |
| OpenRouter | Claude, GPT, Gemini, Llama 等 |
| 阿里云百炼 | 通义千问系列, DeepSeek 系列 |
| 硅基流动 | DeepSeek 系列 |
| 火山方舟 | 豆包系列, DeepSeek 系列 |

## 贡献

1. Fork 仓库
2. 创建分支 (`git checkout -b feature/xxx`)
3. 提交 (`git commit -m 'Add xxx'`)
4. Push (`git push origin feature/xxx`)
5. 开 PR

## 许可证

MIT

---

<div align="center">

**[报告问题](https://github.com/CalsRanna/athena/issues)**

</div>
