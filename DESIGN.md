## Overview

Athena 是一个跨平台的 AI 工作台（Flutter 桌面 / 移动客户端 + nocterm 终端客户端）。它的视觉语言是对
**Claude 桌面端 `--cds-*` 设计系统**的语义化重建：暖调中性灰画布、近黑文字、几乎无彩色、层级靠"表面色差 +
发丝接缝线"建立。整体观感安静、克制、偏专业，没有任何装饰性渐变、光晕、彩色插图或阴影堆叠。

**氛围与语气**

- 冷暖由表面决定，不由强调色决定：画布是暖白 `#FCFCFB`（深色近黑 `#1A1A19`），文字是 `#0B0B0B`；
  全站只有一抹彩色（`accent` 蓝 `#2A78D6`），出现位置极少——发送键图标、会话行"运行中"状态点、
  Material 组件的默认强调（滑块、进度条、光标）。唯一的例外是"运行中"状态点的色相循环：
  它绕的是 `accent` 自己的色相、相对亮度恒等于 `accent`，不引入第二种强调色（见 Rows & Lists）。
- "安静"是硬性取向：同类容器在浅色主题下的明度差只有 3–6/255，靠一档提亮与 1px 线区分层次，
  而不是靠边框加粗或投影加深。

**密度与版式**

- 紧凑但留呼吸：控件高 32（设置面板）/ 约 40（全站标准输入），列表行高 26（侧栏会话行）、
  32（设置导航行）、40（设置内容行，含说明时约 69）；间距按 4 / 8 / 12 / 16 / 20 / 24 / 32 一档刻度取用。
- 桌面是"双区工作台"：288 侧栏（`AthenaSpace.sidebar`）+ 定宽 768 的内容列居中（`kChatColumnWidth`），
  列外左右至少留 32（`kChatColumnMinPadding`）；移动是单列滚动页 + 底部 sheet。
- 顶栏高 46，只在工作区上方画一条极浅底线（`neutralHairline` `#F7F7F7`）；侧栏右边界与页脚上边用
  `borderChrome` `#EFEFED`（"面与面的接缝"，比容器轮廓线轻一档）。

**主题与无障碍取向**

- 浅色（默认，对齐 Claude 桌面端原生观感）/ 深色（同语义镜像，画布近黑但**不用纯黑**），跟随系统。
- 主文字对画布的对比度约 16:1（`#0B0B0B` on `#FCFCFB`）；UI 正文与消息正文同号（13），保证一轮对话里
  问与答是同一阅读层级。
- 全站三档字号（Small 0.85 / Medium 1.0 / Large 1.15）**叠在系统无障碍缩放之上**，只缩放字号、不动几何；
  运行中 shimmer 尊重 `MediaQuery.disableAnimations`；全局 `NoSplash`，交互反馈不依赖 Material ripple，
  改由前景色 alpha 叠加与按压缩放表达。

**证据与口径**

- 本文所有几何、色值、字重均可在 `packages/athena_gui/lib/theme/athena_tokens.dart`（不随主题变化的常量）、
  `theme/athena_colors.dart`（颜色，挂 `ThemeExtension`）、`theme/athena_settings.dart`（设置面板实测几何）
  中逐条核对；组件规格取自 `lib/widget/`（设计系统控件）与 `lib/component/`、`lib/page/`（业务组件与页面）。
- 色值来源是 Claude `app.asar` 里的 `--cds-*` 变量，并与窗口截图采样交叉验证；带 "实测" 字样的几何值同源。
- 过渡时长取自各组件源码的显式声明（`Duration` 出现频次：120ms 二十处、150ms 四处、200ms 三处、
  100ms 三处、140ms / 240ms / 1800ms / 2400ms 各一处）。据此归纳出的"节奏档位"是聚合结论，不是单一 token。

## Colors

调色板是**两级中性**：画布族用偏暖的中性灰（白端带黄绿感 `#FCFCFB` / `#FBFBF9` / `#F3F3F0`，黑端 `#0B0B0B`），
而铺在纯白容器上的线、控件底、行底另用一组**真中性灰**（`neutral*`）——暖灰压在纯白上会偏黄。
浅色为实测基准，深色是同一语义体系的镜像。

**Primary**

- **`accent`** (light `#2A78D6` / dark `#5598E7`): 全局唯一的彩色强调，同时挂到 `ColorScheme.primary`。
  角色：composer 发送 / 终止键的图标色、侧栏会话行"Agent 运行中"状态点、Material 强调（滑块、进度条、输入光标）。
  深色档比浅色档提亮两档，因为深色画布会吃掉蓝色的对比度。
- **`markdownLink`** (light `#256ABF` / dark `#6DA7EC`): Markdown 链接与引用条目文字。比 `accent` 深一档，
  因为它是正文里的小字，需要更高的文字对比度。

**Secondary（反色墨块：主操作与"对比块"的填充色）**

