# Athena 核心与 UI 拆分方案（Core / GUI / TUI）

> 目标：把 Agent 核心从 Flutter UI 中解耦出来，形成纯 Dart 的 `athena_core` 包，
> 让 GUI（Flutter）与 TUI（终端）两个应用共享同一套 Agent 引擎、数据层与业务服务。

---

## 1. 现状分析

### 1.1 项目规模

| 目录 | 行数 | 归属 |
|------|-----:|------|
| `agent/` | 4,122 | **核心**（AgentService、工具、权限、Skill） |
| `database/` | 2,573 | **核心**（Schema + 31 个迁移） |
| `view_model/` | 2,750 | 混合（signals 状态 + UI 对话框） |
| `service/` | 1,291 | **核心**（LlmClient、Chat、Summary、Translation、TRPG…） |
| `repository/` | 854 | **核心**（SQLite 持久化） |
| `entity/` | 761 | **核心**（纯数据模型） |
| `preset/` + `model/` + `extension/` | 757 | **核心** |
| `util/` | 554 | 混合（核心工具 + UI 工具） |
| `page/` | 9,743 | **UI** |
| `widget/` + `component/` + `router/` | 5,085 | **UI** |

核心候选约 **10,800 行**，UI 约 **17,700 行**。

### 1.2 关键结论：Agent 核心已经具备良好的解耦基础

`AgentService.run()` 已经通过 **`Stream<AgentEvent>`**（sealed class：text / reasoning /
toolCall / toolResult / done / usage …）对外输出，并提供了 `onPermission` /
`beforeToolCall` / `afterToolCall` 三个 hook 与 `steer()` / `followUp()` / `abort()` 控制接口。
**这套接口是 UI 无关的**，是拆分的最重要资产，不需要重写。

真正需要动手的是下面几个「残留耦合点」。

---

## 2. 核心耦合点清单（必须拆除）

| # | 位置 | 耦合内容 | 拆除方式 |
|---|------|---------|---------|
| C1 | `agent/agent_service.dart` L15 | `package:flutter/foundation.dart`（仅用 `@protected`/`@visibleForTesting`） | 换成 `package:meta/meta.dart`（纯 Dart，语义一致） |
| C2 | `service/llm_client.dart` L5 | 同上（`@visibleForTesting`） | 同上 |
| C3 | `service/model_catalog_service.dart` L11 | 同上（6 处 `@visibleForTesting`） | 同上 |
| C4 | `database/database.dart` L32 | `path_provider`（Flutter 插件）取数据库路径 | `Database.ensureInitialized({required String dbPath})` 改为**路径注入**，路径发现逻辑移交给各 App |
| C5 | `database/database.dart` L30 | `laconic_sqlite` → `sqflite`（Flutter 插件） | 抽象出 `SqlDriver` 接口（或注入 `DatabaseFactory`）。GUI 用 sqflite，TUI 用 `sqflite_common_ffi`（纯 Dart FFI，桌面可用，零迁移成本） |
| C6 | `util/shared_preference_util.dart` | `shared_preferences`（Flutter 插件） | 定义核心 `KeyValueStore` 接口（get/set/remove/keys）。GUI 实现包 SharedPreferences；TUI 实现为 JSON 文件。`maxAgentIterations` 等设置项迁入核心 `AppSettings`（signals + KeyValueStore） |
| C7 | `view_model/delegate/agent_stream_delegate.dart` | 混入 GUI 对话框（`showPermissionDialog`、`showSkillTrustDialog`、router） | 拆出核心编排层 `AgentRunCoordinator`（消息落库/占位消息/压缩/用量记录，无 UI），对话框通过回调注入（详见 §4.2） |
| C8 | `util/` 混合 | `color_util`、`window_util`、`system_tray_util` 是 UI | 留在 GUI；`logger_util`、`retry`、`context_window_util`、`tool_args_formatter` 归核心 |
| C9 | `di.dart` | 应用级装配 | 拆成 `CoreContainer`（核心服务） + 各 App 自己的 DI 扩展 |

**注意**：`PermissionService`/`PermissionStore`、`SkillTrustStore` 已经用 `dart:io` 文件持久化，
不依赖 Flutter，天然可进核心，无需改动。

