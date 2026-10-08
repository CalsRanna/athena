# WIDGETS.md — Athena GUI 组件与交互口径

本文件定义 GUI 实现必须满足的组件与交互规范：组件分层与清单、图标尺寸、步骤卡与桌面对话框，以及交互与状态的落地规则，另含设置面板的逐项几何规格。

**视觉与交互的设计语言**（色板、排版、几何、阴影、动效）见 [DESIGN.md](DESIGN.md)——本文件规定这些口径在 GUI 上**怎么落地**。前端的分层与依赖方向是架构约定，见 [CONVENTIONS.md §1.3](CONVENTIONS.md)。

本文的行为要求与精确规格约束实现。文档、源码、token 与测试的关系，以及不一致时的处理方式，统一见 [CONVENTIONS.md 的文档与实现关系](CONVENTIONS.md#文档与实现的关系)。

### 平台范围

桌面指 macOS / Windows / Linux，移动指 Android / iOS。§1 是桌面设置面板规格；§2 的控件按清单标明适用平台；§3 的共享 GUI 规则适用于两端，hover 与桌面专属行为只在桌面或指针交互时适用。TUI 的视觉映射见 DESIGN，业务行为见 CONVENTIONS。

---

## §1 桌面设置面板

设置面板的几何以 **macOS 浅色主题整窗截图实测**为起点（1296×783 逻辑窗口，2x Retina），按像素量取后折半成逻辑值。以下规格由 `AthenaSettings` 集中实现，取值须与本表一致：

| 项 | 值 |
|---|---|
| 面板最大宽度 | 1024（参照实测宽 1026，规范取整为 1024） |
| 上下留白 | 44 |
| 面板圆角 | 16（`AthenaRadius.panel`） |
| 浅色遮罩 | 压 40% 黑 |
| 导航宽（含 1px 分界线） | 192 |
| 导航内边距 / 行左内缩 | 12 |
| 导航行高 / 行距 | 36 / 4 |
| 导航图标 / 图标与标签间距 | 16 / 12 |
| 搜索框高 | 36 |
| 内容区左右内边距 | 24 |
| 行块外扩 | 8 |
| 内容区顶部标题带 | 60 |
| 内容区底部内边距 | 40 |
| 分区标题与首控件间距 | 28 |
| 分区之间间距 | 40 |
| 行上下内边距 | 16 |
| 控件高 | 36 |
| 控件列宽（常规 / 窄 / 宽） | 316 / 120 / 360 |
| 行内按钮高 | 32 |

**行块外扩 8** 是个容易被改错的规则：可点行的 hover 底、选中底比文字列**每边宽 8**（列表行块比正文列宽一圈），所以内容区实际按 `panePadding − rowInset` 内缩，每一行自带 `rowInset` 的水平内边距——文字列仍落在 24 的位置上。

**顶部标题带 60** 不是随手取的：关闭键独占面板顶部一条，若按旧值 24，首个分区标题会与关闭键同一水平线，分区标题右侧的控件（如 Provider 的启用开关）会直接压在关闭键上。

### 设置面板的分组

设置行统一用「标题 + 可选说明 + 右侧控件列」的形状：

- 行标签与说明**同号**（14），标签 w600、说明 w400；说明用 `textSecondary`
- 标签与说明间距 4
- 分隔线、控件描边、选中底走 `neutral*` 一组（与 composer 共用）
- **一个分区放一组同类设置**。别把三个各只有一行的设置拆成三个分区——分区标题与行标签会互相重复
- Provider 列表按 `Enabled` / `Disabled` 分组并显示数量，启用组在前，组内沿用原顺序；未启用名称用 `textSecondary`，仍可点击进入详情。分组只表达启停状态，不把填写密钥等同于服务可用。

### 设置的保存契约

两种契约，按内容的性质选：

| 契约 | 用于 | 理由 |
|---|---|---|
| **改了即存**（无页面级 Save） | Provider、Default models、General、Agent | 分段控件点选即生效；数字与密钥在失焦或回车时提交，非法值就地报错并回退 |
| **攒着 + 底部粘性保存栏**（Discard / Save）| Sentinel、Skill | 提示词往往要改很久，逐字段失焦保存会把半成品写进磁盘 |

设置面板的遮罩**只吸收点击、不关闭面板**——编辑区有显式 Save 时，误触遮罩会丢掉未保存的编辑。关闭走右上角的 X 或 `Esc`。

---

## §2 组件分层

### 层次

组件职责、目录归属与依赖方向统一见 [CONVENTIONS.md §1.3](CONVENTIONS.md#13-前端分层与依赖方向)。本节列出 GUI 控件的选用与呈现规格。

### 基础控件

| 控件 | 平台 | 说明 |
|---|---|---|
| `AthenaPrimaryButton` / `AthenaSecondaryButton` / `AthenaTextButton` / `AthenaIconButton` / `AthenaGhostIconButton` | 桌面与移动 | 五种按钮角色。**主路径操作按钮一律从 Primary CTA 派生** |
| `AthenaInput` / `AthenaFormField` / `AthenaFormTileLabel` | 桌面与移动 | 输入框 / 带标签与校验的字段 / 表单标签 |
| `AthenaSwitch` / `AthenaCheckbox` | 桌面与移动 | 开关 / 勾选框 |
| `AthenaTag` / `AthenaTagButton` / `AthenaContextChip` | 桌面与移动 | 筛选 chip / 可点 tag 按钮 / composer 上的上下文 chip |
| `AthenaHover` | 指针交互 | hover 状态机骨架，见下 |
| `AthenaScaffold` / `AthenaAppBar` | 桌面与移动 | 页面外壳，按平台分叉 |
| `AthenaDesktopDialog` / `AthenaDialogActions` | 桌面 | 对话框外壳与底部动作行，见下 |
| `AthenaBottomSheetTile` | 移动 | 底部面板行 |
| `AthenaMarkdown` | 桌面与移动 | Markdown 渲染 |
| `AthenaWorkspaceTextSize` | 桌面与移动 | 会话字号档位的 `InheritedWidget` 载体 |

### 平台通用控件

按 [CONVENTIONS.md §1.3](CONVENTIONS.md#13-前端分层与依赖方向) 的归属规则选用以下平台通用控件：

| 控件 | 位置 | 说明 |
|---|---|---|
| `DesktopContextMenu` 系列 | `page/desktop/component/` | 桌面右键菜单，支持向上展开与二级菜单 |
| `DesktopMenuTile` | `page/desktop/component/` | 桌面左侧栏 / 列表行 |
| `AthenaSettings*`（`panel` / `row` / `nav` / `control`）、`DesktopSettingFormField` / `DesktopSettingFormActions` | `page/desktop/setting/component/` | 设置面板与设置表单专用一组 |
| `MobileSettingTile` | `page/mobile/setting/component/` | 移动设置行 |
| `MobileGridTile` | `page/mobile/component/` | 移动宫格块（Skill / Sentinel / Experience 列表共用） |

**按钮的语义**：主操作（青瓷实心）、次操作（中性面）、文字按钮（前景反馈见 §3）、图标按钮（中性反色面）。图标按钮用反色面是为了**避免把次要导航也渲染成青瓷主操作**。

**权限审批卡（桌面与移动）**是待处理的 UI 决策，工具名、调用描述与命令 / 参数统一用常规 UI 档（14 / 22），不随会话 Text size 改变；工具名用 `section` 字重，描述与详情用 `body`。审批行为见 [CONVENTIONS.md §12.1](CONVENTIONS.md#121-权限审批)。执行详情可滚动，审批按钮始终可访问。

**提问卡（桌面与移动）**同样统一用常规 UI 档（14 / 22），不随会话 Text size 改变；标题用 `section`，问题用 `label`，选项、选项说明与多选提示用 `body`，辅助信息通过次级文字色区分。

**`AthenaTag`**：胶囊 + 1px 实线边框，没有渐变边框。选中态靠「提亮底色 + 加粗文字」，**不做明暗反转的实心填充**——反转填充会在安静的灰阶层次里跳出一块高对比色块。

### Desktop Dialog

桌面对话框外壳 = `surfaceMobile` 底 + `AthenaRadius.panel` 圆角 + `AthenaShadow.modal`，内边距 24，宽 320–520。给 `title` 就渲染标题行（`AthenaTextStyle.title`），再给 `onClose` 会在标题行右端放一个 ghost 关闭键。

**桌面的确认、输入与设置表单对话框都从这里派生**，不要再各自画容器。桌面设置面板本身按 §1 的独立布局与尺寸实现。

### 什么该抽成公共组件

抽取原则统一见 [CONVENTIONS.md §1.3](CONVENTIONS.md#13-前端分层与依赖方向)，这里以 `AthenaHover` 说明如何落地。

`AthenaHover` 收敛 `bool hover` + `handleEnter`/`handleExit` + `MouseRegion` + `GestureDetector` 这段状态机与手势骨架。**装饰仍由调用方在 `builder` 里画**，按各自组件规格选取底色、描边与圆角，过渡时长遵守 §3。

动画静止态的透明色规则统一见 [§3 的 hover 规则](#3-交互与状态)。

### 步骤卡

推理、工具调用、压缩在消息列表里都是**步骤**，共用一组视觉原语（`step_primitives.dart`）：折叠头 = 图标 + 单行省略文案 + 展开箭头 + 运行中 shimmer。

- **展开箭头是「这里能展开」的唯一提示**：静止不显示，hover 或已展开时显形，展开后转到指向下并保持可见（鼠标移开后仍提示"点它可以收起"）。箭头只给可展开的头（`onTap` 为空的头不给——点了没有反应）；三种步骤今天都有正文，所以卡片里的头都能展开。箭头不改变行高：隐藏时仍占位
- 卡片里的文字**与消息正文同档同重**：折叠头、推理正文、工具输出都跟随 Text size（13 / 14 / 15，w400）。折叠头曾在那两次排版重构的交接处落到 `caption` 档（12），还一度挂在 `label` 档的 w500 上——卡片里没有比正文更小或更重的文字层级
- **三种步骤在跑的时候都能展开**：工具调用展开是一句 `Using a tool` 占位——参数不进消息列表，展开只确认"它已经在跑了"，结果返回后正文换成结果本身、展开态不变；压缩展开是此刻的详情（覆盖多少条消息、多少 tokens）。正在跑不等于不可点
- **组头的用量后缀按「已结算」计算**：工具是计数，开始即确定、返回时数字不能跳，所以含正在跑的那一个；推理的耗时与压缩的次数还在长，先不计，等它结束才出现。三种当前步都接后缀——`Thinking` / 压缩状态说的是"此刻在做什么"，后缀说的是"已经用了多少"，不接的话这两个状态就成了唯一看不到进度的
- 这些卡片**没有底板**，直接坐在页面底色上，因此统一用 `textSecondary` 前景、`AthenaIcon.regularSize` 图标
- hover 的前景反馈见 §3；运行中的头由 shimmer 的 `srcIn` 统一改色，此时提亮被覆盖
- 步骤分组与渲染规则见代码：`step_card.dart`、`message_tiles.dart`

### 图标

图标库是 `lucide_icons_flutter`。两处集中：

- `AthenaIcons` —— 跨页面共用的**导航与状态**语义（返回、前进、更多、时间、错误、连接、下拉）。同一功能必须用同一字形
- `StepCard.toolIcon(toolName)` —— 工具名到字形的唯一映射表，权限卡也复用它。新增工具时在这里加一行

其余一次性图标就地引 `LucideIcons.xxx` 即可。判据是：**这个字形会不会出现在两处以上**——会，就进映射表；不会，就不要为了整齐而绕一层。

通用图标尺寸由 `AthenaIcon` 提供，按角色选档，调用方不再写裸尺寸：

| token | 尺寸 | 用途 |
|---|---|---|
| `inlineSize` | 14 | 文案旁的辅助图标、下拉箭头（含步骤头的展开箭头）、紧凑 ghost 按钮 |
| `regularSize` | 16 | 常规导航与操作、菜单、步骤头、权限卡、运行指示器 |
| `largeSize` | 24 | 移动设置列表等较大引导图标 |

13 / 15 不再作为独立档位。控件内部符号按容器比例保留：16px 勾选框内的勾号 11、紧凑关闭标记 12；窗口红黄绿控制的符号 10、可见圆点 14，遵循独立的窗口控制规则。设置空态保留 `AthenaSettings.emptyStateIconSize` = 28，属于独立展示组件，不套用列表图标尺寸。**代码块语言条**（图标 + 语言标签 + 复制键）原按容器取 12，现已整行走正文档（14 / w400）——它和正文并排出现，比正文小一号会被读成另一层的信息。

图标按钮的**可见盒子**与**点击区域**分开：`AthenaIconButtonSize.compact` = 28（ghost、消息操作），`regular` = 32（导航按钮）。移动导航的返回、更多、新增等共用 `AthenaIconButton`，可见盒子 32，外层 `touchTarget` = 48；桌面使用可见盒子本身作为点击区域。移动顶栏按按钮实际宽度分配剩余标题空间，避免多个操作按钮挤出屏幕。窗口控制不参与这两档映射。


---

## §3 交互与状态

### hover（桌面与指针交互）

hover 的视觉反馈按组件角色选择，不使用覆盖所有控件的文字变色规则：

| 组件 | hover 反馈 | 与其他状态的区别 |
|---|---|---|
| 侧栏 / 列表 / 菜单行 | 背景切到 `surfaceHover`，标签文字与语义色保持稳定 | 选中态按组件规格表达，不由 hover 改变当前选择 |
| 设置导航与可点设置行 | 背景使用对应的 `neutral*` 反馈色，文字保持稳定 | 选中底使用 `neutralSelected` |
| 文字按钮、可展开的步骤头 | 前景从 `textSecondary` 提亮到 `textPrimary`；文字按钮可同时出现 hover 底色 | 步骤运行中由 shimmer 接管前景，见 §2 |
| 主按钮与次按钮 | 调整填充或底色，保留该表面配套的前景色 | 禁用态不能按可操作状态反馈 |
| Ghost 图标按钮 | 背景使用 `textPrimary` 的 5% 透明度，前景保持稳定 | 点击区域与图标尺寸见 §2 |

颜色过渡使用 [DESIGN.md §6](DESIGN.md#6-动效) 的 `AthenaMotion.hover`。移动触屏的操作入口必须能通过可见控件或明确的长按交互访问，不能依赖 hover。

水波（splash）**GUI 两端关闭**（`splashFactory: NoSplash.splashFactory`）。`Material` 只在结构必需处出现：桌面设置面板内的 `TextField` 需要 `Material` 祖先（设置路由是非透明路由，没有 `Scaffold`），以及浮层的透明包装。

**`Colors.transparent` 不能用作动画的静止态**——它的 RGB 是黑，`AnimatedContainer` 从它插值到浅色时会先闪一下深色。用目标色的 `withValues(alpha: 0)`，RGB 全程一致、只有 alpha 在动。这条在本项目被独立踩过多次，是全站最容易复发的坑。

### 滚动（桌面与移动）

桌面三平台统一 `ClampingScrollPhysics`，移动端保留平台默认（iOS 的回弹是系统预期）。

Flutter 给 macOS 默认装的是 `BouncingScrollPhysics`——那是触摸屏的惯性语义，放在桌面窗口里是持续的视觉噪音：列表每滚到底都晃一下。

平台判定走 `getPlatform(context)`（即 `ThemeData.platform`）而**不是** `PlatformUtil`：Flutter 默认 physics 正是按这个信号分派的，两者必须同源；顺带也让 widget 测试能换平台断言。

### 加载与运行中

运行统计的计算、更新与持久化契约见 [CONVENTIONS.md §12.4](CONVENTIONS.md#124-运行统计)，本节只规定 GUI 的呈现。

- 助手消息底部工具条在 run 进行中常显：运行指示、实时耗时、累计输出 token 与最近一次 LLM 响应的生成速度（保留一位小数）；完成后换成复制、最终耗时、输出 token 与速度，恢复整卡 hover 显形。输出 token 与速度分别在有数值时显示，缺失时隐藏对应项，不补造 `0` 或 `—` 占位。两项均缺失时只保留耗时与运行指示；历史消息缺失耗时时仍显示 `—`
- 工具条的 `StreamingIndicator` 使用独立圆形进度动画：与 Step Header 图标共用 `AthenaIcon.regularSize`，1.5px 圆头细线、次级文字色，无水平内边距；垂直居中于 `AthenaIconButtonSize.compact` 高的工具条，切换成复制按钮时不改变行高
- 输出 token 总数在一万以下使用千分位（`1,234`），一万起使用十进制 K / M / B / T 简写（`12.3K`、`1.2M`），最多一位小数并去掉 `.0`
- 输出 token 总数与生成速度变化时，以 500ms（`AthenaMotion.slower`）线性过渡到新值；途中再次更新从当前显示值继续，首次显示或未知值不补造动画，耗时刷新不重启动画。千分位与简写应用于动画显示值
- 运行中的步骤头用 shimmer（`AthenaMotion.cycle`）表达，不引入转圈图标
- 状态点（`StatusDot`）用色相循环表达后台活动，周期遵守 [DESIGN.md §6](DESIGN.md#6-动效) 的例外规格
- 瞬时反馈（「已复制」、桌面轻提示）停留 `AthenaMotion.linger` 后自动复原/消失

### 会话回退

共享回退行为见 [CONVENTIONS.md §12.3](CONVENTIONS.md#123-会话回退rewind)，本节规定 GUI 的操作入口与界面反馈。

用户消息操作条使用 `Rewind` 与 history 图标，桌面沿用 hover 显形，移动端长按
菜单提供同一入口。确认文案说明回退点、现有草稿替换、停止排队输入与后台工作，
以及文件和已执行命令不撤销。提交后恢复原文与图片，输入框聚焦，消息列表滚到底。
回退期间输入框只读，避免等待收尾时新草稿被恢复内容覆盖。

### 空态与错误

- 空态用 `AthenaTextStyle.hero` 的标题 + `textSecondary` 的说明
- 错误文字用 `statusError`（菜单里的危险项用 `dangerText`）
- **不回退到子树级错误边界**：组件接不住子树的 build 异常，别想着加

### 没有行为就不摆入口

桌面侧栏只放「新建会话」这一项导航行，设置菜单只放设置与关于——不摆没有对应能力的入口。移动端同样只呈现已有能力对应的入口。空白入口比缺少入口更糟：用户点进去才发现是空的。

同一条判断也适用于数字：**宁可空着也不给错的数字**。轮次指示器在整段会话的计数还没扫完时不画，而不是先画一个暂时正确的近似值。

### 消息列表结构（桌面与移动）

**同一处控件的根类型不能随状态改变。** 例如消息列表根控件类型一旦随「有无审批卡」变化，滚动视图及其 `ScrollPosition` 会被整体重建，新 position 从偏移 0 起步，贴底校正要晚一帧才生效——表现为弹卡时列表先跳到顶部再跳回底部。

同理，历史加载期间必须保留滚动视图（只是不给 sliver），只有「确实是空会话」才换成占位控件。

**桌面轮次条的动态正文不进控件配置。** 工作区由 `Watch` 驱动，agent 工作期间会随状态更新重建；轮次条的正文内容也在更新，所以宿主只把**结构**（条数、窗口摆位、条宽）交给它、按结构缓存控件实例，内容留到 hover 现取。把不断变化的值当配置传进去，会让这棵子树反复重建与重绘——这种脏标记由重建传导，外面包 `RepaintBoundary` 挡不住。

**桌面轮次条不按被卡片挤压后的消息区居中。** 审批 / 提问卡片挤占的是消息区的高度；轮次条排在**整列**高度里居中，卡片弹出时才不会整体上移（旧写法下卡片一多，条列先被压扁、再被挤成零高）。

### 两种状态不得靠同一种手段区分

- 列表行的运行状态用**形状**（实心点 = 运行中，描边圆环 = 静止），形状本身是一条不依赖颜色的线索
- 运行中的色相循环刻意不用 `statusSuccess` / `statusWarning` 一类的固定色——那会被读成结果状态，而「运行中」不是任何一种结果

### 桌面专属

- 窗口原生背景色跟随主题（浅色下避免露出默认黑底）；`⌘W` 隐藏窗口
- 托盘常驻，退出前优雅停止后台任务
- 单实例：重复启动的进程直接退出，不碰数据目录
