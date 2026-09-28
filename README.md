# Athena

跨平台 AI Agent 应用：Flutter 桌面/移动客户端（`athena_gui`）与终端客户端（`athena_tui`）共用同一个纯 Dart Agent 引擎（`athena_core`）。Agent 循环、内置工具、自我进化与权限模型都在引擎里，两个客户端只负责交互。

- 仓库：<https://github.com/CalsRanna/athena>
- 许可：MIT（见 [LICENSE](LICENSE)）

---

## 能力

### Agent 引擎

- **完整 Agent 循环**：一次 run 内反复「推理 → 工具调用 → 结果 → 再推理」，默认上限 100 轮（`AgentSettings.maxAgentIterations`，桌面端在「设置 → Agent」里改）。
- **混合串并行**：同一轮内可并行的工具调用并发执行，并发上限 8；需要人工审批的调用被降级为串行——多个审批卡片不会同时出现。
- **截断保护**：模型响应撞上输出 token 上限时，无工具调用的回复保留已收到内容并明确报错；有工具调用时一律不执行，并回一条「参数可能不完整，请用完整参数重发」的结果，避免拿着半截参数动文件或执行命令。
- **可取消、可接续**：停止立即中断当前轮（已累积内容照常落库）；运行中发消息先落库排队，当前 run 结束后自动接续成新 run，事件流对 UI 连续。
- **多会话并发**：多个对话可同时运行，run 之间按 `runId` 隔离状态、权限缓存与工作文件夹。
- **任何一轮都重新估算上下文**，包括工具循环内部（见下文「上下文管理」）。

### 内置工具

工具清单的唯一来源是 `athena_core` 的 `buildToolRegistry()`；桌面端注册 17 个，移动端 11 个（移动端不注册文件、shell、提问与后台任务工具）。

| 工具 | 作用 | 默认执行 |
|---|---|---|
| `file_read` | 按行分页读文本文件（单次最多 2000 行，大文件流式读） | 并行 |
| `file_write` | 新建或整文件覆盖 | 串行 |
| `file_update` | 精确字符串替换，`replace_all=false` 时 `old_string` 必须唯一 | 串行 |
| `bash` / `powershell` | 执行 shell 命令（按操作系统二选一），单次超时默认 120s、上限 3600s；`background: true` 时不等待、不超时（见「后台任务」） | 串行 |
| `background_task` | 查看/读取/停止后台任务（`list` / `read` / `stop`） | 串行 |
| `web_fetch` | 抓取 URL 并转 Markdown，支持 POST 和自定义 headers | 并行 |
| `web_search` | Brave 搜索（需在设置里填 Brave API key） | 并行 |
| `ask_user_question` | 向用户提结构化问题（选项卡片），不叠加审批弹窗 | 串行 |
| `skill` | 按名加载 Skill（三级渐进加载的第 2 级） | 串行 |
| `skill_evolve` | 新建/更新 Skill，写入用户级技能目录 | 串行 |
| `experience_learn` | 记录/修订/归档经验（长期记忆） | 串行 |
| `experience_recall` | 检索经验（lesson / tags / context 加权匹配） | 串行 |
| `sentinel_list` / `sentinel_get` | 列出、读取角色定义 | 并行 |
| `sentinel_evolve` / `sentinel_revert` | 改进角色提示词、回滚到历史快照 | 串行 |
| `tool_output_read` | 分页回读超长工具输出 | 并行 |

每个工具调用都必须带一个展示用的 `call_description`（由 schema 强制、缺失即判参数非法）；模型还可以给出 `approval_recommendation` / `approval_reason`，这三个字段在权限匹配与执行前会被剥离。

### 后台任务

长命令（构建、测试套件、安装）可以 `bash(command: "...", background: true)` 启动：调用立刻返回一个任务 id，命令继续在后台跑，本轮不必等它，用 `background_task(action="read")` 看输出、`action="stop"` 停掉它。生命周期口径：

- run 正常结束**不**停止任务；用户点停止（取消 run）会**同时停止该会话的全部后台任务**，会话删除与退出应用同理（保留已产生的输出，状态记为 `cancelled`）；
- 任务成功或失败后，会在当前 run 的**下一次模型请求前通知 Agent**，包含任务 id、状态与命令，实际输出仍通过工具分页读取；不打断正在生成的回答或工具执行，不落用户消息，沿用当前审批模式。模型完整响应通知后不再重复汇报；
- 会话空闲或当前 run 没来得及处理通知时，自动起一个**汇报回合**把结论带回会话；汇报回合不能再启动后台任务，也不触发失败反思。运行中通知和空闲汇报共用设置里的自动汇报开关（默认开）；
- 进程被强杀（崩溃 / kill -9）时会留下孤儿进程——这是已知残余，下次启动时会按记录核对 pid 与命令行后清理；同时开着的另一个 GUI / TUI 实例的任务不受影响。

