# Design System

## 1. Visual Theme & Atmosphere

Athena 是一个跨平台的 AI 工作台。它的视觉语言基准是 **Claude 桌面端**
（macOS 版，OpenAI）。

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
| 正文字号 | `--cds-font-size-body` | **15**（desktop 的 comfortable 档） |
| 消息正文字号 | `--cds-font-size-prose` | **15**（行高 22） |
| 头像档位 | `--cds-avatar-lg/md/sm/xs` | 36 / 28 / 20 / 16 |

### 核心特征

- **浅色为原生形态**：Claude 默认是暖白底 + 暖灰侧栏。深色是同一体系的镜像。
- **灰阶是暖的**：`--cds-gray-*` 从 `#fff` 到 `#0b0b0b`，白端带黄绿感
  （`#f9f9f7` / `#fcfcfb`），和中性灰一眼能分辨。深色画布取 `#1A1A19`，
  侧栏更暗（`#0F0F0F`），不使用纯黑。
- **UI 用系统字体，等宽只给代码**：Claude 的侧栏、设置、按钮、正文都是比例字体；
  等宽只出现在代码块、行内代码和内置终端。
- **圆角偏大**：可点行 8、容器 12、浮层 16、composer 20、chip 是胶囊。
- **浮起容器带柔阴影**：composer 与浮层不是硬 1px 描边，而是一圈很柔的投影。
- **唯一彩色是强调蓝** `#4E82EF`，用于主要动作 / 语音 / 链接。

Anthena 在 Claude 语言之上的自有取舍：
1. 会话上下文（角色、模型）以 chip 形式内嵌在 composer 顶部；
2. 侧栏页脚承载设置入口（Claude 那里是账号）。

**核心设计理念**
- 背景必须退后，内容和控制区必须前置。
- 层级靠三样东西：灰底提亮、极淡分隔线、柔阴影。不要引入第四种手段。
- 界面应当像"为长时间使用而设计"，而不是为了首屏惊艳。
- 桌面和移动端共享同一套审美语言，只改变结构，不改变人格。

### Priority Rules

1. **先保住"白底 + 系统字体 + 大圆角"的底子**。
2. **再保住克制感**：如果"更强视觉冲击"和"更安静的专业工具感"冲突，选后者。
3. **再考虑层次强化**：优先增加灰度差与柔阴影，而不是新增颜色或特效。
4. **最后才允许局部变化**：新页面可以有新构图，但不能引入第二套视觉人格。

### Forbidden Patterns

- 纯黑画布（`#000000`）
- 全站等宽字体
- 装饰性渐变边框、发光 / 光晕
- 硬 1px 描边代替 composer 的柔阴影
- 大面积单色品牌色；强调色只有 `accent` 一支，且只用于主要动作

---

## 2. Color Palette & Roles

Claude 的色板是一套**偏暖的中性灰**，和 Codex 的中性灰完全不同：白端带一点黄绿
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

### Borders

| Token | Light | Dark |
|-------|-------|------|
| `border` | `#E1E0D9` | `#2C2C2A` |
| `borderStrong` | `#C3C2B7` | `#454442` |
| `divider` | `#E1E0D9` | `#2C2C2A` |

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

### Semantic Principles

- `accent` 是全局唯一彩色，只用于主要动作、语音与链接。
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

取值口径：Claude 的 `.cds-root` **默认档**（不叠加 `data-density=comfortable`
与 `data-text-size`）。实测为 caption 12 / body 14 / prose 15 / heading 14；
早期实现记成 11 / 13 / 13，整体小一档。

| Role | Token | Size | Line height | Weight | Font | Usage |
|------|-------|------|-------------|--------|------|-------|
| Hero | `AthenaFontSize.hero` | 22 | — | 600 | UI | 空态欢迎大标题 |
| Page / Dialog Title | `AthenaFontSize.title` | 15 | — | 600 | UI | 对话框、页面标题（`--cds-font-size-heading--textlg`） |
| Section Title | `AthenaFontSize.section` | 14 | — | 500-600 | UI | 分区标题、卡片标题（`--cds-font-size-heading`） |
| Prose | `AthenaFontSize.prose` | 15 | **22** | 400 | UI | **消息正文（Markdown）**（`--cds-font-size-prose` / `--cds-leading-prose`） |
| Body | `AthenaFontSize.body` | 15 | 22 | 400 | UI | 正文、输入框、**列表行**（`--cds-font-size-body` / `--cds-leading-body`） |
| Label | `AthenaFontSize.label` | 12 | — | 400-600 | UI | 标签、chip、小按钮 |
| Caption | `AthenaFontSize.caption` | 12 | — | 400 | UI | 元信息、分组标题（`--cds-font-size-caption`） |
| Mono | `AthenaFontSize.mono` | 12 | — | 400 | Mono | 代码、工具参数、输出（`--cds-font-size-code`） |

