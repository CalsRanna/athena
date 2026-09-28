# GUI 组件复用方案

> 诊断日期：2026-09-28
> 范围：`packages/athena_gui/lib`（146 个 dart 文件 / 28094 行）

## 一、结论先行

**"组件不够标准"这个直觉是对的一半，但问题不在你以为的地方。**

需要先纠正一个可能的预期：这个项目的设计系统**不是缺失，而是接近完备**——`theme/athena_tokens.dart` 有完整的圆角 / 间距 / 字号预设（连行盒都预设好了），`theme/athena_colors.dart` 挂 `ThemeExtension` 随主题切换，DESIGN.md 有 34161 字的组件规格，AGENTS.md 明确写了 `widget/` = 设计系统原语、`component/` = 业务组件的边界。

而且这个边界**98% 被遵守**。全库 0 处 `Color(0x` 字面量（唯一例外是色板定义文件自己）、0 处裸 `ElevatedButton`/`TextButton`（80 处 `GestureDetector` 是刻意的——`splashFactory: NoSplash` 关掉了 Material ripple）。

**真正的问题是三种"该抽象而没抽象"的地方，它们不属于设计系统层，而是组件形态层：**

| # | 问题 | 量化 | 性质 |
|---|---|---|---|
| 1 | **五个菜单条目各自手搓** | 455 行重复实现 | 已有 `DesktopContextMenuTile`，但它只支持单行文字，需要"标题+描述+勾选"的地方全部绕开 |
| 2 | **移动端一整套平行表单体系** | 7 个页面 0 处使用设置系统，21 处手写 label+gap+input | 桌面端 9 个页面全部走 `AthenaSettings*`，移动端完全另起一套 |
| 3 | **hover 状态机逐文件重复** | 25 处 `bool hover`，17 个文件 | 连"不能用 `Colors.transparent` 插值"的注释都在 6 个文件里抄了一遍 |

外加一批**低风险速赢**（僵尸组件、反向依赖、失效的错误边界）和**两个功能性缺陷**。

---

## 二、先说不要动的部分

避免过度重构。以下都是**有意设计**，不要"统一"掉：

- **`widget/` vs `component/` 目录划分** —— 约定清晰且被遵守，保留。
- **80 处 `GestureDetector` + 48 处 `MouseRegion` 而非 `InkWell`** —— `athena_theme.dart:71` 设了 `NoSplash.splashFactory`，全站不要 Material ripple，自绘是刻意的。
- **`widget/switch.dart` / `widget/checkbox.dart` 自绘** —— 全库 0 处原生 `Switch(`/`Checkbox(`，替换是完整的。
- **`widget/markdown.dart`（541 行，11 类）** —— 10 个类都是 `flutter_markdown` 的插件式扩展点，100% 内聚，**拆了只会变成 10 个 30 行的碎片**。
- **`component/elicit_card.dart`（439 行）** —— 单一状态机（多问题分步 + 多选 + 自由输入互斥），内聚。
- **`component/permission_card.dart` vs `elicit_card.dart` 的相似外壳** —— 两者外壳确实逐行同构（`surfaceMobile` + `border` + `AthenaRadius.container` + `EdgeInsets.all(16)` + `Column`），但**这是两次使用，不是模式**。抽"卡片外壳"组件只会得到一个参数比内容还多的包装。
- **`widget/dialog.dart` 里的移动端手搓按钮** —— 见 §5.4，这个要改，但**不是因为它重复，而是因为它违反了自己文件里引用的规范**。

---

## 三、方案主体

### 方案 1：菜单条目统一到 `DesktopContextMenuTile` ✅ 已完成（2026-09-28）

> 执行结果：5 个手搓 tile 全部消除，共减 487 行（含 `context_menu.dart` 因扩展 API 增加的 82 行），
> 净减约 400 行。`flutter analyze` 干净、101 个测试全通过。详见文末「执行记录」。

**问题证据**

`widget/context_menu.dart:171` 的 `DesktopContextMenuTile` 已经是事实标准（30 处调用），被 21 个文件 import。但它只接受 `String text`，渲染成单行。于是所有需要"标题 + 描述 + 选中勾"的地方**全部绕开它，各自手搓**：

