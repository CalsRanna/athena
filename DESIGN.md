## Overview

Athena 是一个跨平台的 AI 工作台（Flutter 桌面 / 移动客户端 + nocterm 终端客户端）。默认采用
**青瓷配色**：中性瓷白 / 墨绿灰画布、清晰正文、克制的青绿色强调，层级靠表面色差与发丝接缝线建立。
以 14 / 22 为常规文字基准，控件与列表适度留白；整体安静、偏专业，没有装饰性渐变、光晕、彩色插图或阴影堆叠。

**氛围与语气**

- 浅色画布 `#FAFBFA`、侧栏 `#F0F3F1`、正文 `#202824`；深色使用墨绿灰，避免纯黑。
- 青瓷强调 `accent`（浅色 `#0F766E` / 深色 `#65C7BC`）用于主按钮、确认键、选中控件、链接、
  发送键与运行中状态。选中面使用低饱和青瓷填充，正文与大面积卡片保持中性。
- 成功、警告、错误各有独立的结果色，不以品牌色代替状态语义。运行中状态点沿用围绕 accent 的等亮度色相循环。
- 侧栏、画布、浮层以轻微底色差分层，分隔线保持 1px，不用厚边框或加深投影补层次。

**密度与版式**

- 字号与间距一起适度放松：设置控件高 36，标准按钮高 40、小按钮高 32；侧栏会话行高 32，
  设置导航行高 36、行距 4，设置内容行上下各留 16；间距按 4 / 8 / 12 / 16 / 20 / 24 / 32 一档刻度取用。
- 桌面是"双区工作台"：288 侧栏（`AthenaSpace.sidebar`）+ 定宽 768 的内容列居中（`kChatColumnWidth`），
  列外左右至少留 32（`kChatColumnMinPadding`）；移动是单列滚动页 + 底部 sheet。
- 顶栏高 46，只在工作区上方画一条极浅底线（`neutralHairline` `#E8EEE9`）；侧栏右边界与页脚上边用
  `borderChrome` `#E0E7E2`（"面与面的接缝"，比容器轮廓线轻一档）。

**主题与无障碍取向**

- 浅色 / 深色采用同一青瓷语义体系，支持跟随系统，深色画布**不用纯黑**。
- 主文字对画布的对比度约 14.6:1（`#202824` on `#FAFBFA`）；UI 正文使用 14 / 22，用户与助手消息
  共用所选正文档位，保证一轮对话里问与答是同一阅读层级。
- 会话正文与代码共用三组固定字号 / 行高（Small 13 / 20、Medium 14 / 22、Large 15 / 24），保留系统无障碍缩放；composer、placeholder、侧栏、顶栏、设置与菜单不受档位影响。
  运行中 shimmer 尊重 `MediaQuery.disableAnimations`；全局 `NoSplash`，交互反馈不依赖 Material ripple，
  改由前景色 alpha 叠加与按压缩放表达。

**证据与口径**

- 本文所有几何、色值、字重均可在 `packages/athena_gui/lib/theme/athena_tokens.dart`（不随主题变化的常量）、
  `theme/athena_colors.dart`（颜色，挂 `ThemeExtension`）、`theme/athena_settings.dart`（设置面板实测几何）
  中逐条核对；组件规格取自 `lib/widget/`（设计系统控件）与 `lib/component/`、`lib/page/`（业务组件与页面）。
- 色值以 `AthenaColors.light` / `dark` 的青瓷色板为准；带 "实测" 字样的几何仍沿用原 Claude 参照，不表示颜色继续跟随该参照。
- 过渡时长取自各组件源码的显式声明。120ms 为主要交互节奏，其他时长服务淡入淡出、按压与运行状态；它们不是单一 token。

## Colors

色板按语义分为中性表面、青瓷操作色与结果状态色。浅色主按钮用深青瓷配白字，深色用亮青瓷配深色字，
不能把白字固定到所有强调色底上。`neutral*` 保留既有控件角色命名，选中底也采用青瓷浅填充。

**主操作与反色面**

- `accent` / `textOnAccent`：主按钮、移动确认键、开关开启与 Checkbox 勾选的填充 / 前景；
  同时映射 Material 的 primary / onPrimary 与 secondary / onSecondary。
- `surfaceSelected` / `neutralSelected`：会话行、设置导航与列表选中面；会话与设置导航的选中文字用 `accent`。
- `surfaceRaised` / `textOnRaised`：中性反色块，用于移动实体卡、提示框和导航图标按钮。
- `markdownLink` 使用青瓷强调。成功、警告、错误独立于主操作；危险菜单项用 `dangerText`。