---

## 3. 目标架构

采用 **monorepo + 多 package** 结构（在同一 git 仓库内，`git mv` 保留历史）：

```
athena/                          # monorepo 根
├── melos.yaml                   # 可选，多包编排（先不加也可）
├── packages/
│   ├── athena_core/             # ★ 纯 Dart，零 Flutter 依赖
│   │   ├── lib/
│   │   │   ├── athena_core.dart         # 公开 API 汇总导出
│   │   │   └── src/
│   │   │       ├── agent/               # AgentService、工具、权限、Skill、cancel_token
│   │   │       ├── coordinator/         # AgentRunCoordinator（无 UI 编排层）
│   │   │       ├── entity/  model/  preset/
│   │   │       ├── repository/          # 依赖 SqlDriver 抽象
│   │   │       ├── service/             # LlmClient、Chat/Summary/Translation/TRPG…
│   │   │       ├── database/            # Schema + 迁移（驱动无关）
│   │   │       ├── storage/             # KeyValueStore 接口 + AppSettings
│   │   │       └── util/                # logger、retry、platform(注入)、context_window…
│   │   ├── test/                        # agent / service / repository / database 测试
│   │   └── pubspec.yaml                 # 纯 Dart 依赖
│   ├── athena_gui/              # ★ 当前 Flutter 应用（原项目 git mv）
│   │   ├── lib/
│   │   │   ├── main.dart  di.dart       # UI 装配 + CoreContainer
│   │   │   ├── page/  widget/  component/  router/
│   │   │   ├── view_model/              # signals 状态（保留）
│   │   │   ├── delegate/                # GuiAgentStreamDelegate（对话框实现）
│   │   │   └── platform/                # KeyValueStore(SharedPrefs)、SqlDriver(sqflite)
│   │   └── pubspec.yaml                 # 依赖 athena_core (path)
│   └── athena_tui/              # ★ 新建，纯 Dart 终端应用
│       ├── lib/
│       │   ├── main.dart  di.dart
│       │   ├── delegate/                # TuiAgentStreamDelegate（stdin 审批）
│       │   ├── platform/                # KeyValueStore(JSON)、SqlDriver(sqflite_common_ffi)
│       │   └── ui/                      # 渲染层（先 stdout/stderr 行式，后接终端库）
│       └── pubspec.yaml                 # 依赖 athena_core (path)
└── README.md  DESIGN.md  AGENTS.md      # 更新后的文档留在根
```

依赖方向（严格单向）：

```
athena_tui ─┐
            ├─→ athena_core   （纯 Dart，无 Flutter）
athena_gui ─┘
```

### 3.1 依赖划分

**athena_core 允许的依赖（全部纯 Dart）**：
`async`、`get_it`（可选，DI 可留在 App）、`http`、`openai_dart`、`yaml`、`logger`、
`markdown`、`html`、`path`、`process`、`signals`、`synchronized`、`uuid`、`meta`、
`sqflite_common_ffi`（仅 TUI/桌面驱动，作为 dev/平台依赖由 App 注入）。

**留在 GUI 的依赖**：`flutter`、`auto_route`、`flutter_markdown*`、`cached_network_image`、
`file_picker`、`google_fonts`、`hugeicons`、`image_gallery_saver_plus`、`tray_manager`、
`url_launcher`、`visibility_detector`、`window_manager`、`shared_preferences`、
`path_provider`、`package_info_plus`、`signals_flutter`、`flutter_slidable`、
`flutter_staggered_grid_view`、`gpt_markdown` 等。

---

## 4. 关键设计

### 4.1 Agent 事件模型（已有，保持不动）

`AgentEvent` sealed class 是核心对外契约，**不修改**。GUI 与 TUI 各自消费同一流。

### 4.2 新增：`AgentRunCoordinator`（核心编排层）

从现有 `AgentStreamDelegate` 中提取**与 UI 无关**的部分到核心：

```
class AgentRunCoordinator {
  Stream<RunEvent> send({required ChatEntity chat, required MessageEntity message});
  void stop();
  void steer(ChatMessage m);  void followUp(ChatMessage m);  void clearQueues();
}
```