| 文件 | 类 | 行数 |
|---|---|---|
| `page/desktop/home/component/permission_mode_selector.dart:94` | `_ModeTile` | 90 |
| `page/desktop/home/component/context_selector.dart:79` | `_ContextOption` | 89 |
| `page/desktop/home/component/model_selector.dart:90` | `_ModelTile` | 98 |
| `page/desktop/setting/provider/component/api_format_menu.dart:110` | `_ApiFormatTile` | 69 |
| `page/desktop/setting/component/model_menu.dart:97` | `_ModelTile` | 109 |
| | **合计** | **455 行** |

这五个类**结构完全同构**。以 `_ModeTile`（`permission_mode_selector.dart:105-183`）和 `_ModelTile`（`model_selector.dart:107-187`）为例，逐项对照：

| 要素 | 两者是否一致 |
|---|---|
| `bool hover = false` + `handleEnter`/`handleExit` | 逐字相同 |
| `Container` + `BoxDecoration(borderRadius: AthenaRadius.row, color: hover ? surfaceHover : null)` | 逐字相同 |
| `padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7/8)` | 一致（12 是同一个值，7/8 有细微出入） |
| `width: DesktopContextMenuConfiguration.widthOf(context)` | 逐字相同 |
| `MouseRegion(cursor: click) → GestureDetector(behavior: opaque)` | 逐字相同 |
| `handleTap` 里 `DesktopContextMenuManager.instance.dismiss()` | 逐字相同 |
| 浮层里必须写全 `decoration: TextDecoration.none` 的注释 | 两个文件各抄了一遍 |

**重复的不只是样式，还有一段踩坑注释**——`model_selector.dart:111` 与 `permission_mode_selector.dart:107` 都有注释「浮层不在 Material 之下，文字样式要写全（含 decoration），与菜单条目一致」。这说明这个坑被独立踩了多次。

**方案**

给 `DesktopContextMenuTile` 增加可选的第二行与选中态，而不是新建组件：

```dart
// widget/context_menu.dart
DesktopContextMenuTile(
  text: 'Use chat history',           // 现有，保持
  description: 'Include earlier messages in this chat.',  // 新增，可选
  selected: enabled,                  // 新增，可选，行尾打勾
  // icon / trailing / danger / enabled 保持不变
)
```

关键点：
- **`description != null` 时降级为两行布局**，`selected` 时行尾补 `LucideIcons.check`（16 / `textPrimary`）。
- **保留 `vertical: 7`（单行）与 `vertical: 8`（双行）两档内边距**，与 DESIGN.md「主条目高 36、次级条目高 38」一致——这正好对应现有两种实现，**不要强行统一成同一个值**。
- **「浮层必须写全 `decoration`」这条注释只在 `DesktopContextMenuTile` 里留一份**，其余四处删掉。
- `_ModeTile` / `_ContextOption` / `_ApiFormatTile` 改为「数据映射 + 调用 Tile」，每个类降到 15 行以内。`_ModelTile` 因带 `_DefaultBadge`，保留为薄包装。

**收益**：删掉约 400 行重复，5 处踩坑注释归一，新增菜单项自动获得一致的 hover / 勾选 / 无障碍语义。

**顺带**：`_MenuHeader`（`permission_mode_selector.dart:73`，`fromLTRB(12, 8, 12, 4)` + `caption` + `textWeak`）与 `DesktopContextMenuGroupLabel`（`context_menu.dart:561`）**是同一个东西**，删除前者改用后者。

**风险**：**低**。这是纯样式组件的参数扩展，行为不变。已有 `test/widget/context_menu_test.dart`（105 行）和 `context_selector_test.dart`（158 行）可作为回归网。

---

### 方案 2：移动端表单行组件

**问题证据**

桌面端 9 个设置页面**全部**使用 `AthenaSettings*` 系统，无一手搓。移动端 7 个页面**一处都没用**：

| 页面 | `AthenaSettings*` 使用次数 |
|---|---|
| `page/mobile/setting/agent_page.dart` | 0 |
| `page/mobile/provider/provider_form_page.dart` | 0 |
| `page/mobile/provider/model_form_page.dart` | 0 |
| `page/mobile/skill/form.dart` | 0 |
| `page/mobile/sentinel/form.dart` | 0 |
| `page/mobile/chat/chat_configuration.dart` | 0 |
| `page/mobile/default_model/default_model_form_page.dart` | 0 |

