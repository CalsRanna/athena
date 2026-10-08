# CONVENTIONS.md — Athena 仓库约定

本文件是 Athena 仓库**工程约定、架构边界与共享行为契约**的统一出处。它写给在本仓库工作的 AI Agent，也写给加入项目的开发者。GUI 与 TUI 共用的行为见 §12；使用入口与操作说明见 [README.md](README.md)。

相关文档：

- 设计语言（色板、排版、几何、阴影、动效）见 [DESIGN.md](DESIGN.md)
- GUI 组件与交互的落地口径见 [WIDGETS.md](WIDGETS.md)

### 文档与实现的关系

**文档定义预期行为与约束，代码实现这些要求，测试验证实现是否符合要求。** 源码反映当前实现；源码与注释不能自动覆盖文档规范。未在文档中规定的实现细节与取舍理由，可查阅源码及其注释。

各文档按主题承担规范职责，不采用整份文档之间的统一优先级：

| 文档 | 负责范围 |
|---|---|
| [AGENTS.md](AGENTS.md) | Agent 的工作行为与执行流程 |
| 本文 | 工程约定、架构边界与 GUI / TUI 共享行为契约 |
| [DESIGN.md](DESIGN.md) | 视觉原则、设计 token 的语义与规范值 |
| [WIDGETS.md](WIDGETS.md) | GUI 组件选用、具体交互、显示与几何规格 |
| [README.md](README.md) | 能力概览、使用入口与操作说明；引用对应规范 |

具体组件规格应遵守设计语言，例外必须在对应规则处明确说明。共享行为由本文定义，GUI 展示与交互由 WIDGETS 定义。其他文档引用主出处，避免重复定义同一规则。

文档中的精确取值是规范值，源码中的 token 是集中实现与取值入口，必须与规范一致。调整规范值时，同步更新对应 token 与相关验证。

发现不一致时，先按主题找到负责的规范并核对预期要求；实现偏离规范时修正实现与验证。若确认需求已改变，先修订对应规范，再同步实现与验证。文档之间有冲突时应统一对应规则，不能仅因现有代码采用某种做法，就将它视为正确要求。

---

## 1. 分层与依赖方向

```
athena_gui ──┐
             ├──→ athena_core
athena_tui ──┘
```

| 层 | 包 | 可以依赖 | 不可以依赖 |
|---|---|---|---|
| 引擎 | `athena_core` | Dart SDK、`anthropic_sdk_dart`、`openai_dart`、`signals`、`yaml` 等纯 Dart 库 | **Flutter、任何 UI 框架** |
| 前端 | `athena_gui` / `athena_tui` | `athena_core` | 彼此（`athena_gui` 与 `athena_tui` 之间零依赖） |

`athena_core` 必须保持零 Flutter 依赖——它同时服务 Flutter GUI 与纯 Dart TUI，且核心逻辑的单测不启动 Flutter 运行时。

### 1.1 什么该放在 core

判断标准是**「这是引擎的事实，还是装配层的选择」**。

`lib/agent/tool/tool_set.dart` 里的 `buildToolRegistry` 是这条标准的样板：因为「有哪些工具、按什么顺序注册、哪个平台注册哪些」是引擎的事实，所以清单放在 core；而工作目录、角色变更回调这类每个前端各自的差异项，才由 `di.dart` / `tui_di.dart` 作为参数传入。

同类判断适用于任何两端共用的逻辑：**两个前端都要的行为放 core，只有一端需要的放该端**。反面例子是把同一份清单在两个装配层各铺一遍，仅靠注释断言一致——加一个工具要同时改两个包，漏一处就是两端能力静默漂移。

### 1.2 什么该放在前端

- 页面、组件、主题、平台集成（窗口、托盘、剪贴板、单实例）
- 前端专有的状态编排（`ChatViewModel` / `ChatController`）
- 前端专有的持久化实现与一次性迁移（GUI 把旧的 SharedPreferences 偏好搬进
  `setting.yaml` 的 `PrefsIntoSettingMigration`；用户偏好本身存在 core 的
  `UserSettingsStore` 里，两个前端共用同一份 `~/.athena/setting.yaml`）

