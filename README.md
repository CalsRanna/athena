# Athena

跨平台 AI Agent 应用：Flutter 桌面/移动客户端（`athena_gui`）与终端客户端（`athena_tui`）共用同一个纯 Dart Agent 引擎（`athena_core`）。Agent 循环、内置工具、自我进化与权限模型都在引擎里，两个客户端只负责交互。

- 仓库：<https://github.com/CalsRanna/athena>
- 许可：MIT（见 [LICENSE](LICENSE)）

---

## 能力

### Agent 引擎

- **完整 Agent 循环**：一次 run 内反复「推理 → 工具调用 → 结果 → 再推理」，默认上限 100 轮（`AgentSettings.maxAgentIterations`，桌面端在「设置 → Agent」里改）。
- **混合串并行**：同一轮内可并行的工具调用并发执行，并发上限 8；需要人工审批的调用被降级为串行——多个审批卡片不会同时出现。
- **截断保护**：模型响应撞上输出 token 上限时，该轮所有工具调用一律不执行，并回一条「参数可能不完整，请用完整参数重发」的结果，避免拿着半截参数动文件或执行命令。
- **可取消、可接续**：停止立即中断当前轮（已累积内容照常落库）；运行中发消息先落库排队，当前 run 结束后自动接续成新 run，事件流对 UI 连续。
- **多会话并发**：多个对话可同时运行，run 之间按 `runId` 隔离状态、权限缓存与工作文件夹。
- **任何一轮都重新估算上下文**，包括工具循环内部（见下文「上下文管理」）。

### 内置工具

工具清单的唯一来源是 `athena_core` 的 `buildToolRegistry()`；桌面端注册 16 个，移动端 11 个（移动端不注册文件、shell 与提问工具）。

| 工具 | 作用 | 危险等级 | 默认执行 |
|---|---|---|---|
| `file_read` | 按行分页读文本文件（单次最多 2000 行，大文件流式读） | 只读 | 并行 |
| `file_write` | 新建或整文件覆盖 | 危险 | 串行 |
| `file_update` | 精确字符串替换，`replace_all=false` 时 `old_string` 必须唯一 | 危险 | 串行 |
| `bash` / `powershell` | 执行 shell 命令（按操作系统二选一），单次超时默认 120s、上限 3600s | 危险 | 按命令判定（只读命令可并行） |
| `web_fetch` | 抓取 URL 并转 Markdown；POST 或带自定义 headers 时需审批 | 只读 | 并行 |
| `web_search` | Brave 搜索（需在设置里填 Brave API key） | 只读 | 并行 |
| `ask_user_question` | 向用户提结构化问题（选项卡片），不触发审批弹窗 | 只读 | 串行 |
| `skill` | 按名加载 Skill（三级渐进加载的第 2 级） | 危险 | 串行 |
| `skill_evolve` | 新建/更新 Skill，写入用户级技能目录 | 危险 | 串行 |
| `experience_learn` | 记录/修订/归档经验（长期记忆） | 危险 | 串行 |
| `experience_recall` | 检索经验（lesson / tags / context 加权匹配） | 只读 | 串行 |
| `sentinel_list` / `sentinel_get` | 列出、读取角色定义 | 只读 | 并行 |
| `sentinel_evolve` / `sentinel_revert` | 改进角色提示词、回滚到历史快照 | 危险 | 串行 |
| `tool_output_read` | 分页回读超长工具输出 | 只读 | 并行 |

每个工具调用都必须带一个展示用的 `call_description`（由 schema 强制、缺失即判参数非法）；模型还可以给出 `approval_recommendation` / `approval_reason`，这三个字段在权限匹配与执行前会被剥离。

### 权限模型

判定顺序（`PermissionService.check`，与 Claude Code 的 deny → ask → allow 一致）：

1. **deny 规则**：整条命令或复合命令的任一子命令命中即拒绝，优先于一切放行路径；
2. **只读短路**：只读工具、只读 shell 命令（`ls`、`git status` 等）直接放行，永不弹窗。例外是 `web_fetch` 的 POST 或自定义 headers——它们能驱动内网接口；
3. **会话级缓存**：本 run 内已批准的同工具、同完整参数直接放行（缓存按 `runId` 隔离）；被用户拒绝过的同一调用在本 run 内不再放行；
4. **持久规则**：命中放行规则则放行。

审批模式三档（`AgentSettings.approvalMode`，桌面端 composer 左下角、TUI `/review` 共用，下一轮 run 生效）：

- `manual`——需要审批的调用一律问人；
- `ai_review`（默认）——先由一个独立的、无工具、单独的提示词请求审核（20s 超时，只对本次调用有效）；拿不准或模型自己标 `ask` 的仍问人；
- `bypass`——需要审批的调用直接放行，不问 AI 也不问人；**deny 规则仍然生效**。

拒绝与放行都会作为「用户决定」喂给后续的 AI 审核，AI 审核不会写入会话或持久规则。桌面端审批以会话内卡片呈现，TUI 是终端内模态。