**本仓把正文与消息正文拉平成同一号（都是 15 / 22）**。Claude 有意让消息
比界面大一号（默认档 14/15，comfortable 档 15/18），但侧栏与工作区字号
不一致会让界面读起来像两个层级，故不跟这条。行高是**绝对行盒**（22px），
不是随字号缩放的比例；`proseHeight` / `bodyHeight` 是换算后的比值 ≈ 1.4667。

**密度口径**：Claude 桌面端 `index.html` 的 `<html>` 带
`data-density="comfortable"`，该档比默认档整体大一档（body 14→15、
caption 12→13、radius 6→8、icon 16→24）。本仓只取 body 的 15，其余仍按
默认档——圆角、图标、控件高已经按默认档铺满全仓，整体切换是另一件事。

**列表行（侧栏会话、设置页各行）用 Body 14，不是 Label 12**。实测 Claude 的
侧栏会话行与消息正文只差 1px；用 Label 会让侧栏比工作区小一整号，看上去像
两个不同层级的界面。`label` 只留给 chip、小按钮、工具卡这类真正的"控件标签"。
一并注意行高：Body 的行盒是 20（`AthenaFontSize.bodyHeight`）。

### Principles

- 层级靠**字重 + 灰度**，不靠字号。只有空态欢迎语明显放大。
- 技术信息（工具名、参数、输出）要保持"技术感"，但不能抢正文的视觉中心。
- 工具**名**用 UI 字体（w600），工具**参数 / 输出**用等宽。

---

## 4. Component Stylings

### Buttons

**Primary CTA**
- Background: `surfaceRaised`（浅色=近黑，深色=白）
- Text: `textOnRaised`
- Shape: `BorderRadius.circular(8)`
- Padding: `horizontal 16, vertical 10`
- Hover: 填充向画布色混入 12%
- Disabled: `surfaceButtonSecondary` 底 + `textSecondary` 字

**Secondary Button**
- Background: transparent
- Border: `1px solid border`
- Text: `textPrimary`
- Shape: `8`
- Hover: 底 `surfaceHover` + 边框提亮到 `borderStrong`

**Icon Button**
- Background: `surfaceRaised`
- Icon: `iconOnRaised`
- Shape: `8`（不是圆形，除非是头像或语音按钮）

**Send / Voice Button**
- Background: `accent`
- Icon: 白色
- Shape: `pill`（圆形）
- 全站唯一一处彩色实心块。

### Inputs

**Canonical Input Style**
- Background: `inputBackground`
- Border: `1px solid border`（聚焦提亮到 `borderStrong`）
- Radius: 8
- Padding: `horizontal 12, vertical 10`
- 聚焦不出现焦点环、不出现光晕。

**Composer（版式取自 Claude 桌面端）**

版式取自 Claude 桌面端：两个**独立的圆角容器**上下堆叠（上下文条 + 输入框），
控制项排在容器**外面**单独一行。

- **上下文条**（上容器）：`surfaceButtonSecondary` 灰底、**无描边**、
  圆角 12、高 42，放当前角色
- 间距 **5**
- **输入容器**（下容器）：**纯白**（`surfaceMobile`）底 + 1px `borderStrong` 描边、
  圆角 12，含输入区
