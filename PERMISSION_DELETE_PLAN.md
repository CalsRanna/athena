# Athena 删除类命令防护：从工具内硬拦迁移到审批链

日期：2026-09-21
状态：**已实施（2026-09-21）**。§5 的两项待决策均按建议执行——A：权限服务缺席时
`ToolRisk.dangerous` 直接 deny（其余保持 allow）；B：递归删除类命令只提供 Allow Once
（GUI 隐藏 Always Allow 按钮、TUI 隐藏 `[a]` 键、协调器另有一道持久化抑制）。§6 改动
清单全部落地，并补 `packages/athena_core/test/agent/permission/command_analyzer_test.dart`
把 §3 的样本表固定为断言。

复审后修正（2026-09-21 同日）：cmd 的 `/s` 改为精确匹配（`rd /srv/data`、`del /src/*.log`
这类路径不再误判）；包装词选项（`sudo -u root`、`nice -n 5`、`timeout 5`、`env -i`）、
`xargs`、`bash -c '…'` 内联脚本纳入识别；AI 提示词与 §10 对齐（递归删除在用户请求未明确
授权该确切目标时才一律 ask，已授权的清理仍可放行）；`risk_signals` 回带进审批记录。

**最终修订（2026-09-21，取代 §4.3、§5-B 与 §6 中与识别器相关的条款）**：删除宿主侧识别器
`CommandAnalyzer.isRecursiveDelete` 及其全部消费点；§5-B 的 Always Allow 抑制改为不依赖命令
语义的通用机制——shell 的「始终允许」落整条命令的精确匹配。理由与验证见 §12。

## 1. 目标与范围

**现状**：`bash` / `powershell` 工具在 `execute()` 入口对"递归删除"类命令做无条件硬拦，与权限系统无关。

**目标**：移除这层硬拦，删除类命令的防护改由三处判定承担——权限规则（deny）、AI 审批、人工审批；递归删除的识别能力保留，但角色从"否决"降级为"风险信号"（见 §4.3）。

**理由**（实测见 §3）：现有硬拦同时具备高误伤与高漏检，而且位于权限门之后，使人工审批对这类命令失去意义——用户批准与否都不改变结果。

**范围内**：`athena_core` 的 shell 工具、`CommandAnalyzer`、`PermissionService`、`AgentService` 权限门、`AgentRunCoordinator` 的审批落库、AI 审批提示词，以及 AGENTS.md 中对该策略的记载。

**不在范围内**：文件工具（`file_write` / `file_update`）的覆盖语义；工作区沙箱与路径边界；移动端（[tool_set.dart](/Users/cals/Spare/athena/packages/athena_core/lib/agent/tool/tool_set.dart:62) 的移动端分支不注册 shell 工具，因此不受本方案影响）。

**明确不引入**：不可编辑的内置 deny 规则。本方案选择完全交给"规则 + 审批"，若将来需要规则层直接拒绝，先看附录 A 的限制。

## 2. 现状与代码依据