- **`surfaceRaised`** (light `#0B0B0B` / dark `#FFFFFF`): 主按钮实心底、确认键、Checkbox 选中块、
  图标按钮底、移动端网格卡（Skill / Sentinel / Experience）反色底。它是"画布的反色块"，随主题翻转。
- **`textOnRaised`** (light `#FFFFFF` / dark `#0B0B0B`): 上述反色块上的主文字与图标。
- **`textSecondaryOnRaised`** (light `#A5A49A` / dark `#5F5E5A`): 反色块上的次级文字（如复制成功后的 "Copied"）。

**Tertiary（状态与危险）**

- **`statusSuccess`** (light `#0CA30C` / dark `#35B231`): 开关开启轨道、成功 toast 图标。
- **`statusWarning`** (light `#EB6834` / dark `#F09978`): 警告 toast 图标、会话行"重命名中"状态点。
- **`statusError`** (light `#D03B3B` / dark `#E66767`): 错误 toast 图标、错误边界图标、工具结果正文的
  `Error:` 前缀。
- **`dangerText`** (light `#832F2B` / dark `#E66767`): 菜单危险项（Delete）与设置行校验错误的**文字**专用色，
  比 `statusError` 更深——大面积色块与一行小字对明度的要求不同。
- **`markdownStrikethrough`** (light `#898781` / dark `#898781`): 删除线文字与线色。
- **`markdownMath`** (light `#0B0B0B` / dark `#E1E0D9`): 公式文字。

**Neutral — 画布族（暖灰，用于表面、文字、边框）**

| 角色 | Token | Light | Dark |
|---|---|---|---|
| 主画布 | `surface` | `#FCFCFB` | `#1A1A19` |
| 侧栏 / 顶栏 / 次级面板 | `surfacePanel` | `#FBFBF9` | `#151515` |
| 对话 / sheet / 弹出层 | `surfaceMobile` | `#FFFFFF` | `#1E1E1D` |
| 深层容器 / 未选中 chip 内层 | `surfaceDeep` | `#F3F3F0` | `#151515` |
| 次级按钮底 / 上下文条 / 中性色块 | `surfaceButtonSecondary` | `#F0EFEC` | `#2C2C2A` |
| 行 hover 底 | `surfaceHover` | `#F0EFEC` | `#2C2C2A` |
| 行选中底 | `surfaceSelected` | `#EDECE9` | `#383835` |
| 主文字 / 关键图标 | `textPrimary` | `#0B0B0B` | `#F6F6F4` |
| 输入框文字 | `textInput` | `#20201F` | `#E7E6E1` |
| 次级辅助文字 | `textSecondary` | `#6D6B67` | `#A5A49A` |
| 最弱文字 / 占位符 | `textWeak` | `#898781` | `#898781` |
| 列表行静止标签 | `textRowLabel` | `#52514E` | `#A5A49A` |
| 容器描边 / 分隔线 | `border` / `divider` | `#E1E0D9` | `#2C2C2A` |
| 聚焦 / 激活描边 | `borderStrong` | `#C3C2B7` | `#454442` |
| 窗口外壳接缝线 | `borderChrome` | `#EFEFED` | `#212121` |
| 次级图标 | `iconSecondary` | `#898781` | `#A5A49A` |
| 反色块上的图标 | `iconOnRaised` | `#FFFFFF` | `#0B0B0B` |
| 顶部发丝线 | `neutralHairline` | `#F7F7F7` | `#212121` |
| 输入容器 / 分段控件轨道底 | `inputBackground` | `#FFFFFF` | `#1E1E1D` |
| 代码 / 引用 / 工具输出底 | `codeBackground` | `#F6F6F4` | `#20201F` |
| 代码块语言条 / 表头 / 脚注头 | `cardHeader` | `#F0EFEC` | `#2C2C2A` |
| 反色块上的正文与代码 | `textOnCode` | `#20201F` | `#E1E0D9` |
| 代码面上的次级文字 | `textSecondaryOnCode` | `#6D6B67` | `#A5A49A` |

**Neutral — 白底中性灰族（`neutral*`，只用在纯白容器内）**

| 角色 | Token | Light | Dark |
|---|---|---|---|
| 顶栏底线（只比画布暗 5/255） | `neutralHairline` | `#F7F7F7` | `#212121` |
| 设置面板发丝线 / 分段轨道 / 设置行 hover 底 | `neutralRule` | `#F3F3F3` | `#2A2A28` |
| 白底容器 1px 描边（composer 常态、设置控件、搜索框） | `neutralBorder` | `#E4E4E3` | `#2C2C2A` |
| composer / 输入框聚焦描边 | `neutralBorderStrong` | `#BFBFBE` | `#454442` |
| 设置导航与列表选中行底 | `neutralSelected` | `#E3E3E2` | `#2C2C2A` |
| 分段控件选中块 / 下拉框底 | `neutralControlFill` | `#FFFFFF` | `#383835` |

