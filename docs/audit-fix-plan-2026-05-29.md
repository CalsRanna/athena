# Athena 审计修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL：执行本计划时，每个阶段用 superpowers:subagent-driven-development（推荐，每任务派新 subagent + 阶段间评审）或 superpowers:executing-plans（同会话批量执行 + 检查点）逐任务实施。任务用 `- [ ]` 复选框跟踪。

**Goal：** 分阶段、可独立交付地修复 `docs/audit-2026-05-29.md` 中的全部 35 项发现，安全优先，每阶段自带回归测试。

**Architecture：** 8 个阶段，按「安全 → 正确性 → 架构 → 文档/测试」排序。每阶段聚焦一个内聚领域（尽量只触碰同一组文件），独立可交付、自带测试、可单独成一个 PR。本文件是**路线图级**计划；执行某阶段时，再把该阶段展开为 bite-sized TDD 步骤（写失败测试 → 跑红 → 最小实现 → 跑绿 → 提交）。

**Tech Stack：** Flutter、signals、GetIt、Laconic + SQLite、openai_dart、flutter_test。

---

## 阶段总览与状态

| 阶段 | 主题 | 覆盖发现 | 严重 | 状态 | 依赖 |
|---|---|---|---|---|---|
| P1 | 权限模型自洽（沙箱/审批） | S1 S2 S5 S6 S8 / T2 T3 | 高 | 待开始 | — |
| P2 | Skill 信任与提权防护 | S3 | 高 | 待开始 | P1 |
| P3 | 外发面与密钥 | S4 S7 S9 | 中 | 待开始 | P1 |
| P4 | 流式 / 取消 / 并发正确性 | C2 C5 C8 C12 | 高 | 待开始 | — |
| P5 | 网络层健壮性 | C1 C9 C10 C13 | 高 | 待开始 | — |
| P6 | 数据完整性 | C3 C4 C6 C7 C11 | 高 | 已完成 | C3 先验证 |
| P7 | 架构：DI 与解耦 | A1–A9 | 高 | 已完成 | — |
| P8 | 文档与测试补强 | D1 / T1 余项 + 迁移/file_update/VM 测试 | 中 | 已完成 | — |

> 推荐执行顺序：P1 → P2 → P3 →（P4 ‖ P5 ‖ P6 可并行）→ P7 → P8。P7（DI 重构）面大风险高，刻意排在安全/正确性收口之后，且建议执行前为其单独细化一份 plan。

---

## 执行约定（所有阶段通用）

- **TDD**：每个修复先写**失败测试**（重现 bug / 锁定行为），再改实现，最后 `flutter analyze` 零告警 + `flutter test` 全过。
- **每阶段一分支一 PR**：分支名 `fix/audit-pN-<topic>`；PR 描述引用发现 ID（如 “closes S2, S6”）。
- **频繁提交**：每个发现（或其测试+实现）一次提交，conventional commits 风格（`fix(agent): ...` / `test(permission): ...`）。提交信息**不含任何 AI 署名标记**。
- **完成即更新追踪**：改完一条，把 `docs/audit-2026-05-29.md` 对应行「状态」改为「已修复」，并在该文件「更新记录」追加一行。
- **回归基线**：动手前先记录 `flutter test` 当前为 95 项全过，作为不回归的基线。

---

## P1 — 权限模型自洽（沙箱 / 审批）

**目标：** 消除权限模型的内部矛盾与可绕过点，让“危险等级 + 审批 + 沙箱”三者语义一致、对抗用例可回归。

**覆盖发现：** S1（读类工具等级不一致）、S2（`..` 穿越绕过）、S6（forbidden 未拦截）、S5（审批文案截断）、S8（命令黑名单可绕过）；新增测试 T2（路径穿越对抗）、T3（沙箱绕过变体）。

**涉及文件：**
- 修改：`lib/agent/permission/permission_service.dart`、`lib/agent/permission/permission_rule.dart`、`lib/agent/permission/sandbox.dart`、`lib/agent/agent_service.dart`、`lib/agent/tool/unix_search_tool.dart`、`lib/agent/tool/powershell_search_tool.dart`、`lib/agent/tool/list_directory_tool.dart`、`lib/view_model/chat_view_model.dart`（`_formatToolArgs`）
- 测试：`test/agent/permission/permission_rule_test.dart`、`test/agent/permission/sandbox_test.dart`、新增 `test/agent/agent_service_gating_test.dart`