| Token | Light | Dark |
|---|---|---|
| `surface` | `#FAFBFA` | `#171B1A` |
| `surfacePanel` | `#F0F3F1` | `#121615` |
| `surfaceMobile` | `#FFFFFF` | `#202624` |
| `surfaceDeep` | `#EDF1EE` | `#121615` |
| `surfaceRaised` | `#202824` | `#E8EDE9` |
| `surfaceButtonSecondary` | `#EDF1EE` | `#232C27` |
| `surfaceHover` | `#E6ECE8` | `#2B3730` |
| `surfaceSelected` | `#DEEEEA` | `#213E38` |
| `textPrimary` | `#202824` | `#E8EDE9` |
| `textInput` | `#202824` | `#E8EDE9` |
| `textSecondary` | `#626E67` | `#A1AEA7` |
| `textWeak` | `#626E67` | `#A1AEA7` |
| `textRowLabel` | `#4F5F55` | `#B5C2B9` |
| `dangerText` | `#9F3636` | `#EB9595` |
| `textOnRaised` | `#FFFFFF` | `#202824` |
| `textSecondaryOnRaised` | `#A1AEA7` | `#4F5F55` |
| `textOnCode` | `#202824` | `#E8EDE9` |
| `textSecondaryOnCode` | `#58675E` | `#AFBCB4` |
| `border` | `#DCE3DE` | `#35413B` |
| `borderStrong` | `#83998C` | `#6D8778` |
| `divider` | `#DCE3DE` | `#35413B` |
| `borderChrome` | `#E0E7E2` | `#2A342E` |
| `neutralHairline` | `#E8EEE9` | `#2A342E` |
| `neutralRule` | `#EDF1EE` | `#232C27` |
| `neutralBorder` | `#DCE3DE` | `#35413B` |
| `neutralBorderStrong` | `#83998C` | `#6D8778` |
| `neutralSelected` | `#DEEEEA` | `#213E38` |
| `neutralControlFill` | `#FFFFFF` | `#2B3730` |
| `scrim` | `#66000000` | `#7A000000` |
| `inputBackground` | `#FFFFFF` | `#202624` |
| `accent` | `#0F766E` | `#65C7BC` |
| `textOnAccent` | `#FFFFFF` | `#10251F` |
| `statusSuccess` | `#35734A` | `#8BC89D` |
| `statusWarning` | `#8E6019` | `#E5B975` |
| `statusError` | `#B24141` | `#EB9595` |
| `switchKnob` | `#FFFFFF` | `#E8EDE9` |
| `switchTrackOff` | `#83998C` | `#6D8778` |
| `checkboxOff` | `#718078` | `#81978A` |
| `iconSecondary` | `#626E67` | `#A1AEA7` |
| `iconOnRaised` | `#FFFFFF` | `#202824` |
| `shadow` | `#202824` | `#000000` |
| `cardHeader` | `#E6ECE8` | `#2B3730` |
| `codeBackground` | `#EDF1EE` | `#232C27` |
| `markdownLink` | `#0F766E` | `#65C7BC` |
| `markdownStrikethrough` | `#626E67` | `#A1AEA7` |
| `markdownMath` | `#202824` | `#E8EDE9` |

**派生规则**

- hover / ghost 填充 = `textPrimary` 5%；用户消息气泡底同样使用 `textPrimary` 5%。
- 主按钮 hover = `surface` 8% 叠在 `accent` 上，文字始终取 `textOnAccent`，浅色悬停仍有至少 4.5:1 对比度；禁用态使用中性底与次级文字。
- 上下文 chip 在已有底色上叠加前景色 5%，避免把 hover 与选中态混为一谈。
- 开关开启的滑块用 `textOnAccent`，关闭时用 `switchKnob`；深色亮青瓷轨道上配深色滑块。
- 正文 / 次级文字对画布、主按钮文字对实心底的对比度均至少 4.5:1；本表不等于所有透明叠加态的无障碍认证。
- TUI 的品牌 teal 同步深色强调 `#65C7BC`，状态栏前景为 `#10251F`；终端背景继续由用户的终端主题决定。

## Typography

**字体族**

- **Headline Font**: 系统 UI 字体（`AthenaFont.ui = null`，交给平台默认：macOS SF Pro / Windows Segoe UI），
  显式回退链 `PingFang SC` / `Microsoft YaHei` / `Noto Sans CJK SC`。字重 w500–w600。
- **Body Font**: 与 Headline **同一字体族**，w400。UI 正文与消息正文都以它渲染，不切换到衬线或等宽。
- **Mono Font**: `Menlo`，回退 `SF Mono` / `Consolas` / `Cascadia Mono` / `DejaVu Sans Mono` / `monospace`
  再回退 CJK 字体（`athenaMono()` 是唯一入口）。**只用于**代码块、行内代码、工具名与参数、终端文本、
  技术标签（模型 id、URL、引用徽标）；正文与 UI 一律不传 `fontFamily`。

**层级（一个角色 = 字号 + 行盒 + 默认字重）**

以 Medium 正文 14 / 22 为基准，UI 只使用四级：辅助 12 / 18、常规 14 / 22、标题 16 / 24、空态标题 20 / 28。

| 角色 | Token | 字号 | 字重 | 行盒 | 用途 |
|---|---|---|---|---|---|
| 空态大标题 | `AthenaTextStyle.hero` | 20 | w600 | 28 | 会话空态的角色名 |
| 页 / 对话框 / 设置分区标题 | `title` | 16 | w600 | 24 | 顶栏、对话框、设置分区 |
| 卡片 / 列表项标题与表单标签 | `section` | 14 | w600 | 22 | 卡片名、设置行标签 |
| 菜单条目 / 选择器行 / 设置行 | `row` | 14 | w400 | 22 | 菜单项、导航行、下拉框文字 |
| 消息正文（Markdown） | `prose` | 14（默认） | w400 | 22（≈1.571） | 助手正文、用户气泡文字；三档见下 |
| UI 正文 / 输入框 / 列表行 | `body` | 14 | w400 | 22 | 侧栏会话行、输入框、卡片磁贴 |
| 按钮 / chip / 可操作标签 | `label` | 14 | w500 | 22 | 按钮文字、上下文 chip |
| 辅助说明 / 元信息 / 步骤头 | `caption` | 12 | w400 | 18 | 卡片描述、时间、分组名、工具折叠头 |
| 消息代码 / 工具输出 | `AthenaTextSize.code` | 14（默认） | w400 | 22（≈1.571） | 行内代码、代码块与工具输出，与正文同档 |
| 技术标签 | `mono` | 12 | 继承 | 18 | 代码语言条、工具名、模型 id 等；可编辑输入仍为 14 / 22 |