界面文案、交互反馈、平台差异（GUI 会话内审批卡 vs TUI 内联审批）属于前端。共享行为由 §12 定义，前端通过状态与回调接入，不各自实现另一套引擎规则。

### 1.3 前端分层与依赖方向

GUI 的视图组件分五类，依赖从页面指向基础设施。箭头表示调用方可以依赖的方向：

```
页面及其私有子件 ──→ 跨页面业务组件 ──┐
       │                             ├──→ 基础控件 ──→ 主题
       └──────────→ 平台通用控件 ─────┘
```

各类都可以直接使用主题。同层组件可以复用，但不得形成循环依赖；基础控件不认识业务，跨页面业务组件与平台通用控件不依赖具体页面。

| 层 | 位置 | 职责 |
|---|---|---|
| 主题 | `theme/` | 色板、token、图标、滚动行为。**实现中的统一取值入口**，取值须符合设计与组件规范 |
| 基础控件 | `widget/` | 无业务含义的通用件：按钮、输入框、对话框外壳、Markdown。以平台中立件为主，个别按平台分叉但共用一个公开入口的件（`AthenaAppBar`）也留在这里 |
| 平台通用控件 | `page/<platform>/component/` 或 `page/<platform>/<area>/component/` | 本平台或本功能区多个页面共用的通用件（桌面右键菜单、移动宫格块等），不参与跨平台复用 |
| 复用组件 | `component/` | 跨页面复用的业务组件：消息渲染、步骤卡、权限卡、提问卡 |
| 页面 | `page/` | 具体页面与其私有子件（`page/**/component/`） |

平台通用控件可以依赖本平台其他通用控件、`widget/` 与 `theme/`，不依赖另一平台或具体页面。**目录位置不能单独决定职责**：供多个页面使用且不依赖某个页面的是平台通用控件；只服务宿主页面、依赖其状态或流程的是页面私有子件，留在该页面对应目录中。

跨页面业务组件可以消费 ViewModel 提供的状态与回调，基础控件只通过展示值与回调接收输入。基础控件不依赖业务组件、ViewModel、具体页面或应用路由；修改它时应验证受影响的调用方行为。

**公共组件优先收敛骨架，保留真实的设计差异。** 可复用状态机、手势和布局结构；装饰仍可由调用方提供。当包装参数比被包裹内容还多时，不强行抽象。判断是否公共还要看使用范围：跨平台通用件进 `widget/`，平台通用件留在对应平台，页面私有子件不因形式相似就升级为公共组件。

分层为 GUI 独有；TUI 的 `ui/` / `bridge/` / `view_model/` 与之不同构，见 §2 的「前端」。各层组件的设计口径与清单见 [WIDGETS.md §2](WIDGETS.md)。

### 1.4 编排与状态的职责

| 模块 | 负责 | 边界 |
|---|---|---|
| `AgentService` | 单次 run 内的模型请求、工具循环、权限门、取消与运行结果 | 输出引擎事件，不负责页面状态与会话文件格式 |
| `AgentRunCoordinator` | 会话 run 生命周期：上下文、消息占位、事件转换、统计、取消收尾、后台汇报与回退 | 调用服务与仓储完成业务流程，向前端输出纯数据事件，不渲染 UI |
| core 的 `service/` | LLM 与协议适配、模型目录、摘要生成、会话配置等应用服务 | 可以调用仓储；文件格式、读写与锁由 `storage/` 实现 |
| `repository/` | 会话、消息、模型等仓储接口 | 描述读写契约，不实现文件操作 |
| `storage/` | 持久化实现、锁、迁移、快照与纯持久化编排（如 `ChatStore`） | 不调用 LLM，不呈现 UI；调用仓储的业务服务不因此归入本层 |
| GUI 的 `AgentStreamDelegate` / TUI 的 `TuiAgentBridge` | 对接 coordinator 事件与本端审批、提问回调 | 不复制 core 的 run 编排与权限规则 |
| `ChatViewModel` / `ChatController` 等状态层 | 本端界面状态、会话选择、草稿、排队输入与用户操作编排 | 调用服务、仓储或桥接层；界面提示通过状态或回调交给视图，不直接渲染控件或弹窗 |
| 页面与组件 | 展示状态、收集用户输入、提交操作 | 控件可持有 hover、展开等局部 UI 状态；业务规则与共享 run 状态由上述层负责 |