**控件与遮罩**

- **`switchKnob`** (light `#FFFFFF` / dark `#FFFFFF`): 开关滑块（始终为白圆）。
- **`switchTrackOff`** (light `#C3C2B7` / dark `#454442`): 开关关闭轨道。
- **`checkboxOff`** (light `#B4B3A8` / dark `#5F5E5A`): Checkbox 未选中描边。
- **`scrim`** (light `#66000000` / dark `#7A000000`): 设置面板遮罩，相当于画布压 40%（深色 48%）黑。
- **`shadow`** (light `#0B0B0B` / dark `#000000`): 所有柔阴影的基色，按 alpha 取用（见 Elevation）。

**派生规则**

- 状态反馈一律用"前景色 + alpha"派生，不用固定灰：hover / ghost 填充 = `textPrimary` 5%，
  主按钮 hover = `surface` 12% 叠在 `surfaceRaised` 上，用户消息气泡底 = `textPrimary` 5%。
- 浅色下 `surfaceHover` 与 `surfaceButtonSecondary` 同值（`#F0EFEC`）——所以落在灰底上的控件（上下文 chip、
  设置行）不能靠换灰阶表达 hover，必须叠一层 alpha 填充，否则"hover 等于没反应"。

## Typography

**字体族**

- **Headline Font**: 系统 UI 字体（`AthenaFont.ui = null`，交给平台默认：macOS SF Pro / Windows Segoe UI），
  显式回退链 `PingFang SC` / `Microsoft YaHei` / `Noto Sans CJK SC`。字重 w500–w600。
- **Body Font**: 与 Headline **同一字体族**，w400。UI 正文与消息正文都以它渲染，不切换到衬线或等宽。
- **Mono Font**: `Menlo`，回退 `SF Mono` / `Consolas` / `Cascadia Mono` / `DejaVu Sans Mono` / `monospace`
  再回退 CJK 字体（`athenaMono()` 是唯一入口）。**只用于**代码块、行内代码、工具名与参数、终端文本、
  技术标签（模型 id、URL、引用徽标）；正文与 UI 一律不传 `fontFamily`。

**层级（一个角色 = 字号 + 默认字重）**

| 角色 | Token | 字号 | 字重 | 行盒 | 用途 |
|---|---|---|---|---|---|
| 空态大标题 | `AthenaTextStyle.hero` | 22 | w600 | 1.25 | 会话空态的角色名 |
| 页 / 对话框标题 | `title` | 15 | w600 | — | 桌面对话框标题、移动顶栏标题 |
| 分区 / 卡片 / 列表项标题 | `section` | 14 | w500（表单标签用 w600） | 1.4 | 卡片名、设置行标签 |
| 菜单条目 / 选择器行 / 设置行 | `row` | 14 | w400 | 1.3–1.4 | 菜单项、导航行、下拉框文字 |
| 消息正文（Markdown） | `prose` | 13 | w400 | 20（≈1.538） | 助手正文、用户气泡文字 |
| UI 正文 / 输入框 / 列表行 | `body` | 13 | w400 | 19（≈1.462） | 侧栏会话行、输入框、卡片磁贴 |
| 标签 / chip / 小按钮 / 工具名 | `label` | 12 | w500 | 1.4 | 按钮文字、chip、徽标、工具名 |
| 说明 / 元信息 / 步骤头 | `caption` | 12 | w400 | 1.4–1.6 | 卡片描述、设置说明、工具折叠头 |
| 代码 / 终端 | `mono` | 12 | 继承 | 1.5–1.6 | 代码块、工具参数与输出 |

**排版关系与规则**

- **标题不放大字号**：Markdown 的 h1–h6 与正文**同号、同行盒、同字族**，只用 `bold` 区分层级
  （`w700`）；表头与正文同理，只保留 `w600` 的加粗差异。层级交给字重与间距，不靠字号跳档。
- **菜单与设置行仍是 14**：`row` 与 `section` 同号但角色不同——前者是常规字重的行文字，后者是加粗的标题；
  不要写成 `section + w400`。
- 设置面板有两个**主字号表之外**的实测档：分区标题 16 / w600（面板独有，主表没有 16 这一档）、
  分段控件与徽标 12。移动端导航组标题 12 / w400 / `textWeak`。
- 行高是"绝对行盒"而非比例：`prose` = 20 / 13，`body` = 19 / 13 只在多行时附加（单行控件文字不设行高）。
  设置行标签与说明同为 14，说明的行高 1.5（14 号字落在 22 行盒内）。
- **字号档位**：Small 0.85 / Medium 1.0 / Large 1.15，作为一层 `TextScaler` 叠在系统缩放之上
  （`scale = 系统缩放 × 档位系数`）。放大到 1.15 时侧栏行（26 / 13）、设置导航行（32 / 14）、
  列表行（40 / 14）、分段与输入框（32）都仍有余量，因此既有固定高度不随字号档位改变。
