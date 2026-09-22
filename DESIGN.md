# Design System

## 1. Visual Theme & Atmosphere

Athena 是一个跨平台的 AI 工作台。它的视觉语言基准是 **Claude 桌面端**
（macOS 版，Anthropic）。

本节所有数值来自 **Claude 桌面端的 `app.asar`**（`/Applications/Claude.app/Contents/Resources/app.asar`
里的 `MainWindowPage-*.css`，一套 `--cds-*` 设计系统），并与窗口截图采样交叉验证。

| 项 | Claude 实测 / token | 值 |
|----|--------------------|-----|
| 中性灰阶 | `--cds-gray-0..900` | `#fff` → `#fcfcfb` → `#f9f9f7` … `#0b0b0b` |
| 画布 | `--cds-gray-10`（采样一致） | `#FCFCFB` |
| 侧栏 / 面板 | 实测采样 | `#FBFBF9`（与画布几乎无差） |
| 行 hover | 实测采样 | `#F0EFEC` |
| 行选中 | `--cds-gray-60` | `#EDECE9` |
| 弹出层 | `--cds-surface-2` | `#FFFFFF` |
| 描边 | `--cds-gray-100` | `#E1E0D9` |
| 主文字 | `--cds-gray-900` | `#0B0B0B` |
| 次级文字 | `--cds-gray-500` | `#6D6B67` |
| 弱文字 | `--cds-gray-400` | `#898781` |
| 强调 | `--cds-role-accent-fill` = `blue-450` | `#2A78D6` |
| composer 圆角 | `--cds-radius-composer` | **12** |
| 正文字号 | `--cds-font-size-body` | 默认档 14；**本仓取 `--textsm` 档 13**（行高 19，见 §3） |
| 消息正文字号 | `--cds-font-size-prose` | 默认档 15；**本仓取 `--textsm` 档 13**（行高 20） |
| 头像档位 | `--cds-avatar-lg/md/sm/xs` | 36 / 28 / 20 / 16 |

### 核心特征

- **浅色为原生形态**：Claude 默认是暖白底 + 暖灰侧栏。深色是同一体系的镜像。
- **灰阶是暖的**：`--cds-gray-*` 从 `#fff` 到 `#0b0b0b`，白端带黄绿感
  （`#f9f9f7` / `#fcfcfb`），和中性灰一眼能分辨。深色画布取 `#1A1A19`，
  侧栏更暗（`#151515`），不使用纯黑。
- **UI 用系统字体，等宽只给代码**：Claude 的侧栏、设置、按钮、正文都是比例字体；
  等宽只出现在代码块、行内代码和内置终端。
- **圆角克制**：可点行 / 控件 7、卡片 10、对话框 / 菜单 12；筛选 chip 是胶囊，
  composer 内的 chip 是 4 的小方块。
- **浮层带柔阴影**：对话框与菜单不是硬 1px 描边，而是一圈很柔的投影；
  composer 输入容器是 1px 中性灰描边加一层向下的柔投影。
- **唯一彩色是强调蓝** `#2A78D6`（深色 `#5598E7`），用于发送键与运行中状态点。

Athena 在 Claude 语言之上的自有取舍：
1. 会话上下文（角色、模型）以 chip 形式内嵌在 composer 顶部；
2. 侧栏页脚是账号式菜单入口（Claude 那里是账号），点开只有设置与关于两个真实条目。

**核心设计理念**
- 背景必须退后，内容和控制区必须前置。
- 层级靠三样东西：灰底提亮、极淡分隔线、柔阴影。不要引入第四种手段。
- 界面应当像"为长时间使用而设计"，而不是为了首屏惊艳。
- 桌面和移动端共享同一套审美语言，只改变结构，不改变人格。

### Priority Rules

1. **先保住"暖白底 + 系统字体 + 克制的圆角"的底子**。
2. **再保住克制感**：如果"更强视觉冲击"和"更安静的专业工具感"冲突，选后者。
3. **再考虑层次强化**：优先增加灰度差与柔阴影，而不是新增颜色或特效。
4. **最后才允许局部变化**：新页面可以有新构图，但不能引入第二套视觉人格。

### Forbidden Patterns

- 纯黑画布（`#000000`）
- 全站等宽字体
- 装饰性渐变边框、发光 / 光晕
- 用硬 1px 描边代替对话框 / 菜单的柔阴影
- 大面积单色品牌色；强调色只有 `accent` 一支，且只用于主要动作

---

## 2. Color Palette & Roles

Claude 的色板是一套**偏暖的中性灰**，和普通中性灰一眼能分辨：白端带一点黄绿
（`#f9f9f7` / `#fcfcfb`），黑端是 `#0b0b0b`。它同样用"基色 + alpha"派生
（`--cds-alpha-0..9` = `neutral-900` 的 0/5/10/20/35/50/60/70/85/95%）。

### Primary Surfaces

| Token | Light | Dark | 说明 |
|-------|-------|------|------|
| `surface` | `#FCFCFB` | `#1A1A19` | 主画布 |
| `surfacePanel` | `#FBFBF9` | `#151515` | 侧栏 / 顶栏（与画布几乎无差） |
| `surfaceMobile` | `#FFFFFF` | `#1E1E1D` | 对话框 / sheet |
| `surfaceDeep` | `#F3F3F0` | `#151515` | 深层容器 |
| `surfaceRaised` | `#0B0B0B` | `#FFFFFF` | 主操作实心底 |
| `surfaceButtonSecondary` | `#F0EFEC` | `#2C2C2A` | 次级按钮 / 上下文条 |
| `surfaceHover` | `#F0EFEC` | `#2C2C2A` | hover 态（实测） |
| `surfaceSelected` | `#EDECE9` | `#383835` | 选中态（实测） |

### Text

| Token | Light | Dark | Claude 来源 |
|-------|-------|------|------------|
| `textPrimary` | `#0B0B0B` | `#F6F6F4` | `gray-900` / `gray-30` |
| `textInput` | `#20201F` | `#E7E6E1` | `gray-800` / `gray-80` |
| `textSecondary` | `#6D6B67` | `#A5A49A` | `gray-500` / `gray-300` |
| `textWeak` | `#898781` | `#898781` | `gray-400` |
| `textRowLabel` | `#52514E` | `#A5A49A` | 列表行标签的静止色（`gray-600`，比次级文字更深） |
| `textOnRaised` | `#FFFFFF` | `#0B0B0B` | 反色块上的文字 |
| `textOnCode` | `#20201F` | `#E1E0D9` | 代码容器上的文字 |
| `textSecondaryOnRaised` | `#A5A49A` | `#5F5E5A` | 反色块上的次级文字 |
| `textSecondaryOnCode` | `#6D6B67` | `#A5A49A` | 代码容器上的次级文字与图标 |
| `dangerText` | `#832F2B` | `#E66767` | 菜单危险项文字（比 `statusError` 深） |