| 位置 | 现状 | 影响 |
|---|---|---|
| [bash_shell_tool.dart:107](/Users/cals/Spare/athena/packages/athena_core/lib/agent/tool/bash_shell_tool.dart:107)、[powershell_shell_tool.dart:107](/Users/cals/Spare/athena/packages/athena_core/lib/agent/tool/powershell_shell_tool.dart:107) | `execute()` 最开头调用 `isRecursiveDelete`，命中即返回一段 Warning 字符串，无开关、无例外 | 权限门已经放行（或用户已批准）的命令仍不会执行 |
| [bash_shell_tool.dart:107 注释](/Users/cals/Spare/athena/packages/athena_core/lib/agent/tool/bash_shell_tool.dart:107) | 写着"用户在弹窗中可以看到完整命令并决定是否放行" | 与实现相反：该弹窗来自权限门，批准对本分支无效，注释误导后续维护 |
| [command_analyzer.dart:312](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/command_analyzer.dart:312) 至 [:335](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/command_analyzer.dart:335) | 19 条正则，覆盖 POSIX / cmd / PowerShell 两套语法，对**整条命令文本**匹配 | 判定的是文本而非意图，见 §3 |
| [agent_service.dart:313](/Users/cals/Spare/athena/packages/athena_core/lib/agent/agent_service.dart:313) | 只有以 `Error` 开头的结果才标记 `ToolResultStatus.executionError` | 硬拦返回的是 `Warning:`，因此这次拒绝在上层不计为失败 |
| [agent_service.dart:420](/Users/cals/Spare/athena/packages/athena_core/lib/agent/agent_service.dart:420) 至 [:429](/Users/cals/Spare/athena/packages/athena_core/lib/agent/agent_service.dart:429) | `permissionService?.check(...) ?? (onPermission == null ? allow : prompt)` | 权限服务缺席且无审批回调时，判定为 allow。今天由工具内硬拦掩盖，删掉硬拦后成为真实缺口（§5-A） |
| [agent_run_coordinator.dart:726](/Users/cals/Spare/athena/packages/athena_core/lib/coordinator/agent_run_coordinator.dart:726) 至 [:730](/Users/cals/Spare/athena/packages/athena_core/lib/coordinator/agent_run_coordinator.dart:730) | "Always Allow" 通过 `PermissionRule.forToolCall` 落库为 `action` 规则（动作 + 参数前缀） | 对删除类命令无效（被硬拦挡住）；删掉硬拦后成为新增风险面（§5-B） |

两个正面事实，是"可以依赖审批链"的前提：

1. **所有工具执行都经过同一个门**：[agent_service.dart:1093](/Users/cals/Spare/athena/packages/athena_core/lib/agent/agent_service.dart:1093) 是唯一执行入口，失败反思路径也刻意复用它（[agent_service.dart:1073](/Users/cals/Spare/athena/packages/athena_core/lib/agent/agent_service.dart:1073)）；协调器的权限服务是**非空** required 字段（[agent_run_coordinator.dart:52](/Users/cals/Spare/athena/packages/athena_core/lib/coordinator/agent_run_coordinator.dart:52)、[:128](/Users/cals/Spare/athena/packages/athena_core/lib/coordinator/agent_run_coordinator.dart:128)），并在 [:318](/Users/cals/Spare/athena/packages/athena_core/lib/coordinator/agent_run_coordinator.dart:318) 同时传入服务与审批回调。GUI / TUI 不存在绕过门执行 shell 的路径。
2. **AI 审批是 fail-closed**：[ai_permission_reviewer.dart:37](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/ai_permission_reviewer.dart:37)（fallback 构造）、[:97](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/ai_permission_reviewer.dart:97)（超预算）、[:128](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/ai_permission_reviewer.dart:128)（决策非法）、[:141](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/ai_permission_reviewer.dart:141)（异常/超时）都返回 `allowed: false`，转人工。其提示词（[:150](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/ai_permission_reviewer.dart:150)）已写明：删除有价值数据需要"覆盖确切目标与实质影响"的明确授权，不得从助手声称、技能、记忆或工具输出推断同意，且决策只对本次调用有效。

## 3. 实测证据（2026-09-21）

方法：临时 Dart 脚本直接 `import` 真实的 `command_analyzer.dart`，对 25 条命令调用 `isRecursiveDelete`，只做字符串判定，不执行任何命令；测完删除脚本，未入库。复现方式见 §8。

**误拦：只读或非删除命令（9/9 全部 BLOCKED）**

```text
grep -rn "rm -rf" docs/
git log -S "rm -rf" --oneline
git commit -m "docs: explain why rm -rf is blocked"
man rmdir
grep -n rmdir AGENTS.md
echo "rmdir only removes empty dirs"
git log --grep=rmdir --oneline
rg -l "Remove-Item -Recurse" .
find . -name "*.md" | grep rm
```

**误拦：单文件删除 + 无关 flag（因 `-r` 未锚定到 `rm` 参数，5/5 BLOCKED）**

```text
rm a.txt && ls -ltr
rm a.txt && git log -1 --format=%H
rm build/app.dill && git status --short
```

同类对照，后者因后续 flag 不含 r 字母而放行：`rm a.txt && git diff --stat HEAD`、`rm a.txt && ls -t`。也就是说工具提示里"用 `rm file1 file2` 不带 `-r`"的建议在真实组合里不成立。