调用仓储完成业务操作与实现存储是不同职责。归属按类承担的主要契约判断，不能仅凭是否发起网络请求或类名包含 `Service` 决定。

---

## 2. 目录约定

### athena_core

```
lib/
├── agent/          引擎本体
│   ├── agent_service.dart    run 驱动与工具循环
│   ├── context_*.dart        预算与压缩
│   ├── tool/                 工具系统
│   ├── permission/           权限编排、规则、AI 审核
│   ├── skill/                技能加载与注册
│   ├── evolution/            反思、进化提示词、记忆摘要、角色快照
│   ├── task/                 后台任务
│   └── elicit/               向用户提问的通道
├── coordinator/    run 编排与对外事件（run_event.dart）
├── service/        LLM 适配（三种协议）、模型目录、摘要与会话应用服务
├── storage/        持久化实现：文件存储、锁、JSONL 会话、仓储实现、id 迁移
├── repository/     仓储接口
├── entity/         领域模型
├── util/           路径、日志、重试、分页读取等纯工具
├── extension/      Map / 集合等类型的扩展方法
└── seed/           内置种子数据
```

`entity/` 定义领域数据；仓储采用**接口与实现分离**：接口在 `repository/`，文件持久化实现落在 `storage/`。

各目录的职责边界见 §1.4。`service/` 和 `coordinator/` 可以通过仓储组织读写；序列化、文件操作、锁与迁移由 `storage/` 实现。`ChatStore` 这类纯持久化编排仍归 `storage/`，`ChatUpdateService` 这类应用服务则保留在 `service/`。

### 前端

两个前端的目录并不同构。GUI 按 `page/`（页面）、`component/`（跨页面业务组件）、`widget/`（基础控件）、`view_model/`（状态）、`theme/`、`extension/`（扩展方法）、`util/`（平台集成）组织，组合根是 `lib/di.dart`；TUI 按 `ui/`（`app.dart`、`theme.dart`、`text_util.dart` 与 `ui/widgets/`）、`bridge/`、`view_model/` 组织（无 `page/`），组合根是 `lib/di/tui_di.dart`。

---

## 3. 命名

- 文件 `snake_case.dart`，类型 `UpperCamelCase`，成员 `lowerCamelCase`
- 工具类固定 `XxxTool`，文件名 `xxx_tool.dart`；工具名（下发给模型的 `name`）固定 `snake_case`，与用户可见文案一致
- 私有实现类用 `_` 前缀；同类小私有类集中在使用它的文件尾部，不单独建文件
- 概念三元组：`xxx_service.dart`（编排）、`xxx_rule.dart`（纯值对象）、`xxx_prompt.dart`（回调 typedef）
- 持久化实体的 id 一律 `String?`（未入库时为 null），由 `IdGenerator` 生成 UUIDv7
- 页面类一律 `<Platform><Area?>...Page`（`Desktop` / `Mobile` 前缀）；页面文件一律 `xxx_page.dart`，词根取类名去掉平台前缀再 snake_case
- 选择器（选一个值的交互）：触发控件用 `...Selector`，弹出菜单面板用 `...Menu`，对话框面板用 `...Dialog`。同一交互桌面弹 `...Menu`、移动端弹底部 `...Dialog`，这是**有意的平台差异**，不是命名不一致