**排版关系与规则**

- **标题不放大字号**：Markdown 的 h1–h6 与正文**同号、同行盒、同字族**，只用 `bold` 区分层级
  （`w700`）；表头与正文同理，只保留 `w600` 的加粗差异。层级交给字重与间距，不靠字号跳档。
- **常规 UI 统一为 14 / 22**：`row` 与 `section` 同号但角色不同——前者是常规字重的行文字，后者是加粗的标题；
  不要写成 `section + w400`。
- 设置分区标题共用 16 / 24；分段控件使用 14 / 22，徽标与导航组标题使用 12 / 18。设置行标签与说明同为 14 / 22，以字重和颜色区分。
- 所有文字预设都带固定行盒；Flutter 的 `height` 用行盒 / 字号换算，组件不另写比例覆盖。
  Material `TextTheme` 同步这些预设，未显式指定样式的正文也使用 14 / 22。
- **字号档位**：`AthenaTextSize` 定义 Small 13 / 20、Medium 14 / 22（默认）、Large 15 / 24 三组固定排版，`prose` 与 `code` 共用字号和行盒，只区分字体族。
  `AthenaWorkspaceTextSize` 仅在消息列表内提供所选档位，用户消息、助手正文、Markdown 标题、表格、引用与列表共用，桌面与移动端范围一致。
  行内代码、代码块与工具输出跟随同一档位；工具头、技术标签、composer、空会话 placeholder、轮次导航、审批控件、侧栏、顶栏、设置与弹出菜单不受档位影响。
  固定值均指系统缩放前的逻辑像素；不替换或线性化系统 `TextScaler`，保留完整的无障碍文字缩放规则。
- 禁止把整个 UI 做成等宽字体——那是对参照实现的误读；等宽只是代码与技术值的局部语言。
- emoji 不进文档、注释与界面文案。

## Icons

- 桌面、移动与通用组件的界面图标统一使用 `lucide_icons_flutter` 的 `LucideIcons`，由 Flutter `Icon`
  渲染；使用默认线条字重，不混用其他图标库。颜色跟随所在控件的语义色与 `IconTheme`，沿用各组件规定的尺寸。
- 同类功能用同一字形：Provider 为 `plug`、模型为 `cpu`、角色为 `userRound`、经验为 `brain`、
  Skill 为 `bookOpen`、Agent 设置为 `workflow`；推理能力为 `brainCircuit`、视觉能力为 `eye`。
- 操作图标：新增 `plus`、编辑 `pencilLine`、删除 `trash2`、关闭 `x`、确认 `check`、
  发送 `arrowUp`、停止 `square`；展开提示用 `chevronDown` / `chevronRight`。
- 常用语义集中在 `theme/athena_icons.dart` 的 `AthenaIcons`：`back` → `chevronLeft`、
  `forward` → `chevronRight`、`more` → `ellipsis`、`time` → `clock`、`error` → `circleAlert`、
  `connection` → `plug`、`dropdown` → `chevronDown`。对应入口引用这些常量，桌面与移动保持一致；
  Provider 与连通性检查共用连接图标，模型下拉选择使用下拉图标，警告仍使用 `triangleAlert`。
- 工具步骤与审批卡共享 `StepCard.toolIcon`，所有内置工具必须显式映射：终端为 `terminal`、
  文件与工具输出读取为 `file`、写文件为 `pencilLine`、网页为 `globe`、搜索为 `search`，
  后台任务为 `listTodo`、提问为 `messageCircleQuestion`；技能读取/演进共用 `bookOpen`，
  角色列表/读取/演进/回退共用 `userRound`，经验学习/回忆共用 `brain`。未知工具以 `wrench` 兜底。
  审批卡标题使用 15 号工具图标，颜色跟随标题的 `textPrimary`。
- 步骤组进行中的图标跟随当前步骤：工具用对应映射、推理用 `sparkles`、压缩用 `fileArchive`；
  结束后使用汇总图标（含工具为 `wrench`，否则为 `sparkles`）。

## Elevation

**深度靠表面色差与发丝线。** 浅色画布 `#FAFBFA`、侧栏 `#F0F3F1`、代码面 `#EDF1EE`、
浮层 `#FFFFFF` 各有层次；深色画布 `#171B1A`、侧栏 `#121615`、浮层 `#202624` 同样区分。
壳层的顶栏线用 `neutralHairline`，侧栏与页脚接缝用 `borderChrome`，容器轮廓用 `border`。

**圆角收敛为四档**（`AthenaRadius`）：4 用于徽标、行内代码、勾选框；8 用于按钮、输入框、列表行；
12 用于卡片、代码块、composer、菜单；16 用于对话框、设置面板与移动底部面板的上角。
胶囊 chip、发送键、头像与圆形状态点保留角色形状。菜单外层 12、内边距 4、行圆角 8，嵌套轮廓一致。