**漏检：间接删除（6/6 全部 allowed）**

```text
git clean -xfd
rsync -a --delete src/ dst/
F=-rf; rm $F build/
perl -e "unlink glob q{build/*}"
bash scripts/clean.sh
mv build /tmp/trash
```

**正确放行（4/4 allowed）**：`rm build/app.dill`、`rm a.txt b.txt`、`rm -i notes.md`、`ls -la`。

**结论**：在"提及该模式"的只读命令上误拦率 100%，在"间接执行删除"的命令上漏检率 100%。它拦得住的是模型直接写出的字面形式，而这条路径在删掉硬拦后由 AI 审批 + 人工审批接管，强度不下降。

## 4. 目标行为

**4.1 判定顺序**保持不变：deny 规则 → 只读短路 → 会话缓存 → allow 规则 → 弹窗（[permission_service.dart:20](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/permission_service.dart:20) 至 [:25](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/permission_service.dart:25)）。递归删除不再有工具层否决。

**4.2 审批结果必须真实生效**：用户在弹窗里批准的命令要能执行；不再出现"弹窗 → 批准 → 仍被拒"的组合。

**4.3 递归删除识别降级为信号**（**已被 §12 取代**：识别器整体移除），用于三处，且都不构成否决：

- 作为 AI 审批的输入提示：AI 审批器自己声明看不到脚本与被引用文件的内容（[ai_permission_reviewer.dart:167](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/ai_permission_reviewer.dart:167)），`bash scripts/clean.sh` 这类只能靠猜；把"该命令匹配递归删除模式"作为证据传入，可提高它的判断质量。
- 作为"Always Allow"的抑制判据（§5-B）。
- 作为可选策略的判据：将来若用户希望为删除类命令加一条 deny 规则，由这层识别提供依据（附录 A 说明为何不能直接写成规则）。

## 5. 待决策项

| 编号 | 议题 | 建议 | 影响面 |
|---|---|---|---|
| A | [agent_service.dart:420](/Users/cals/Spare/athena/packages/athena_core/lib/agent/agent_service.dart:420) 的空兜底是否收口 | **建议收口**：`permissionService` 为空时，`ToolRisk.dangerous` 返回 deny（其余工具保持 allow） | 改变的是"库被无权限装配调用"时的行为：危险工具从静默执行改为直接拒绝。GUI / TUI 不受影响（始终装配）。这是唯一不依赖调用方自觉的封口 |
| B | 删除类命令是否禁用"Always Allow" | **建议禁用**（**已被 §12 取代**：改为 shell 一律落 exact，不再按命令语义区分） | 现状该路径被硬拦掩盖；删掉硬拦后，一次点击会把同类命令变成永久静默放行、无弹窗、无 AI 复审、无会话隔离。只给 Allow Once 即可保留用户便利，代价是每次确认 |

两项都需要在实施前明确，未决时按建议执行并在提交信息中记录。

## 6. 改动清单