**关键决策（启动时确认；以下为推荐默认）：**
- **S1 → 推荐“收紧”**：把 `search` / `list_directory` 的 `dangerLevel` 提升为 `needsApproval`，与 `file_read` 对齐。这是**最小且安全方向**的修复，不引入新子系统。
  - 备选（更优 UX，但属新功能，建议作为后续独立阶段）：引入“工作区根”概念——读取工作区内 `safe`、区外 `needsApproval`。若选此项，P1 仅做 S2/S5/S6/S8，S1 拆到专门阶段。
- **S2 → 在权限检查之前统一 canonical 化**：复用 `PathSandbox` 的解析逻辑（`~`、`..`、symlink、去尾斜杠），对 `file_*` 工具的 `path` 参数先规范化，再做规则匹配与沙箱校验，使“规则匹配的路径”与“真正落盘的路径”一致。

**任务清单：**
- [ ] **S2-canonicalize**：在 `PathSandbox` 暴露/复用规范化（`resolveAbsolute` 已有），让 `PermissionService._extractKeyArg`（或其调用点 agent_service）对文件类工具的 path 先规范化再传入 `matchesAllow`/`isDangerous`。
  - 测试先行：在 `permission_rule_test.dart` 加用例——递归规则 `/a/b/` + 请求 `/a/b/../../etc/x` 应**不**匹配（规范化后 `/etc/x` 不在 `/a/b/` 下）；含相对路径、重复斜杠、尾斜杠差异。
- [ ] **S1-gate-reads**（按推荐默认）：`UnixSearchTool`/`PowerShellSearchTool`/`ListDirectoryTool` 的 `dangerLevel` 改为 `needsApproval`。
  - 测试：新增 gating 测试断言这三个工具进入审批门（见 agent_service_gating_test）。
  - 同步：在 `permission_service.dart` 为 `search`/`list_directory` 增加合理的 `_extractKeyArg`（按 path 粒度）与 `generateRule` 描述（“Always allow listing/searching in 目录”）。
- [ ] **S6-forbidden**：在 `agent_service.dart` 工具执行前增加 `if (effectiveLevel == DangerLevel.forbidden) { 注入拒绝消息; continue; }`，确保 forbidden 永不 execute。
  - 测试：gating 测试注入一个 forbidden 工具，断言不执行且返回拒绝文案。
- [ ] **S5-full-command**：`chat_view_model.dart` 的 `_formatToolArgs` 对 `bash`/`powershell` 的 `command`（及其它命令类）**不截断**，完整展示（弹窗内可滚动）；其余参数保留截断。
  - 验证：手动在桌面端触发一条 >120 字符命令审批，确认完整可见。
- [ ] **S8-deny-hardening**：加固 `sandbox.canExecute` 与内置 deny 规则——
  - `_hasDestructiveRm` 兼容 `-r -f` 分写、`-fr`、`/bin/rm`、`--recursive`；`_splitByOperators` 增加换行符切分；重定向检测覆盖 `>>`、`1>`、`tee`；pipe-to-shell 增补常见解释器（`python`/`node`/`perl`/`ruby`）。
  - deny 规则的 `contains` 子串匹配改为更稳健的归一化匹配（折叠多空格、大小写）。
  - 测试 T3：在 `sandbox_test.dart` 补全上述每种绕过变体的拒绝用例。
- [ ] **T1-gating（本阶段部分）**：新增 `test/agent/agent_service_gating_test.dart`——用 fake `ChatService`（产出预设 tool_call 流）+ fake `ToolRegistry` + 桩 `PermissionService`/`onPermission`，覆盖：needsApproval 工具在 `check==null` 且拒绝时不执行；`check==true` 跳过弹窗；`onPermission==null` 注入 deniedMsg；forbidden 不执行；取消令牌在等待审批时返回 false。

**完成标准（DoD）：** 上述测试全过；`flutter analyze` 零告警；递归授权无法经 `..` 越界；三类读工具与 file_read 等级一致；forbidden 必被拦截；审批弹窗对命令不截断。