- 禁止把整个 UI 做成等宽字体——那是对参照实现的误读；等宽只是代码与技术值的局部语言。
- emoji 不进文档、注释与界面文案。

## Icons

- 桌面、移动与通用组件的界面图标统一使用 `lucide_icons_flutter` 的 `LucideIcons`，由 Flutter `Icon`
  渲染；使用默认线条字重，不混用其他图标库。颜色跟随所在控件的语义色与 `IconTheme`，沿用各组件规定的尺寸。
- 同类功能用同一字形：Provider 为 `plug`、模型为 `cpu`、角色为 `bot`、经验为 `brain`、
  Skill 为 `bookOpen`；推理能力为 `brainCircuit`、视觉能力为 `eye`。
- 操作图标：新增 `plus`、编辑 `pencilLine`、删除 `trash2`、关闭 `x`、确认 `check`、
  发送 `arrowUp`、停止 `square`；展开提示用 `chevronDown` / `chevronRight`。
- 工具步骤与审批卡共享 `StepCard.toolIcon`，终端为 `terminal`、读文件为 `file`、
  写文件为 `pencilLine`、网页为 `globe`、搜索为 `search`，通用工具为 `wrench`。

## Elevation

**深度不靠阴影，靠表面色差与发丝线。** 浅色主题下画布 `#FCFCFB`、侧栏 `#FBFBF9`、深层容器 `#F3F3F0`、
浮层 `#FFFFFF` 相邻两档只差 3–6/255；层次由"提亮一档的底 + 1px 的分隔线"表达。壳层只有三种线：
顶栏底线（`neutralHairline`，只比画布暗 5/255，且只画在工作区上方）、侧栏右边界与页脚上边
（`borderChrome`，5% 中性黑）、容器轮廓（`border`，10% 中性黑）。

**阴影只有两条配方 + 一条面板专用**（基色取 `colors.shadow`，随主题翻转）：

- **`AthenaShadow.raised`** —— 低浮起：基色 5% / blur 12 / offset (0, 3) 叠 4% / blur 2 / offset (0, 1)。
  用于移动端 composer、行内浮层（如推理强度面板）。
- **`AthenaShadow.overlay`** —— 高浮起：基色 10% / blur 28 / offset (0, 10) 叠 6% / blur 6 / offset (0, 2)。
  用于桌面对话框、右键与选择菜单、悬浮预览卡、加载提示。
- **设置面板专用**：10% / blur 12 / offset (0, 4)。参照实现的整窗面板阴影很窄（约 10px 内衰减完、紧贴边缘最深），
  用 `overlay` 那种 28px 大范围投影会显得"飘"。
- 桌面 composer 另有一层向下偏移的极淡投影：`0x0C000000` / blur 20 / offset (0, 4)，紧贴下边框处比画布暗约 7/255。

**不用阴影的地方同样有规则**：静态容器（权限卡、提问卡、排队消息面板、标准输入框）用 **1px 边框 + 平涂底色**；
代码块、引用块、脚注区**连边框都不要**，靠 `codeBackground` 与画布的底色差自成一层，语言条再用
`cardHeader` 提亮一档划分标题与正文。

**交互深度**

- 全局禁用 Material ripple（`splashFactory: NoSplash.splashFactory`）；也不做 focus ring、不做光晕。
- 状态反馈 = 前景色 alpha 叠加（ghost / hover 填充 5%，主按钮 hover 12%）+ 按压缩放 0.975
  （按下 60ms `easeOut`、回弹 200ms `easeOutBack`，仅用于 composer 内的压缩按钮）。
- 过渡节奏：**120ms 是唯一主档**（hover、描边加深、分段切换、行底变化），chip / tag 用 150ms，
  透明淡出用 60–100ms（菜单与预览卡退场要跟手），预览卡进场 140ms（淡入 + 上浮 6% + 0.98 缩放），
  消息操作条显形为"延迟 100ms + 120ms 淡入"、隐去为 60ms，工具头 shimmer 以 1800ms 循环。
- 遮罩：设置面板 `#66000000`（40% 黑）；遮罩只吸收点击、**不关闭面板**（编辑区有显式 Save，误触不应丢草稿）。
- 设置面板内容区顶部保留固定 60 高标题带（`AthenaSettings.paneTopPadding`），返回链接与关闭按钮保持固定；底边使用 1 逻辑像素的 `neutralHairline`，与工作区标题栏一致。滚动视口从标题带下方开始并裁剪正文，无返回链接的页面同样保留此区域；列表顶部内边距为 24（`AthenaSettings.panePadding`），让首项内容与底边分隔线留出空间。底部保存栏固定，不随正文滚动。

## Components

**Buttons**