- 间距 **4**
- **容器外的一行**：左（配置、图片），右（模型、推理强度、token 指示、发送）
- 容器不用阴影，只用填充与描边区分层级
- 桌面居中，`maxWidth 768`（`kChatColumnWidth`），底部留白 **12**
- 实测（与 Claude 逐项对齐）：
  - 上容器高 **40**、内边距水平 **6**（加上 chip 自身 10，布局内缩 16，与 Claude 的 17 同档。
    两边的「首个墨迹」不能直接比，因为图标字形的留白不同）
  - 间距 **5**
  - 输入容器高 **44**、**纯白**底，边框**随焦点切换**：
    常态 `#E1E1E0`（浅灰）→ 聚焦 `#BFBFBE`（加深）。两个值都是中性灰，
    而本仓的 `border` / `borderStrong` 属暖灰系，白底上会偏黄，所以单独定义。
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
    （与模型名同字号、**常规字重**）、细线圆环（token）
  - **发送/停止键在输入容器的右端内部**（Claude 的位置），不在容器外那一行
  - 容器外那一行最右是 token 圆环（状态指示，不是控件）
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
- Shape: `pill`
- `filled: false`（默认使用）：**完全不画底色**——它坐在已经是浅灰的上下文条上，
  再画一层同色底就成了"看不见的胶囊"。Claude 的上下文项就是条上直接排的文字 + 图标。
  操作行里单独出现的模型名也用 `filled: false`，与 Claude 桌面端的
  底部模型文字一致（不画底）。
- `filled: true` 用于带外单独出现的场景
- 左侧可选 13px 图标；文字 `textSecondary`
- Hover: 填充提亮到 `surfaceSelected`

**原则**：容器内（composer）的 chip 不画边；独立出现的筛选 chip 画边。
两者都是胶囊。

### Switch / Toggle

- Track: `34 × 18`，圆角 6
- Knob: `12 × 12` 圆形，`switchKnob`
- On: `statusSuccess`
- Off: `switchTrackOff`
- Duration: `120ms`

### Checkbox

- 尺寸 `16 × 16`，圆角 4
- 选中：`surfaceRaised` 实心 + `iconOnRaised` 勾
- 未选中：`checkboxOff` 描边

### Dialogs & Sheets

**Desktop Dialog**
- Background: `surfaceMobile`
- Radius: `AthenaRadius.panel`（16）
- Shadow: `AthenaShadow.overlay`
- Width: `min 320 / max 520`
- Padding: 24
- Title: 17 / w600

**Mobile Sheet**
- Background: `surfaceMobile`
- Padding: `horizontal 20, vertical 16`
- 按钮全宽、圆角 8

**Toast / Message Overlay**
- Background: `surfaceMobile`
- Radius: 16 + `overlay` 阴影
- 边框取语义色 40% 透明度（仅用于提示，不用于常规面板）

### Cards & Surfaces

- 浮起容器用**柔阴影**，不要用硬描边（这是 composer 的关键形态）。
- 静态容器（代码块、引用块）用**淡描边 + 灰底**。
- 会话内的权限审批卡与提问卡是浅色面板（`surfaceMobile` + `overlay` 阴影）。
- 助手消息不画底板，直接坐在画布上。

### Sidebar Row（Claude 实测）

- 行高 **26**（**固定高度**，不要靠垂直内边距撑），左右内缩各 **8**，圆角 10。
  hover 才出现的 `⋮` 高 20，比标签的行盒（约 17）高；靠内容撑会把整行顶高，
  表现为"hover 上去整行变高"
- **leading 是状态点**（直径 6），不是图标：静止 `iconSecondary` @45%，
  hover 加深到 @75%；运行中用 `accent`，固定用 `textRowLabel`
- **尾部静止时为空**，hover 才出现一个 `⋮` 按钮（`iconSecondary`，14px）。
  旧版把图钉 / 进度圈常驻在行尾，与 Claude 不符
- 标签用 `textRowLabel`（`#52514E`），**hover 不变色**——只有底色变

### Menus（右键 / 弹出）

- 面板：`surfaceMobile` 白底 + 1px `border`，圆角 12，内边距 4
- 条目：高约 **32**（内边距 12 × 7），文字 14
- 分组之间用 `DesktopContextMenuSeparator`（1px `border`，上下间距 4）
- 危险项（Delete）用 `dangerText`（浅色 `#832F2B`，比 `statusError` 更深）

### Component Coverage Rules