**阴影共用三条配方**（基色取 `colors.shadow`，随主题变化）：

- **`AthenaShadow.raised`**：基色 4% / blur 8 / offset (0, 2) 叠 3% / blur 2 / offset (0, 1)。
  桌面与移动端 composer 共用；推理强度控件内的滑块也使用这一档。
- **`AthenaShadow.overlay`**：基色 8% / blur 16 / offset (0, 4) 叠 4% / blur 3 / offset (0, 1)。
  用于右键与选择菜单、悬浮预览卡、加载提示，投影贴近容器。
- **`AthenaShadow.modal`**：基色 10% / blur 24 / offset (0, 8) 叠 5% / blur 6 / offset (0, 2)。
  桌面对话框与设置面板共用，配合遮罩表达模态层级。
- 深色菜单、预览、加载提示、对话框与设置面板另加 1px `border` 轮廓；通过 `foregroundDecoration`
  绘制，不增加内边距、不改变菜单宽度或锚点位置。

**不用阴影的地方同样有规则**：静态容器（权限卡、提问卡、排队消息面板、标准输入框）用 **1px 边框 + 平涂底色**；
代码块、引用块、脚注区**连边框都不要**，靠 `codeBackground` 与画布的底色差自成一层，语言条再用
`cardHeader` 提亮一档划分标题与正文。

**交互深度**

- 全局禁用 Material ripple（`splashFactory: NoSplash.splashFactory`）；也不做 focus ring、不做光晕。
- 状态反馈 = 前景色 alpha 叠加（ghost / hover 填充 5%，主按钮 hover 8%）+ 按压缩放 0.975
  （按下 60ms `easeOut`、回弹 200ms `easeOutBack`，仅用于 composer 内的压缩按钮）。
- 过渡节奏：**120ms 是唯一主档**（hover、描边变色、分段切换、行底变化），chip / tag 用 150ms，
  透明淡出用 60–100ms（菜单与预览卡退场要跟手），预览卡进场 140ms（淡入 + 上浮 6% + 0.98 缩放），
  消息操作条显形为"延迟 100ms + 120ms 淡入"、隐去为 60ms，工具头 shimmer 以 1800ms 循环。
- 遮罩：设置面板 `#66000000`（40% 黑）；遮罩只吸收点击、**不关闭面板**（编辑区有显式 Save，误触不应丢草稿）。
- 设置面板内容区顶部保留固定 60 高标题带（`AthenaSettings.paneTopPadding`），返回链接与关闭按钮保持固定；底边使用 1 逻辑像素的 `neutralHairline`，与工作区标题栏一致。滚动视口从标题带下方开始并裁剪正文，无返回链接的页面同样保留此区域；列表顶部内边距为 24（`AthenaSettings.panePadding`），让首项内容与底边分隔线留出空间。底部保存栏固定，不随正文滚动。

## Components

**Buttons**

- **Primary（`AthenaPrimaryButton`）**：填充 `accent`，前景 `textOnAccent`，圆角 8（`control`），
  内边距 `16 × 9`、高 40（`.small` 为 `12 × 5`、高 32），文字 `label` 14 / 22 / w600，图标 14。
  hover 只把填充微压暗/提亮（`surface` 8% 叠在实心底上），**不做光晕、不做位移**；禁用态填 `surfaceButtonSecondary`、
  文字 `textSecondary`。它是主路径操作的唯一来源（确认键、允许一次等）。
- **Secondary（`AthenaSecondaryButton`）**：线框——`border` 1px + 透明底，圆角 8，前景 `textPrimary`；
  内边距 `16 × 8`、高 40（`.small` 为 `12 × 4`、高 32）。hover 底色变 `surfaceHover` 并把描边加深到 `borderStrong`；禁用态文字降为 `textSecondary`。
- **Text button（`AthenaTextButton`）**：无描边无底，高 32，`label` 14 / 22 / `textSecondary`，hover 填 `surfaceHover`、
  文字转 `textPrimary`，圆角 8（移动端页面里的次要动作，如新增模型）。
- **Ghost icon button（`AthenaGhostIconButton`）**：默认盒 28、图标 14，静止无底，hover 填 `textPrimary` 5%，
  圆角 8；设置面板里的关闭 / 新增键、行尾 `⋯` 键（盒 24）与对话框关闭键都用它。
- **Icon-only（composer 内）**：22 × 22、图标 16，圆角 4（嵌套档小方块），按下缩放 0.975。
- **反色图标按钮（`AthenaIconButton`）**：`surfaceRaised` 底 + 16 图标，圆角 8，内边距 12——
  移动端页头动作按钮（同步、新增、返回）用它，内边距常按需收窄。

**Inputs**

- **标准输入（`AthenaInput`）**：平涂 `inputBackground` + 1px `border`，圆角 8，内边距 `12 × 10`，
  文字 `body` 14 / 行高 22 / 色 `textInput`，占位符 `textSecondary`，光标高 15 / 宽 1.5。
  **聚焦使用 1px `accent` 边框，不做焦点环、不做光晕**；失焦 / 点外部即回调 `onBlur`。