职责：用户消息落库 → 构建上下文（含压缩）→ 追加占位消息 → 消费 `AgentEvent` 流 →
流式更新 `MessageEntity` → 用量落库 → 收尾/取消/错误落库。产出 `RunEvent`（消息已存/
已更新/迭代变化/用量变化…），全部为纯数据，无 Flutter 类型。

**权限与 Skill 信任通过回调注入**：

```dart
typedef PermissionPrompt = Future<bool> Function(String toolName, String arguments);
typedef SkillTrustPrompt = Future<bool> Function(String dir, List<String> names);
```

- GUI：`GuiAgentStreamDelegate` 用 `showPermissionDialog` / `showSkillTrustDialog` 实现；
- TUI：用 stdin 的 `y/n` 提示实现；
- 两者共用同一份 `AgentRunCoordinator`。

### 4.3 存储抽象

```dart
// core/storage/key_value_store.dart
abstract interface class KeyValueStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
  Future<Set<String>> getKeys();
}
```

- 核心 `AppSettings`（maxAgentIterations、默认模型、命名模型等）改为 signals + KeyValueStore；
- `PermissionStore`/`SkillTrustStore` 已是文件存储，不动。

### 4.4 数据库驱动注入

```dart
// core/database/database.dart
class Database {
  static Future<void> ensureInitialized({
    required String dbPath,
    SqlDriver? driver,   // 不传时用默认（sqflite_common 兼容实现）
  });
}
```

- GUI：`sqflite`（现状不变，只是路径改为注入）；
- TUI：`sqflite_common_ffi`（纯 Dart FFI，macOS 自带 libsqlite3，Linux 需 `libsqlite3-dev`）。

### 4.5 工具注册策略

当前工具集合按平台差异在 `di.dart` 里注册（桌面 11 个 / 移动 3 个）。拆包后：
- 核心提供 `ToolRegistry` 与各工具类；
- 各 App 负责「注册哪些工具」：GUI 桌面 = bash/powershell + 文件 + web + skill + evolve；
  TUI 桌面 = 与 GUI 桌面一致（TUI 天然是桌面）；
- 可提供 `core.registerDesktopTools(...)` / `registerMobileTools(...)` 便捷方法。

---

## 5. 分阶段实施路线图

> 每个阶段结束都必须能编译 + 测试全绿，避免长分支。

### Phase 0 — 基线冻结（0.5 天）
1. 新建分支 `feature/core-ui-split`。
2. 跑 `flutter analyze` + `flutter test` 记录基线。
3. 创建 monorepo 目录骨架（`packages/` 三个占位目录 + `melos.yaml` 可后补）。

### Phase 1 — 核心去 Flutter 化（1–2 天，不动目录）
1. C1/C2/C3：3 个文件的 `flutter/foundation.dart` → `package:meta/meta.dart`。
2. C4/C5：`Database.ensureInitialized` 支持路径注入；引入驱动抽象。
3. C6：新增 `KeyValueStore` 接口 + 核心 `AppSettings`；`SharedPreferenceUtil` 收敛为 GUI 实现。
4. 验证：`grep -rn "package:flutter" lib/agent lib/entity lib/repository lib/database lib/service lib/model lib/preset` → **零结果**（view_model/util 暂不算）。

### Phase 2 — 提取 athena_core 包（2–3 天）
1. `git mv` 以下目录到 `packages/athena_core/lib/src/`：
   `agent/ entity/ model/ repository/ service/ database/ preset/ extension/`
   + 核心 util（`logger_util` `retry` `context_window_util` `tool_args_formatter` `platform_util`）。
2. 新建 `packages/athena_core/pubspec.yaml`（纯 Dart 依赖）。
3. 批量改写 import：`package:athena/...` → `package:athena_core/...`（用脚本 + `dart analyze` 迭代）。
4. 迁移核心测试（`test/agent/` `test/service/` `test/repository/` `test/database/` `test/util/` 中核心部分）。
5. GUI 改为 `path` 依赖 athena_core，跑通 `flutter analyze` + `flutter test`。

