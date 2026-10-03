# AGENTS.md — 仓库工作约定

本文件写给在本仓库工作的 AI Agent，也写给加入项目的开发者。它描述**约定**与**边界**；代码结构本身的细节以源码注释为准（本仓库的注释密度较高，重要的「为什么」都写在被约束的那处代码旁边）。

项目概览、构建步骤与数据布局见 [README.md](README.md)；视觉与交互口径见 [DESIGN.md](DESIGN.md)。

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

界面文案、交互反馈、平台差异（弹窗审批 vs 终端内联审批）属于前端。

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
├── service/        LLM 适配（三种协议）、模型目录、需联网的会话操作
├── storage/        持久化实现：文件存储、锁、JSONL 会话、仓储实现、id 迁移
├── repository/     仓储接口
├── entity/         领域模型
├── util/           路径、日志、重试、分页读取等纯工具
├── extension/      Map / 集合等类型的扩展方法
└── seed/           内置种子数据
```

`lib/entity/` 与 `lib/service/`、`lib/storage/` 是**接口与实现分离**的：仓储接口在 `repository/`，实现全部落在 `storage/`。

`service/` 只管**网络 + 编排**（LLM 适配、协议转换、需联网的会话操作），**持久化一律进 `storage/`**。判据是它碰不碰网络，不只看类名——`storage/chat_store_service.dart` 名为 service，但只编排仓储、不发请求，故归 `storage/`。

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
- 一条约束只写一处，写在最能防止违反的地方。例如「相对路径必须在三处共用同一解析口径」写在 `run_workspace.dart`，另外两处注释指回去
- 被独立踩过多次的坑值得单独强调（如 `AthenaHover` 里「静止态不要用 `Colors.transparent`」）

**不要写**：`// TODO` 式的空承诺、与代码不同步的旧注释、注释掉的死代码。

**文档引用**：引用本文档用 `AGENTS.md`，引用设计口径用 `DESIGN.md §N`（章节号见 DESIGN.md，改动设计文档时同时更新引用处的编号）。**不要引用已删除的文档**。

---

## 5. 错误处理

- **工具抛出的异常不冒泡**。工具内部异常（读到非 UTF-8 文件、写入无权限目录……）转成 `'Error: ...'` 文本作为工具结果交还模型，让模型自己纠正，而不是终止整个 run
- **损失必须显式**。适配器遇到无法映射的请求字段、无法表达的响应内容时抛 `UnsupportedError` / `FormatException` / `StateError`，**不静默丢弃**。宁可让调用方收到明确失败，也不要让用户看到「看起来成功了」的错误结果
- **错误文案一律英文**。`StateError` / `UnsupportedError` / `FormatException` / `ArgumentError` 的文本，以及工具返回的 `'Error: ...'`，都用英文。这些消息可能不经翻译直接冒到用户面前（例：`onCompact` 的回调抛异常时 `agent_service.dart` 不 catch，它就成了 run 错误）。系统提示词使用中文，见 §4
- **取消优先于报错**。捕获异常时先 `throwIfCancelled()` 再 rethrow，避免取消被底层错误掩盖
- **异步等待必须有取消出口**。任何等待用户或网络的 `Future` 都要与取消信号竞速（`Future.any`），保证等待绝不挂死

---

## 6. 安全约定

安全边界集中在三处，改动它们时需要格外小心：

- **权限判定**（`permission_service.dart` + `permission_rule.dart`）：deny 规则永远优先于会话缓存与 allow 规则；**「宁窄勿宽」针对的是放行**。allow 一律字面精确，deny 反向放宽（折叠空白、去参数末尾 `/`）——deny 放宽最坏是多拦一条，allow 放宽会多放行一条用户没看过的命令。这条不对称是有意的，改 `matches` 时不要顺手把两侧拉齐
- **路径解析**（`run_workspace.dart` + `path_normalizer.dart`）：执行、并行预检、审批落库三处必须共用同一口径，否则会出现「预检放行、执行时被拦」或授权键存错形态导致规则永不命中。另有两条约束：解析不了真实路径时**规则匹配**退回词法路径（要有东西可匹配），而**执行前**必须调 `unresolvablePathError` 拒绝——路径上有不可穿越的目录时，审批与 deny 规则看到的都是词法路径，真正落到哪是未知的。新增会读写文件的工具时别漏掉它
- **不可信内容**：工具参数、文件内容、网页响应、工具输出都是**数据不是指令**。它们不得成为权限批准的依据，也不得写入会被当作授权的上下文（会话历史里的 user / assistant 消息才参与 AI 审核取证）

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