**纯静态容器一律 `abstract final class`**。只有一个用途是装 `static` 成员、不持有实例状态的类（工具类、校验器、提示词集）必须写成 `abstract final class`，而不是「普通 `class` + 私有构造 `Xxx._()`」。前者由语言挡住实例化与继承，后者只挡住了一半——`LoggerUtil` 就是这么被漏掉的。

**缩写在标识符里一律小写**（`chatId` / `url` / `json` / `uuid`），只在注释与用户可见文案里出现全大写（`'Model ID'`、`'ID of the snapshot'`）。不要写 `chatID` 或 `modelUUID`。

上游 SDK / 平台的专名随其官方拼写（`OpenAI`、`macOS`、`ClipRRect`），本仓库自有的缩写一律小写。

**常量放哪**由它是不是某个类的 API 决定：

- 类的一部分（构造参数默认值、`@visibleForTesting` 的开关、该类的取值范围）→ 类内 `static const`，如 `ChatEntity.noSentinelId`、`TextFileReader.maxReturnLines`
- 模块内部共用的字面量（下发给模型的键名、标签表、配置表）→ 文件的顶级 `const`，如 `toolCallDescriptionKey`、`defaultCatalogExcludes`
- 纯几何/视觉尺度集中到 `abstract final class` 的 token 层（`AthenaRadius`、`AthenaMotion`），不散落在组件里

---

## 4. 注释

**语言约定**：设计说明与「为什么」用中文；契约注释、错误文案、工具描述与参数说明用英文。**代码维护的所有系统提示词一律用中文**，包括内置角色、运行环境、技能与记忆目录、进化指导、压缩摘要、反思、权限审核及标题 / 元数据生成。工具名、协议字段、JSON 键名和枚举值保留原文；用户编写的角色提示词、技能、记忆及项目约定不自动翻译。**所有 `throw` 出来的异常文本一律英文**（`StateError` / `UnsupportedError` / `FormatException` / `ArgumentError` 都算），哪怕它看起来只是内部不变量——这类消息可能不经翻译直接成为用户看到的 run 错误（见 §5）。中文可以出现在注释、日志与系统提示词里。

**写什么**：

- 自由的注释密度较高，但只写代码本身读不出来的东西——**约束、反直觉之处、被否决的方案、踩过的坑**。不要复述代码在做什么
- 规范要求在负责该主题的文档中定义，代码注释引用对应规范；局部实现细节与取舍理由只写在最能防止违反的位置。例如路径解析的安全要求见 §6，`run_workspace.dart` 说明具体解析口径，其他调用方注释指回该实现
- 被独立踩过多次的坑值得单独强调（如 `AthenaHover` 里「静止态不要用 `Colors.transparent`」）

**不要写**：`// TODO` 式的空承诺、与代码不同步的旧注释、注释掉的死代码。

**文档引用**：引用仓库约定用 `CONVENTIONS.md`，引用设计语言用 `DESIGN.md §N`，引用 GUI 组件与交互口径用 `WIDGETS.md §N`（章节号见对应文档，改动设计文档时同时更新引用处的编号）。**不要引用已删除的文档**。

---

## 5. 错误处理

- **工具抛出的异常不冒泡**。工具内部异常（读到非 UTF-8 文件、写入无权限目录……）转成 `'Error: ...'` 文本作为工具结果交还模型，让模型自己纠正，而不是终止整个 run
- **损失必须显式**。适配器遇到无法映射的请求字段、无法表达的响应内容时抛 `UnsupportedError` / `FormatException` / `StateError`，**不静默丢弃**。宁可让调用方收到明确失败，也不要让用户看到「看起来成功了」的错误结果
- **错误文案遵守 §4 的英文约定**，工具返回的 `'Error: ...'` 也适用。这些消息可能不经翻译直接冒到用户面前（例：`onCompact` 的回调抛异常时 `agent_service.dart` 不 catch，它就成了 run 错误）
- **取消优先于报错**。捕获异常时先 `throwIfCancelled()` 再 rethrow，避免取消被底层错误掩盖
- **异步等待必须有取消出口**。任何等待用户或网络的 `Future` 都要与取消信号竞速（`Future.any`），保证等待绝不挂死