移动端手写的模式在 `page/mobile/setting/agent_page.dart:13-30` 等 21 处反复出现：

```dart
Column(children: [
  AthenaFormTileLabel.large(title: 'Max Iterations'),
  const SizedBox(height: 12),
  AthenaInput(controller: iterationsController, placeholder: '100'),
  const SizedBox(height: 4),
  Text('Maximum number of agent loop iterations...', style: tipTextStyle),
  const SizedBox(height: 16),
  // ... 下一项重复同样的序列
])
```

**这正是 `AthenaSettingsRow` 的纵向版本**——label / control / description / error 四要素齐全，只是没抽成组件。

**方案**

抽一个移动版行组件，参数形状对齐 `AthenaSettingsRow`（便于日后理解与迁移），但**不共用实现**：

```dart
// widget/form_field.dart（新增）
class AthenaFormField extends StatelessWidget {
  final String label;
  final Widget control;          // 通常是 AthenaInput
  final String? description;     // 对应 AthenaSettingsRow.description
  final String? error;           // 对应 AthenaSettingsRow.error
  final double gap;              // 默认 12，紧凑处传 8

  // 渲染：label → gap → control → (4) → description / error
}
```

**关键约束**：
- **移动端不要直接用 `AthenaSettingsRow`**。它是 36 高控件 + 192 导航 + 桌面浮层体系的一部分，`widget/settings/` 的几何口径（`theme/athena_settings.dart`）是为桌面面板定的。强行复用会把桌面几何带进移动端。
- 复用 `AthenaFormTileLabel`（已有，6 文件 21 处）作为 label 渲染。
- **`error` 走 `dangerText`**，与 `AthenaSettingsRow` 一致——移动端现在完全没有行内校验反馈（见 §5.5）。

**收益**：7 个页面 21 处手写序列收敛为一个组件；日后加行内校验、调整间距只需改一处。

---

### 方案 3：hover 状态机抽象

**问题证据**

`bool hover = false` 出现 **25 处，分布 17 个文件**。每处配套一段 `MouseRegion(onEnter/onExit) + setState + AnimatedContainer(120ms)` 样板，约 12 行。

更值得注意的是：**同一段踩坑注释被抄了 6 次**——「不能从 `Colors.transparent` 做插值：它的 RGB 是黑，AnimatedContainer 从中途经过时会渲染成半透明深灰，表现为 hover 先闪一下深色再变浅」。出现位置：

`widget/menu.dart:59-61`、`widget/button.dart:271`、`widget/checkbox.dart:57`、`widget/tag.dart:187-189`、`widget/settings/control.dart:61-63`、`widget/settings/row.dart:174`、`widget/settings/panel.dart:230`

（`AnimatedContainer(duration: 120ms)` 出现 21 次。）

**方案**

新增 `widget/hover.dart`：

```dart
/// 把 hover 状态机收敛到一处。回调里拿到 hover 布尔值，
/// 静止态用 `base.withValues(alpha: 0)` 而不是 Colors.transparent——
/// 后者的 RGB 是黑，插值途中会闪一下深色（这条坑注释只在这里留一份）。
class AthenaHover extends StatefulWidget {
  final Widget Function(BuildContext context, bool hover) builder;
  final SystemMouseCursor cursor;
  final bool enabled;
  final VoidCallback? onTap;
  // ...
}
```

**适用范围（重要）**：
- **适合**：`widget/menu.dart`、`widget/button.dart`、`widget/checkbox.dart`、`widget/tag.dart`、`widget/settings/*.dart` 这类**纯视觉 hover**。
- **不适合**：`widget/settings/row.dart:73` 有 hover + selected + dimmed 三个正交状态；`widget/window_button.dart` 的 hover 由父级传入；`component/status_dot.dart` 的 hover 参与动画。**这些保留各自实现**，不要硬套。

**收益**：删掉约 200 行样板 + 5 份重复注释。**注意这是收益最小、风险最高的一项**——它改的是遍布全库的交互路径。如果只做一件事，先做方案 1。

---

## 四、速赢清单（低风险，可单独提交）