### 自我进化与长期记忆

- **Skill**：三级渐进加载。Level 1 只注入技能目录（最多 20 条，按最近使用排序），命中任务时用 `skill` 工具加载正文。用户级技能存放在 `~/.athena/skills/{name}/SKILL.md`；内置 `self-evolve` 由代码注册，不可编辑或删除。
- **经验（长期记忆）**：每次 run 开始时，把当前 Sentinel 可见的全部 active 经验以「一条一行」的稳定目录注入上下文（顺序稳定，利于 provider 复用 prompt 前缀缓存），只列出 `lesson`；`context` / `tags` 等细节由 `experience_recall` 按需加载。经验分 `self`（仅当前 Sentinel）与 `shared`（所有 Sentinel）。
- **失败反思**：run 结束时若失败可归因（同一工具失败 ≥2 次，或迭代耗尽），引擎会用一次独立的 LLM 调用提炼教训，再走标准 `experience_learn` 工具路径（校验 → 审批 → 执行）写入。用户取消、单次工具失败、单纯的权限拒绝都不会被包装成「需要学习的失败」。
- **Sentinel 优化**：`sentinel_evolve` / `sentinel_revert` 每次写入前先落一条历史快照，可回滚，回滚本身也可回滚。

### 上下文管理

- **保留策略**（`ChatEntity.retention`）：`0` = 零上下文（每次只带当前用户消息）；`-1`（默认）= 自动管理。
- **自动压缩**：仅 `retention == -1` 时启用。每轮请求前估算上下文，达到 `min(窗口 80%, 输入上限)` 就把全部有效历史快照压缩成一条带覆盖范围的摘要消息；原始消息保留在库里（标记 `compacted`，不参与组装）。压缩过程本身是一条可观察的步骤（触发 → 汇总 → 落盘 → 完成/失败/取消），同一消息 id 逐阶段更新。
- **预算**：输入上限 = 窗口 − `min(8192, max(256, 窗口/5))`（给输出留空间）；估算按 UTF-8 字节数 / 2，外加每张图片 4096 token，并随真实 usage 向上校准。若仍超限，较旧的工具结果会被替换为引用（可用 `tool_output_read` 回读），最新的工具批次始终保留。
- **长输出**：超过 24000 字符的工具输出落盘到 `~/.athena/tool_outputs/`（按内容哈希寻址），模型只看到前 2000 字符与回读提示；单次回读上限 12000 字符。

### 客户端

**桌面（macOS / Windows / Linux）**

- 多区工作台：288 宽侧栏（会话列表、置顶、批量选择、删除）+ 工作区（消息流、轮次条、composer）。
- Claude 桌面端风格的设置浮层面板：Providers / Default models / Agent / Sentinels / Skills / Experiences / General / About，导航带搜索，改动即存。
- composer 上可切换模型、角色、工作文件夹、推理强度、保留策略、审批模式，并显示上下文占用圆环（≥80% 变警示色）。
- 会话内审批卡片与提问卡片；会话级工作文件夹（只影响后续 run）。
- 发送首条消息时用模型自动命名会话；角色元数据（名称/描述/标签/头像）也可由模型生成。
- 系统托盘、Cmd+W 隐藏窗口、Win 单实例守卫（macOS 由 LaunchServices 保证）。

**移动（iOS / Android）**

- 分段浏览页面：首页（欢迎 / 新建会话 / 最近会话 / 经验 / 角色）、聊天、最近会话列表、角色、Skill、经验、Provider、设置（Agent / Provider / Sentinels / Skills / Experiences / Default Model / Data / Appearance / About）。
- 用户级数据（Skill、经验、Sentinel 历史）落在应用沙盒的 Application Support 目录，而非 `$HOME`。
- 不注册文件、shell 与提问工具。

**终端（`athena_tui`）**

- 基于 nocterm 的 TUI，工作区为命令行参数或当前目录（不存在时自动创建）。
- 斜杠命令：`/new` `/list` `/switch` `/delete` `/json` `/model` `/sentinels` `/providers` `/help` `/review` `/quit`。
- 终端内审批与提问模态；与 GUI 共用同一份引擎、工具集、权限规则与数据目录。

---

## 安装

### 预编译包

打 `v*` tag 会触发 Release workflow，产出三个平台的压缩包：

| 平台 | 产物 | 包内可执行文件 |
|---|---|---|
| macOS | `Athena-macOS.zip` | `Athena.app` |
| Windows | `Athena-Windows.zip` | `athena.exe` |
| Linux | `Athena-Linux.tar.gz` | 解压后的 bundle 目录 |

包管理器清单（Homebrew Cask `athena`、Windows 清单元数据）的模板放在 `packages/athena_gui/dist/`，该目录是发布中转产物、不入库。

### 从源码构建

前置：Flutter **3.41.4** stable（与本仓 CI / release 使用的版本一致），Dart SDK `>=3.8.0`。根目录没有 `pubspec.yaml`，三个包各自 `pub get`。