- **设置面板输入（`AthenaSettingsTextField`）**：高 36、圆角 8、描边 `neutralBorder`（聚焦 `accent`）、
  文字 14；`mono: true` 用于 URL 与模型 id；密钥型默认遮住、右端一枚 24 盒的 ghost 眼睛键切换明文。
  它比全站标准输入矮一档，为的是与同一行的其他设置控件齐平。
- **多行输入（`AthenaSettingsTextArea`）**：同一套描边与圆角，最少 6 行、随内容增高，使用 14 / 22。
- **搜索框（`AthenaSettingsSearchField`）**：高 36、圆角 8、白底 + 1px `neutralBorder`，图标 14 / `textWeak`，
  聚焦描边用 `accent`；有输入时右端出现 12 号清除叉。
- **桌面 / 移动 composer**：`surfaceMobile` 底、圆角 12、`raised` 柔阴影；1px `neutralBorder` 描边，
  聚焦切换为 `accent`，过渡 120ms，不改变边框粗细。

**Chips & Tags**

- **筛选 chip（`AthenaTag` / `AthenaTagButton`）**：**胶囊**（圆角 999）+ 1px 描边 + 平涂底，
  未选中底 `surfaceDeep` / 描边 `border` / 文字 `textSecondary` w500；选中底 `surfaceSelected` /
  描边 `borderStrong` / 文字 `textPrimary` w600。选中态靠"提亮底色 + 加粗文字"表达，
  **不做明暗反转的实心填充**。大档 `12 × 6` / `label` 14 / 22，小档 `8 × 3` / `caption` 12。
- **上下文 chip（`AthenaContextChip`，composer 内）**：小圆角方块（圆角 4）、**无描边**，
  静止填 `surfaceButtonSecondary`，hover 叠前景色 5%；左侧常带 13px 图标，标签最宽 200 并省略；
  尾随控件静止透明、hover 才显形（占位常驻 + `IgnorePointer`，避免 hover 进出行宽跳动）。
- **聊天历史入口（`DesktopContextSelector`）**：上下文条最右的无填充 chip，开启用 `AthenaIcons.time`（Lucide `clock`）+
  `Context on`，关闭用 `clockFading` + `Context off`，均沿用 13px 图标与中性前景色，无下拉箭头。
  点击使用统一菜单向上展开，间隔 8、右边对齐 chip；内容宽 280（另加面板两侧各 4 内边距），
  两项为 `Use chat history` / `Current message only`，附说明与当前项勾选，选择后立即保存并关闭。
  原 Configure 对话框与桌面 composer 的 Temperature 设置入口移除。

**Cards & Containers**

- **助手消息没有卡片底板**：内容直接铺在画布上，卡片级内边距上下各 16、左右 4；轮次之间留 16。
- **后台任务完成通知**：运行中交给 Agent 的状态通知不生成用户气泡或独立通知卡；读取输出与后续回答复用当前 run 的工具卡和助手正文。会话空闲时的自动汇报沿用普通助手消息与运行指示，已确认的运行中通知不再另起汇报。
- **用户消息气泡**：右对齐，底 `textPrimary` 5%、圆角 12、内边距 `12 × 8`、最大宽度为列宽的 **77%**，
  文字与助手正文共用所选 `AthenaTextSize.prose`，默认 14 / 行高 22。图片是输入内容的一部分，渲染在文字之前。
- **弹窗卡片（权限审批 / 提问）**：`surfaceMobile` 底 + 1px `border` + 圆角 12 + 内边距 16，
  非模态、随会话渲染在消息列表里；桌面按钮行右对齐（次要在左、主操作最右），移动改为全宽堆叠、主操作在最上。
  工具按完整调用处理审批：手动模式问人、AI 模式先审核再按需问人、所有权限模式直接放行；
  读取、搜索和后台汇报调用也遵循此流程，显式 deny 与已有授权优先处理。
  提问工具直接呈现提问卡，不叠加审批卡；复合命令作为完整调用展示，不拆成多个子命令审批卡。
- **代码块 / 脚注区**：`codeBackground` 底 + 圆角 12，无边框；语言条用 `cardHeader` 圆角只取上两角，
  12 号 mono + 12 图标 + 40% 透明度的复制键；代码正文取 `AthenaTextSize.code`，默认 14 / 行高 22、内边距 `12 × 8`。
- **行内代码 / 引用徽标**：`codeBackground` 底 + 圆角 4，行内代码取 `AthenaTextSize.code`，字号与行高和正文一致；引用徽标字形 10，属徽标尺寸而非文字档位。
- **排队消息面板**：`inputBackground` 底 + 1px `border` + 圆角 12 + 内边距 12，头部 `label` + `caption`，
  列表最多 120 高、逐条两行省略。
- **移动端卡片**：网格实体卡（Skill / Sentinel / Experience）用**反色底** `surfaceRaised` + 圆角 12 +
  内边距 12，标题 `section`、副标题 `caption`，均为 `textOnRaised`；首页卡片行 `160 × 160`、圆角 12、
  底 `surfaceButtonSecondary`。
- **详情/引用块（References）**：圆角 12 + `codeBackground` + 内边距 16，首行 `w600`、逐条 `textPrimary`。

**Menus & Popovers**

- 面板：`surfaceMobile` + 圆角 12 + `AthenaShadow.overlay`，内边距 4，默认宽 120（选择菜单可传更宽，
  子菜单 168），越界时四边各留 8 收回窗内，碰到窗底改向上展开。