### Borders

| Token | Light | Dark |
|-------|-------|------|
| `border` | `#E1E0D9` | `#2C2C2A` |
| `borderStrong` | `#C3C2B7` | `#454442` |
| `divider` | `#E1E0D9` | `#2C2C2A` |
| `borderChrome` | `#EFEFED` | `#212121` |

`borderChrome` 是**窗口外壳**的接缝线（侧栏右边界、侧栏页脚上边、顶栏里那段侧栏边）：
它比 `border` 轻一档（neutral-900 的 5% 对 10%，实测对比度 1.11:1 对 1.28:1），
因为外壳线是「面与面的接缝」，不是容器的轮廓——容器描边该更实，外壳接缝该更虚。

### 白底上的中性灰

Claude 的**设置面板**与 **composer 输入容器**用的是一组**中性灰**（neutral-900 的
alpha 阶：约 3% / 5% / 10% / 25%），不是侧栏那套暖灰——暖灰铺在纯白容器上会偏黄。
这组灰只有下面 7 个 token，全站的"白底上的线与底"都从这里取，不再各自定义：

| Token | Light | Dark | 用途 |
|-------|-------|------|------|
| `neutralHairline` | `#F7F7F7` | `#212121` | 顶栏底线（只比画布暗 5/255） |
| `neutralRule` | `#F3F3F3` | `#2A2A28` | 设置面板发丝分隔线、分段控件轨道、行 hover 底 |
| `neutralBorder` | `#E4E4E3` | `#2C2C2A` | 白底容器的 1px 描边：composer 常态、设置控件、搜索框、导航 / 列表分界 |
| `neutralBorderStrong` | `#BFBFBE` | `#454442` | composer 聚焦描边 |
| `neutralSelected` | `#E3E3E2` | `#2C2C2A` | 设置导航 / 列表的选中行底 |
| `neutralControlFill` | `#FFFFFF` | `#383835` | 分段控件选中块、下拉框底 |
| `scrim` | `#0B0B0B` @40% | `#000000` @48% | 设置面板遮罩 |

`neutralBorder` 的实测值在 `#E1E1E0`（composer）到 `#E7E7E7`（设置控件）之间，
取中值 `#E4E4E3`（导航分界的实测值），各处偏差不超过 3/255。深色一套无法从浅色
截图量取，按同一语义镜像推导。设置面板里与既有 token 同值的角色直接复用既有
token：导航底 = `surfacePanel`、内容区与搜索框底 = `surfaceMobile`、导航静止字 =
`textRowLabel`、分组标题与说明 = `textWeak`、选中字 = `textPrimary`。

### Accent & Status

| Token | Light | Dark | Claude 来源 |
|-------|-------|------|------------|
| `accent` | `#2A78D6` | `#5598E7` | `role-accent-fill` = `blue-450` / `blue-350` |
| `statusSuccess` | `#0CA30C` | `#35B231` | `green-400` / `green-350` |
| `statusWarning` | `#EB6834` | `#F09978` | `orange-350` / `orange-250` |
| `statusError` | `#D03B3B` | `#E66767` | `red-450` / `red-350` |

### 控件与容器

| Token | Light | Dark |
|-------|-------|------|
| `switchTrackOff` | `#C3C2B7` | `#454442` |
| `checkboxOff` | `#B4B3A8` | `#5F5E5A` |
| `iconSecondary` | `#898781` | `#A5A49A` |
| `cardHeader` | `#F0EFEC` | `#2C2C2A` |
| `codeBackground` | `#F6F6F4` | `#20201F` |
| `avatarBackground` | `#E4E3DD` | `#383835` |
| `shadow` | `#0B0B0B` | `#000000` |
| `switchKnob` | `#FFFFFF` | `#FFFFFF` |
| `iconOnRaised` | `#FFFFFF` | `#0B0B0B` |
| `inputBackground` | `#FFFFFF` | `#1E1E1D` |

### Markdown

| Token | Light | Dark |
|-------|-------|------|
| `markdownLink` | `#256ABF` | `#6DA7EC` |
| `markdownStrikethrough` | `#898781` | `#898781` |
| `markdownMath` | `#0B0B0B` | `#E1E0D9` |

### Semantic Principles

- `accent` 是全局唯一彩色，只用于发送键、运行中状态点与 Material 默认强调（光标、进度条）；
  Markdown 链接另有 `markdownLink`。
- 状态色只承担功能语义；色相取自 Claude 的 `green / orange / red` 色阶。
- 选中与 hover 用**灰阶档位**表达（`gray-70` / `gray-90`），不做反转填充。
- **hover 只改底色，文字不动**。实测 Claude 的侧栏行在 hover 前后标签都是
  `#52514F`；把标签一起提亮会让文字"闪一下"，是错的。
- **不要从 `Colors.transparent` 做颜色动画**。它的 RGB 是黑色，`AnimatedContainer`
  插值中途会渲染成半透明深灰，表现为"hover 先闪一下深色再变浅"。要用目标色的
  0 透明度版本（`color.withValues(alpha: 0)`），让 RGB 全程一致、只有 alpha 在动。
- 一次只用一种手段：有灰底就不要再加边框。

### Token Governance

- 不新增彩色；`accent` 之外任何色相都要有功能语义。
- 新增灰阶一律从 `--cds-gray-*` 这套暖灰里取，不要手挑一个相近的中性灰。
- 不新增圆角或阴影等级（见 §5、§6）。
- 白底容器上的线与底只从 `neutral*` 七个 token 里取，不要再在组件里私藏一个
  `Color(0x...)`。

---

## 3. Typography Rules

### Font Family

- **UI / 正文 / 按钮 / 侧栏 / 设置**：系统字体（`AthenaFont.ui == null`）。
  macOS 上是 SF Pro，Windows 上是 Segoe UI；CJK 由系统回退处理。
- **代码 / 行内代码 / 工具输出 / 终端**：`AthenaFont.mono`（Menlo → SF Mono →
  Consolas → DejaVu Sans Mono → monospace）。
- 全站**只有一个等宽来源**：`athenaMono()`。不要引入第二种等宽字体。

> **历史教训**：早期实现把整个 UI 做成等宽，并因此移除了 `google_fonts`。
> 这是误读——Claude 只有代码与终端用等宽，UI 是比例字体。