---

## P2 — Skill 信任与提权防护

**目标：** 阻断“项目级 Skill 静默降权 + 描述注入系统提示词”的提权链。

**覆盖发现：** S3。

**涉及文件：**
- 修改：`lib/agent/skill/skill_registry.dart`（`effectiveDangerLevel`、`loadAll`、`level1Prompt`）、`lib/agent/skill/skill_loader.dart`（信任状态）、可能新增 `lib/agent/skill/skill_trust_store.dart`、审批/信任弹窗 `lib/widget/`、`lib/view_model/chat_view_model.dart` 接线
- 测试：`test/agent/skill/skill_loader_test.dart`、新增 `test/agent/skill/skill_trust_test.dart`

**关键决策（推荐“两者都做”）：**
- **硬下限**：`effectiveDangerLevel` 中，对一组“危险工具”（`bash`/`powershell`/`file_write`/`file_update`/`file_delete`）永不因 skill 的 `allowed-tools` 降为 `safe`（最多保持其原始等级）。
- **项目信任**：首次加载某项目目录（`Directory.current/.athena/skills`）的 skills 时，弹窗让用户确认信任；未信任前，项目级 skills 既不参与 `level1Prompt` 注入、也不生效 `allowed-tools` 降权。信任状态持久化（如 `~/.athena/trusted_skill_dirs.json`）。

**任务清单：**
- [ ] **硬下限**：定义危险工具集合常量；改 `effectiveDangerLevel`，危险工具命中 allowed-tools 时不降级。
  - 测试：扩展 `skill_loader_test.dart`——skill 声明 `allowed-tools: bash` 时，bash 仍为 needsApproval（对比普通 safe 工具可降级）。
- [ ] **信任存储**：实现 `SkillTrustStore`（load/save/isTrusted(dirPath)/trust(dirPath)），持久化到 `~/.athena/`。
  - 测试：信任前 `isTrusted` 为 false，trust 后为 true，重载保持。
- [ ] **加载门控**：`SkillRegistry.loadAll` 对项目级目录，仅在已信任时纳入 `_skills`（影响 `level1Prompt` 与降权）；未信任时跳过或标记为“需信任”。
- [ ] **信任弹窗接线**：在会话启动/首次需要时触发信任确认 UI；用户拒绝则项目 skills 不生效。
  - 验证：在一个含 `.athena/skills/` 的测试项目目录打开应用，确认未信任时 skill 不出现在系统提示、bash 仍弹窗。

**完成标准：** 危险工具无法被任何 skill 降为 safe；未信任的项目级 skill 不注入提示词、不降权；信任状态可持久化。

---

## P3 — 外发面与密钥

**目标：** 收紧数据外发通道与本地密钥可达性。

**覆盖发现：** S4（web_fetch 全 URL 放开 + 无 SSRF 防护）、S7（DB 含明文 API Key 且不在黑名单）、S9（SQL 入日志可能含敏感值）。

**涉及文件：**
- 修改：`lib/agent/tool/web_fetch_tool.dart`、`lib/agent/permission/permission_service.dart`（web_fetch 规则按 host 粒度）、`lib/agent/permission/sandbox.dart`（黑名单加数据目录）、`lib/database/database.dart`（日志）
- 测试：新增 `test/agent/tool/web_fetch_tool_test.dart`、扩展 `test/agent/permission/sandbox_test.dart`、`permission_rule_test.dart`

**任务清单：**
- [ ] **S4-host-scope**：`PermissionService` 对 `web_fetch` 的 `generateRule`/`generateRuleDescription` 改为按 origin（scheme+host[:port]）粒度，而非无 pattern 全放开；`_extractKeyArg('web_fetch')` 提取 host。
  - 测试：允许 `https://a.com` 后，对 `https://b.com` 仍需审批。
- [ ] **S4-SSRF**：`web_fetch_tool` 解析 URL 后，拒绝 loopback（127.0.0.0/8、::1、localhost）、link-local（169.254.0.0/16，含云元数据）、私网段（10/172.16/192.168）——或在审批文案明确标红提示“内网地址”。
  - 测试：`http://169.254.169.254/` 与 `http://localhost` 被拒绝（或标记）。