- 条目：内边距 `12 × 8`（单行高 38，两行由内容撑开），圆角 8，hover 填 `surfaceHover`，
  文字 `row` 14；危险项用 `dangerText`；禁用项文字降为 `textSecondary`；带图标时图标 16、间距 10。
  三种形态由同一个 `DesktopContextMenuTile` 表达，不要再手搓：**单行**（只给 `text`）、
  **带说明的两行**（加 `description`）、**选择项**（加 `selected`：标题、可选
  `description`、可选 `badge` 跟在标题后、行尾常驻 16 的勾选槽位，并声明「按钮 + 选中」语义）。
  `badge` 属于标题行（省略号在它之前生效），`trailing` 属于行尾（调用方给的内容原样贴边）；
  另 `muted` 只弱化文字、仍可点，`enabled: false` 才连同点击与 hover 一起禁用。
- 分组小标题 `caption` 12 / `textWeak`（内边距 12/8/12/4）；分组之间用 1px `border` 分隔线，上下各留 4。
- 浮层不在 Material 之下，文字样式必须写全（含 `decoration`）——这是浮层里常见的漏色点。

**Dialogs & Sheets**

- **桌面对话框（`AthenaDesktopDialog`）**：`surfaceMobile` 底 + 圆角 16 + `AthenaShadow.modal`，
  内边距 24，宽 320–520；标题 `title` 16 / 24 / w600、`title` 与内容之间留 16；
  按钮行右对齐、间距 8（次要在前、主操作在后）。确认、输入与表单模态共用这个外壳；默认模型列表沿用相同圆角、阴影与深色轮廓。
- **移动端 sheet**：`showModalBottomSheet` + `surfaceMobile` 底、上角 16（主题统一）；确认面板主/次按钮
  **全宽堆叠、主操作在最上**，用全站的 `AthenaPrimaryButton` / `AthenaSecondaryButton`
  （`child: Center(...)` 撑满，不要自己画 `Container`）；打开前先释放焦点，避免关闭后键盘回落自动弹出。
- **加载提示**：`surfaceMobile` + 圆角 12 + `overlay` 阴影，16 × 16 描边 2 的进度环 + `caption` 文字。
- **轻提示**：桌面是左下角浮层（`surfaceMobile` + 圆角 12 + 描边取状态色 40% + 内边距 `16 × 12`，
  图标 16 + `caption`，3 秒后自动消失）；移动用 floating SnackBar，同样是浮层底色 + 状态图标。

**Rows & Lists**

- **侧栏会话行（`DesktopMenuTile`）**：**固定高 32**（不靠内容撑，避免 hover 出现 `⋮` 时行高跳动）、
  圆角 8、水平内边距 11；文字 `body` 14 / 行高 22，静止 `textRowLabel`、选中 `accent`；
  hover 只换底色（`surfaceHover`）不动文字，选中底色 `surfaceSelected`；leading 是直径 6 的状态点，
  **不在跑时是 1px 描边的圆环、运行中是实心点**（形状本身也是一条不依赖颜色的状态线索），
  颜色档位：静止 `iconSecondary` 45%、hover 75%、重命名中 `statusWarning`；运行中 `accent` 实心
  且带**色相循环**：色相每 2400ms 绕一圈，明度按"相对亮度等于 `accent`"反解，所以整圈对比度都在
  accent 那一档（浅色对画布约 5.3:1，允许 8bit 量化误差）——不这么做的话沿用同一 HSL 明度的
  黄绿相位在浅色画布上只有 1.5:1，圆点会淡到看不见；`disableAnimations` 时停在 `accent` 原色。
  尾部 `⋮` 只在 hover 出现。
- **设置行（`AthenaSettingsRow`）**：上下内边距 16、左右自带 8 的 `rowInset`（可点行的 hover/选中底比文字列宽一圈，
  文字仍与分区标题对齐），圆角 8；hover 底 `neutralRule`、选中底 `neutralSelected`、归档项文字降为 `textSecondary`；
  标签 14 / w600、说明 14 / w400 / `textWeak`、校验错误 `dangerText`；标签后的徽标
  （圆角 4 + `surfaceButtonSecondary` + `caption` 12，内边距 `5 × 1`）；左侧状态点直径 6；Sentinel 列表直接展示名称与说明，不放头像；
  行尾控件与标签之间留 24，钻取箭头 14 / `iconSecondary`。
- **设置导航行（`AthenaSettingsNavItem`）**：高 36、圆角 8、行距 4、左内边距 12 / 右 8，
  图标 16 + 间距 12，标签 14；选中换底 `neutralSelected` 与色 `accent`（w500），**不靠加粗**避免整列跳动。
- **移动端设置行（`MobileSettingTile` / `MobileGridTile`）**：`ListTile` + 16 号图标 + 右端箭头；
  网格卡见 Cards。
- **移动端表单字段（`AthenaFormField`）**：标签 16 / 24 / w600（复用 `AthenaFormTileLabel.large`，
  可用 `trailing` 挂"生成"星标）→ **12** → 控件（通常是 `AthenaInput`）→ 4（或 `descriptionGap: 8`）
  → 说明 `caption` / `textSecondary`。它是 `AthenaSettingsRow` 的**纵向版本**，
  **两者不共用实现**——桌面行是「左标签 + 右控件」的横向布局、绑 36 高的控件尺度，
  把它的几何带进移动端会得到一列挤在一起的控件。字段之间的间距（16 / 20 / 32）由调用方写
  `SizedBox`，不属字段内部。`error` 给值时取代说明并转 `dangerText`。