### Hierarchy

取值口径：Claude 的 `.cds-root` 默认档是 caption 12 / body 14 / prose 15 /
heading 14；本仓的正文与消息正文取的是它**文字档 small** 解析后的值
（`--cds-font-size-body--textsm` / `--cds-font-size-prose--textsm` = 13），
并用窗口截图的文字总宽反推交叉验证过（侧栏行反推 12.6、消息正文反推 13.0；
按 14 / 15 算都对不上）。标题、标签、说明仍按默认档。

| Role | Token | Size | Line height | Weight | Font | Usage |
|------|-------|------|-------------|--------|------|-------|
| Hero | `AthenaFontSize.hero` | 22 | — | 600 | UI | 空态欢迎大标题 |
| Page / Dialog Title | `AthenaFontSize.title` | 15 | — | 600 | UI | 对话框、页面标题（`--cds-font-size-heading--textlg`） |
| Section Title | `AthenaFontSize.section` | 14 | — | 500-600 | UI | 分区标题、卡片标题（`--cds-font-size-heading`） |
| Prose | `AthenaFontSize.prose` | 13 | **20**（`proseHeight`） | 400 | UI | **消息正文（Markdown）**（`--cds-font-size-prose--textsm` / `--cds-leading-prose`） |
| Body | `AthenaFontSize.body` | 13 | **19**（`bodyHeight`） | 400 | UI | 正文、输入框、**侧栏行**（`--cds-font-size-body--textsm` / `--cds-leading-body`） |
| Label | `AthenaFontSize.label` | 12 | — | 400-600 | UI | 标签、chip、小按钮 |
| Caption | `AthenaFontSize.caption` | 12 | — | 400 | UI | 元信息、分组标题（`--cds-font-size-caption`） |
| Mono | `AthenaFontSize.mono` | 12 | — | 400 | Mono | 代码、工具参数、输出（`--cds-font-size-code`） |

| Row | `AthenaFontSize.row` | 14 | — | 400 | UI | 菜单条目、选择器行、设置行（Claude 默认档 body） |

`row` 与 `section` 同号不同角色：`section` 是加粗的标题，`row` 是常规字重的行文字。

**调用方不直接拼 `TextStyle`**，而是取 `AthenaTextStyle` 的预设再补颜色：

```dart
Text(title, style: AthenaTextStyle.section.copyWith(color: colors.textPrimary));
```

| 预设 | 字号 / 字重 | 行盒 |
|------|------------|------|
| `AthenaTextStyle.hero` | 22 / w600 | — |
| `AthenaTextStyle.title` | 15 / w600 | — |
| `AthenaTextStyle.section` | 14 / w500 | — |
| `AthenaTextStyle.row` | 14 / w400 | — |
| `AthenaTextStyle.prose` | 13 / w400 | **20**（烧进预设） |
| `AthenaTextStyle.body` | 13 / w400 | 不带；多行时加 `height: AthenaFontSize.bodyHeight` |
| `AthenaTextStyle.label` | 12 / w500 | — |
| `AthenaTextStyle.caption` | 12 / w400 | — |
| `athenaMono()` | 12 / w400 | — |

字重与预设不同时用 `copyWith(fontWeight:)` 覆盖；行高只有 `prose` 烧进预设（它
一定是多行正文），`body` 多数时候是单行控件文字，多行时再显式给 `bodyHeight`。

**主字号表没有 16 与 20 这两档**。曾经的 16（移动端列表标题）归入 `section`，
20（移动端页标题、桌面表单对话框标题）归入 `title`、页内的分区标题归入 `section`，
24（移动端首页大标题）归入 `hero`——层级靠字重与灰度，不靠再多一档字号。全仓只剩两处字面量字号，都不是
文字档位：空态头像里的 emoji 字形（26）与脚注 / 引用徽标的字形（10）。

设置面板的字号（`AthenaSettings.navFontSize` / `rowFontSize` / `controlFontSize` 等）
都是主字号表的别名（`row` / `body` / `label` / `caption`）；唯一的例外是分区标题
`headingFontSize` = 16，它是设置面板独有的实测值。

**本仓把 UI 正文与消息正文拉平成同一号（都是 13）**。Claude 有意让消息比界面
大一号（默认档 14 / 15），但侧栏与工作区字号不一致会让界面读起来像两个层级，
故不跟这条。行高是**绝对行盒**（prose 20 / body 19），不是随字号缩放的比例；
`proseHeight` / `bodyHeight` 是换算后的比值。

**密度口径**：Claude 桌面端 `index.html` 的 `<html>` 带
`data-density="comfortable"`，该档比默认档整体大一档（body 14→15、
caption 12→13、radius 6→8、icon 16→24）。本仓不跟 comfortable 档——圆角、图标、
控件高都按默认档铺满全仓，整体切换是另一件事。

**列表行用 Body，不是 Label**：侧栏会话行取 `AthenaFontSize.body`（13），设置页
各行取 `AthenaSettings.rowFontSize`（14）。实测 Claude 的侧栏会话行与消息正文
同号；用 Label 12 会让侧栏比工作区小一整号，看上去像两个不同层级的界面。
`label` 只留给 chip、小按钮、工具卡这类真正的"控件标签"。

### Principles

- 层级靠**字重 + 灰度**，不靠字号。只有空态欢迎语明显放大。
- 技术信息（工具名、参数、输出）要保持"技术感"，但不能抢正文的视觉中心。
- 工具**名**用 UI 字体（w600），工具**参数 / 输出**用等宽。

---

### Font Size Setting（字号档位）

设置 → Advanced → Appearance 里的 **Font size**（Small / Medium / Large），
对应 `AthenaTextSize`（0.85 / 1.0 / 1.15），默认 Medium；Claude 桌面端在同一个
位置也有一档文字大小设置，这里与它同形。移动端在设置 → Appearance 弹层里给同
三档（`Small / Medium / Large text`）。

机制是**在应用根部叠一层 `TextScaler`**（`main.dart` 的 `applyTextSize`），
而不是把 token 值改成动态的——这样全站文字（UI、正文、Markdown、代码、输入框）
一次性生效，调用点一处都不用改。它**乘在系统无障碍缩放之上**，不覆盖系统设置
（按正文号取等效系数再相乘，因为系统缩放在 Android 14+ 是非线性的）。

**只缩放字号，不动几何**。1.15 倍下所有含文字的固定高度都仍有余量：侧栏行
26 / 字号 13、设置导航行 32 / 字号 14、列表行 40 / 字号 14、分段控件与输入框
32、composer 上下文条 40、顶栏 46。**注意**：若以后把档位拉大到 ~1.3，这些固定
高度会先顶不住，届时要改成"字号与几何一起缩放"（Claude 的 `data-density` 正是
两者一起动）。