- [ ] **S7-denylist-datadir**：把应用数据目录（`getApplicationSupportDirectory()` 下含 `athena.db`）加入 `PathSandbox` 默认黑名单，使 Agent 无法经 file_read/search 读取自身密钥库。
  - 注意：黑名单按绝对路径，需在运行时解析数据目录（构造 sandbox 时注入，或 sandbox 内异步解析）。
  - 测试：sandbox 拒绝读取数据目录下路径。
- [ ] **S9-log**：`database.dart` 的 `listen` 回调避免记录可能含密钥/PII 的语句值——改为仅记录 SQL 模板/操作类型，或在非 debug 构建关闭；至少 providers/messages 表的写入不落明文。
- [ ] （可选，登记为后续）密钥转存 OS keychain——本阶段不做，留待独立任务。

**完成标准：** web_fetch 永久规则按 host 隔离、内网地址被拦或显著告警；Agent 无法读取应用数据目录；敏感值不进日志。

---

## P4 — 流式 / 取消 / 并发正确性

**目标：** 修复聊天/翻译流式与取消路径的数据丢失与并发竞态。

**覆盖发现：** C2（取消内容丢失/标记错位）、C5（翻译流式不更新）、C8（TRPG 无重入保护）、C12（删除当前 chat / 后台命名流未守卫）。

**涉及文件：**
- 修改：`lib/view_model/chat_view_model.dart`（`_consumeAgentStream`/`sendMessage`/`deleteChat(s)`/`renameChat`）、`lib/view_model/translation_view_model.dart`（`performTranslation`）、`lib/view_model/trpg_view_model.dart`（`sendPlayerAction`）
- 测试：新增 `test/view_model/chat_view_model_stream_test.dart`、`test/view_model/translation_view_model_test.dart`、`test/view_model/trpg_view_model_test.dart`

**任务清单：**
- [ ] **C2-cancel-persist**：`_consumeAgentStream` 在流中（或退出/异常时）持久化 `current`；`sendMessage` 的 `CancelledException` 分支基于最新 `current`（而非第 512 行旧占位）落库。可让 `_consumeAgentStream` 把最新 message 暴露给外层（如成员字段或 finally 写回）。
  - 测试先行：注入 fake AgentService 发若干 text 事件后令 cancelToken 取消，断言已生成内容被持久化、取消标记打在正确消息上。
- [ ] **C5-translation-stream**：`performTranslation` 的 `await for` 循环内 `translatedText.value = buffer.toString()`（或 `appendTranslatedText(chunk)`），使流式 UI 实时更新。
  - 测试：fake 翻译流，断言 `translatedText` 随 chunk 增长。
- [ ] **C8-trpg-reentrancy**：`sendPlayerAction` 开头加 `if (isStreaming.value) return;`。
  - 测试：流式中再次调用应被忽略，不产生第二条流/重复入库。
- [ ] **C12-delete-guard**：`deleteChat`/`deleteChats` 删除当前流式 chat 前先 `stopGenerating()` 或拒绝；`renameChat` 后台流绑定可取消（chat 删除时取消）。
  - 测试：流式中删除当前 chat 不产生孤儿/无效写入。

**完成标准：** 取消后已生成内容不丢、标记不错位；翻译流式可见；TRPG 无并发双流；删除/重命名与流式不冲突。

---

## P5 — 网络层健壮性

**目标：** 消除 HTTP 资源泄漏与重试/消息构建的正确性问题。

**覆盖发现：** C1（OpenAIClient 不 close）、C10（上下文截断切断 tool 配对）、C13（`_isRetryable` 子串误判）、C9（retry 日志插值 bug）。

**涉及文件：**
- 修改：`lib/service/chat_service.dart`、`lib/service/summary_service.dart`、`lib/service/translation_service.dart`、`lib/service/memory_service.dart`、`lib/service/trpg_service.dart`、`lib/service/chat_message_service.dart`、`lib/util/retry.dart`
- 测试：新增 `test/service/chat_message_service_test.dart`、`test/util/retry_test.dart`