- 所有主路径操作按钮必须从 **Primary CTA** 派生。
- 所有筛选 chip 从 **AthenaTag** 派生；composer 内 chip 从 **AthenaContextChip** 派生。
- 所有文本输入从 **Canonical Input Style** 派生；会话输入必须用 **Composer**。
- 所有桌面模态必须优先使用 **Desktop Dialog** 语言。

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
| `AthenaSpace.sidebar` | 260 | 桌面左侧栏宽度 |

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
| Composer 高 | 约 114 |
| Composer 底距 | 20 |
| 顶栏 | 只有侧栏那一段是 `surfacePanel`，画布上方透明；内含会话标题 |

- 侧栏底色 `surfacePanel`，与画布以 1px `border` 分开
- 顶栏**有会话标题**（Claude 的顶栏不是空的）：左侧是窗口控制，中间是当前会话标题。
  Athena 没有导航箭头与右面板，所以只保留标题
- 顶栏实测：高 **46 逻辑**，底色与画布相同（相当于透明），底边是一条**极浅**的线
  `#F7F7F7`（只比画布暗 5/255）且贯穿整条——它是顶栏唯一的轮廓
- 侧栏内容：分组列表（Pinned / Chats）+ 底部页脚（应用标识 + 设置入口）
- **会话列定宽居中**：消息与 composer 走同一条 768 宽的列（`chatColumnPadding()`
  按画布宽度算两侧留白），左右边缘对齐；画布不够宽时退回 32 的最小留白
- **消息不带头像**（Claude 的对话渲染里没有头像元素）
- **用户消息是右对齐的浅灰气泡**：前景色 5% 填充、圆角 16、内边距 12×8、
  最宽为列宽的 77%
- **助手消息没有气泡**：内容直接铺满列宽
- 结构：侧栏 → 顶栏 → 主内容区 → 底部 composer

### Mobile Layout

- Horizontal padding: `16px`
- 单列；composer 与桌面同一形态（浮起容器 + 柔阴影）

### Border Radius Scale

取自 Claude 的 `--cds-radius-*`：最小档 5，
控件档 7，**composer 也只有 12**，没有 20/24 这种大圆角。

| Claude 变量 | 值 | 本仓 token | 组件 |
|-----------|-----|-----------|------|
| `--cds-radius` | 4 | `xs` | 极小元素 |
| `--cds-radius--sm` / `--xs` | 5 | `inline` | 徽标、行内代码、勾选框 |
| `--cds-radius--lg` | 7 | `row` / `control` | 列表行、按钮、输入框 |
| （卡片 / 面板） | 10 | `container` | 卡片、代码块 |
| `--cds-radius-composer` | 12 | `panel` / `menu` / `composer` | 对话框、菜单、composer |
| `--radius-full` | 9999 | `pill` | chip、发送按钮、头像 |

### Desktop Layout（实测值）

| 项 | 值 |
|----|-----|
| 侧栏宽 | 260 |
| Composer | 上下文条 + 输入容器，宽 768（`kChatColumnWidth`），底部 20 |
| 会话列 | 768 宽居中，内部再留 16（`kChatColumnInnerPadding`） |
| 顶栏 | 只有侧栏那一段是 `surfacePanel`，画布上方透明；内含会话标题 |

### Page Archetypes

**Desktop Chat Workspace**
- 分区：侧栏列表、顶栏标题、主内容区、底部 composer
- 主内容区最安静；composer 是视觉重心（浮起 + 柔阴影）
- 空态是居中大标题 + 胶囊标签

**Settings / Configuration**
- 工具化、列表化、表单化布局
- 强调清晰层级，不强调装饰性卡片堆叠

---

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Canvas | `surface`，无阴影无边框 | 主工作区 |
| Panel | `surfacePanel` + 1px `border` | 侧栏、顶栏 |
| Static content | `codeBackground` + 1px `border` | 代码块、引用块 |
| Selected | `surfaceSelected` | 选中行、选中 chip |
| Hover | `surfaceHover` | 悬停行 |
| **Floating** | `surface`/`surfaceMobile` + `AthenaShadow.raised` | composer |
| **Overlay** | `surfaceMobile` + `AthenaShadow.overlay` | 对话框、菜单 |

### Principles

- **静态容器用边框，浮起容器用阴影**——这是本体系最重要的一条分工。
- 不要给静态卡片加阴影，也不要给浮起容器加硬描边。
- 真正的视觉焦点应当很少，这样它们才有力量。

---

## 7. Do's and Don'ts