- **Primary（`AthenaPrimaryButton`）**：填充 `surfaceRaised`，前景 `textOnRaised`，圆角 7（`control`），
  内边距 `16 × 10`（`.small` 为 `12 × 6`，高约 28），文字 `label` 12 / w600，图标 14。
  hover 只把填充微压暗/提亮（`surface` 12% 叠在实心底上），**不做光晕、不做位移**；禁用态填 `surfaceButtonSecondary`、
  文字 `textSecondary`。它是主路径操作的唯一来源（确认键、允许一次等）。
- **Secondary（`AthenaSecondaryButton`）**：线框——`border` 1px + 透明底，圆角 7，前景 `textPrimary`；
  hover 底色变 `surfaceHover` 并把描边加深到 `borderStrong`；禁用态文字降为 `textSecondary`。
- **Text button（`AthenaTextButton`）**：无描边无底，`label` 12 / `textSecondary`，hover 填 `surfaceHover`、
  文字转 `textPrimary`，圆角 7（移动端页面里的次要动作，如新增模型）。
- **Ghost icon button（`AthenaGhostIconButton`）**：默认盒 28、图标 14，静止无底，hover 填 `textPrimary` 5%，
  圆角 7；设置面板里的关闭 / 新增键、行尾 `⋯` 键（盒 24）与对话框关闭键都用它。
- **Icon-only（composer 内）**：22 × 22、图标 16，圆角 4（嵌套档小方块），按下缩放 0.975。
- **反色图标按钮（`AthenaIconButton`）**：`surfaceRaised` 底 + 16 图标，圆角 7，内边距 12——
  移动端页头动作按钮（同步、新增、返回）用它，内边距常按需收窄。

**Inputs**

- **标准输入（`AthenaInput`）**：平涂 `inputBackground` + 1px `border`，圆角 7，内边距 `12 × 10`，
  文字 `body` 13 / 行高 1.5 / 色 `textInput`，占位符 `textSecondary`，光标高 15 / 宽 1.5。
  **聚焦只把描边加深到 `borderStrong`，不做焦点环、不做光晕**；失焦 / 点外部即回调 `onBlur`。
- **设置面板输入（`AthenaSettingsTextField`）**：高 32、圆角 8、描边 `neutralBorder`（聚焦 `neutralBorderStrong`）、
  文字 14；`mono: true` 用于 URL 与模型 id；密钥型默认遮住、右端一枚 24 盒的 ghost 眼睛键切换明文。
  它比全站标准输入矮一档，为的是与同一行的其他设置控件齐平。
- **多行输入（`AthenaSettingsTextArea`）**：同一套描边与圆角，最少 6 行、随内容增高，行高 1.5。
- **搜索框（`AthenaSettingsSearchField`）**：高 32、圆角 8、白底 + 1px `neutralBorder`，图标 14 / `textWeak`，
  有输入时右端出现 12 号清除叉。

**Chips & Tags**

- **筛选 chip（`AthenaTag` / `AthenaTagButton`）**：**胶囊**（圆角 999）+ 1px 描边 + 平涂底，
  未选中底 `surfaceDeep` / 描边 `border` / 文字 `textSecondary` w500；选中底 `surfaceSelected` /
  描边 `borderStrong` / 文字 `textPrimary` w600。选中态靠"提亮底色 + 加粗文字"表达，
  **不做明暗反转的实心填充**。大档 `12 × 6` / `label` 12，小档 `8 × 3` / `caption` 12。
- **上下文 chip（`AthenaContextChip`，composer 内）**：小圆角方块（圆角 4）、**无描边**，
  静止填 `surfaceButtonSecondary`，hover 叠前景色 5%；左侧常带 13px 图标，标签最宽 200 并省略；
  尾随控件静止透明、hover 才显形（占位常驻 + `IgnorePointer`，避免 hover 进出行宽跳动）。
- **聊天历史入口（`DesktopContextSelector`）**：上下文条最右的无填充 chip，开启用 Lucide `clock4` +
  `Context on`，关闭用 `clockFading` + `Context off`，均沿用 13px 图标与中性前景色，无下拉箭头。
  点击使用统一菜单向上展开，间隔 8、右边对齐 chip；内容宽 280（另加面板两侧各 4 内边距），
  两项为 `Use chat history` / `Current message only`，附说明与当前项勾选，选择后立即保存并关闭。
  原 Configure 对话框与桌面 composer 的 Temperature 设置入口移除。

**Cards & Containers**

- **助手消息没有卡片底板**：内容直接铺在画布上，卡片级内边距上下各 16、左右 4；轮次之间留 16。
- **用户消息气泡**：右对齐，底 `textPrimary` 5%、圆角 8、内边距 `12 × 8`、最大宽度为列宽的 **77%**，
  文字 `prose` 13 / 行高 20。图片是输入内容的一部分，渲染在文字之前。