**任务清单：**
- [ ] **C1-client-close**：每处 `OpenAIClient.withApiKey(...)` 用 `try/finally` 在请求/流结束后 `endSession()`；或在 DI 按 provider 缓存复用单例 client（择一，全局一致）。先确认 openai_dart v5 的释放 API 名称。
  - 验证：长会话/多轮迭代后无连接累积（手动观察或加计数断言于可注入的 client 工厂）。
- [ ] **C10-toolcall-pairing**：`chat_message_service` 截断上下文后，校验并对齐 assistant(tool_calls) ↔ tool 结果配对，避免出现“有 tool 结果无对应 assistant”导致部分端点 400。
  - 测试：构造截断点落在配对中间的消息序列，断言输出不破坏配对。
- [ ] **C13-retryable**：`_isRetryable` 优先基于异常类型/HTTP 状态码判定，弱化纯子串匹配，避免业务错误被重试 10 次。
  - 测试：含 "connection limit" 文案的业务异常不被判为可重试。
- [ ] **C9-log-fix**：`retry.dart:43` 改为 `${config.maxAttempts}`。
  - 测试：可选，断言日志格式或直接目视。

**完成标准：** 无未关闭 client；截断不破坏 tool 配对；重试分类基于类型/状态码；日志正确。

---

## P6 — 数据完整性

**目标：** 保障删除级联、反序列化健壮性与主键/排序稳定性。

**覆盖发现：** C3（foreign_keys 连接级，可能失效）、C4（getString/getInt 裸强转）、C6（导入 ID 失配）、C7（毫秒时间戳主键碰撞）、C11（TRPG 按 created_at 排序不稳定）。

**涉及文件：**
- 修改：`lib/database/database.dart`、`lib/extension/json_map_extension.dart`、`lib/view_model/setting_view_model.dart`（导入）、`lib/view_model/summary_view_model.dart`、`lib/view_model/translation_view_model.dart`、`lib/repository/trpg_message_repository.dart`
- 测试：新增 `test/extension/json_map_extension_test.dart`、`test/database/migration_test.dart`

**任务清单：**
- [ ] **C3-verify-first**：先确认 laconic + laconic_sqlite 的连接模型（单持久连接 vs 连接池）。
  - 若**单连接**：标注 C3 为“已接受/不适用”，在审计文件记录结论。
  - 若**池/多连接**：在每次获取连接处设 `PRAGMA foreign_keys=ON`，或在所有 delete 路径显式手动级联（不依赖 FK）。
  - 测试：删除带子行的 provider/chat 后，断言子行被删（无孤儿）。
- [ ] **C4-safe-cast**：`getString` → 非 String 时回退 `value.toString()`；`getInt`/`getIntOrNull` → `int.tryParse(value.toString())`，与 getDouble/getBool 的健壮处理一致。
  - 测试：传入 int 给 getString、String 给 getInt 等混合类型均不抛、返回合理值。
- [ ] **C6-import-reconcile**：`importData` 在重插后，校验并修复既有 chats 的 `model_id`/`sentinel_id`（指向不存在则置默认或提示），或在导入前明确告知将清空/重置会话引用。
  - 测试：导入后既有 chat 不再触发 “Model not found”。
- [ ] **C7-pk**：summary/translation 主键改用自增或 UUID（或 `microsecondsSinceEpoch` + 去重），避免同毫秒碰撞。
  - 测试：连续创建多条，主键唯一、回写命中正确记录。
- [ ] **C11-ordering**：`trpg_message_repository` 排序改为 `orderBy('id')` 或追加 `id` 次级键。
  - 测试：同毫秒入库的多条消息顺序稳定。

**完成标准：** 删除级联可靠（或确认无需）；反序列化对类型不敏感；导入后引用一致；主键/排序稳定。

---

## P7 — 架构：DI 与解耦

**目标：** 让依赖图显式可见、降低 VM 间隐藏耦合、拆分 God Object。**面大风险高，建议执行前为本阶段单独细化一份 plan，并拆成 P7a/P7b/P7c 子阶段分别 PR。**

**覆盖发现：** A1（DI 退化为服务定位）、A2（VM↔VM 隐藏耦合）、A3（Provider/Model 双向耦合）、A4（retryConfig 真相分裂）、A5（默认模型逻辑散落+重复）、A6（ChatViewModel 过载）、A7（死 import）、A8（setState/signals 混用）、A9（chat Service 边界模糊）。