### Do

- 用白底（浅色）/ `#212121`（深色）作为主画布
- 用系统字体承载 UI 与正文，等宽只给代码
- 用柔阴影表达"浮起"，用淡边框表达"分隔"
- 主操作用"画布的反色块"或 `accent` 胶囊
- chip 一律胶囊；容器内的 chip 不画边
- 保持高密度，紧凑但不拥挤

### Don't

- 不要使用纯黑画布
- 不要把整个 UI 做成等宽字体
- 不要引入渐变边框、发光、光晕
- 不要给静态卡片加阴影，也不要给 composer 加硬描边
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
- Composer 居中浮起，`maxWidth 860`

### Mobile

- 单列，`surfaceMobile` 背景
- bottom sheet 代替大多数模态居中弹窗
- Composer 与桌面同一形态

### Motion & State Principles

- 所有交互动效服务于"状态确认"，而不是炫技。
- hover 只做轻微强调，不改变组件类型。
- 时长：hover / 选中 `120-150ms`，开关 `120ms`。

---

## 9. Agent Prompt Guide

### Athena Visual Summary

- Claude-desktop-derived AI workspace
- Light-first: white canvas (`#FFFFFF`), `#FAFAFA` sidebar, `#E8E8E9` hairline dividers
- **System UI font**; monospace only for code, inline code, tool args and output
- Message hierarchy from weight and gray value, not size
- Radii 4 / 8 / 12 / 16 / 20, plus pills for chips and the send button
- Static containers use hairline borders; floating containers use soft shadows
- One chromatic accent: `#4E82EF`
- Calm, technical, high-density, non-marketing, non-social

### Quick Color Reference

| Use | Light（实测） | Dark |
|-----|------|------|
| Canvas | `#FFFFFF` | `#212121` |
| Sidebar / app bar | `#FAFAFA` | `#171717` |
| Divider / border | `#E8E8E9` | `#2F2F2F` |
| Selected row | `#EDEEEF` | `#333333` |
| Chip fill | `#F4F4F4` | `#2F2F2F` |
| Primary text | `#1A1C1F` | `#ECECEC` |
| Secondary text | `#6E6E73` | `#A0A0A5` |
| Weak text | `#C3C3C5` | `#6E6E73` |
| Accent | `#4E82EF` | `#6E9BF5` |

### Prompt Fragments

**For the Athena Composer**
"Build a chat composer as ONE floating container: white fill, 20px radius, and a
soft shadow (no hard border). Inside, stack three rows: pills showing the current
context (role, model) with a light `#F4F4F4` fill and no border; the borderless
text field; and an action row with settings on the left and a circular blue
`#4E82EF` send button on the right. Centered, max width 860, 32px side margins."

**For Athena Chips**
"Build a compact pill chip: fully rounded, 13px system-font label. Filter chips get
a 1px `#E8E8E9` border with a `#F7F7F7` fill; chips inside the composer get NO
border, only a `#F4F4F4` fill. Selected is `#EDEEEF` fill with `#1A1C1F` weighted
text. No gradient, no glow."

**For Athena Code Block**
"Build a code block: `#F7F7F7` fill with a 1px `#E8E8E9` border and 12px radius, a
`#F4F4F4` header strip carrying the monospace language label and a copy button, and
`#1A1C1F` monospace body text. The body is the only monospace in the UI."

**For the Athena Sidebar**
"Build a `#FAFAFA` sidebar, 260px wide, separated from the white canvas by a 1px
`#E8E8E9` line. Rows are 8px-radius with the system font; the selected row is
`#EDEEEF`. Add uppercase-ish `#C3C3C5` group labels and a bottom footer with a
rounded app avatar, the app name, and a settings icon."

### Final Instruction to Agents

1. 先保证它像 Claude 桌面端：暖白底、系统字体、克制的圆角、少量阴影。
2. 浮起容器用阴影，静态容器用边框——不要混用。
3. 等宽只给代码；UI 与正文一律系统字体。
4. chip 一律胶囊；`#4E82EF` 是唯一的彩色。
5. 桌面与移动共享气质，只改变结构，不改变人格。
6. 不新增颜色、圆角或阴影体系，先从现有 token 派生。
7. 多个方向都合理时，选更克制、更工具化的那个。