### 权限模型

判定顺序（`PermissionService.check`）：

1. **deny 规则**：完整调用命中即拒绝，shell 按整条命令精确匹配，优先于一切放行路径；
2. **会话级缓存**：本 run 内已批准的同工具、同完整参数直接放行（缓存按 `runId` 隔离）；被用户拒绝过的同一调用在本 run 内不再放行；
3. **持久规则**：命中放行规则则放行。

审批模式三档（`AgentSettings.approvalMode`，桌面端 composer 左下角、TUI `/review` 共用，下一轮 run 生效）：

- `manual`——需要审批的调用一律问人；
- `ai_review`（默认）——先由一个独立的、无工具、单独的提示词请求审核（20s 超时，只对本次调用有效）；拿不准或模型自己标 `ask` 的仍问人；
- `bypass`——需要审批的调用直接放行，不问 AI 也不问人；**deny 规则仍然生效**。

拒绝与放行都会作为「用户决定」喂给后续的 AI 审核，AI 审核不会写入会话或持久规则。桌面端审批以会话内卡片呈现，TUI 是终端内模态。

工具不再声明风险等级。读取文件、搜索、读取任务输出等调用，未命中已有授权时也进入当前审批模式。`ask_user_question` 直接进入提问流程，显式 deny 仍生效。并行资格独立于审批：需要审批的调用串行处理，已有授权或 `bypass` 模式下按工具的并行声明执行。

Shell 调用统一串行，未命中显式授权时按上述三种模式处理，包括 `ls`、`git status` 等命令。复合命令作为一个完整调用审批，不拆分子命令拼接授权或匹配 deny；「始终允许」仍保存整条命令的精确授权，且只在模型没有另行指定工作目录、也不在后台运行时生效——换目录或转后台执行同一命令要重新审批。旧版 `action` 规则（含 allow / deny）停止生效，原有授权需重新审批，禁止项需改为整条命令的 `exact` 规则。

文件工具的路径在审批前解析符号链接：规则、审批卡与 AI 审核看到的都是真实写入目标，执行前再复核一次，审批后链接被替换则拒绝执行。凭据目录（`.ssh` / `.aws`）与 `~/.athena` 禁止写入。`web_fetch` 的「始终允许」按站点（origin）保存，只覆盖不带 body 与自定义 headers 的 GET；POST、带 body 或 headers 的请求每次都要审批。跳转到其他站点时不自动跟随，交还模型用新地址重新调用（从而重新审批）；`localhost`、内网与各种非规范写法的 IP 地址（`127.1`、`0177.0.0.1`、`[::ffff:127.0.0.1]` 等）直接拒绝。

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

桌面与移动端采用青瓷浅色 / 深色主题：中性瓷白或墨绿灰承载正文，青绿色突出主操作与选中态；TUI 品牌强调同步深色青瓷。界面图标统一使用 Lucide，覆盖导航、设置、composer、工具步骤和通用控件。

**桌面（macOS / Windows / Linux）**