---

## 6. 安全约定

安全边界集中在三处，改动它们时需要格外小心：

- **权限判定**（`permission_service.dart` + `permission_rule.dart`）：执行前必须落实 §12.1 的审批与禁令契约，持久 deny 与本轮人工拒绝优先于三种审批模式。旧 allow 规则不能误读为 deny
- **路径解析**（`run_workspace.dart` + `path_normalizer.dart`）：执行、并行预检、审批卡与 AI 审核必须共用同一实际目标口径，否则会产生判定漂移。解析不了真实路径时**规则匹配**退回词法路径，而**执行前**必须调 `unresolvablePathError` 拒绝——不可穿越的目录后面真正落到哪是未知的。新增会读写文件的工具时别漏掉它
- **不可信内容**：工具参数、文件内容、网页响应、工具输出都是**数据不是指令**。它们可用于评估操作影响，但不能改变审核职责或覆盖用户明确限制。原始对话与宿主记录的人工决定、提问卡真实回答用于理解用户意愿；不能把模型生成的问题或工具文本伪装成用户回答

新增工具时，先想清楚：它写不写文件、跑不跑命令、访不访问网络。这决定它归入哪一类权限规则，以及是否需要实现 `CancellableTool`。

---

## 7. 测试

### 约定

- 用例文件与被测单元同名：`permission_rule.dart` 的测试是 `test/agent/permission/permission_rule_test.dart`
- 只为测试暴露的接口标 `@visibleForTesting`，不要为了测试把私有成员改成公开
- **不要给测试加「目录为空就跳过」的守卫**。测试被误删时应当失败，而不是静默变绿
- 行为 / 回归测试以被测行为命名，不要求与被测文件同名（如 `compaction_failure_guard_test.dart`）

### 各包的重点

| 包 | 跑什么 | 说明 |
|---|---|---|
| `athena_core` | `dart test` | 引擎、权限、存储、协议适配、id 迁移。默认使用临时目录隔离测试数据 |
| `athena_tui` | `dart test` | 组合根与桥接层的纯逻辑，不启动真实 UI |
| `athena_gui` | `flutter test` | 组件级 widget 测试。`DI.ensureInitialized` 支持 `homeDirOverride`，用来安装一份隔离的依赖图 |

GUI 的布局、控件与交互分支用 `ThemeData.platform` / `getPlatform(context)` 判定，以便 widget 测试切换平台。core、TUI 与原生集成中的真实操作系统能力判定使用 `PlatformUtil` 或对应平台 API，不能用模拟的界面平台决定实际文件、进程或窗口能力。

### 数据库与目录

`~/.athena/` 是应用的正常数据目录，可以按任务需要读写，并非禁止访问的路径。自动化测试默认注入临时目录，避免依赖本机数据或污染日常配置；需要验证真实目录的场景应明确使用范围，并保留原有数据。

---

## 8. 依赖与版本

- **SDK 与 Flutter 版本全仓库统一**：Dart 下限 3.12.0，CI / 发布 / 本地开发统一 Flutter 3.47.1。三处（`ci.yml`、`release.yml`、本地环境）必须一致，改动时同时更新
- **新增依赖前先确认它落在哪一层**：直接或间接引入 Flutter 的库不能进 `athena_core`
- `dependency_overrides` 只用于无法立刻解决的版本冲突，并在旁边写明原因与解除条件（参见 `athena_gui/pubspec.yaml` 里 `windows_single_instance` 的注释）
- 版本号只在发布时递增（`athena_gui/pubspec.yaml`），打 tag 前同步

---

## 9. 常用命令