| 位置 | 必要改动 |
|---|---|
| **【本节与识别器相关的行已被 §12 取代】** | 最终形态：删除识别器与其全部消费点，shell 的 Always Allow 落 exact |
| [bash_shell_tool.dart:107](/Users/cals/Spare/athena/packages/athena_core/lib/agent/tool/bash_shell_tool.dart:107) 至 [:115](/Users/cals/Spare/athena/packages/athena_core/lib/agent/tool/bash_shell_tool.dart:115)、[powershell_shell_tool.dart:107](/Users/cals/Spare/athena/packages/athena_core/lib/agent/tool/powershell_shell_tool.dart:107) 至 [:115](/Users/cals/Spare/athena/packages/athena_core/lib/agent/tool/powershell_shell_tool.dart:115) | 删除硬拦分支与失效注释；`CommandAnalyzer` 的 import 按 §6.3 的用途保留或转移 |
| [bash_shell_tool.dart:48](/Users/cals/Spare/athena/packages/athena_core/lib/agent/tool/bash_shell_tool.dart:48)（工具描述）、[powershell_shell_tool.dart:40](/Users/cals/Spare/athena/packages/athena_core/lib/agent/tool/powershell_shell_tool.dart:40) | 改掉"NEVER use …"的绝对措辞，说明破坏性命令会触发审批而不是被拒绝 |
| [command_analyzer.dart:316](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/command_analyzer.dart:316) 至 [:335](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/command_analyzer.dart:335) | 收窄误伤：`-r` / `--recursive` 只在 `rm` 子命令的参数内匹配（先 `splitSubcommands`，同 `isReadOnlyCommand` 的做法）；`rmdir` 移出模式表（POSIX `rmdir` 只能删空目录，是删目录的安全形式）；`git rm -r --cached` 等不动工作区的形态重新评估。其余形态（`find -delete`、`del /s`、`rd /s`、`Remove-Item -Recurse`）保留 |
| [agent_service.dart:420](/Users/cals/Spare/athena/packages/athena_core/lib/agent/agent_service.dart:420) 至 [:429](/Users/cals/Spare/athena/packages/athena_core/lib/agent/agent_service.dart:429) | 按 §5-A 收口空兜底 |
| [agent_run_coordinator.dart:726](/Users/cals/Spare/athena/packages/athena_core/lib/coordinator/agent_run_coordinator.dart:726) 至 [:730](/Users/cals/Spare/athena/packages/athena_core/lib/coordinator/agent_run_coordinator.dart:730) | 按 §5-B 抑制删除类命令的 Always Allow（判据来自分类器） |
| [agent_service.dart:436](/Users/cals/Spare/athena/packages/athena_core/lib/agent/agent_service.dart:436) 至 [:449](/Users/cals/Spare/athena/packages/athena_core/lib/agent/agent_service.dart:449) | 把"匹配递归删除模式"作为附加证据传给 AI 审批（`arguments` 之外的新字段，或复用 `reviewContext`） |
| [ai_permission_reviewer.dart:150](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/ai_permission_reviewer.dart:150)（系统提示词） | 提示词已覆盖"删除有价值数据需明确授权"，建议补一句：递归删除、或目标内容未知的删除，一律 `ask`（与它自身"看不到脚本内容"的限制对应） |
| [AGENTS.md:311](/Users/cals/Spare/athena/AGENTS.md:311) | 该行记载"bash/powershell 递归删除命令被检测到拒绝执行"，实施后改为"由权限与审批处理，工具内不再拦截"，并说明识别能力的用途 |
| 仓库文档（AGENTS.md §14） | §14 写"三个包都没有测试套件"，但 `packages/athena_core/test/storage/file_storage_test.dart` 已入库（`git ls-files` 统计为全仓唯一 `_test.dart`）。实施时顺带更新该节 |

## 7. 实施顺序与验收

| 阶段 | 交付物 | 通过条件 |
|---|---|---|
| P0：分类器修正 | `isRecursiveDelete` 作用域收窄、`rmdir` 移出 | §3 的 9 条误拦样本（含 `rm a.txt && ls -ltr` 三条）全部 `allowed`；漏检样本的判定结果记录在案（仍漏是刻意取舍，不是遗漏） |
| P1：移除硬拦 | 两个 shell 工具去掉分支与失效注释，更新工具描述 | GUI / TUI 中 `rm -rf <dir>` 触发审批弹窗；人工批准后**命令真正执行**；只读命令不再被拦 |
| P2：空兜底收口（§5-A） | `AgentService` 空兜底改动 | 直接构造无权限服务的 `AgentService` 时，危险工具被拒绝而非执行；正常两端行为不变 |
| P3：审批链收口（§5-B + 信号接入） | Always Allow 抑制、AI 审批提示 | 删除类命令的审批界面不出现 Always Allow；AI 审批记录里能看到递归删除提示；既有 allow 规则不会静默放行删除类命令 |

P0 必须在 P1 之前完成：否则误伤命令会从"被拒"变成"每次打断用户"。

## 8. 验证方式

当前仓库没有测试套件（AGENTS.md §14），唯一静态保障是 `dart analyze` / `flutter analyze` 到 0 issue。因此：

