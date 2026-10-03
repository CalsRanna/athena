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
| [`athena_gui`](packages/athena_gui) | Flutter GUI，桌面三平台（发布目标）+ Android / iOS（移动页面树） | 4.0.2+1030 |
| [`athena_tui`](packages/athena_tui) | 终端客户端，复用同一引擎 | 0.1.0 |

## 能力

**Agent 引擎**

- 多轮工具循环，带并行工具执行（并发上限 8）
- 三种 LLM 协议：OpenAI Chat Completions、OpenAI Responses、Anthropic Messages。上层的请求与事件统一为 Chat Completions 形状，协议差异收敛在两个适配器里
- 推理状态按协议原生保存与回放：Responses 的加密推理项、Messages 的 thinking 签名、Chat Completions 的 `reasoning_details`，各自完整持久化，切换 provider 后自动失效而非串用。Messages 兼容端点的全部无签名推理保留展示与正常工具调用，在完成明细中标记为不可回放，不保存为原生签名状态
- 上下文预算与自动压缩：估算超出窗口时先回收旧工具输出，再摘要压缩历史；摘要与它的覆盖范围一同提交，原消息保留可回溯
- 失败反思：同一工具累计失败两次以上时，用一次独立 LLM 调用提炼教训，并复用标准工具路径写入经验库

**内置工具**（桌面端 17 个，移动端 11 个）

`file_read` / `file_write` / `file_update` 精确读改文件（带符号链接复核与外部修改检测）；`bash` / `powershell` 执行 shell（超时可控、可转后台、退出时按进程树终止）；`background_task` 查看与取回后台任务输出；`web_fetch` / `web_search` 联网；`ask_user_question` 向用户提结构化问题；`skill` / `skill_evolve` 加载与编写技能；`experience_learn` / `experience_recall` 沉淀与检索经验；`sentinel_list` / `sentinel_get` / `sentinel_evolve` / `sentinel_revert` 管理角色并可回滚；`tool_output_read` 分页读回超长输出。

`bash` 与 `powershell` 按操作系统互斥注册。移动端不注册任意文件与进程工具，但保留联网与全部进化类工具。

**权限模型**

- 三档审批模式：手动 / AI 自动审核 / 所有权限。**挂在会话上**，多对话同时运行时各按各自的档位处理；改档位下一轮 run 生效。三档都不越过 deny 规则
- 规则按工具类型收窄：shell 匹配整条命令（不做动作前缀分析），文件工具匹配路径（支持 `*` / `**` / `?`，两侧都先解析符号链接），`web_fetch` 匹配 origin
- allow 与 deny 的松紧不对称：**allow 字面精确**（「始终允许」的范围就是用户当时看到的那条命令），**deny 折叠空白并去掉参数末尾的 `/`**——deny 放宽最坏是多拦一条，allow 放宽会多放行一条用户没看过的命令
- 会话级批准按 run 隔离，并发运行的任务之间不互相放行
- AI 审核由当前模型独立请求完成，只把原始用户与助手消息作为证据；工具参数、文件内容、URL 与工具输出一律视为数据而非指令。审核结论仅作用于这一次调用，不落规则
- 配置了 `permissions.json` 的跨进程锁与 mtime 变更检测，两个前端可同时运行而不互相覆盖规则

**Skill 与经验**

- Skill 是 `~/.athena/skills/<name>/SKILL.md`，front matter 只有 `name` 与 `description`
- 两段式注入：常驻的是技能目录（最多 20 条，按最近使用排序），技能正文由模型按需加载
- 内置 `self-evolve` 技能，代码注册，指导模型何时沉淀技能、经验与角色改进
- 经验按角色隔离，`scope="shared"` 才是全局；每次 run 注入当前角色可见的经验目录（内容稳定以复用 prompt 缓存），完整内容按需检索

**Sentinel（角色）**

角色即一段 system prompt。演进前自动存快照，可回滚，回滚本身也可回滚。快照按角色 id 归档而非按名字，因此改名不会丢失或错认历史。

**前端**

- 桌面 GUI：多会话侧栏、流式消息（推理 / 工具调用 / 压缩各自成步骤卡片，连续步骤自动成组）、Markdown 与 LaTeX 渲染、图片粘贴、系统托盘、单实例
- 移动 GUI：面向触屏的独立页面树，覆盖会话、模型、Provider、角色、技能、经验的管理
- 终端 TUI：状态栏、消息列表、输入区、权限条与选择弹层，斜杠命令驱动

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

权限审批在终端内联提示：`y` 允许、`n` 拒绝、`a` 总是允许（写入 `~/.athena/permissions.json`）。

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

内置的种子数据只有角色「Athena」一项；provider 与模型完全由 models.dev 同步产生。

## 数据

两个前端共用同一份数据，根目录是 `~/.athena/`（移动端无可靠的 `$HOME`，改用应用的 Application Support 目录）。同时运行时，读写通过跨进程文件锁串行化。

```
~/.athena/
├── sessions/{chatId}.jsonl     # 一个会话一个文件：首行是会话元数据，其后每行一条消息
├── providers/{id}.yaml         # 一个 provider 一个文件：配置（含 API key）+ 它名下的模型
├── sentinels/{id}.yaml         # 一个角色一个文件
├── setting.yaml                # 用户偏好，两个前端共用（默认模型、主题、字号、窗口尺寸…）
├── permissions.json            # 权限规则
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

### 检查与测试

```bash
cd packages/athena_core && dart analyze && dart test
```

```bash
cd packages/athena_tui && dart analyze && dart test
```

```bash
cd packages/athena_gui && flutter analyze && flutter test
```

`athena_gui` 的测试运行前同样需要先跑一次 `build_runner`。

CI（[.github/workflows/ci.yml](.github/workflows/ci.yml)）在 Ubuntu 上分三个 job 跑这三个包，与发布流程共用同一套检查。测试目录被误删时会直接失败，而不是静默跳过。

### 提交信息

`<type>(<scope>): <summary>`，type 用 `feat` / `fix` / `refactor` / `docs` / `chore` / `build` / `test`，scope 取包名或子系统名（`agent` / `theme` / `storage` / `athena_gui` …）。正文写清**为什么**改，而不只是改了什么。提交信息中不添加任何工具署名。

### 发布

GUI 通过 GitHub Release 分发，三平台各自打包后由 `tapster publish` 更新 Homebrew tap 与 Scoop bucket：

```bash
git tag v4.0.3 && git push origin v4.0.3
```

tag 推送后触发 [release.yml](.github/workflows/release.yml)：先复用 CI 的三包检查，再并行构建 macOS（`.zip`，内含 `Athena.app`）、Windows（`.zip`，内含 `athena.exe`）、Linux（`.tar.gz`）。发布配置见 [`packages/athena_gui/.tapster.yaml`](packages/athena_gui/.tapster.yaml)，checksum 由 `tapster publish` 从 Release asset digest 解析，不需要手工维护。

打 tag 前记得同步 `packages/athena_gui/pubspec.yaml` 的 `version`。

## 文档

| 文档 | 内容 |
|---|---|
| [AGENTS.md](AGENTS.md) | 仓库结构、分层与依赖方向、编码与测试约定 |
| [DESIGN.md](DESIGN.md) | 设计系统：色板、排版、几何、组件分层与交互规则 |

放入工作区根目录的 `AGENTS.md` 会被 Agent 读取并注入上下文，用于告诉它该项目的约定。它随每次请求注入、不写入会话历史，也不会成为权限批准的依据。

## 许可

[MIT](LICENSE)