提交前跑对应包的 `analyze`、`test` 与 `format --set-exit-if-changed`——CI（[.github/workflows/ci.yml](.github/workflows/ci.yml)）跑的就是这三条，本地过了 CI 就不会红。

```bash
cd packages/athena_core && dart analyze && dart test && dart format --output=none --set-exit-if-changed $(find lib test -name '*.dart' ! -name '*.g.dart' ! -name '*.gr.dart')
```

```bash
cd packages/athena_tui && dart analyze && dart test && dart format --output=none --set-exit-if-changed $(find lib test -name '*.dart' ! -name '*.g.dart' ! -name '*.gr.dart')
```

```bash
cd packages/athena_gui && flutter analyze && flutter test && dart format --output=none --set-exit-if-changed $(find lib test -name '*.dart' ! -name '*.g.dart' ! -name '*.gr.dart')
```

`athena_gui` 还要在首次拉取依赖后、以及改了带 `@RoutePage` 的页面之后重新生成路由：

```bash
cd packages/athena_gui && dart run build_runner build --delete-conflicting-outputs
```

改完 Dart / Flutter 代码后跑一次 hot reload（或 hot restart）。

`format` 那条只扫 `lib test` 两个目录，且用 `find` 排除了 `.g.dart` / `.gr.dart`：生成文件不符合格式器口径，且 build_runner 会覆盖，格式化它们没有意义。

---

## 10. 提交与发布

### 提交信息

```
<type>(<scope>): <summary>
```

- type：`feat` / `fix` / `refactor` / `docs` / `chore` / `build` / `test`
- scope：包名或子系统名（`agent` / `storage` / `theme` / `athena_gui` / `step-primitives` …）
- summary 与正文用**英文**，说明**为什么**这样改——尤其是被否决的方案与它的代价
- 正文从简：主题一行说清改了什么，正文只在「为什么」不显然时才写，通常一两句
- 提交信息中**不添加任何工具署名或生成标记**
- 一次提交只做一件事；大范围重排（如全仓库改名、格式化）单独成一次提交

### 发布

GUI 通过 GitHub Release 分发，由 tag 触发三平台构建与 `tapster publish`（更新 Homebrew tap 与 Scoop bucket）：

```bash
git tag v4.0.3 && git push origin v4.0.3
```

tag 推送后触发 [release.yml](.github/workflows/release.yml)：先复用 [ci.yml](.github/workflows/ci.yml) 的三包检查，再并行构建 macOS（`.zip`，内含 `Athena.app`）、Windows（`.zip`，内含 `athena.exe`）、Linux（`.tar.gz`）。发布配置见 [`packages/athena_gui/.tapster.yaml`](packages/athena_gui/.tapster.yaml)，checksum 由 `tapster publish` 从 Release asset digest 解析，不需要手工维护。要点：

- tag 推送会先跑 CI 的三包检查，检查不过就不出包
- **Linux 平台的代码必须过 Linux CI**：CI 与发布都在 Ubuntu 上跑，只在 macOS 本地验证等于没验证
- 打 tag 前同步 `packages/athena_gui/pubspec.yaml` 的版本号

---

## 11. 编码风格速查

- 用 `const` 构造与 `final` 字段；不重新赋值的局部变量与单例引用用 `final`，常量上下文中的构造与声明用 `const`，由共享 lint 约束。能用 `switch` 表达式表达的分支不要写成 `if/else` 链
- 集合操作优先（`map` / `where` / `fold`），不手写索引循环
- 一个文件放一个**主**类，并把它承担不了的小件（同族的 sealed 子类、纯值对象、token 常量类、同一处私有的伴生类）留在同文件；工具类用 `abstract final class` 防止实例化与继承
  - 判断标准是「这个类能不能独立站住」，不是数量。`run_event.dart` 里 11 个 sealed 事件子类、`athena_tokens.dart` 里 9 个 token 类都刻意留在一起——拆开只会让调用方多跑几个 import
  - 反之，一个类有独立的行为与测试就该独立成文件