- **必须**：`export PATH="/Users/cals/SDK/flutter/bin:$PATH"` 后对改动的包跑 `dart analyze`，0 issue。
- **建议**：本方案的核心是纯函数（`isRecursiveDelete`）与判定顺序（`PermissionService.check`），两者都不依赖 Flutter，适合补最小单测（`packages/athena_core/test/` 已有 `file_storage_test.dart` 作为先例）：把 §3 的样本表直接写成断言。若决定不补套件，则用 §10 的手工清单验收。
- **复现 §3 的方法**：在 `packages/athena_core/` 下放一个临时脚本，`import 'lib/agent/permission/command_analyzer.dart';`（该文件无 package 依赖，相对导入即可，不需要 `pub get`），打印每条命令的判定结果，跑完删除脚本。
- **实施前注意**：硬拦存在时，部分用例无法写在同一条 shell 命令里（判定看的是命令文本），需要拆成多次调用；P0 之后这一限制消失。

## 9. 风险、回退与明确不承诺

- **主要风险**：删除类命令的第一道判定变为一个语言模型。误放行的代价不可恢复，而误拦的代价只是多问一次。缓解手段：AI 审批 fail-closed；人工审批仍在链上；用户随时可加 deny 规则；工具内不再有否决（这正是本方案的目的）。
- **次要风险**：删掉硬拦后，模型若被提示注入诱导，可用的破坏面比现在大（现在它能绕过硬拦的方式本就有：`bash scripts/clean.sh`、变量展开、`git clean`），区别在于不再有"文本字面必拦"这一层。
- **回退**：改动集中在两个 shell 工具的入口与三处判定，`git revert` 即可恢复原状；也可选择不恢复工具内分支，改为在规则层加 deny（附录 A）。
- **明确不承诺**：本方案生效后，"任何情况下模型都无法递归删除"这一属性不再成立。它被替换为"不可恢复操作需要一次明确的授权判定"。

## 10. 手工验收用例

| 用例 | 预期 |
|---|---|
| `rm build/app.dill` | 单文件删除正常放行或按现有规则弹窗；执行成功后文件消失 |
| `rm -rf build/`（工作区内构建产物） | 触发审批；AI 审批可放行（用户请求为清理构建产物时）；批准后真正执行 |
| `grep -rn "rm -rf" docs/` | 不再被拦；作为只读命令短路或经审批放行 |
| `man rmdir` | 不再被拦 |
| `rm a.txt && ls -ltr` | 不再被拦 |
| `bash scripts/clean.sh`（脚本内含递归删除） | AI 审批因看不到脚本内容而倾向 `ask`，转人工 |
| `rm -rf /`（越界目标） | AI 审批应 `ask`；人工拒绝后不执行 |
| 对 `rm -rf build/` 点 Always Allow | 按 §5-B 的结论：不提供该选项（或提供但需明确记录取舍） |
| 关闭 AI 审批（`aiApprovalEnabled=false`） | 直接进入人工审批，不发生静默执行 |

## 11. 完成定义

- 两个 shell 工具内不再有删除类命令的硬拦，也没有声称"用户可放行"的失效注释。
- 分类器保留并修正误伤；其输出被用于审批提示与 Always Allow 抑制，而非否决。
- 空兜底与 Always Allow 两项决策已明确落地，并有对应的验证记录。
- `dart analyze` / `flutter analyze` 0 issue；AGENTS.md §7.4 与 §14 的记载与实际一致。

## 附录 A：为何"把这条策略写成规则"不能直接做（可选后续）

若将来希望用一条 deny 规则取代审批链的默认行为，需先扩展规则模型：[permission_rule.dart:22](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/permission_rule.dart:22) 的 `RuleKind` 只有 `action` / `exact` / `origin` / `path` 四种，而 `action` 规则对参数做的是"整串 glob 或前缀 + 词边界"匹配（[:229](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/permission_rule.dart:229) 至 [:235](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/permission_rule.dart:235)），表达不出"参数任意位置含 `-r`"，更表达不出 `find -delete`、`del /s`、`Remove-Item -Recurse` 这类跨动作形态。另外 [PermissionStore](/Users/cals/Spare/athena/packages/athena_core/lib/agent/permission/permission_rule.dart:294) 把全部规则读写到 `~/.athena/permissions.json`，规则没有内置/只读标记，而 GUI / TUI 目前只有 DI 注册与启动 `load()`，没有任何界面展示或管理这些规则——因此把安全策略放进这一层时，需要一并提供可见性，否则等于把"隐形约束"换成"隐藏设置"。