平台分支用 `Theme.platform` / `getPlatform(context)` 判定，不用 `PlatformUtil`——后者在测试里恒为宿主平台，测不了多平台分支。

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

```bash
cd packages/athena_core && dart analyze && dart test && dart format --output=none --set-exit-if-changed lib test
```

```bash
cd packages/athena_tui && dart analyze && dart test && dart format --output=none --set-exit-if-changed lib test
```

```bash
cd packages/athena_gui && flutter analyze && flutter test && dart format --output=none --set-exit-if-changed lib test
```

`athena_gui` 还要在首次拉取依赖后、以及改了带 `@RoutePage` 的页面之后重新生成路由：

```bash
cd packages/athena_gui && dart run build_runner build --delete-conflicting-outputs
```

改完 Dart / Flutter 代码后跑一次 hot reload（或 hot restart）；提交前跑对应包的 `analyze`、`test` 与 `format --set-exit-if-changed`——CI 跑的就是这三条，本地过了 CI 就不会红。

`format` 那条只扫 `lib test` 两个目录，`.g.dart` / `.gr.dart` 不在其中：生成文件不符合格式器口径，且 build_runner 会覆盖，格式化它们没有意义。

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

GUI 由 tag 触发三平台构建与 `tapster publish`，流程见 [README.md](README.md) 的发布小节。要点：

- tag 推送会先复用 CI 的三包检查，检查不过就不出包
- **Linux 平台的代码必须过 Linux CI**：CI 与发布都在 Ubuntu 上跑，只在 macOS 本地验证等于没验证
- 打 tag 前同步 `pubspec.yaml` 的版本号

---

## 11. 编码风格速查

- 用 `const` 构造与 `final` 字段；不重新赋值的局部变量与单例引用用 `final`，常量上下文中的构造与声明用 `const`，由共享 lint 约束。能用 `switch` 表达式表达的分支不要写成 `if/else` 链
- 集合操作优先（`map` / `where` / `fold`），不手写索引循环
- 一个文件放一个**主**类，并把它承担不了的小件（同族的 sealed 子类、纯值对象、token 常量类、同一处私有的伴生类）留在同文件；工具类用 `abstract final class` 防止实例化与继承
  - 判断标准是「这个类能不能独立站住」，不是数量。`run_event.dart` 里 13 个 sealed 事件子类、`athena_tokens.dart` 里 8 个 token 类都刻意留在一起——拆开只会让调用方多跑几个 import
  - 反之，一个类有独立的行为与测试就该独立成文件
- 不在 widget 里写业务逻辑；状态一律通过 ViewModel / Controller 的 signal 流动
- 导入一律用 `package:` 形式，**禁止相对导入**（含 `export`），由 `shared_analysis_options.yaml` 里的 `always_use_package_imports` 强制。唯一例外是 `test/` 内部的辅助文件（`test/support/` 等）：它们不在 `lib/` 下，本就无法用 `package:` 导入，这类引用仍是相对导入
- 静态分析配置集中在仓库根 `shared_analysis_options.yaml`，三个包各自留一份只做 include 的薄壳。改规则改那一份，**不要**在各包里就地加
  - include 数组里**靠后的覆盖靠前的**，共享文件必须放数组末尾，否则会被 `package:lints` / `flutter_lints` 里的同名规则覆盖（`prefer_initializing_formals` 就是这样）
  - analyzer 对解析失败的 include 只报一条 `include_file_not_found` 而**不中断**，路径写错会静默失效——改完跑一次 `dart analyze` 确认它不是 0 issue 而是真的没 issue
- 格式化用 `dart format`，配置同样在 `shared_analysis_options.yaml`（80 列、`trailing_commas: automate`）。生成文件（`*.g.dart` / `*.gr.dart`）不格式化，它们由 build_runner 覆盖