## 4. Component Stylings

### Buttons

**Primary CTA**
- Background: `surfaceRaised`（浅色=近黑，深色=白）
- Text: `textOnRaised`，`label` 12 / w600
- Shape: `AthenaRadius.control`（7）
- Padding: `horizontal 16, vertical 10`
- Hover: 填充向画布色混入 12%
- Disabled: `surfaceButtonSecondary` 底 + `textSecondary` 字

**Secondary Button**
- Background: transparent
- Border: `1px solid border`
- Text: `textPrimary`，`label` 12 / w500
- Shape: `AthenaRadius.control`（7）
- Hover: 底 `surfaceHover` + 边框提亮到 `borderStrong`

**Icon Button**
- Background: `surfaceRaised`
- Icon: `iconOnRaised` 16，内边距 12
- Shape: `AthenaRadius.control`（7），不是圆形

**Ghost Icon Button**（`AthenaGhostIconButton`）
- 静止无底无边；hover 填充前景色 5%（Claude 的 `--cds-fill-ghost-hover`）
- 盒 28、图标 14、圆角 `row`（7）；图标色 `textRowLabel`
- 用于设置面板的关闭 / 新增键与桌面对话框的关闭键

**Send Button**
- 桌面（composer 输入容器右端内部）：22×22 的 ghost 图标按钮，无填充无描边，
  图标 16 取 `accent`，hover 前景色 5%，按下 `scale(.975)`。这是桌面端 `accent`
  作为实色出现的唯一位置
- 移动端：`accent` 实心胶囊 + 白色图标 16——全站唯一一处彩色实心块

### Inputs

**Canonical Input Style**
- Background: `inputBackground`
- Border: `1px solid border`（聚焦提亮到 `borderStrong`）
- Radius: `AthenaRadius.control`（7）
- 字号 `body` 13
- Padding: `horizontal 12, vertical 10`
- 聚焦不出现焦点环、不出现光晕。

**Composer（版式取自 Claude 桌面端）**

版式取自 Claude 桌面端：两个**独立的圆角容器**上下堆叠（上下文条 + 输入框），
控制项排在容器**外面**单独一行。

- **上下文条**（上容器）：`surfaceButtonSecondary` 灰底、**无描边**、
  圆角 `container`（10）、高 40，放当前 Sentinel 与工作文件夹 chip
- 间距 **5**
- **输入容器**（下容器）：**纯白**（`surfaceMobile`）底 + 1px **中性灰**描边
  （常态 `neutralBorder`、聚焦 `neutralBorderStrong`，见 §2「白底上的中性灰」）、
  圆角 `container`（10），含输入区与右端的发送键
- 间距 **4**
- **容器外的一行**：左（配置、图片），右（模型、推理强度、token 指示）
- 上下文条不带阴影；输入容器带一层**向下偏移的柔投影**（见下），是全站唯一
  "描边 + 阴影"并用的容器
- 桌面居中，宽 **768**（`kChatColumnWidth`），两侧最少留 32，底部留白 **12**
- 实测（与 Claude 逐项对齐）：
  - 上容器高 **40**、内边距水平 **6**（加上 chip 自身 10，布局内缩 16，与 Claude 的 17 同档。
    两边的「首个墨迹」不能直接比，因为图标字形的留白不同）
  - 间距 **5**
  - 输入容器高 **44**、**纯白**底，边框**随焦点切换**：
    常态 `neutralBorder`（实测 `#E1E1E0`）→ 聚焦 `neutralBorderStrong`（`#BFBFBE`）。
    两个值都是中性灰，本仓的 `border` / `borderStrong` 属暖灰系，白底上会偏黄。
    Claude 的 CSS 里对应 `focus:border-[...]` 效用类
  - 输入容器下方还有一层**向下偏移的柔投影**（`0x0C000000`、blur 20、offset `(0,4)`）：
    紧贴下边框处比画布暗约 **7/255**，约 **18 逻辑**内平滑衰减到 0，上方几乎没有。
    这是"下边框看起来比上边框深"的真正原因，不是第二条边框色
  - 占位符距容器左缘 **10**，颜色是**浅灰 `#898782`**（`gray-400` = 本仓 `textWeak`）。
    不要把光标误当占位符：聚焦时占位符左侧会有一条深色 caret，按"首个墨迹"取值
    会得到 caret 的颜色
  - 间距 **4**
  - 容器外那一行总高约 **34**（控件高约 24）、底部留白 **12**
  - 两个容器与容器的左右边界都在逻辑 408..1176，即宽 **768**

- **容器外那一行不用任何填充或描边**（Claude 的语言是「文字 + 细线」）：
  - 左：一段**纯文字**（`Configure`，图标 16 + 文字 13，无框无底）+ 一个裸图标（图片）
  - 右：**纯文字**模型名（只显示模型名，不带 provider、不带图标）、推理强度
    （与模型名同字号、**常规字重**）、细线圆环（上下文占用）
  - **发送/停止键在输入容器的右端内部**（Claude 的位置），不在容器外那一行
  - 容器外那一行最右是上下文圆环：hover 只给一句深色 tooltip（`surfaceRaised`
    底 + `textOnRaised` 字，`Context 181.6k / 1M (18%)`），点击才在圆环上方弹出
    右对齐的明细面板（浮层样式同菜单）：标题行 + 6 高分段占用条（缓存命中
    `accent` / 未命中 `textSecondary` / 剩余 `border`）+ 三行图例。只看上下文，
    不统计会话累计用量
  - 控件状态（取自 Claude CSS）：
    - hover：ghost 填充 = **前景色 5%**（暗色 7.5%），圆角 4
    - 按下：`scale(.975)`，按下 60ms 快档、回弹 200ms 带弹簧
    - 输入框聚焦：**不加焦点环**，容器边框保持不变（Claude 的 `.cds-input:focus`
      只清 box-shadow，`:focus-visible` 才加 1px accent + 6px 辉光；composer 的
      编辑器没有焦点规则）
  - **控件阶梯**（Claude 的 `[data-step=1..5]`，实测）：
    `radius / control 高 / 嵌套高` = `5/20/16`、`6/24/18`、`7/28/20`、`8/32/22`、`10/40/28`。
    容器内的嵌套按钮取 `嵌套高`，圆角为 `radius − (control − 嵌套高)/2`
  - 容器内按钮**不是圆形**，是圆角 3–4 的小方块
  - 这一行所有图标 16、文字 13（`AthenaFontSize.body`）、统一 `textPrimary`
  - 模型名与推理强度之间 4，推理强度与圆环之间 12（Claude 实测约 20）