```bash
# 桌面 / 移动客户端
cd packages/athena_gui
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 生成路由等代码，必需
flutter run -d macos                                        # 或 windows / linux / <device id>
flutter build macos                                         # 打发布包

# 终端客户端
cd packages/athena_tui
dart pub get
dart run bin/athena.dart [工作区目录]
```

VS Code 的 `.vscode/launch.json` 已提供 `athena_gui` 的 debug / profile / release 三种启动配置。

---

## 首次配置

1. **填 Provider**：桌面端「设置 → Providers」填 base URL 与 API key；TUI 用 `/providers`。provider 的权威存储是 `~/.athena/setting.yaml`（含 API key，可手工编辑，重启生效）。
2. **选默认模型**：桌面端「设置 → Default models」有会话、话题命名、角色元数据三个用途各一行；TUI 用 `/model`（写回 `setting.yaml`）。
3. **可选**：`设置 → Agent` 里填 Brave API key（`web_search` 用）、改最大迭代次数与最大重试次数。

预设 provider（Deep Seek、Open Router、阿里云百炼、硅基流动、MiniMax、智谱AI、OpenAI、Google、xAI、月之暗面 Kimi、阶跃星辰）的模型元数据会在启动时后台从 [models.dev](https://models.dev/api.json) 同步（3.2MB，7 天 TTL 缓存，只同步最近一年发布且支持推理的模型）；同步失败自动降级到上次缓存，不阻塞启动。不在预设列表里的 provider 不受同步影响。任何 OpenAI 兼容服务都可以手工加。

---

## 数据与配置

桌面端数据根目录是 `~/.athena/`（GUI 与 TUI 共用，可同时运行）；移动端是应用沙盒的 Application Support 目录。

| 路径 | 内容 |
|---|---|
| `sessions/{chatId}.jsonl` | 一个对话一个文件：首行会话元数据，之后每行一条消息 |
| `models.json` | 模型列表（JSON 数组） |
| `sentinels.json` | 角色列表（JSON 数组） |
| `meta.json` | 自增 id 计数（key 为文件/目录路径） |
| `setting.yaml` | provider 配置（含 API key）与 TUI 默认模型 |
| `models_dev_cache.json` | models.dev 目录缓存 |
| `permissions.json` | 持久权限规则（「始终允许」） |
| `tool_outputs/{sha256}.txt` | 超长工具输出（内容寻址） |
| `experiences/shared/`、`experiences/{sentinelId}/` | 经验（一条一个 JSON 文件） |
| `sentinels/{encodedName}/history/` | Sentinel 变更历史快照 |
| `skills/{name}/SKILL.md` | 用户级 Skill |
| `kv.json` | TUI 的键值设置（GUI 用 SharedPreferences） |

写入采用「进程内串行 + 跨进程文件锁 + 临时文件 rename」三条保障：GUI 与 TUI 可能同时打开同一目录，读到的要么是旧文件要么是新文件，不会读到写坏一半的内容。文件永远是唯一真相，缓存类数据都可删除重建。

配置的导出 / 导入 / 重置：桌面端在「设置 → General」（Data 分区：显示数据目录、导出为 JSON 备份、导入并替换现有 Provider 与 Model；Danger zone：Reset Athena），移动端在设置里的 Data 页。重置会删除本机全部会话、Provider、Model 与 Sentinel 并恢复默认设置，但不动目录缓存与工具输出。

---

## 仓库结构

```
packages/
  athena_core/    纯 Dart 引擎：Agent 循环、工具、权限、Skill、进化、领域模型、服务、本地存储
  athena_gui/     Flutter 桌面/移动应用：页面、组件、设计系统、ViewModel、路由
  athena_tui/     nocterm 终端客户端：终端 UI、桥接层、控制器
```

依赖方向严格单向：`athena_gui` / `athena_tui` → `athena_core`，`athena_core` 不依赖 Flutter，也不含任何 SQL。

---

## 测试与 CI

| 范围 | 命令 |
|---|---|
| `athena_core` | `dart analyze`、`dart test`（`test/storage/`、`test/agent/permission/`） |
| `athena_gui` | `flutter analyze`、`flutter test`（`test/widget/`） |
| `athena_tui` | `dart analyze`（目前无测试目录） |

CI 在 push / PR 到 `main` 时跑 `athena_core` 与 `athena_gui` 两个 job；`athena_gui` 的 job 会先跑 `build_runner` 再 analyze（生成代码缺失会直接失败）。`athena_core` 里的 `tool/bench_message_loading.dart` 是只读的加载性能基准脚本，不参与 CI。

---

## 相关文档

- [AGENTS.md](AGENTS.md)——面向在本仓改代码的工程指南：命令、分层、硬约束、常见任务。
- [DESIGN.md](DESIGN.md)——视觉与交互设计口径（设计 token、色板、组件规格）。
