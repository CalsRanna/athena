# Athena Agent 转型设计方案

将 Athena 从聊天助手转型为具备工具调用能力的 AI Agent。

## 目标

- 放弃 MCP，改用内置工具（Shell、文件系统、搜索）
- 实现 Claude Code 风格的 Skill 系统（三级渐进式加载）
- 权限与沙箱机制，用户可控
- 桌面端优先

## 整体架构

在现有分层基础上新增 `lib/agent/` 层：

```
lib/
├── agent/                          # 新增：Agent 层
│   ├── agent_service.dart          # Agent 循环编排
│   ├── tool/
│   │   ├── tool_interface.dart     # 工具抽象接口
│   │   ├── tool_registry.dart      # 工具注册表
│   │   ├── shell_tool.dart         # Shell 命令执行
│   │   ├── file_read_tool.dart     # 文件读取
│   │   ├── file_write_tool.dart    # 文件写入
│   │   ├── file_delete_tool.dart   # 文件删除
│   │   ├── search_tool.dart        # grep/find 搜索
│   │   └── skill_tool.dart         # Skill 加载（内置工具）
│   ├── permission/
│   │   ├── permission_service.dart # 权限检查与审批
│   │   └── sandbox.dart            # 路径沙箱
│   └── skill/
│       ├── skill_loader.dart       # 扫描/解析 SKILL.md
│       └── skill_registry.dart     # Skill 注册与 Level 1 注入
├── service/
│   ├── chat_service.dart           # 工具调用：tools 参数、tool_calls 解析
│   └── ...
├── view_model/
│   ├── chat_view_model.dart        # 工具调用卡片渲染、审批流程集成
│   └── ...
├── entity/
│   ├── message_entity.dart         # 新增 tool_calls、tool_results 字段
│   └── ...
└── page/desktop/home/component/
    ├── tool_call_card.dart         # 新增：工具调用卡片
    ├── tool_result_card.dart       # 新增：工具结果卡片
    └── approval_dialog.dart        # 新增：权限审批弹窗
```

## 核心接口

### Tool 接口

```dart
enum DangerLevel { safe, needsApproval, forbidden }

abstract class Tool {
  String get name;
  String get description;
  Map<String, dynamic> get parameters;  // JSON Schema
  DangerLevel get dangerLevel;

  Future<String> execute(Map<String, dynamic> args);
}
```

### ToolRegistry

启动时注册所有内置工具，以 Map<String, Tool> 维护。新增工具只需实现 Tool 接口并注册。

### AgentService

编排 Agent 循环：

1. 构建 messages — system prompt（sentinel + 活跃 skill prompt + 工具列表）+ 历史消息 + 新用户消息
2. 调用 LLM（stream，带 tools 参数）
3. 解析 stream chunk — 文本实时渲染，tool_calls 累积
4. 遇到 tool_calls — PermissionService 判断 → 自动执行或弹审批框 → 执行工具 → 结果注入 messages
5. 继续步骤 2，直到 LLM 不再调用工具或达到最大轮次（默认 10 轮）

## 内置工具

MVP 阶段实现 6 个工具：

| 工具 | 危险等级 | 功能 |
|---|---|---|
| search | safe | grep/find 在项目目录搜索 |
| file_read | safe | 读取文件内容 |
| shell | needsApproval | 执行终端命令 |
| file_write | needsApproval | 写入/创建文件 |
| file_delete | needsApproval | 删除文件 |
| skill | safe | 加载 Skill 的 Level 2 内容 |

### Skill 作为内置工具

Skill 不是"系统被动匹配注入 prompt"，而是 Agent **主动调用**的内置工具。Agent 判断某个 Skill 匹配当前任务时，调用 `Skill("code-reviewer")`。SkillTool.execute() 返回该 Skill 的 SKILL.md body 文本，Agent 将其注入下一轮推理的上下文。

## Skill 系统

### 三级渐进式加载

| 层级 | 内容 | 加载时机 | Token 成本 |
|---|---|---|---|
| Level 1 | name + description | 会话启动时全量加载 | ~100/skill |
| Level 2 | SKILL.md 完整指令 | Agent 调用 Skill("name") 时 | 按需 |
| Level 3 | scripts/references 等资源 | Level 2 指令引用时 | 按需 |

### 文件结构

Skill 是目录，SKILL.md 为入口：

```
~/.athena/skills/           # 用户级
└── code-reviewer/
    ├── SKILL.md
    └── scripts/

.athena/skills/              # 项目级（版本控制）
└── db-migration-review/
    ├── SKILL.md
    └── references/
```

### SKILL.md 格式

```markdown
---
name: code-reviewer
description: >
  Review code for bugs, security issues, and style problems.
  Use when user asks for code review or "review this".
allowed-tools: Read, Grep, Glob, Bash(git diff *)
disable-model-invocation: false
---

## Role
You are a senior code reviewer.

## Process
1. Read the changed files
2. Run tests if available
3. Report issues grouped by severity
```

### Frontmatter 字段

| 字段 | 必填 | 说明 |
|---|---|---|
| name | 是 | Skill 唯一标识，也是调用名称 |
| description | 是 | 用途 + 触发场景，Agent 据此判断是否调用 |
| allowed-tools | 否 | 该 Skill 激活期间免审批的工具列表，支持 Bash 子命令粒度 |
| disable-model-invocation | 否 | true 时仅用户手动 /name 调用，Agent 不会自动匹配 |
| user-invocable | 否 | false 时从 / 菜单隐藏，纯后台技能 |