### Phase 3 — 提取编排层（2–3 天）
1. 从 `AgentStreamDelegate` 抽出 `AgentRunCoordinator` 进核心，`RunEvent` 定义好。
2. GUI 侧 `GuiAgentStreamDelegate` 改为薄包装（只负责对话框回调 + 事件转发到 ViewModel）。
3. 行为回归：权限弹窗、Skill 信任弹窗、取消、压缩、自动命名全部复测。

### Phase 4 — TUI 应用（2–3 天）
1. `athena_tui`：`main.dart` + `CoreContainer` + `TuiAgentStreamDelegate`（stdin 审批）。
2. 渲染：先用 stdout 行式输出（消息/工具卡片/思考流），验证核心链路。
3. 再接入终端 UI 库（如 `dart_console` / `ncurses` 绑定），做布局与滚动。
4. 配置：`~/.athena-tui/` 数据目录 + JSON KeyValueStore + FFI 数据库驱动。

### Phase 5 — 收尾（1 天）
1. 更新 `README.md` / `AGENTS.md` / `DESIGN.md` 中的架构说明。
2. 可选：`melos.yaml`（`melos run test` / `melos bootstrap`）统一多包命令。
3. 可选：将 `athena_core` 发布到 pub.dev，便于未来独立仓库消费。

**总计约 8–12 个工作日**，其中 Phase 1–3 是核心改造（GUI 可随时回归），Phase 4 是增量收益。

---

## 6. 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| sqflite 在 TUI 下不可用 | TUI 无法持久化 | 用 `sqflite_common_ffi`（纯 Dart FFI）；macOS 自带 sqlite3，Linux 需装 `libsqlite3-dev`，README 注明 |
| 批量改 import 出错 | 编译大面积失败 | 分目录小步迁移 + 每步 `dart analyze`；先改核心包再改 GUI |
| `AgentRunCoordinator` 抽取引入行为差异 | 聊天/权限回归 | 保留原 `AgentStreamDelegate` 测试，抽取后新旧行为对比测试 |
| signals 版本/API 变化 | 编译错误 | signals 6.x 纯 Dart 稳定，锁版本即可 |
| auto_route 生成代码 | 仅影响 GUI | 不影响核心；GUI 内 build_runner 照旧 |
| 单仓库体积增大 | 开发体验 | melos + 包级 `dart test` 隔离；CI 可只跑受影响包 |

---

## 7. 验收标准

1. `dart analyze`（athena_core）：**0 error**，且 `grep -rn "package:flutter"` 核心包内**零结果**。
2. `flutter test`（athena_gui）：与拆分前**全量通过**，覆盖率不下降。
3. `dart test`（athena_core + athena_tui）：全绿。
4. GUI 回归：聊天、Agent 多轮工具调用、权限弹窗（Allow/Deny/Always）、Skill 信任、
   取消保留内容、自动压缩、自动命名、设置项全部正常。
5. TUI 验收：能完成一次完整 Agent 对话（含工具调用 + stdin 权限审批 + 取消），
   数据与 GUI 互不干扰（各自独立数据目录）。
6. `AGENTS.md` / `README.md` 架构章节与最终代码一致。

---

## 8. 附：本次调研的关键证据

- `AgentService.run()` 输出 `Stream<AgentEvent>`（`lib/agent/agent_service.dart` L115–129），
  事件模型完备：text / reasoning / toolCall / toolCallArgs / toolResult / iterationComplete /
  done / turnStart / toolExecutionStart / toolExecutionUpdate / usage。
- `AgentStreamDelegate`（`lib/view_model/delegate/agent_stream_delegate.dart`）是 GUI 与 Agent
  的唯一桥，其中 UI 耦合仅限权限对话框（L518 `showPermissionDialog`）与 Skill 信任对话框
  （L243 `showSkillTrustDialog`），其余（落库/压缩/用量）均为可上提的逻辑。
- 核心目录对 Flutter 的依赖仅 3 处 `flutter/foundation.dart`（均为注解），
  以及 `database.dart` 的 `path_provider` + `laconic_sqlite`(sqflite) 与
  `shared_preference_util.dart` 的 `shared_preferences`。
- `PermissionStore` / `SkillTrustStore` 已用 `dart:io` 文件持久化，无需改造。