- 业务状态通过 ViewModel / Controller 的 signal 流动，控件局部 UI 状态与各层职责见 §1.4
- 导入一律用 `package:` 形式，**禁止相对导入**（含 `export`），由 `shared_analysis_options.yaml` 里的 `always_use_package_imports` 强制。唯一例外是 `test/` 内部的辅助文件（`test/support/` 等）：它们不在 `lib/` 下，本就无法用 `package:` 导入，这类引用仍是相对导入
- 静态分析配置集中在仓库根 `shared_analysis_options.yaml`，三个包各自留一份只做 include 的薄壳。改规则改那一份，**不要**在各包里就地加
  - include 数组里**靠后的覆盖靠前的**，共享文件必须放数组末尾，否则会被 `package:lints` / `flutter_lints` 里的同名规则覆盖（`prefer_initializing_formals` 就是这样）
  - analyzer 对解析失败的 include 只报一条 `include_file_not_found` 而**不中断**，路径写错会静默失效——改完跑一次 `dart analyze` 确认它不是 0 issue 而是真的没 issue
- 格式化用 `dart format`，配置同样在 `shared_analysis_options.yaml`（80 列、`trailing_commas: automate`）。生成文件（`*.g.dart` / `*.gr.dart`）不格式化，它们由 build_runner 覆盖

---

## 12. 共享行为契约

本节定义 GUI 与 TUI 共用的产品行为，作为实现与行为测试的依据。README 保留能力概览与操作说明，WIDGETS 定义 GUI 的展示与交互；两者引用本节，不另行定义共享行为。改变这些行为时先更新对应契约，再同步实现与验证。

### 12.1 权限审批

- 三档审批模式挂在会话上，修改后从下一轮 run 生效：Manual 每次由用户决定；AI Review 由当前模型独立替用户作审批决定，只有需要用户权衡或审核不可用时转人工；Bypass 跳过审批。三档都遵守持久 deny 禁令与本轮人工拒绝
- 人工只允许或拒绝当次调用；批准不复用、不缓存，不生成持久 allow 规则。旧 `permissions.json` 中的 allow（含省略 effect 的旧规则）停止生效，已有 deny 保留
- 持久禁令按工具类型匹配：shell 匹配完整命令文本（折叠空白并去掉参数末尾 `/`，不做命令语义分析），文件工具匹配真实路径（支持 `*` / `**` / `?`），`web_fetch` 匹配 origin。路径解析的安全边界见 §6
- 本轮人工拒绝按 run 隔离，阻止相同调用重试；AI 同时参考宿主记录的拒绝，避免换工具产生同等效果
- AI 审核结合原始对话、实际参数、工作目录、宿主记录的人工决定与提问卡真实回答，判断相关性、影响和可恢复性。常规文件修改无需逐项授权；审核的信任边界见 §6
- 提问工具本身进入提问通道，不叠加权限审批；显式 deny 仍然生效
- 禁令文件使用跨进程锁与 mtime 变更检测，GUI 与 TUI 共用且能及时发现手工修改

权限判定由 core 的 `agent/permission/` 与 `AgentService` 负责，前端负责呈现请求和提交用户决定。验证覆盖三档模式、deny 优先级、批准不复用、run 间拒绝隔离，以及提问通道。

### 12.2 Agent 循环、协议与上下文

- Agent 执行多轮推理与工具循环，支持并行工具执行，并发上限 8
- 支持 OpenAI Chat Completions、OpenAI Responses、Anthropic Messages 三种协议。上层请求与事件统一为 Chat Completions 形状，Responses 与 Messages 的协议差异分别收敛在适配器里
- 推理状态按协议原生保存与回放：Responses 的加密推理项、Messages 的 thinking 签名、Chat Completions 的 `reasoning_details` 各自完整持久化，切换 provider 后自动失效而非串用。Messages 兼容端点的全部无签名推理保留展示与正常工具调用，在完成明细中标记为不可回放，不保存为原生签名状态
- 上下文估算超出窗口时，先回收旧工具输出，再摘要压缩历史。摘要与覆盖范围一同提交，原消息保留可回溯；会话回退时的覆盖关系处理见 §12.3