**子阶段：**
- [ ] **P7a 低风险清理**：A7（删 `trpg_page.dart:3` 死 import）、A8（业务 loading 统一用 VM signal）、A9（为 chat 四 Service 补职责边界文档注释）、A4（ChatService 改为从配置源读取 retryConfig 或注入不可变配置，去掉外部写字段）。
- [ ] **P7b 解耦**：A5（抽 `resolveDefaultModel()` 到领域 Service，UI/VM 复用，去重）、A3（Provider/Model 单向数据流，事件驱动或合并 Catalog）。
- [ ] **P7c DI 显式化 + God Object 拆分**：A1（`di.dart` 注册时显式传依赖，构造参数成唯一真相源）、A2（VM 间依赖进构造签名或下沉 Service）、A6（把 `_askPermission`/`_formatToolArgs` 抽到 PermissionInteractor，`_consumeAgentStream` 抽到 AgentEventReducer）。

**测试/验证：** 每子阶段后 `flutter analyze` + `flutter test` 全过；P7c 后补关键 VM 的可测试性（构造注入 fake 依赖）。

**完成标准：** 依赖在构造签名可见；ChatViewModel 显著瘦身；无运行期隐藏环；全部既有测试不回归。

---

## P8 — 文档与测试补强

**目标：** 让 CLAUDE.md 反映最终代码状态，并补齐安全/数据攸关的剩余测试缺口。

**覆盖发现：** D1（CLAUDE.md 多处偏差）、T1 余项（AgentService 主循环非门控部分：迭代上限、取消传播、摘要、截断）、迁移测试、file_update 测试、ChatViewModel/服务测试。

**任务清单：**
- [ ] **D1-doc**（放在最后，确保反映 P1–P7 终态）：更新 CLAUDE.md——工具清单（约 11 个，列全 file_update/list_directory/web_fetch/web_search，说明 bash/powershell 平台二选一）；危险等级表按 P1 决策更新（file_read 实际等级、web_fetch=needsApproval）；**重写沙箱小节为黑名单模型**（删除“白名单=项目目录”的错误描述，列全实际黑名单 + P3 新增数据目录 + P1/P2 的审批与信任机制）；删除 `chat_view_model.dart` 过时的“待实现 MCP”注释；补全服务清单（ChatManage/ChatSupport/Sentinel）与正确的目录树。
- [ ] **T1-rest**：补 `agent_service` 的迭代上限收尾、取消在多点传播、辅助模型摘要回退、`_smartTruncate` 截断的测试。
- [ ] **迁移测试**：用临时 SQLite 跑全部迁移，验证 `db_integrity` 的孤儿清理、CASCADE 生效、context_window 归一化（含 `_formatThousands`、K/M、已含 context 的跳过分支）、迁移幂等。
- [ ] **file_update 测试**：唯一/多匹配校验、replace_all、行号前缀剥离、引号归一化、CRLF 保留、mtime 外部修改检测、删除吞换行。
- [ ] **低价值测试清理**：`powershell_shell_tool_test`/`powershell_search_tool_test` 补真实 execute 行为或与 unix 版参数化合并。

**完成标准：** CLAUDE.md 与代码一致（尤其沙箱模型与危险等级表）；AgentService、迁移、file_update 有行为级覆盖；测试信噪比提升。

---

## 自检（spec 覆盖核对）

35 项发现映射阶段：S1/S2/S5/S6/S8 → P1；S3 → P2；S4/S7/S9 → P3；C2/C5/C8/C12 → P4；C1/C9/C10/C13 → P5；C3/C4/C6/C7/C11 → P6；A1–A9 → P7；D1 + T1/T2/T3 → 分布于 P1/P8。无遗漏。

---

## 更新记录

| 日期 | 变更 | 处理人 |
|---|---|---|
| 2026-05-29 | 初版分阶段修复计划生成（8 阶段） | - |
| 2026-06-05 | P7/P8 收尾：A1（DI 全显式注册）+ A6（PermissionInteractor 抽取），全部 8 个阶段完成 | - |