| # | 项 | 位置 | 动作 |
|---|---|---|---|
| 1 | `DesktopPopButton` | `widget/app_bar.dart:26` | **删**。零引用——`MobilePopButton`（`:49`）在 `:154` 被用了，桌面分支忘了用 |
| 2 | `DesktopEditDeleteContextMenu` | `widget/context_menu.dart:120` | **删**。零引用，`chat_list.dart:252` 与 `provider.dart:260` 各自手搓了菜单项 |
| 3 | `AthenaSecondaryButton.medium` | `widget/button.dart:121` | **删**。零引用，且 padding 与默认构造器**完全相同**（都是 `16 × 8`） |
| 4 | ~~`AthenaSettingsControlWidth.{narrow,normal}`~~ | `widget/settings/control.dart:22-23` | **【已修正：改为保留】** 原判断有误——`narrow` 别名确实无人用，但底层常量 `AthenaSettings.controlNarrowWidth` 被 `agent_page.dart:160` **直接使用**（绕过了别名）；且 DESIGN.md:358 明确记载「控件宽度三档：窄 120 / 常规 316 / 宽 360」，是**已文档化的设计 token**。正确做法是把 `agent_page.dart:160` 改用 `.narrow` 别名，三档全部保留 |
| 5 | `AthenaAppBar.leading` | `widget/app_bar.dart:12` | **删**。21 处调用，**0 处**传（含 `_DesktopAppBar` / `_MobileAppBar` 内部的 `leading ?? fallback` 分支，都随参数一并简化） |
| 6 | `CopyButton` 搬到 `widget/` | `component/button.dart` | **移**。`widget/markdown.dart:3` import 了 `component/button.dart`——**这是全库唯一一处 `widget/` → `component/` 反向依赖**。它无业务耦合，应属原语层 |
| 7 | `TurnNavigator` 上提 | `page/desktop/home/component/turn_navigator.dart` | **移**到 `component/`。`component/message_sliver.dart:7` import 了 `page/desktop/...`——全库唯一 `component/` → `page/` 依赖 |
| 8 | `widget/settings_nav.dart` | `widget/settings_nav.dart` | **移**入 `widget/settings/nav.dart`。它全是 `AthenaSettings.*` token 驱动，是三件套的同体系成员，漏在外面 |
| 9 | `_MessageActionButton` | `component/message_tiles.dart:603` | **改用** `AthenaGhostIconButton(box: 24, iconSize: 16)` 外包 `Tooltip`。除 Tooltip 外逐行等价，且能顺带获得 120ms 过渡（现在没有） |
| 10 | 对话框按钮行三处拷贝 | `widget/dialog.dart:381`、`:437`、`provider_form_dialog.dart:158` | **抽** `AthenaDialogActions`。三处都是 `Row[Secondary(Cancel), SizedBox(sm), Primary(Confirm)]` |
| 11 | `DesktopSettingFormField` / `Actions` | `provider/component/provider_form_dialog.dart:101,148` | **搬家**。它们事实上是公共组件，却被 `sentinel_form_dialog.dart:2`、`skill_form_dialog.dart:2`、`model_form_dialog.dart:3` 反向 import——sentinel 和 skill 为了拿一个 label 组件，必须 import provider 的表单文件。移到 `widget/settings/` |
| 12 | `_formatDate` × 4 | `experience.dart:345`、`experience/detail.dart:182`、`experience/list.dart:155`、`home/home.dart:113` | **合并**到 `util/` |
| 13 | 移动端悬浮新建按钮 | `mobile/sentinel/list.dart:35`、`mobile/skill/list.dart:48` | **抽公共组件**。两段逐字复制（我已 diff 确认，仅文案与两处 `const` 不同） |

---

## 五、需要修的功能性问题

诊断过程中发现三处**不是风格问题、而是行为缺陷**的地方。它们不属于"抽组件"，但值得一并知道：

### 5.1 `AthenaErrorBoundary` 从不捕获错误

`widget/error_boundary.dart:24` 声明了 `FlutterErrorDetails? _error`，`:28` 判断 `if (_error != null)`，`:58` 在 retry 时置 null——**但全文没有任何一处给 `_error` 赋值**。没有 `FlutterError.onError`、没有 `ErrorWidget.builder`、没有 try/catch。

两个调用点（`page/mobile/home/home.dart:62`、`page/mobile/chat/chat.dart:69`）都传了 `onRetry: _initializeViewModels`，期望它能兜住初始化异常。**实际上错误视图永远不可达，68 行里只有 20 行是活的。**

### 5.2 移动端 Brave API Key 明文显示