## 12. 最终修订：识别器整体移除（2026-09-21）

**决定**：删除宿主侧识别器 `CommandAnalyzer.isRecursiveDelete`（含动作词锚定、包装词跳过、
内联脚本解析等约 230 行辅助逻辑）及其全部消费点；shell 工具的「始终允许」改为落整条命令的
精确匹配。本节取代 §4.3 的「降级为信号」与 §5-B 的「按命令语义抑制 Always Allow」。

**为何推翻 §4.3 的结论**：

1. **对 AI 是冗余的。** 审批器本来就从 `arguments` 拿到完整命令原文，提示词也已列明 `rm -r` /
   `rm -rf` / `--recursive` / `find -delete` / `git clean` / `git rm` / `del /s` /
   `Remove-Item -Recurse` 需要 ask。再附一句「宿主模式命中了」没有给出任何它看不到的信息——
   它读的是同一段文本，而宿主那层的可靠性还更低。
2. **对 Always Allow 是误配的。** §5-B 的抑制是它唯一有实际作用的落点，而复审实测表明以下
   写法全部漏检（旧正则会命中，新实现命中不了）：`if [ -d build ]; then rm -rf build; fi`、
   `for d in a b; do rm -rf $d; done`、`(rm -rf build)`、`! rm -rf build`、`{ rm -rf build; }`、
   `time rm -rf build`、`exec rm -rf build`、`echo $(rm -rf build)`、`` `rm -rf build` ``、
   `/bin/rm -rf build`、`bash -lc "rm -rf build"`、`setsid/ionice/chrt/stdbuf/runuser/su -c … rm -rf`、
   `find … -exec sh -c "rm -rf {}"`。用一个漏检率很高的模式决定「哪些命令不能被记住」，
   产出的是防线的外观而不是防线。
3. **「一次点击 = 永久静默放行」不是删除类命令独有的风险。** 它对任何破坏性命令都成立
   （`git clean -xfd`、`mv`、`truncate -s0`、`> f` 都不在识别表内）。用命令语义做判据注定
   覆盖不全，因此改为不依赖语义的通用收口。

**新的行为**：

- 宿主不解析 shell 语法、不匹配命令文本；`rm` 与其它 shell 命令走同一个权限门。
- 「始终允许」对 shell 落 `RuleKind.exact`（整条命令精确匹配，见 `PermissionRule.forToolCall`）：
  `npm test` 的授权不再顺带放行 `npm test -- --watch`，`rm -rf build` 的授权不再顺带放行
  `rm -rf build -f`。`RuleKind.action` 仅为读取旧版本落下的 `~/.athena/permissions.json` 保留。
- 审批器不再收到 `risk_signals` 字段，`approvalReview` 回到 decision/reason/source。
- §4.3 提到「将来可为删除类命令加一条 deny 规则」仍然成立，但判据不再来自宿主的模式匹配。

**改动面**：`command_analyzer.dart`、`permission_rule.dart`（`fromCommand` 一并删除）、
`agent_service.dart`、`ai_permission_reviewer.dart`、`permission_prompt.dart`、
`agent_run_coordinator.dart`、GUI（delegate + 审批卡片）、TUI（bridge + app）、
测试（删 `command_analyzer_test.dart`，新增 `permission_rule_test.dart`）、README / AGENTS.md。

**验证**：`packages/athena_core` 下 `dart test` 通过、`dart analyze` 0 issue；
`flutter analyze` 在 `athena_gui` / `athena_tui` 均 0 issue。GUI / TUI 的运行时行为
（批准后真正执行、exact 规则下加参数会重新弹窗）未在运行实例上验证。

**已知代价**：删除后「递归删除」不再有任何宿主侧识别，判定强度只来自 AI 审批（fail-closed，
读完整原文）与人工审批；§9 的「明确不承诺」依然适用，且第一道判定完全交给模型。