- 桌面端 `Enter` 发送、`Shift+Enter` 换行；小键盘 Enter 同样发送

### Chips

**AthenaTag / AthenaTagButton**（筛选类）
- Shape: `pill`
- Border: `1px solid border`
- Unselected: `surfaceDeep` 底 + `textSecondary` 字
- Selected: `surfaceSelected` 底 + `textPrimary` 字 + `w600`
- Hover: `surfaceHover` 底 + `borderStrong` 边框

**AthenaContextChip**（composer 上下文条上的项）
- Shape: `AthenaRadius.xs` = **4**（**不是胶囊**）。上下文条是容器（`_SquishButton` 的
  hover 底同样是 `xs`），条内的可点控件取嵌套档的小方块——与 Claude 的
  `[data-step]` 阶梯一致（容器内按钮取嵌套高、圆角 3–4 的小方块）。
- `filled: false`（默认使用）：**完全不画底色**——它坐在已经是浅灰的上下文条上，
  再画一层同色底就成了"看不见的胶囊"。Claude 的上下文项就是条上直接排的文字 + 图标。
  操作行里单独出现的模型名也用 `filled: false`，与 Claude 桌面端的
  底部模型文字一致（不画底）。
- `filled: true` 用于带外单独出现的场景
- 左侧可选 13px 图标；文字 `textSecondary`
- `trailing`（如清除按钮）：**静止透明、hover 才显形**（与消息操作条同一条规则），
  进入用 `AnimatedOpacity` 120ms；占位始终保留（不摘控件），否则 hover 进出会让
  chip 宽度跳；不可见时同时 `IgnorePointer`，免得点到看不见的叉。
- Hover: **前景色 5% 的 alpha 叠加层**（`textPrimary.withValues(alpha: 0.05)`），
  不是固定灰。上下文带的底色就是 `surfaceButtonSecondary`，而表面状态灰在浅色下
  几乎与它同值——`surfaceHover` 与它完全相同，`surfaceSelected` 只深 3/255
  （`#F0EFEC` → `#EDECE9`），落在带上 hover 等于没有反馈。
  合成像素：浅色 `#F0EFEC` → `#E5E4E1`（Δ11），深色 `#2C2C2A` → `#363634`（Δ10）。
  这与 Claude「hover 中的 chip」同档：它的 chip 静止 `bg-neutral-chip` =
  neutral-900 的 5%（`#F0F0EF`，等于本仓的条底色）、hover `bg-neutral-chip-hover`
  = 10%（`#E4E4E3`）。`filled: true` 的 chip 把叠加层合成到自己的底色上
  （`Color.alphaBlend`），静止与 hover 都保持不透明，避免插值中途出现半透明深色。

**原则**：容器内（composer）的 chip 不画边、用嵌套档小圆角（4）；独立出现的筛选
chip 画边、用胶囊。上下文条上两个 chip（Sentinel、工作文件夹）都能**清除**：
清掉 Sentinel 就是「不使用 Sentinel」（`ChatEntity.noSentinelId`），chip 显示
`No Sentinel` 且不再出现清除按钮；清掉文件夹则显示 `No folder`。

### Switch / Toggle

- Track: `34 × 18`，圆角 7（`inline` + 2）
- Knob: `12 × 12` 圆形，`switchKnob`
- On: `statusSuccess`
- Off: `switchTrackOff`
- Duration: `120ms`

### Checkbox

- 尺寸 `16 × 16`，圆角 `inline`（5）
- 选中：`surfaceRaised` 实心 + `iconOnRaised` 勾
- 未选中：`checkboxOff` 描边

### Dialogs & Sheets

**Desktop Dialog**（`AthenaDesktopDialog`）
- Background: `surfaceMobile`
- Radius: `AthenaRadius.panel`（12）
- Shadow: `AthenaShadow.overlay`
- Width: `min 320 / max 520`
- Padding: 24
- Title: `title` 15 / w600，右端可选 ghost 关闭键；正文 `body` 13、`textSecondary`
- 确认 / 输入对话框与设置里的四个表单对话框都从它派生，不要再各自画容器

**Mobile Sheet**
- Background: `surfaceMobile`
- Padding: `horizontal 20, vertical 16`
- 按钮全宽、圆角 `control`（7）

**Toast / Message Overlay**
- Background: `surfaceMobile`
- Radius: `container`（10）；**无阴影**，只有 1px 描边
- 边框取语义色 40% 透明度（仅用于提示，不用于常规面板）

### Cards & Surfaces

- 对话框、菜单这类浮层用**柔阴影**（`AthenaShadow.overlay`），不用硬描边。
- composer 输入容器是例外：1px 中性灰描边 + 一层向下的柔投影并用（见 §4 Composer）。
- 引用块只有**左侧 1px `border` 竖线**，无底色；代码块**不描边**——它靠 `codeBackground` 与页面底色的差自成一层，header 再用 `cardHeader` 提亮一档划分标题与正文。
- 会话内的权限审批卡与提问卡是浅色面板（`surfaceMobile` + `overlay` 阴影）。
- 助手消息不画底板，直接坐在画布上。

### Sidebar Row（Claude 实测）

- 行高 **26**（**固定高度**，不要靠垂直内边距撑），左右内缩各 **8**，圆角 `row`（7）。
  hover 才出现的 `⋮` 高 20，比标签的行盒（约 17）高；靠内容撑会把整行顶高，
  表现为"hover 上去整行变高"
- **leading 是状态点**（直径 6），不是图标：静止 `iconSecondary` @45%，
  hover 加深到 @75%；运行中用 `accent`，固定用 `textRowLabel`
- **尾部静止时为空**，hover 才出现一个 `⋮` 按钮（`iconSecondary`，14px）。
  旧版把图钉 / 进度圈常驻在行尾，与 Claude 不符
- 标签用 `textRowLabel`（`#52514E`），**hover 不变色**——只有底色变

### Message Actions（消息操作条，Claude 实测）

Claude 的操作条**不在消息右侧**，而是排在**正文下方**；静止时全透明，
指针进入**整条消息行**才淡入。助手消息与用户消息用同一套。

- **位置**：助手消息排在卡片最后一段的正下方、与正文左对齐；用户消息排在
  气泡正下方、跟气泡一起右对齐。它**常驻占位**（`AnimatedOpacity`，不是
  `Visibility`），所以卡片高度不随 hover 变化，正文宽度也不会被挤压。