`page/mobile/setting/agent_page.dart:140` 是 `AthenaInput(controller: braveApiKeyController, placeholder: 'BSA...')`——**没有 `obscureText`**。

桌面端同一字段（`page/desktop/setting/agent_page.dart:142`）传了 `obscure: true`。

### 5.3 移动端密钥没有显示切换键

承接上条：`AthenaSettingsTextField` 自带 eye 切换（`control.dart:299-309`），`AthenaInput` 没有。这是 §方案 2 里两个输入框该合并的具体动机之一。

### 5.4 `widget/dialog.dart` 的移动端按钮违反自家规范

`widget/dialog.dart:337-349` 手搓了主按钮（`Container` + `BoxDecoration(accent)` + `Text`），而不是用 `AthenaPrimaryButton`。同样的问题在 `_InputDialogState`（`:501-551`）里重复。

而 `component/permission_card.dart:15-16` 明确注释着：「按钮直接用全站的 `AthenaPrimaryButton` / `AthenaSecondaryButton`（DESIGN.md：主路径操作按钮一律从 Primary CTA 派生）」。

**同一个仓库里，一个文件引用规范，另一个文件违反规范。** 这 4 个手搓方法还都零 hover 反馈。

### 5.5 移动端表单缺行内校验

`AthenaSettingsRow` 有 `error` 参数（`dangerText`），桌面端用得很足。移动端因为不用这套，**没有任何行内校验反馈**——例如 `provider_name_page.dart:47` 空名时静默 `return`，用户看不到任何提示。

---

## 六、建议的执行顺序

按「收益 / 风险」排序，每步都可独立提交、独立验证：

**第一轮（速赢，纯删除与搬家，无行为变化）**
§4 的 1-8。这些是僵尸代码和依赖方向修正，不碰任何交互路径。跑一遍 `flutter analyze` + 现有 22 个 widget 测试即可。

**第二轮（方案 1：菜单条目）**
收益最大、风险最低的实质重构。455 行 → 约 50 行。有 `context_menu_test.dart` 与 `context_selector_test.dart` 兜底。

**第三轮（§5 的功能性缺陷）**
5.1 / 5.2 是真 bug，建议优先于方案 2——尤其 5.2 是密钥明文。5.4 顺手做掉。

**第四轮（方案 2：移动端表单行）**
需要逐个页面迁移，改动面大但每页独立。建议从 `mobile/setting/agent_page.dart` 试点（它同时涉及 5.2 和 5.5）。

**第五轮（方案 3：hover 抽象）**
最后做。它触及全库交互路径，收益最小、回归风险最高。**如果时间有限，这一轮可以不做。**

---

## 七、预期收益

| 项 | 现状 | 预期 |
|---|---|---|
| 菜单条目重复 | 455 行 / 5 处 | 约 50 行 |
| hover 样板 | 25 处 / 17 文件 + 6 份重复注释 | 收敛到 1 处 |
| 移动端表单序列 | 21 处手写 | 1 个组件 |
| 僵尸组件 | 5 个 public 声明 / 0 引用 | 0 |
| 反向依赖 | 2 处（`widget/`→`component/`、`component/`→`page/`） | 0 |
| 功能性缺陷 | 3 处 | 0 |

**注意预期上限**：粗估全库重复代码约 700–900 行，占总代码量的 2.5–3%。**这不是一个"代码腐烂"的仓库，而是一个设计系统完备、但组件形态层还没收敛的仓库。** 方案的价值主要在可维护性（新增菜单项 / 表单字段只需改一处），而非代码量减少。

---

## 八、关于测试

GUI 有 22 个 widget 测试（3864 行），但**覆盖不均匀**：

- **覆盖良好**：`workspace_text_size`、`home_page_new_chat`、`clipboard_image_input`、`chat_run_state`、`step_card`、`status_dot`、`turn_indicator`
- **可直接用于本次重构**：`context_menu_test.dart`、`context_selector_test.dart`、`api_format_select_test.dart`、`permission_card_test.dart`
- **完全没覆盖**：`widget/settings/` 三件套（设置面板的滚动只有一个 93 行的测试）、所有 provider / sentinel / skill / experience 表单

**建议**：第二、四轮重构前，先给对应区域补测试。特别是 `AthenaSettingsRow` 这种 12 个参数的组件，改之前需要确定现有行为。

