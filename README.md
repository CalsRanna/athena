# Athena

跨平台 AI Agent 应用：一个 UI 无关的 Agent 引擎，两个前端。

完整的 Agent 循环（推理 → 工具调用 → 结果 → 再推理）、内置工具集、可自我进化的 Skill 与经验库、可回滚的角色（Sentinel）演进，以及一套按调用逐次判定的权限模型。桌面 GUI（Flutter）与终端 TUI（nocterm）共享同一个引擎、同一份数据，可同时运行。

## 组成

```
athena
├── packages/athena_core   # 纯 Dart Agent 引擎（零 Flutter）：循环、工具、权限、存储
├── packages/athena_gui    # Flutter 桌面 / 移动 GUI
└── packages/athena_tui    # nocterm 终端客户端
```

依赖方向严格单向：两个前端都依赖 `athena_core`，彼此不依赖。

| 包 | 说明 | 版本 |
|---|---|---|
| [`athena_core`](packages/athena_core) | Agent 引擎、领域模型、LLM 适配、文件存储。纯 Dart，不含任何 UI 依赖 | 0.1.0 |
| [`athena_gui`](packages/athena_gui) | Flutter GUI，桌面三平台（发布目标）+ Android / iOS（移动页面树） | 4.0.8+1132 |
| [`athena_tui`](packages/athena_tui) | 终端客户端，复用同一引擎 | 0.1.0 |

## 能力

**Agent 引擎**

- 多轮工具循环与并行工具执行
- 支持 OpenAI Chat Completions、OpenAI Responses、Anthropic Messages，保存与回放协议原生推理状态
- 上下文预算与自动压缩，原消息保留可回溯
- 工具失败反思与经验沉淀