- **不要为了操作条在正文右侧预留空白**。它已经不在右侧了，再留一条内缩只会
  让整块正文看着没对齐列宽。
- **显形条件**：整行 hover（`.group/message-row:hover [data-cds=MessageActions]`），
  不是指针压到按钮才显形。**但尚未结束的那一轮的助手消息是例外**：`loading` 期间，
  最后一条用户消息之后的那张助手卡不显形——这一轮还在跑，Copy 只能拿到半截正文，
  收尾后才恢复。**用户消息不受影响**（它照常 hover 显形），上一轮及更早的助手卡
  也不受影响。`loading` 期间仍保留占位高度（`visible: false`，不要把控件摘掉），
  否则收尾瞬间卡片高度变 28、末尾跳一下。
- **时序**：**只动 `opacity`**——`--cds-message-actions-reveal-scale` 在
  `.cds-root` 上是 `none`，不要加缩放。进入用 `--cds-dur-snap`(120ms) 且延迟
  `--cds-message-actions-reveal-in-delay`(100ms)；退出用 `--cds-dur-fast`(60ms)
  且无延迟。
- **按钮**：ghost 图标按钮，控件高 24（`--cds-h-control`）、图标 16
  （`--cds-icon`）、圆角 7（`--cds-radius--lg`），hover 填充
  `--cds-fill-ghost-hover`（浅色 alpha-1 ≈ 5%）。

### Menus（右键 / 弹出）

- 面板：`surfaceMobile` 白底 + `AthenaShadow.overlay`（无描边），圆角 `menu`（12），内边距 4
- 条目：高约 **32**（内边距 12 × 7），文字 14，圆角 `row`（7）
- 分组之间用 `DesktopContextMenuSeparator`（1px `border`，上下间距 4）
- 危险项（Delete）用 `dangerText`（浅色 `#832F2B`，比 `statusError` 更深）

### Settings Panel（设置面板，Claude 实测）

桌面端设置是 **Claude 桌面端设置面板的复刻**。数值来自对 Claude 设置窗口的整窗
截图实测（1296×783 逻辑窗口、2× Retina，按像素量取后折半）；该截图对本仓色板是
**色彩准确**的（画布量到 `#FCFCFB`、内容区量到 `#FFFFFF`、分组标题量到
`#898781`，与既有 token 一致）。几何在 `theme/athena_settings.dart` 的
`AthenaSettings`；颜色取 `AthenaColors` 的 `neutral*` 组（§2）与既有 token，
面板没有自己的色板。

- **居中浮层**：宽 `min(1024, 可用宽 − 64)`、高 `可用高 − 88`（实测 1026×695，
  上下各留 44）、圆角 12；外圈阴影**很窄**（约 10px 内衰减完），不是 overlay
  那种大范围投影。设置路由是**非透明路由**（`DesktopRoute(opaque: false)`），
  所以面板浮在应用之上，背后看得见会话。
- **遮罩**：画布压 40% 黑（实测面板外 `#979795` = `#FCFCFB × 0.6`），只吸收
  点击、**不关闭面板**——设置行有显式 Save，误触会丢未保存的编辑。关闭走右上角
  的 ghost X（14，内缩 15）或 Esc。
- **左栏 192**：底色 `surfacePanel` + 右侧 1px `neutralBorder`。自上而下：**搜索框**
  （高 32、圆角 8、底 `surfaceMobile`、描边 `neutralBorder`、图标与占位 `textWeak`）→
  **分组标题**（`caption` 12、`textWeak`，与行的图标列对齐，上方 28、下方 13）→
  **图标行**（高 32、圆角 8、左内缩 12、图标 16、图标与标签间距 12、标签 `row` 14；
  静止字 `textRowLabel`，hover 底 `neutralRule`，选中底 `neutralSelected` + `textPrimary`）。
- **右栏内容区**：**纯白**底、左右内边距 24；分区标题 16/600、其下 28。
  行是「标签 + 说明」在左、**控件在右**，上下内边距 16（行高约 69）；标签与说明
  **同号 14**（实测大写高都是 10.0），标签半粗近黑、说明常规 `textWeak`。行间是
  1px `neutralRule` 发丝线，只跨内容区的左右内边距。
- **分段控件**：轨道 `neutralRule`**无描边**、高 32、圆角 8；选中块是
  **`neutralControlFill` 填充 + 1px `neutralBorder` 描边**且**铺满轨道高**；
  选中 12 半粗近黑，未选中 12 常规 `textWeak`。
- **下拉**：`neutralControlFill` 底 + 1px `neutralBorder` + 高 32 + 圆角 8 + 右端 chevron。
- **二阶导航在 Claude 里不存在**：Claude 的一个导航项对应**同一内容区里的多个
  分区**（它的 Claude Code 下面是 Code appearance + Appearance）。所以 Agent 的
  General/Tools、Advanced 的 Appearance/Data、Default Model 的三个模型都改成
  **分区标题**，不再有第二列导航。
- **列表类分区**（Provider / Sentinel / Skills / Experiences）保留「列表 + 详情」
  两列，但列表是**内容列表**不是导航：白底、行高 40、行间发丝线、没有圆角选中块，
  靠右侧 1px `neutralBorder` 与详情分开。

**为什么用中性灰**：Claude 的设置面板用一组**中性灰**，而 `AthenaColors` 的暖灰
（`divider` `#E1E0D9` 等）铺在纯白面板上会偏黄。这组灰与 composer 输入容器共用，
定义在 §2「白底上的中性灰」，面板自己不再持有色板。

**已知偏差**：设置里的文本输入仍用 canonical `AthenaInput`（高约 40、描边
`#E1E0D9`、13 号），而 Claude 的设置控件是 32 高、`#E6E6E6`、14 号。理由是全站
只保留一个输入样式，不为设置页再引入一套；含输入的行因此比 Claude 高约 3px。

### Component Coverage Rules

- 所有主路径操作按钮必须从 **Primary CTA** 派生。
- 所有筛选 chip 从 **AthenaTag** 派生；composer 内 chip 从 **AthenaContextChip** 派生。
- 所有文本输入从 **Canonical Input Style** 派生；会话输入必须用 **Composer**。
- 所有桌面模态必须从 **`AthenaDesktopDialog`** 派生。
- 移动端网格里的实体卡（Skill / Sentinel / Experience）从 **`MobileGridTile`** 派生。
- 所有文字样式从 **`AthenaTextStyle`** 预设派生；等宽走 `athenaMono()`。