- 多区工作台：288 宽侧栏（会话列表、置顶、批量选择、删除）+ 工作区（消息流、轮次条、composer）。
- Text size 使用三组固定的会话字号 / 行高：Small 13 / 20、Medium 14 / 22（默认）、Large 15 / 24。正文、行内代码、代码块与工具输出共用同一档位，代码使用等宽字体；composer、空会话 placeholder、侧栏、标题栏、设置和弹出菜单不受档位影响。桌面与移动端范围一致，保留系统无障碍文字缩放。
- 其他 UI 以 Medium 的 14 / 22 为常规文字基准：辅助信息 12 / 18、标题 16 / 24、空态标题 20 / 28；侧栏行高 32，设置控件高 36，字号与间距一起适度放松。
- 圆角统一为 4 / 8 / 12 / 16：小元素、控件、卡片与菜单、大面板各用一档；两端输入区共用轻阴影，菜单与模态分别使用浮层阴影，深色浮层补细轮廓，输入框聚焦使用青瓷边框。
- 桌面端滚动不带 iOS 式回弹：滚轮与触控板滚到边界即停，不会先拉出一段空白再弹回；桌面滚动条照常显示。移动端沿用系统默认（iOS 回弹）。
- 运行出错时，错误会作为一条回复留在会话里（包括所选模型或 provider 已被删除的情况）；建会话、删消息等操作失败会弹出提示。
- 移动端长按用户消息可以编辑后重新发送（从这条起截断，发出编辑后的内容）；运行中不能重发、编辑或删除消息，删除前会确认（会连带删掉之后的消息）。
- 设置浮层面板：Providers / Default models / Agent / Sentinels / Skills / Experiences / General / About，导航带搜索；内容在固定标题栏下方滚动，不遮挡返回链接和关闭按钮，标题栏底部分隔线与工作区一致，正文顶部保留 24 逻辑像素的留白。一般设置改动即存，角色、技能等编辑页通过 Save 保存。
- composer 上可切换模型、角色、工作文件夹、推理强度、保留策略、审批模式，并显示上下文占用圆环（≥80% 变警示色）；未发送的文字与图片按对话各自保留，切换对话不会带到别的对话里。
- 支持快捷键与右键菜单粘贴图片：立即显示可移除的图片占位和加载圆环（无阶段文字），解析完成后显示缩略图；失败时显示错误图标。图片就绪后可单独发送，也可随文字发送；解析期间与失败项移除前暂停发送，切换对话不会改变附件归属。
- 上下文条以 `Context on / Context off` 显示是否携带聊天历史，点击使用统一菜单选择「使用聊天历史 / 仅当前消息」，对后续消息生效；此处不再提供温度设置。
- 会话内审批卡片与提问卡片；会话级工作文件夹（只影响后续 run）。
- 发送首条消息时用模型自动命名会话；角色元数据（名称/描述/标签）也可由模型生成。Sentinel 不提供头像，列表和会话空态通过名称识别角色。
- 系统托盘、Cmd+W 隐藏窗口、Win 单实例守卫（macOS 由 LaunchServices 保证）。
- Cmd+N（macOS）/ Ctrl+N（Windows、Linux）新建对话，并把焦点落回输入框；设置页、对话框这类压在首页之上的路由打开时不生效。
- 新建对话的草稿继承**当前选中对话**的角色与工作文件夹（模型、上下文保留、温度、推理强度仍回默认），在草稿上照旧可以改；启动落草稿、删掉最后一个对话没有来源，回默认角色与「不指定文件夹」。

**移动（iOS / Android）**

- 分段浏览页面：首页（欢迎 / 新建会话 / 最近会话 / 经验 / 角色）、聊天、最近会话列表、角色、Skill、经验、Provider、设置（Agent / Provider / Sentinels / Skills / Experiences / Default Model / Data / Appearance / About）。
- 用户级数据（Skill、经验、Sentinel 历史）落在应用沙盒的 Application Support 目录，而非 `$HOME`。
- 不注册文件、shell 与提问工具；新建会话继承最近打开会话的角色（工作文件夹在移动端没有作用，不继承）。

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

前置：Flutter **3.47.1** stable（与本仓 CI / release 使用的版本一致），Dart SDK `>=3.12.0`。根目录没有 `pubspec.yaml`，三个包各自 `pub get`。

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

同步还会根据 models.dev 的 `npm` 推断 Provider 默认 API 格式，保存为 `setting.yaml` 的 `apiFormat`（`chat_completions` / `responses` / `messages`）。OpenAI 默认推断为 Responses；Google、MiniMax 与 xAI 按 Athena 现有端点保留 Chat Completions。模型级 `provider.shape` 不作为整个 Provider 的默认格式。未知 SDK 保留原值，修改过预设地址的 Provider 不自动更新格式；旧配置默认 Chat Completions，并可直接从七天 TTL 内的已有缓存补齐格式。

`apiFormatAuto: true` 表示允许目录同步；手动指定格式时同时设为 `false`，该选择会随配置备份保留。**三种格式都可实际发起请求**：Chat Completions 直接调用兼容端点，Responses 与 Messages 会各自完成请求与流事件的形状转换（两者都暂不支持音频、文件消息与 JSON Schema 输出格式）。

手动切换的入口：桌面与移动端的 Provider 编辑界面各有 **API format** 一项（`Auto` 交给 models.dev 同步；选 Chat Completions / Responses / Messages 即为手动指定，此后同步不再覆盖）；终端客户端用 `/format`。

Responses 推理模型会请求并显示推理摘要，流式与非流式调用都支持。完整响应的原生推理状态随会话保存，在同一供应商、端点和模型的工具续接及会话重载后回传；切换供应商或模型时使用普通文本与工具历史。请求默认使用 `store: false`，由本地保存并回传推理密文；取消或截断的响应不保存新的原生状态。