- **hover 骨架（`AthenaHover`）**：桌面 hover 的公共实现——状态机 + `MouseRegion` +
  `GestureDetector`，**装饰由 `builder(context, hover)` 自己画**（各处底色 / 描边 / 时长差异太大，
  不做成参数）。`cursor` 默认 `null` 表示不设置、交给父级（消息卡片这类"hover 只显形操作条、
  本身不可点"的容器用）。**静止态不要写 `Colors.transparent`**：RGB 是黑，`AnimatedContainer`
  从它插值到浅色会先闪一下深色——用目标色的 `withValues(alpha: 0)`；这条说明只在
  `widget/hover.dart` 留一份。用 `Material` + `InkWell` 的交互（如 `StepHeader`）、
  hover 由父级分发的（`MacWindowButton`）、有多个正交状态的（`TileWithSubmenu`）不套它。
- **步骤 / 工具行（`StepHeader`）**：无底板、直接坐在页面上，前景 `textSecondary`，图标 15、圆角 8，
  文案 `caption` 12（技术值是 mono 12）；运行中带一条流动 shimmer（前景色 45% → 95%，
  `disableAnimations` 时自动关闭）；展开正文最多 10 行 mono、`Error:` 前缀转 `statusError`。
  GUI 单步、分组进行中的工具头、展开后的工具项及审批卡标题共用 `StepCard.toolLabel`：
  参数 JSON 尚未完整，或 `call_description` 缺失/为空时显示 `Using a tool`；解析到有效描述后
  显示描述，工具完成后仍保留描述。头部不展示原始参数、关键参数或 JSON；完整参数只在审批详情展示。
  分组结束后的外层头部继续显示步骤汇总。
- **消息操作条（`MessageActionBar`）**：排在正文**下方**（不浮在右侧），常驻占位、默认全透明；
  按钮 24 × 24、图标 16 / `iconSecondary`、圆角 8、hover 填 `textPrimary` 5%。
  本轮未结束的助手消息不显形（但控件不摘下树，否则收尾瞬间卡片高度跳 28）。

**Navigation & Shell**

- **顶栏**：高 46；左侧 288 与侧栏同色并自带右边线（`borderChrome`），右侧工作区上方只有一条
  `neutralHairline` 底线（不画满整宽，否则会横穿侧栏竖线）；标题 `title` 16 / 24 / `textPrimary`，左缩进 12。
- **侧栏**：宽 288、底 `surfacePanel` + 右侧 `borderChrome` 1px；会话列表内边距 `8 / 8 / 8 / 12`，
  分组标题 `caption` 12 / w600 / `textWeak` / 字距 +0.3（上 14 下 6）；分组之上是导航行（`New chat`，
  行尾 hover 才出现快捷键提示 `⌘N` / `Ctrl+N`，`caption` / `textSecondary`）；底部常驻页脚一整行可点，
  页脚上边 `borderChrome`、内边距 8。
- **内容列**：消息与 composer 共用同一条 768 定宽列并居中，列内左右再加 4，窗宽不足 832 时退回两侧各 32 的留白。
- **待发送图片**：输入框边框内、文字上方横排 48 × 48 缩略图，间隔 8、圆角 `inline`；读取和解码期间用 `inputBackground` 底、Lucide 图片图标及 `accent` 加载圆环占位，不显示阶段名称或虚构百分比。失败改为 `statusError` 图片错误图标，悬停显示说明；右上角移除按钮始终可用，解析中与失败项未移除时禁用发送，停止生成按钮仍可用。
- **轮次指示器**：贴消息列左留白（距消息区左缘 12），一条 = 一轮；条高 4、命中行高 12、整列最多 20 条一页，
  宽上限由可用留白算出（留白不足 12 就不显示）；静止长为上限的 50%、hover 那条最长、其余按距离线性递减
  （相隔 4 条回到静止）；颜色只有两档——视口当前轮与 hover 轮用 `textRowLabel`，其余 `iconSecondary` 45%；圆角胶囊。
- **悬浮预览卡（`ChatPreviewCard`）**：挂在轮次条右侧 8、宽 248、圆角 12 + `overlay` 阴影、
  内边距 `12 / 10 / 12 / 12`；第一行 `body` 14 / 22 / w600 / `textPrimary` 单行省略，第二行 `caption` 12 /
  `textSecondary` 最多 3 行；hover 条 150ms 后弹出，卡片不参与命中测试（避免把 hover 从条上抢走）。

**Switch / Checkbox / Segmented / Select**

- **开关（`AthenaSwitch`）**：轨道 34 × 18、圆角 8（`control`）、内边距 3，滑块直径 12；
  开启轨道 `accent` 配 `textOnAccent` 滑块，关闭轨道 `switchTrackOff` 配 `switchKnob` 滑块。
- **勾选框（`AthenaCheckbox`）**：16 × 16、圆角 4；未选中 1px `checkboxOff` 描边，选中块填 `accent` +
  11 号 `textOnAccent` 对勾；提问卡的单选 / 多选标记使用同样配对。