- **弹窗卡片（权限审批 / 提问）**：`surfaceMobile` 底 + 1px `border` + 圆角 10 + 内边距 16，
  非模态、随会话渲染在消息列表里；桌面按钮行右对齐（次要在左、主操作最右），移动改为全宽堆叠、主操作在最上。
  工具按完整调用处理审批：手动模式问人、AI 模式先审核再按需问人、所有权限模式直接放行；
  读取、搜索和后台汇报调用也遵循此流程，显式 deny 与已有授权优先处理。
  提问工具直接呈现提问卡，不叠加审批卡；复合命令作为完整调用展示，不拆成多个子命令审批卡。
- **代码块 / 脚注区**：`codeBackground` 底 + 圆角 10，无边框；语言条用 `cardHeader` 圆角只取上两角，
  12 号 mono + 12 图标 + 40% 透明度的复制键；正文 mono 12 / 行高 1.5、内边距 `12 × 8`。
- **行内代码 / 引用徽标**：`codeBackground` 底 + 圆角 5 / 4，mono 12（引用徽标字形 10，属徽标尺寸而非文字档位）。
- **排队消息面板**：`inputBackground` 底 + 1px `border` + 圆角 10 + 内边距 12，头部 `label` + `caption`，
  列表最多 120 高、逐条两行省略。
- **移动端卡片**：网格实体卡（Skill / Sentinel / Experience）用**反色底** `surfaceRaised` + 圆角 10 +
  内边距 12，标题 `section`、副标题 `caption`，均为 `textOnRaised`；首页卡片行 `160 × 160`、圆角 10、
  底 `surfaceButtonSecondary`。
- **详情/引用块（References）**：圆角 8 + `codeBackground` + 内边距 16，首行 `w600`、逐条 `textPrimary`。

**Menus & Popovers**

- 面板：`surfaceMobile` + 圆角 12 + `AthenaShadow.overlay`，内边距 4，默认宽 120（选择菜单可传更宽，
  子菜单 168），越界时四边各留 8 收回窗内，碰到窗底改向上展开。
- 条目：高约 32（内边距 `12 × 7`，次级条目 `12 × 8`），圆角 7，hover 填 `surfaceHover`，
  文字 `row` 14；危险项用 `dangerText`；禁用项文字降为 `textSecondary`；带图标时图标 16、间距 10。
- 分组小标题 `caption` 12 / `textWeak`（内边距 12/8/12/4）；分组之间用 1px `border` 分隔线，上下各留 4。
- 浮层不在 Material 之下，文字样式必须写全（含 `decoration`）——这是浮层里常见的漏色点。

**Dialogs & Sheets**

- **桌面对话框（`AthenaDesktopDialog`）**：`surfaceMobile` 底 + 圆角 12 + `AthenaShadow.overlay`，
  内边距 24，宽 320–520；标题 `title` 15 / w600、`title` 与内容之间留 16；
  按钮行右对齐、间距 8（次要在前、主操作在后）。所有桌面模态都从这里派生，不再各自画容器。
- **移动端 sheet**：`showModalBottomSheet` + `surfaceMobile` 底；确认面板主/次按钮都是全宽矩形
  （内边距 14、圆角 7）；打开前先释放焦点，避免关闭后键盘回落自动弹出。
- **加载提示**：`surfaceMobile` + 圆角 12 + `overlay` 阴影，16 × 16 描边 2 的进度环 + `caption` 文字。
- **轻提示**：桌面是左下角浮层（`surfaceMobile` + 圆角 10 + 描边取状态色 40% + 内边距 `16 × 12`，
  图标 16 + `caption`，3 秒后自动消失）；移动用 floating SnackBar，同样是浮层底色 + 状态图标。

**Rows & Lists**

- **侧栏会话行（`DesktopMenuTile`）**：**固定高 26**（不靠内容撑，避免 hover 出现 `⋮` 时行高跳动）、
  圆角 7、水平内边距 11；文字 `body` 13 / 行高 19，静止 `textRowLabel`、选中 `textPrimary`；
  hover 只换底色（`surfaceHover`）不动文字，选中底色 `surfaceSelected`；leading 是直径 6 的状态点，
  **不在跑时是 1px 描边的圆环、运行中是实心点**（形状本身也是一条不依赖颜色的状态线索），
  颜色档位：静止 `iconSecondary` 45%、hover 75%、重命名中 `statusWarning`；运行中 `accent` 实心
  且带**色相循环**：色相每 2400ms 绕一圈，明度按"相对亮度等于 `accent`"反解，所以整圈对比度都在
  accent 那一档（浅色实测 4.2–4.4:1，±0.1 来自 8bit 颜色量化）——不这么做的话沿用同一 HSL 明度的
  黄绿相位在浅色画布上只有 1.5:1，圆点会淡到看不见；`disableAnimations` 时停在 `accent` 原色。
  尾部 `⋮` 只在 hover 出现。