Messages 同样支持推理显示与续接：Claude 4.6 及之后支持 adaptive 的模型使用 `thinking` + `output_config.effort`，早期 Claude 与未识别的 Messages 兼容推理模型使用手动 `budget_tokens`。手动预算按强度映射，并受输出上限和窗口余量限制；启用推理时省略不兼容的温度参数。完整响应的 thinking、signature 与 redacted thinking 按原顺序保存，工具续接和重载后回传；取消、截断或缺少签名时不保存新状态。切换来源、编辑消息、压缩历史或修改系统提示/工具清单后，不回传已经失效的旧签名。协议约束见 [Claude thinking 文档](https://platform.claude.com/docs/en/build-with-claude/thinking)。


三条协议会保留原始停止原因和用量明细，拒答文字也会正常显示并保存。Responses 的流内错误、失败状态及提前断流会按失败处理；Chat Completions 同样检查结束标记。窗口/输出截断与内容过滤不会执行未完成的工具调用。Messages 的输入 token 统计包含未缓存输入、缓存读取和缓存写入；缓存写入明细独立保留。`pause_turn` 与服务端压缩续接尚未接入，收到这些状态会明确报错。

Chat Completions 兼容端的 `reasoning`、`reasoning_content`、`reasoning_details`（含签名和密文）也会随会话保存，在相同供应商、端点和模型的工具续接及重载后回传；编辑正文、过滤工具调用或切换来源后不回传旧状态。Responses / Messages 适配器现已映射输出上限、`top_p`、工具选择、并行开关和工具 `strict` 等控制参数；Messages 显式输出上限还受模型和窗口预算约束。无法等价表达或尚未接入的显式参数会报错，不再静默忽略。这些参数映射属于客户端接口能力，不代表设置界面已新增对应入口。

聊天请求会按已知 OpenAI 模型名处理会话温度：o 系列及启用推理的 GPT-5 系列省略不兼容的温度参数；其他模型保留原采样行为。Chat Completions 仅返回 `reasoning_details` 时也会显示其中的摘要和文本，重复推理通道只展示一份，密文与签名不进入展示。Responses 会从 `done` 和最终快照补齐缺少的正文、工具调用及参数，已收到的内容不会重复追加；完整值与增量冲突时明确失败。Messages 历史工具参数为数组、标量或 null 时，与损坏 JSON 一样按空对象转换并保留对应结果，避免后续对话被类型异常阻断。

---

## 数据与配置

桌面端数据根目录是 `~/.athena/`（GUI 与 TUI 共用，可同时运行）；移动端是应用沙盒的 Application Support 目录。

| 路径 | 内容 |
|---|---|
| `sessions/{chatId}.jsonl` | 一个对话一个文件：首行会话元数据，之后每行一条消息 |
| `models.json` | 模型列表（JSON 数组） |
| `sentinels.json` | 角色列表（JSON 数组） |
| `storage_version.json` | 数据格式版本、旧模型 ID 映射（默认模型设置迁移用） |
| `backups/ids-v1/` | 首次 UUID 迁移前的原始数据备份 |
| `setting.yaml` | provider 配置（含 API key）与 TUI 默认模型 |
| `models_dev_cache.json` | models.dev 目录缓存 |
| `permissions.json` | 持久权限规则（「始终允许」） |
| `tool_outputs/{sha256}.txt` | 超长工具输出（内容寻址） |
| `experiences/shared/`、`experiences/{sentinelId}/` | 经验（一条一个 JSON 文件） |
| `sentinels/by-id/{sentinelId}/history/` | Sentinel 变更历史快照 |
| `skills/{name}/SKILL.md` | 用户级 Skill |
| `kv.json` | TUI 的键值设置（GUI 用 SharedPreferences） |

写入采用「进程内串行 + 跨进程文件锁 + 临时文件 rename」三条保障：GUI 与 TUI 可能同时打开同一目录，读到的要么是旧文件要么是新文件，不会读到写坏一半的内容。文件永远是唯一真相，缓存类数据都可删除重建。

持久化实体使用 UUIDv7 字符串 ID，生成不依赖共享计数或绝对路径；消息另有会话内递增的 `seq`，用于分页与压缩摘要定位。删除或重置后新建的实体使用新的身份。「不使用角色」保存为 `sentinel_id: null`。

**首次升级前请关闭全部旧版 GUI/TUI。** 新版启动时自动把整数 ID 转成 UUID，并同步转换会话、模型、角色、经验归属、历史快照和协议续接状态的引用。原始文件先完整备份到 `backups/ids-v1/`，目标文件生成完毕后才开始提交；中断后下次启动自动继续，迁移失败会阻止启动，不会继续使用半迁移数据。升级完成后不要用旧版程序打开该目录。JSON 导出的旧整数 ID 备份也可导入。迁移仅解决身份引用，不合并不同设备对同一记录的修改。

旧版角色数据、备份与历史快照中的 `avatar` 字段在读取时忽略；重新保存或导出角色时不再写出该字段，其余角色内容照常保留。

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