- **分段控件（`AthenaSettingsSegmented`）**：轨道 `neutralRule` 无描边、高 36、圆角 8；
  选中块是**`neutralControlFill` + 1px `neutralBorder` 并铺满轨道高**（不是内缩小块）；
  选中文字 14 / 22 / w600 / `textPrimary`，未选中 14 / 22 / w400 / `textWeak`，每段水平内边距 16。
- **下拉（`AthenaSettingsSelect`）**：白底 + 1px `neutralBorder`（hover 加深到 `neutralBorderStrong`）、
  高 36、圆角 8、文字 14 / 22、右端 chevron 14 / `textWeak`；控件宽度三档：窄 120 / 常规 316 / 宽 360。

**Empty & Status**

- 会话空态：直接以 `hero` 20 / 28 / w600 名称起头，不展示角色头像或替代图标 →
  10 间距 → `body` 14 / 22 / `textSecondary` 说明 → 18 间距 → 胶囊标签（`surfaceButtonSecondary` + `label` 14 / 22 + `12 × 6`）。
- 设置面板空态：28 号图标 + 12 间距 + 标题 14 / w600 + 4 间距 + `textWeak` 提示（最大宽 360）+ 16 间距 + 动作按钮。
- **错误呈现**：页面初始化失败走 `AthenaDialog.error`（一次性提示，不打断页面）。全库**没有**子树级
  错误边界组件——Flutter 的构建期异常走全局 `FlutterError.onError` / `ErrorWidget.builder`，
  组件内部接不住子树的 build 异常；移动端页面各自的 `try/catch` 已经是全部兜底。
- 桌面窗口左上角的三枚圆形按钮（红 / 橙 / 绿，取自 Material `Colors.red/orange/green`，实心圆 + 2 内边距 +
  10 号图标）是**平台外壳例外**，不属于语义色板，不要在其他位置引用这三个色值。

## Do's and Don'ts

- **Do** 所有颜色、几何、字号只从 `theme/athena_colors.dart`（颜色，走 `ThemeExtension`）与
  `theme/athena_tokens.dart`（几何 / 排版 / 阴影）取用；设置面板的实测几何在 `theme/athena_settings.dart`。
  页面上出现裸 `Color(0x…)` 或 `Colors.xxx` 就是漏 token 的信号。
- **Do** 需要 token 之外的颜色时**从 token 派生**，不要另写色值：目前唯一的派生点是运行中状态点的
  色相循环（`StatusDot.colorAt`），它取 `accent` 的色相 / 饱和度，明度由"相对亮度等于 `accent`"反解，
  因此整圈对比度与 `accent` 相同。
- **Do** 用"同色不同 alpha"表达 hover 与选中：填充取前景色 5%（ghost）、主按钮 hover 取 `surface` 8%。
  在 `AnimatedContainer` 里**永远不要**用 `Colors.transparent` 参与插值——它的 RGB 是黑，
  中途会渲染成半透明深灰，表现为 hover 先闪一下深色；请用目标色的 0 透明度版本。
- **Do** 让状态不止靠颜色：运行中 / 重命名中同时有状态点与文字（状态点自己再分实心 / 圆环两形），
  错误在正文里带 `Error:` 前缀，危险菜单项用 `dangerText` 而非直接把 `statusError` 当文字色。
- **Do** 圆角只用 4 / 8 / 12 / 16 四档（胶囊 999 仅限筛选 chip、头像、轮次条）；
  浮层只从 `AthenaShadow.raised` / `overlay` / `modal` 三条配方里取，静态容器用 1px 边框而不是阴影。
- **Don't** 引入第二主色。GUI 的强调为青瓷 `accent`，TUI 的品牌 teal 与 GUI 深色强调同值；
  成功、警告、错误仅表达结果，不能拿来替代主操作色。
- **Don't** 给助手消息加气泡或卡片底板，也不要给容器加渐变、光晕、focus ring、ripple，或 20 以上的大圆角——
  Athena 按组件角色分配圆角（最小 4、控件 8、容器 12、大面板 16），层级靠字重、间距与底色差，不靠放大字号或加深投影。
- **Don't** 把整个 UI 做成等宽字体，也不要用纯黑 `#000000` 当画布或文字色（浅色画布 `#FAFBFA`、
  文字 `#202824`，深色画布 `#171B1A`）；纯黑只出现在深色主题的阴影基色里。
- **Don't** 在桌面端做 iOS 式滚动回弹。滚到底就停住（`ClampingScrollPhysics`），不要先拉出一段空白再弹回去——
  桌面三平台（macOS / Windows / Linux）统一，移动端保留系统默认回弹。口径落在 `AthenaScrollBehavior`
  （`theme/athena_scroll_behavior.dart`），由 `main.dart` 的 `MaterialApp.router(scrollBehavior:)` 注入；
  不要在单个 ScrollView 上零散写 `physics:`（`NeverScrollableScrollPhysics` 这类功能性禁用除外）。
- **Don't** 让文档与代码脱钩：本文件已按 Overview / Colors / Typography / Elevation / Components /
  Do's and Don'ts 六节重排，源代码注释里对旧章节号（DESIGN.md §2 / §3 / §4）的引用需要在
  下一批改动里同步更新（`athena_settings.dart`、`athena_tokens.dart`、`widget/dialog.dart`、
  `widget/markdown.dart`、`component/sentinel_placeholder.dart`、`component/permission_card.dart`）；
  改动视觉行为时同步本文件，并核对文中引用的常量仍然存在。