### 发现路径

| 范围 | 路径 | 共享 |
|---|---|---|
| 项目 | `.athena/skills/` | 版本控制 |
| 用户 | `~/.athena/skills/` | 个人 |

### Agent 调用流程

```
用户消息 → Agent 推理 → 判定当前任务匹配某个 Skill
  → Agent 调用 Skill("code-reviewer")
  → SkillTool 读取 SKILL.md body，返回完整指令文本
  → 指令注入下一轮 system prompt
  → 同时该 Skill 的 allowed-tools 生效
  → 继续推理与工具调用循环
```

## 权限系统

### 三层权限模型

```
最终权限 = 工具默认危险等级 × Skill allowed-tools 覆盖 × 用户规则
```

**工具默认危险等级**：

| 工具 | 等级 | 理由 |
|---|---|---|
| search | safe | 只读 |
| file_read | safe | 只读 |
| skill | safe | 只读 |
| shell | needsApproval | 可修改系统 |
| file_write | needsApproval | 修改文件 |
| file_delete | needsApproval | 破坏性 |

**Skill 覆盖**：`allowed-tools` 声明的工具在该 Skill 激活期间免审批。

**用户规则**（`~/.athena/permissions.yaml`）：

```yaml
rules:
  - path: "~/projects/*"
    action: allow_all
  - path: "~/.ssh/*"
    action: deny_all
  - command: "git diff"
    action: allow
```

### 审批 UI

Agent 调用工具 → PermissionService 判断为 needsApproval → 弹出对话框：

```
┌─────────────────────────────────┐
│  ⚠️ Shell 命令                  │
│                                 │
│  npm install                    │
│                                 │
│  [ ] 本次对话中记住此选择         │
│                                 │
│  [拒绝]             [批准执行]   │
└─────────────────────────────────┘
```

- 批准 → 执行工具 → 展示结果卡片
- 拒绝 → 告知 LLM 用户拒绝了此操作
- "记住选择" → 本次对话中相同工具不再询问

## 沙箱（MVP）

MVP 阶段做路径级沙箱，不做容器/VM 隔离：

```dart
class PathSandbox {
  final List<String> allowedPaths;   // 白名单路径
  final List<String> deniedPaths;    // 黑名单路径

  bool canRead(String path);
  bool canWrite(String path);
  bool canExecute(String command);
}
```

- 默认白名单：当前项目目录
- 默认黑名单：`~/.ssh`、`~/.aws`、`/etc`、`/System`
- 文件操作前校验，shell 命令提示中告知 LLM 工作目录约束

## 数据库迁移

Message 表新增两个字段：

```sql
ALTER TABLE message ADD COLUMN tool_calls TEXT DEFAULT '';
ALTER TABLE message ADD COLUMN tool_results TEXT DEFAULT '';
```

MessageEntity 新增：

```dart
final String toolCalls;     // JSON: [{"id":"", "name":"", "arguments":{}}]
final String toolResults;   // JSON: [{"id":"", "name":"", "result":""}]
```

UI 渲染时，若 toolCalls/toolResults 非空，在消息气泡中追加工具调用/结果卡片。

## UI 改动

### 新增组件

| 组件 | 用途 |
|---|---|
| `tool_call_card.dart` | 工具调用占位卡片（展示工具名、参数、执行状态） |
| `tool_result_card.dart` | 工具结果卡片（成功/失败/被拒，结果可展开） |
| `approval_dialog.dart` | 权限审批弹窗 |

### 聊天消息流渲染变化

stream chunk 处理新增 tool_calls delta 分支：

```dart
await for (final chunk in stream) {
  if (chunk 是文本 content) {
    // 现有逻辑
  }
  if (chunk 包含 tool_calls delta) {
    // 积累 tool_call JSON
    // finish_reason=tool_calls 时：
    // 1. 保存中间消息到 DB（含 tool_calls JSON）
    // 2. 渲染工具调用卡片
    // 3. 权限检查 → 执行 → 结果注入 → 继续 Agent 循环
  }
}
```

### 输入区

第一阶段不改动输入区。后续可在保持简洁的前提下加 `/` 快捷命令支持。

## 依赖变更

```yaml
# 移除 MCP 相关
# dart_mcp: ^0.2.2  （删除）

# openai_dart v5 已原生支持工具调用，无需额外依赖
```

## 实施路线

| 阶段 | 内容 | 新文件数 |
|---|---|---|
| Phase 1: 基础设施 | Tool 接口、ToolRegistry、3 个基础工具（search、file_read、shell）、Message 数据库迁移 | 8 |
| Phase 2: Agent 循环 | AgentService、流式 tool_calls 解析、Agent 消息 UI 卡片（tool_call_card、tool_result_card） | 4 |
| Phase 3: 权限系统 | PermissionService、approval_dialog、PathSandbox、permissions.yaml 加载 | 4 |
| Phase 4: Skill 系统 | SkillLoader、SkillRegistry、SkillTool、Agent 集成 | 4 |
| Phase 5: 完善工具 | file_write、file_delete、shell 增强（超时、环境变量）、search 增强 | 0（修改现有文件） |
| Phase 6: 清理收尾 | 移除 MCP 相关代码、更新路由和 DI | 0（删除 + 修改） |

## 不纳入此版本

- Docker/VM 级沙箱隔离
- 多 Agent 协作/子 Agent
- Skill 市场/插件系统
- 浏览器自动化工具
- 远程执行
- 输入区 UI 改动（后续迭代）