`AgentService` 负责工具循环，并依据 `ContextBudget` 决定何时请求压缩；`AgentRunCoordinator` 接入 `ConversationCompactor` 的摘要与覆盖范围提交流程。协议适配与摘要生成由 `service/` 负责，服务与 coordinator 调用仓储完成持久化，职责边界见 §1.4。验证覆盖并行执行、协议推理状态回放、provider 切换，以及压缩覆盖范围与原消息保留。

### 12.3 会话回退（Rewind）

- 回退到选定用户消息发送之前：该消息与后续记录退出历史，原文与图片恢复到输入框；重新发送时携带恢复的图片
- 运行中的会话先取消并等待收尾，同时停止本会话的后台工作和排队输入。另一前端正在运行同一会话时，需要先在那一端停止
- 回退只影响对话记录与模型上下文；已执行的命令、文件修改、角色演进和经验库不随之恢复
- 压缩覆盖关系与原文可见性在同次写入中重建；上下文用量在下一次模型响应前隐藏。没有覆盖元数据的旧版摘要无法可靠回退，必须明确报错并保留历史
- 每次回退提交前保留完整快照 `~/.athena/sessions/<chatId>.jsonl.rewind-<snapshotId>`，快照不出现在会话列表里。手工恢复方法见 [README.md 的回退会话说明](README.md#回退会话rewind)

`AgentRunCoordinator` 负责取消、等待与回退编排，`SessionRewindRepository` 及其存储实现负责历史裁剪、压缩覆盖关系重建与快照，前端负责恢复草稿和附件。验证覆盖记录截断、图片恢复、运行收尾、跨前端占用、压缩元数据与快照保留。

### 12.4 运行统计

- 统计按 run 记录耗时与已上报的累计输出 token，并随消息持久化
- 生成速度采用最近一次 LLM 响应的输出 token 数，除以该次响应从首个到最后一个输出片段的秒数。片段包含推理与工具参数，排除首包等待、尾包等待和工具执行
- 速度只在累计输出 token 变化时更新；计时刷新与 run 结束均保留上次速度
- 未知用量不补造为 `0`；缺失的生成速度不以整个 run 的平均速度代替。GUI 的显隐、数字格式、占位与动画规则见 [WIDGETS.md §3](WIDGETS.md#3-交互与状态)

core 的 `TokenUsage` 记录单次响应的用量与输出时长，`RunStatistics` 累计用量并计算速度，`AgentRunCoordinator` 负责更新与落库。前端消费统计值并呈现。验证覆盖多次响应累计、速度采样、未知用量、运行结束及历史数据读取。

### 12.5 Skill、经验与角色演进

- 用户级 Skill 位于 `~/.athena/skills/<name>/SKILL.md`，front matter 只有 `name` 与 `description`。注入分两段：常驻技能目录最多 20 条、按最近使用排序，技能正文由模型按需加载
- 内置 `self-evolve` 技能由代码注册，指导模型何时沉淀技能、经验与角色改进
- 经验按角色隔离，`scope="shared"` 才是全局。每次 run 注入当前角色可见的经验目录，保持内容稳定以复用 prompt 缓存；完整内容按需检索
- 同一工具累计失败两次以上时，用一次独立 LLM 调用提炼教训，并复用标准工具路径写入经验库
- Sentinel 是一段 system prompt。演进前自动存快照，可回滚，回滚本身也可回滚。快照按角色 id 归档而非按名字，因此改名不丢失或错认历史

core 的 `agent/skill/`、`agent/evolution/` 与对应工具负责加载、反思和演进，存储层负责经验隔离与角色快照。验证覆盖技能目录与加载、经验可见范围、失败反思，以及角色改名后的历史与回滚。