- **设置行（`AthenaSettingsRow`）**：上下内边距 16、左右自带 8 的 `rowInset`（可点行的 hover/选中底比文字列宽一圈，
  文字仍与分区标题对齐），圆角 8；hover 底 `neutralRule`、选中底 `neutralSelected`、归档项文字降为 `textSecondary`；
  标签 14 / w600、说明 14 / w400 / `textWeak`、校验错误 `dangerText`；标签后的徽标
  （圆角 4 + `surfaceButtonSecondary` + `caption` 12，内边距 `5 × 1`）；左侧状态点直径 6；Sentinel 列表直接展示名称与说明，不放头像；
  行尾控件与标签之间留 24，钻取箭头 14 / `iconSecondary`。
- **设置导航行（`AthenaSettingsNavItem`）**：高 32、圆角 8、行距 2、左内边距 12 / 右 8，
  图标 16 + 间距 12，标签 14；选中换底 `neutralSelected` 与色 `textPrimary`（w500），**不靠加粗**避免整列跳动。
- **移动端设置行（`MobileSettingTile` / `MobileGridTile`）**：`ListTile` + 16 号图标 + 右端箭头；
  网格卡见 Cards。
- **步骤 / 工具行（`StepHeader`）**：无底板、直接坐在页面上，前景 `textSecondary`，图标 15、圆角 8，
  文案 `caption` 12（技术值是 mono 12）；运行中带一条流动 shimmer（前景色 45% → 95%，
  `disableAnimations` 时自动关闭）；展开正文最多 10 行 mono、`Error:` 前缀转 `statusError`。
- **消息操作条（`MessageActionBar`）**：排在正文**下方**（不浮在右侧），常驻占位、默认全透明；
  按钮 24 × 24、图标 16 / `iconSecondary`、圆角 7、hover 填 `textPrimary` 5%。
  本轮未结束的助手消息不显形（但控件不摘下树，否则收尾瞬间卡片高度跳 28）。

**Navigation & Shell**

- **顶栏**：高 46；左侧 288 与侧栏同色并自带右边线（`borderChrome`），右侧工作区上方只有一条
  `neutralHairline` 底线（不画满整宽，否则会横穿侧栏竖线）；标题 `section` 14 / `textPrimary`，左缩进 12。
- **侧栏**：宽 288、底 `surfacePanel` + 右侧 `borderChrome` 1px；会话列表内边距 `8 / 8 / 8 / 12`，
  分组标题 `label` 12 / w600 / `textWeak` / 字距 +0.3（上 14 下 6）；分组之上是导航行（`New chat`，
  行尾 hover 才出现快捷键提示 `⌘N` / `Ctrl+N`，`caption` / `textSecondary`）；底部常驻页脚一整行可点，
  页脚上边 `borderChrome`、内边距 8。
- **内容列**：消息与 composer 共用同一条 768 定宽列并居中，列内左右再加 4，窗宽不足 832 时退回两侧各 32 的留白。
- **待发送图片**：输入框边框内、文字上方横排 48 × 48 缩略图，间隔 8、圆角 `inline`；读取和解码期间用 `inputBackground` 底、Lucide 图片图标及 `accent` 加载圆环占位，不显示阶段名称或虚构百分比。失败改为 `statusError` 图片错误图标，悬停显示说明；右上角移除按钮始终可用，解析中与失败项未移除时禁用发送，停止生成按钮仍可用。
- **轮次指示器**：贴消息列左留白（距消息区左缘 12），一条 = 一轮；条高 4、命中行高 12、整列最多 20 条一页，
  宽上限由可用留白算出（留白不足 12 就不显示）；静止长为上限的 50%、hover 那条最长、其余按距离线性递减
  （相隔 4 条回到静止）；颜色只有两档——视口当前轮与 hover 轮用 `textRowLabel`，其余 `iconSecondary` 45%；圆角胶囊。
- **悬浮预览卡（`ChatPreviewCard`）**：挂在轮次条右侧 8、宽 248、圆角 10 + `overlay` 阴影、
  内边距 `12 / 10 / 12 / 12`；第一行 `body` 13 / w600 / `textPrimary` 单行省略，第二行 `caption` 12 /
  `textSecondary` 最多 3 行；hover 条 150ms 后弹出，卡片不参与命中测试（避免把 hover 从条上抢走）。

**Switch / Checkbox / Segmented / Select**

- **开关（`AthenaSwitch`）**：轨道 34 × 18、圆角 7（`inline + 2`）、内边距 3，滑块 12 白圆；
  开启轨道 `statusSuccess`，关闭轨道 `switchTrackOff`。
- **勾选框（`AthenaCheckbox`）**：16 × 16、圆角 5；未选中 1px `checkboxOff` 描边，选中块填 `surfaceRaised` +
  11 号 `iconOnRaised` 对勾。