`test/widget/home_page_new_chat_test.dart` 提供了挂真实页面的正确姿势（`DI.ensureInitialized(homeDirOverride: 临时目录)` + 交替 `runAsync`/`pump`），可直接复用。

---

## 九、执行记录

### 第一轮：速赢（2026-09-28 完成）

净减 87 行，两处反向依赖清零。`flutter analyze` 干净，101 个测试全通过。

| # | 项 | 结果 |
|---|---|---|
| 1 | `DesktopPopButton` | 删（零引用） |
| 2 | `DesktopEditDeleteContextMenu` | 删（35 行，零引用） |
| 3 | `AthenaSecondaryButton.medium` | 删（padding 与默认构造器完全相同） |
| 4 | `AthenaSettingsControlWidth.{narrow,normal}` | **改为保留**（见下方修正） |
| 5 | `AthenaAppBar.leading` | 删（21 处调用，0 处传） |
| 6 | `CopyButton` | 移到 `widget/copy_button.dart` |
| 7 | `TurnNavigator` | 移到 `component/`（消除 `component/` → `page/` 依赖） |
| 8 | `settings_nav.dart` | 移到 `widget/settings/nav.dart`（三件套 → 四件套） |

**执行中修正的判断**：原方案要删 `AthenaSettingsControlWidth.{narrow,normal}`，理由是"10 处调用全是 `.wide`"。
这是错的——底层常量 `AthenaSettings.controlNarrowWidth` 被 `agent_page.dart:160` **绕过别名直接使用**，
且 DESIGN.md:358 已文档化"控件宽度三档"。正确做法是反向的：让 `agent_page.dart` 改用 `.narrow` 别名。
已按此执行，AGENTS.md 的"三件套"表述同步改为四件套。

### 第二轮：菜单条目统一（2026-09-28 完成）

5 个手搓 tile 全部消除，净减约 400 行。

| 文件 | 行数变化 |
|---|---|
| `widget/context_menu.dart` | 566 → 648（+82，扩展 API 的成本） |
| `page/desktop/home/component/permission_mode_selector.dart` | 182 → 69（−113） |
| `page/desktop/home/component/context_selector.dart` | 188 → 99（−89） |
| `page/desktop/home/component/model_selector.dart` | 351 → 232（−119） |
| `page/desktop/setting/provider/component/api_format_menu.dart` | 177 → 104（−73） |
| `page/desktop/setting/component/model_menu.dart` | 249 → 156（−93） |
| **合计** | **−405** |

`DesktopContextMenuTile` 新增四个参数：`description`（两行）、`selected`（勾选 + 语义）、
`badge`（标题后小标）、`muted`（灰字但可点）。

**实施中的三处关键判断**（都偏离了原方案，理由如下）：

1. **`selected` 用 `bool?` 而不是 `bool`**。原方案写 `this.selected = false`，但 `context_selector_test` 依赖
   `Semantics(selected:)` 语义，且未选中的选择项必须**如实报 `selected: false`**。用 `bool?`（`null` = 非选择项）
   才能让普通右键菜单条目不被平白加上 `selected: false`。
2. **勾选槽位常驻 16、内边距按行数分档**。这是 `_ContextOption` 原有的"两档都留出勾选位置，说明文字不会随
   选中状态换行"的讲究，必须保留。实测原五处的 padding 与归纳规则**完全吻合**（三个单行都是 7、两个双行都是 8），
   即 DESIGN.md 的「主条目高 36 / 次级条目高 38」，零视觉变化。
3. **`_DefaultBadge` 与能力图标走新增的 `badge` 而不是复用 `trailing`**。它们是标题行的一部分
   （长模型名先省略、不被小标挤掉），`trailing` 是行尾独立控件——语义不同，混用会让省略号位置错误。

**顺带消除**：`_MenuHeader`（permission_mode_selector）与 `_GroupLabel`（model_selector）两处
`DesktopContextMenuGroupLabel` 的重复实现。

**未做**：`reasoning_effort_selector` / `sidebar_footer` / `token_indicator` 里三处直接使用
`DesktopContextMenuConfiguration.widthOf` 的自定义面板内容（滑块面板、菜单头部、明细面板）——
它们不是"条目"，是各菜单里的特有内容，强行套 tile 会得到比内容还多的参数。保留。