### Allowed Exceptions

- 工具执行中的标题可以有一条流动 shimmer 高光。
- macOS 窗口控制灯保持系统样式；头像保持圆形。
- 例外组件只能弱化 Claude 语言，不能创造第二套语言。

---

## 5. Layout Principles

### Spacing System

| Token | Value | Usage |
|-------|-------|-------|
| `AthenaSpace.xs` | 4 | 微调 |
| `AthenaSpace.sm` | 8 | 紧凑控件间距 |
| `AthenaSpace.md` | 12 | 常规模块内间距 |
| `AthenaSpace.lg` | 16 | 页面常规留白 |
| `AthenaSpace.xl` | 20 | 面板内边距 |
| `AthenaSpace.xxl` | 24 | 对话框内边距 |
| `AthenaSpace.xxxl` | 32 | 桌面工作区留白 |
| `AthenaSpace.sidebar` | 288 | 桌面左侧栏宽度 |

### Grid & Density

- 保持 **高密度工具界面**：紧凑但不拥挤。
- 不走营销网站的大留白路线。

### Desktop Layout

实测值（参考侧为窗口像素量取）：

| 项 | 值 |
|----|-----|
| 侧栏宽 | **288**（实测：分界线在逻辑 287） |
| 侧栏行 | 高 **26**（垂直内边距 4）、左右内缩各 **8**、图标起于行内 **11**、文字起于 **30** |
| 会话列宽 | **768** = `kChatColumnWidth`；消息列与 composer 同宽并居中，左右对齐。注意 Claude 的 composer 实测约 810，是本仓保留 768 的已知偏差 |
| Composer 高 | 约 127（上下文条 40 + 5 + 输入容器 44 + 4 + 容器外一行 34） |
| Composer 底距 | 12（两侧最少留 32） |
| 顶栏 | 只有侧栏那一段是 `surfacePanel`，画布上方透明；内含会话标题 |

- 侧栏底色 `surfacePanel`，与画布以 1px `borderChrome` 分开（见 §5 的 `borderChrome`）
- 顶栏**有会话标题**（Claude 的顶栏不是空的）：左侧是窗口控制，中间是当前会话标题。
  Athena 没有导航箭头与右面板，所以只保留标题
- 顶栏实测：高 **46 逻辑**，底色与画布相同（相当于透明），底边是一条**极浅**的线
  `neutralHairline`（`#F7F7F7`，只比画布暗 5/255）——它是顶栏唯一的轮廓
- **顶栏底线只画在工作区那一段**（x ≥ 288）：侧栏上方是侧栏面板的延伸，不画横线，
  否则这条线会横穿侧栏右边线。顶栏里的侧栏条本身**满高 0..46**，它的右边线才是
  与下方侧栏右边线相接的同一段竖线（`AthenaAppBar` 里的 `sidebarStrip` /
  `workspaceStrip`，外层 `CrossAxisAlignment.stretch`）
- 侧栏内容：分组列表（Pinned / Chats）+ 底部页脚。页脚是一整行可点的应用标识
  （标识 + 名称 + 下拉箭头，行高 32、圆角 `row`，hover 与展开中上 `surfaceHover`），
  点击在行上方 4 处弹出与行同宽的菜单：头部「应用名 + 版本」，条目 Settings /
  About Athena（带 16 图标）；面板样式同右键菜单
- **会话列定宽居中**：消息与 composer 走同一条 768 宽的列（`chatColumnPadding()`
  按画布宽度算两侧留白），左右边缘对齐；画布不够宽时退回 32 的最小留白
- **消息不带头像**（Claude 的对话渲染里没有头像元素）
- **用户消息是右对齐的浅灰气泡**：前景色 5% 填充、圆角 8、内边距 12×8、
  最宽为列宽的 77%
- **助手消息没有气泡**：内容直接铺满列宽
- 结构：侧栏 → 顶栏 → 主内容区 → 底部 composer

### Mobile Layout

- Horizontal padding: `16px`
- 单列，`surfaceMobile` 底；composer 是**单个浮起容器**（`surface` 底、圆角
  `composer` 12、`AthenaShadow.raised`、内边距 12），不是桌面的双容器版式

### Border Radius Scale

取自 Claude 的 `--cds-radius-*`：最小档 5，
控件档 7，**composer 也只有 12**，没有 20/24 这种大圆角。

| Claude 变量 | 值 | 本仓 token | 组件 |
|-----------|-----|-----------|------|
| `--cds-radius` | 4 | `xs` | 极小元素 |
| `--cds-radius--sm` / `--xs` | 5 | `inline` | 徽标、行内代码、勾选框 |
| `--cds-radius--lg` | 7 | `row` / `control` | 列表行、按钮、输入框 |
| （卡片 / 面板） | 10 | `container` | 卡片、代码块、桌面 composer 的两个容器 |
| `--cds-radius-composer` | 12 | `panel` / `menu` / `composer` | 对话框、菜单、移动端 composer |
| `--radius-full` | 9999 | `pill` | chip、发送按钮、头像 |

### Page Archetypes

**Desktop Chat Workspace**
- 分区：侧栏列表、顶栏标题、主内容区、底部 composer
- 主内容区最安静；composer 是视觉重心（白底描边 + 向下柔投影）
- 空态是居中大标题 + 胶囊标签

**Settings / Configuration**
- 工具化、列表化、表单化布局
- 强调清晰层级，不强调装饰性卡片堆叠

---

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Canvas | `surface`，无阴影无边框 | 主工作区 |
| Panel | `surfacePanel` + 1px `borderChrome` | 侧栏、顶栏 |
| Quote | 左侧 1px `border` 竖线，无底色 | 引用块 |
| Code block | `codeBackground`，header 为 `cardHeader`，**无边框** | 代码块、脚注区 |
| Selected | `surfaceSelected` | 选中行、选中 chip |
| Hover | `surfaceHover` | 悬停行 |
| **Floating (mobile)** | `surface` + `AthenaShadow.raised` | 移动端 composer |
| **Floating (desktop)** | `surfaceMobile` + 1px `neutralBorder` + 向下柔投影 | 桌面 composer 输入容器 |
| **Overlay** | `surfaceMobile` + `AthenaShadow.overlay` | 对话框、菜单 |

### Principles

- **静态容器用边框，浮起容器用阴影**——这是本体系最重要的一条分工。
- 不要给静态卡片加阴影，也不要给对话框 / 菜单加硬描边
  （composer 输入容器的"描边 + 柔投影"是唯一的例外）。
- 真正的视觉焦点应当很少，这样它们才有力量。

---