- **分段控件（`AthenaSettingsSegmented`）**：轨道 `neutralRule` 无描边、高 32、圆角 8；
  选中块是**纯白 `neutralControlFill` + 1px `neutralBorder` 并铺满轨道高**（不是内缩小块）；
  选中文字 12 / w600 / `textPrimary`，未选中 12 / w400 / `textWeak`，每段水平内边距 16。
- **下拉（`AthenaSettingsSelect`）**：白底 + 1px `neutralBorder`（hover 加深到 `neutralBorderStrong`）、
  高 32、圆角 8、文字 14、右端 chevron 14 / `textWeak`；控件宽度三档：窄 120 / 常规 316 / 宽 360。

**Empty & Status**

- 会话空态：直接以 `hero` 22 / w600 名称起头，不展示角色头像或替代图标 →
  10 间距 → `body` 13 / `textSecondary` 说明 → 18 间距 → 胶囊标签（`surfaceButtonSecondary` + `label` 12 + `12 × 6`）。
- 设置面板空态：28 号图标 + 12 间距 + 标题 14 / w600 + 4 间距 + `textWeak` 提示（最大宽 360）+ 16 间距 + 动作按钮。
- 错误边界：48 号 `statusError` 图标 + 16 间距 + `title` 标题 + 8 间距 + `body` 说明 + 24 间距 + 重试主按钮。
- 桌面窗口左上角的三枚圆形按钮（红 / 橙 / 绿，取自 Material `Colors.red/orange/green`，实心圆 + 2 内边距 +
  10 号图标）是**平台外壳例外**，不属于语义色板，不要在其他位置引用这三个色值。

## Do's and Don'ts

- **Do** 所有颜色、几何、字号只从 `theme/athena_colors.dart`（颜色，走 `ThemeExtension`）与
  `theme/athena_tokens.dart`（几何 / 排版 / 阴影）取用；设置面板的实测几何在 `theme/athena_settings.dart`。
  页面上出现裸 `Color(0x…)` 或 `Colors.xxx` 就是漏 token 的信号。
- **Do** 需要 token 之外的颜色时**从 token 派生**，不要另写色值：目前唯一的派生点是运行中状态点的
  色相循环（`StatusDot.colorAt`），它取 `accent` 的色相 / 饱和度，明度由"相对亮度等于 `accent`"反解，
  因此整圈对比度与 `accent` 相同。
- **Do** 用"同色不同 alpha"表达 hover 与选中：填充取前景色 5%（ghost）、主按钮 hover 取 `surface` 12%。
  在 `AnimatedContainer` 里**永远不要**用 `Colors.transparent` 参与插值——它的 RGB 是黑，
  中途会渲染成半透明深灰，表现为 hover 先闪一下深色；请用目标色的 0 透明度版本。
- **Do** 让状态不止靠颜色：运行中 / 重命名中同时有状态点与文字（状态点自己再分实心 / 圆环两形），
  错误在正文里带 `Error:` 前缀，危险菜单项用 `dangerText` 而非直接把 `statusError` 当文字色。
- **Do** 圆角只用 4 / 5 / 7 / 8 / 10 / 12 这几档（胶囊 999 仅限筛选 chip、头像、轮次条）；
  浮层只从 `AthenaShadow.raised` / `overlay` / 设置面板专用三条配方里取，静态容器用 1px 边框而不是阴影。
- **Don't** 引入第二主色。GUI 的唯一强调是 `accent` 蓝 `#2A78D6`（深色 `#5598E7`）；
  终端客户端 `athena_tui/lib/ui/theme.dart` 里的品牌 teal `#6ABEB9` 是历史遗留，
  不应反向影响 GUI 色板，新代码也不要再引用它（终端侧如需对齐，应以 accent 蓝为准并同步该文件）。
- **Don't** 给助手消息加气泡或卡片底板，也不要给容器加渐变、光晕、focus ring、ripple，或 20 以上的大圆角——
  参照实现的圆角很克制（最小 4、控件 7、composer 12），层级靠字重、间距与底色差，不靠放大字号或加深投影。
- **Don't** 把整个 UI 做成等宽字体，也不要用纯黑 `#000000` 当画布或文字色（浅色画布 `#FCFCFB`、
  文字 `#0B0B0B`，深色画布 `#1A1A19`）；纯黑只出现在深色主题的阴影基色里。
- **Don't** 让文档与代码脱钩：本文件已按 Overview / Colors / Typography / Elevation / Components /
  Do's and Don'ts 六节重排，源代码注释里对旧章节号（DESIGN.md §2 / §3 / §4）的引用需要在
  下一批改动里同步更新（`athena_settings.dart`、`athena_tokens.dart`、`widget/dialog.dart`、
  `widget/markdown.dart`、`component/sentinel_placeholder.dart`、`component/permission_card.dart`）；
  改动视觉行为时同步本文件，并核对文中引用的常量仍然存在。
