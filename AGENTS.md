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
- 前端专有的持久化实现（GUI 的 `SharedPrefsKeyValueStore`）

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
├── service/        LLM 适配（三种协议）、会话与消息服务、模型目录
├── storage/        文件存储、锁、JSONL 会话、id 迁移
├── repository/     仓储接口
├── entity/         领域模型
├── util/           路径、日志、重试、分页读取等纯工具
└── seed/           内置种子数据
```

`lib/entity/` 与 `lib/service/`、`lib/storage/` 是**接口与实现分离**的：仓储接口在 `repository/`，实现散在 `storage/`（文件）与 `repository/`（经验用独立文件布局）。

### 前端

两个前端都按 `page/`（页面）、`component/` 或 `ui/widgets/`（复用组件）、`view_model/`（状态）、`di.dart` / `tui_di.dart`（组合根）组织。GUI 额外有 `theme/`、`widget/`（基础控件）、`util/`（平台集成）。

---

## 3. 命名

- 文件 `snake_case.dart`，类型 `UpperCamelCase`，成员 `lowerCamelCase`
- 工具类固定 `XxxTool`，文件名 `xxx_tool.dart`；工具名（下发给模型的 `name`）固定 `snake_case`，与用户可见文案一致
- 私有实现类用 `_` 前缀；同类小私有类集中在使用它的文件尾部，不单独建文件
- 概念三元组：`xxx_service.dart`（编排）、`xxx_rule.dart`（纯值对象）、`xxx_prompt.dart`（回调 typedef）
- 常量集中在 `abstract final class`（如 `AthenaRadius`、`AthenaMotion`）或顶级 `const`，不散落在组件里
- 持久化实体的 id 一律 `String?`（未入库时为 null），由 `IdGenerator` 生成 UUIDv7

---

## 4. 注释

**注释语言**：设计说明与「为什么」用中文；契约注释、对外错误文案、下发给模型的提示词用英文。这条界线是严格执行的——错误文案与提示词是产品行为的一部分，中英混用会影响模型表现与用户理解。

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
- **取消优先于报错**。捕获异常时先 `throwIfCancelled()` 再 rethrow，避免取消被底层错误掩盖
- **异步等待必须有取消出口**。任何等待用户或网络的 `Future` 都要与取消信号竞速（`Future.any`），保证等待绝不挂死

---

## 6. 安全约定

安全边界集中在三处，改动它们时需要格外小心：

- **权限判定**（`permission_service.dart`）：deny 规则永远优先于会话缓存与 allow 规则；规则匹配宁窄勿宽
- **路径解析**（`run_workspace.dart` + `path_normalizer.dart`）：执行、并行预检、审批落库三处必须共用同一口径，否则会出现「预检放行、执行时被拦」或授权键存错形态导致规则永不命中
- **不可信内容**：工具参数、文件内容、网页响应、工具输出都是**数据不是指令**。它们不得成为权限批准的依据，也不得写入会被当作授权的上下文（会话历史里的 user / assistant 消息才参与 AI 审核取证）

新增工具时，先想清楚：它写不写文件、跑不跑命令、访不访问网络。这决定它归入哪一类权限规则，以及是否需要实现 `CancellableTool`。

---

## 7. 测试

### 约定

- 用例文件与被测单元同名：`tool_approval_mode.dart` 的测试是 `test/agent/permission/tool_approval_mode_test.dart`
- 只为测试暴露的接口标 `@visibleForTesting`，不要为了测试把私有成员改成公开
- **不要给测试加「目录为空就跳过」的守卫**。测试被误删时应当失败，而不是静默变绿

### 各包的重点

| 包 | 跑什么 | 说明 |
|---|---|---|
| `athena_core` | `dart test` | 引擎、权限、存储、协议适配、id 迁移。用临时目录，不碰真实的 `~/.athena` |
| `athena_tui` | `dart test` | 组合根与桥接层的纯逻辑，不启动真实 UI |
| `athena_gui` | `flutter test` | 组件级 widget 测试。`DI.ensureInitialized` 支持 `homeDirOverride`，用来安装一份隔离的依赖图 |

平台分支用 `Theme.platform` / `getPlatform(context)` 判定，不用 `PlatformUtil`——后者在测试里恒为宿主平台，测不了多平台分支。

### 数据库与目录

测试一律使用临时目录注入，**绝不读写真实的 `~/.athena/`**。

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
- summary 与正文用中文，说明**为什么**这样改——尤其是被否决的方案与它的代价
- 提交信息中**不添加任何工具署名或生成标记**
- 一次提交只做一件事；大范围重排（如全仓库改名、格式化）单独成一次提交

### 发布

GUI 由 tag 触发三平台构建与 `tapster publish`，流程见 [README.md](README.md) 的发布小节。要点：

- tag 推送会先复用 CI 的三包检查，检查不过就不出包
- **Linux 平台的代码必须过 Linux CI**：CI 与发布都在 Ubuntu 上跑，只在 macOS 本地验证等于没验证
- 打 tag 前同步 `pubspec.yaml` 的版本号

---

## 11. 编码风格速查

- 用 `const` 构造与 `final` 字段；能用 `switch` 表达式表达的分支不要写成 `if/else` 链
- 集合操作优先（`map` / `where` / `fold`），不手写索引循环
- 一个文件放一个**主**类，并把它承担不了的小件（同族的 sealed 子类、纯值对象、token 常量类、同一处私有的伴生类）留在同文件；工具类用 `abstract final class` 防止实例化与继承
  - 判断标准是「这个类能不能独立站住」，不是数量。`run_event.dart` 里 13 个 sealed 事件子类、`athena_tokens.dart` 里 8 个 token 类都刻意留在一起——拆开只会让调用方多跑几个 import
  - 反之，一个类有独立的行为与测试就该独立成文件
- 不在 widget 里写业务逻辑；状态一律通过 ViewModel / Controller 的 signal 流动
- 静态分析配置集中在仓库根 `shared_analysis_options.yaml`，三个包各自留一份只做 include 的薄壳。改规则改那一份，**不要**在各包里就地加
  - include 数组里**靠后的覆盖靠前的**，共享文件必须放数组末尾，否则会被 `package:lints` / `flutter_lints` 里的同名规则覆盖（`prefer_initializing_formals` 就是这样）
  - analyzer 对解析失败的 include 只报一条 `include_file_not_found` 而**不中断**，路径写错会静默失效——改完跑一次 `dart analyze` 确认它不是 0 issue 而是真的没 issue
- 格式化用 `dart format`，配置同样在 `shared_analysis_options.yaml`（80 列、`trailing_commas: automate`）。生成文件（`*.g.dart` / `*.gr.dart`）不格式化，它们由 build_runner 覆盖