## 7. Do's and Don'ts

### Do

- 用暖白 `#FCFCFB`（浅色）/ `#1A1A19`（深色）作为主画布
- 用系统字体承载 UI 与正文，等宽只给代码
- 用柔阴影表达"浮起"，用淡边框表达"分隔"
- 主操作用"画布的反色块"（`surfaceRaised`）；`accent` 只给发送键与运行中状态点
- 筛选 chip 是胶囊；composer 上下文条内的 chip 是圆角 4 的小方块，不画边不画底
- 保持高密度，紧凑但不拥挤

### Don't

- 不要使用纯黑画布
- 不要把整个 UI 做成等宽字体
- 不要引入渐变边框、发光、光晕
- 不要给静态卡片加阴影，也不要给对话框 / 菜单加硬描边
- 不要新增彩色；`accent` 之外只允许功能语义色
- 不要新增圆角等级
- 不要使用默认 Material 风格白底输入框或系统原生弹窗视觉

---

## 8. Responsive Behavior

### Shared Language, Different Shell

- **视觉语言一致**，**交互壳层适配平台**。
- 桌面和移动可以有不同的布局与容器形式，但不能有不同视觉人格。

### Desktop

- 白底工作台 + `surfacePanel` 侧栏与顶栏
- 分栏、长时间停留、信息并行
- 对话框居中浮层
- Composer 居中，宽 768（`kChatColumnWidth`），两侧最少留 32

### Mobile

- 单列，`surfaceMobile` 背景
- bottom sheet 代替大多数模态居中弹窗
- Composer 是单个浮起容器（见 §5 Mobile Layout）

### Motion & State Principles

- 所有交互动效服务于"状态确认"，而不是炫技。
- hover 只做轻微强调，不改变组件类型。
- 时长：hover / 选中 `120-150ms`，开关 `120ms`。

---

## 9. Agent Prompt Guide

本节是给 Agent 的速查摘要，数值与 §2–§6 及 `theme/` 代码一致；两者冲突时以
代码为准，并回来修这里。

### Athena Visual Summary

- Claude-desktop-derived AI workspace
- Light-first: warm white canvas (`#FCFCFB`), `#FBFBF9` sidebar, `#E1E0D9`
  container borders, `#EFEFED` chrome seams
- **System UI font**; monospace (`athenaMono()`) only for code, inline code,
  tool args and output
- Body and prose are both 13 with fixed line boxes (19 / 20); titles 15,
  section headings 14, labels and captions 12
- Radii 4 / 5 / 7 / 10 / 12 (`AthenaRadius.xs / inline / control / container /
  panel`); pills only for filter chips, the mobile send button and avatars
- Static containers use hairline borders; dialogs and menus use
  `AthenaShadow.overlay`
- One chromatic accent: `#2A78D6` (dark `#5598E7`)
- Calm, technical, high-density, non-marketing, non-social

### Quick Color Reference

| Use | Light | Dark |
|-----|-------|------|
| Canvas (`surface`) | `#FCFCFB` | `#1A1A19` |
| Sidebar / app bar (`surfacePanel`) | `#FBFBF9` | `#151515` |
| Dialog / menu / composer input (`surfaceMobile`) | `#FFFFFF` | `#1E1E1D` |
| Container border (`border`) | `#E1E0D9` | `#2C2C2A` |
| Chrome seam (`borderChrome`) | `#EFEFED` | `#212121` |
| Hover row (`surfaceHover`) | `#F0EFEC` | `#2C2C2A` |
| Selected row (`surfaceSelected`) | `#EDECE9` | `#383835` |
| Primary text (`textPrimary`) | `#0B0B0B` | `#F6F6F4` |
| Secondary text (`textSecondary`) | `#6D6B67` | `#A5A49A` |
| Weak text (`textWeak`) | `#898781` | `#898781` |
| Accent (`accent`) | `#2A78D6` | `#5598E7` |

### Prompt Fragments

**For the Athena Composer (desktop)**
"Build a chat composer as TWO stacked rounded containers, 768 wide, centered,
12 above the window bottom. Top: a 40-high context bar with `#F0EFEC` fill, no
border, 10 radius, holding the Sentinel and workspace chips as bare text plus
13px icons (4 radius, no fill, no border). 5 below it, the input container:
pure white fill, 1px `#E4E4E3` border (`#BFBFBE` when focused), 10 radius, a
soft downward shadow (`0x0C000000`, blur 20, offset 0/4), and a 22×22 ghost
send button at its right end whose icon is `#2A78D6`. 4 below, a bare row:
`Configure` and an image icon on the left, model name / reasoning effort /
token ring on the right, all 13px text and 16px icons, no fills, no borders."

**For Athena Chips**
"Filter chips are pills: 1px `#E1E0D9` border, `#F3F3F0` fill, `#6D6B67` 12px
system-font label; selected is `#EDECE9` fill, `#C3C2B7` border and `#0B0B0B`
w600 text. Chips inside the composer context bar are NOT pills: 4 radius, no
border, no fill; hover adds a 5% foreground overlay. No gradient, no glow."

**For Athena Code Block**
"Build a code block: `#F6F6F4` fill, NO border, 10 radius, a `#F0EFEC` header
strip carrying the language label and a copy button, and `#20201F` 12px
monospace body text. Code is the only monospace in the UI."

**For the Athena Sidebar**
"Build a `#FBFBF9` sidebar, 288 wide, separated from the `#FCFCFB` canvas by a
1px `#EFEFED` line. Rows are 26 high with 7 radius and 13px system-font labels
in `#52514E` that do not change on hover; hover fill `#F0EFEC`, selected fill
`#EDECE9` with w400 text. Leading is a 6px status dot; trailing is empty until
hover reveals a `⋮` button. The footer is one hoverable 32px row (app mark,
name, chevron) that opens a same-width menu above itself: a name/version
header, then Settings and About items with 16px icons."

### Final Instruction to Agents

1. 先保证它像 Claude 桌面端：暖白底、系统字体、克制的圆角、少量阴影。
2. 对话框与菜单用阴影浮起，静态容器用边框——不要混用；composer 输入容器的
   "描边 + 向下柔投影"是唯一的组合体。
3. 等宽只给代码；UI 与正文一律系统字体。
4. 筛选 chip 是胶囊，composer 内的 chip 是圆角 4 的小方块；`#2A78D6` 是唯一的彩色。
5. 桌面与移动共享气质，只改变结构，不改变人格。
6. 不新增颜色、圆角或阴影体系，先从现有 token 派生。
7. 多个方向都合理时，选更克制、更工具化的那个。