循环、协议与上下文契约见 [CONVENTIONS.md §12.2](CONVENTIONS.md#122-agent-循环协议与上下文)，失败反思见 [§12.5](CONVENTIONS.md#125-skill经验与角色演进)。

**内置工具**（桌面端 17 个，移动端 11 个）

`file_read` / `file_write` / `file_update` 精确读改文件（带符号链接复核与外部修改检测）；`bash` / `powershell` 执行 shell（超时可控、可转后台、退出时按进程树终止）；`background_task` 查看与取回后台任务输出；`web_fetch` / `web_search` 联网；`ask_user_question` 向用户提结构化问题；`skill` / `skill_evolve` 加载与编写技能；`experience_learn` / `experience_recall` 沉淀与检索经验；`sentinel_list` / `sentinel_get` / `sentinel_evolve` / `sentinel_revert` 管理角色并可回滚；`tool_output_read` 分页读回超长输出。

`bash` 与 `powershell` 按操作系统互斥注册。移动端不注册任意文件与进程工具，但保留联网与全部进化类工具。

**权限模型**

会话可选择 Manual、AI Review 或 Bypass 三档审批模式，GUI 与 TUI 共用持久禁令。完整审批与禁令契约见 [CONVENTIONS.md §12.1](CONVENTIONS.md#121-权限审批)。

**Skill 与经验**

按需加载 Skill，通过内置 `self-evolve` 指导技能、经验与角色改进；经验可按角色隔离或全局共享。加载与隔离契约见 [CONVENTIONS.md §12.5](CONVENTIONS.md#125-skill经验与角色演进)。

**Sentinel（角色）**

角色以 system prompt 定义，支持带快照的演进与回滚。历史归属与回滚契约见 [CONVENTIONS.md §12.5](CONVENTIONS.md#125-skill经验与角色演进)。

**前端**

- 桌面 GUI：多会话侧栏、流式消息（推理 / 工具调用 / 压缩各自成步骤卡片，连续步骤自动成组）、Markdown 与 LaTeX 渲染、图片粘贴、系统托盘、单实例
- 移动 GUI：面向触屏的独立页面树，覆盖会话、模型、Provider、角色、技能、经验的管理
- 终端 TUI：状态栏、消息列表、输入区、权限条与选择弹层，斜杠命令驱动

## 回退会话（Rewind）

在 GUI 的用户消息操作条点击 **Rewind**，或在移动端长按用户消息选择
**Rewind**，回到该消息发送之前。该消息与后续记录退出历史，原文与图片恢复到
输入框，编辑后再发送。运行中的会话先取消并等待收尾，同时停止本会话的后台工作
和排队输入；另一前端正在运行同一会话时，需要先在那一端停止。

TUI 用 `/rewind` 选择轮次，也可用 `/rewind 3` 回到第 3 轮发送前。
历史图片随原文恢复，下一次发送会携带它们；`/clearimages` 可移除这些附件。

回退只影响对话记录与模型上下文，已执行的命令、文件修改、角色演进和经验库不随之
恢复。完整回退契约与旧版摘要限制见 [CONVENTIONS.md §12.3](CONVENTIONS.md#123-会话回退rewind)。

每次提交前保留完整快照 `~/.athena/sessions/<chatId>.jsonl.rewind-<snapshotId>`，
不会出现在会话列表里。需要恢复时，先退出 GUI 与 TUI，再把所需快照复制回同名
`<chatId>.jsonl`；这会替换回退后继续产生的对话，操作前可另存当前文件。

## 环境要求

- Flutter 3.47.1（含 Dart 3.13.1）——CI、发布流程与本地开发统一使用这一版本
- Dart SDK 下限 3.12.0，由 `anthropic_sdk_dart` 9.x 决定

## 快速开始

### GUI

```bash
cd packages/athena_gui && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter run -d macos
```

`athena_gui` 的路由是 `auto_route` 生成的，`lib/router/router.gr.dart` 需要在首次拉取依赖后生成一次（改了带 `@RoutePage` 的页面之后也要重新生成）。在 VS Code 里也可以直接用 `.vscode/launch.json` 里的 `athena_gui` 配置启动。

### TUI

```bash
cd packages/athena_tui && dart pub get && dart run bin/athena.dart
```

可传入工作区目录：`dart run bin/athena.dart ~/some/project`。缺省用当前目录。工作区是 Agent 的文件、shell 与技能工具的根目录。

| 输入 | 作用 |
|---|---|
| `Enter` | 发送消息 |
| `Esc` | 停止生成 / 关闭弹层 |
| `/new` `Ctrl+N` | 新建会话 |
| `/list` | 列出会话 |
| `/switch` `Ctrl+P` | 切换会话 |
| `/delete` | 删除当前会话 |
| `/model` `Ctrl+M` | 选择模型 |
| `/sentinels` `Ctrl+S` | 选择角色 |
| `/providers` | 配置 Provider 的 API key |
| `/format` | 配置 Provider 的 API 格式 |
| `/review [manual\|ai\|bypass]` | 查看或切换当前会话的审批模式（下一轮生效） |
| `/json <文本>` | 以 JSON 模式运行 |
| `/help` / `/quit` | 帮助 / 退出 |

权限审批在终端内联提示：`y` 允许本次、`n` 拒绝本次。

### 首次配置

1. 启动时会从 [models.dev](https://models.dev/api.json) 同步模型目录（名称、上下文窗口、价格、是否支持推理与图片），缓存 7 天。缓存过期或首次启动约需几秒；无网时降级到缓存，模型为空时前端会提示重试
2. 在 GUI 设置 → Provider 或 TUI `/providers` 里给要用的 provider 填 API key
3. 同步下来的 preset provider 默认是**禁用**状态，需要手动启用

provider 也可以手工加：在 `~/.athena/providers/` 下放一个 `{id}.yaml`（`{id}` 是文件名、也是它的身份），填上 `name` / `baseUrl` / `apiKey`，底下再列出它暴露的模型。自建网关一个文件写到底，重启就能在设置里看到：

```yaml
name: "My Gateway"
baseUrl: "https://gateway.example/v1"
apiKey: "sk-..."
enabled: true
models:
  - id: "gw-chat"          # 本地身份，随便取一个不重复的字符串
    name: "Gateway Chat"
    modelId: "gpt-oss-120b" # 真正发给端点的模型名
    contextWindow: 131072
```

内置的种子数据是角色「Athena」与「Daedalus」两项；provider 与模型完全由 models.dev 同步产生。

## 数据

两个前端共用同一份数据，根目录是 `~/.athena/`（移动端无可靠的 `$HOME`，改用应用的 Application Support 目录）。同时运行时，读写通过跨进程文件锁串行化。

```
~/.athena/
├── sessions/{chatId}.jsonl     # 一个会话一个文件：首行是会话元数据，其后每行一条消息
├── providers/{id}.yaml         # 一个 provider 一个文件：配置（含 API key）+ 它名下的模型
├── sentinels/{id}.yaml         # 一个角色一个文件
├── setting.yaml                # 用户偏好，两个前端共用（默认模型、主题、字号、窗口尺寸…）
├── permissions.json            # 持久 deny 禁令
├── models_dev_cache.json       # models.dev 目录缓存
├── tool_outputs/{sha256}.txt   # 超长工具输出，内容寻址
├── background_tasks/           # 后台任务登记表（用于清理上次强杀遗留的进程）
├── experiences/{scope}/        # 经验，一条一个 JSON 文件
├── sentinels/by-id/{id}/history/  # 角色演进快照
└── skills/{name}/SKILL.md      # 用户级技能
```

首次启动时若有旧版（整数 id）数据，会自动迁移到 UUIDv7 身份，原文件备份在 `backups/ids-v1/`。

> 迁移与读写都不做向后兼容：升级后不要再用旧版本打开同一份数据。

## 开发

工程约定与共享行为契约统一见 [CONVENTIONS.md](CONVENTIONS.md)。按改动涉及的包运行分析、测试与格式检查，完整命令及 GUI 路由生成要求见 [CONVENTIONS.md §9](CONVENTIONS.md#9-常用命令)。CI（[.github/workflows/ci.yml](.github/workflows/ci.yml)）在 Ubuntu 上分三个 job 跑三个包，与发布流程共用同一套检查。

## 文档

| 文档 | 内容 |
|---|---|
| [AGENTS.md](AGENTS.md) | 通用的 Agent 编码行为准则（简洁、外科式改动、目标驱动验证） |
| [CONVENTIONS.md](CONVENTIONS.md) | 工程约定、架构边界与共享行为契约（审批、Agent 循环与上下文、回退、运行统计、技能与角色演进） |
| [DESIGN.md](DESIGN.md) | 共享视觉原则、GUI 色板与排版 / 几何 / 阴影 / 动效规范、TUI 色彩映射 |
| [WIDGETS.md](WIDGETS.md) | GUI 控件清单与平台范围、具体交互与状态、桌面设置面板几何 |

## 许可

[MIT](LICENSE)
