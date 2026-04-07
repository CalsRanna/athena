# Design System

## 1. Visual Theme & Atmosphere

Athena 是一个跨平台的 AI 工作台，不是社交应用，也不是营销网站。它的视觉语言应该让人联想到桌面级创作工具、轻量 IDE 和个人 AI 控制台：克制、安静、专业，但不是冰冷的机械黑盒。

整体气质建立在三个核心特征上：
- **深色沉浸式工作区**：以深灰和蓝灰黑为主，降低背景存在感，让聊天内容、模型控制和角色系统成为焦点。
- **克制的未来感光效**：不依赖大面积炫技渐变，而是把渐变和发光压缩到极少数关键位置，形成品牌记忆点。
- **圆润但不软萌的工具感**：大量使用 pill 形和大圆角，但始终保持理性、紧凑、偏生产力工具的秩序。

Athena 最重要的视觉签名不是“深色”本身，而是以下两种细节：
- **Tag / Chip 的浅色到透明边框渐变**：它让选择器、角色标签和过滤器拥有轻盈的悬浮感，是 Athena 最有辨识度的细节之一。
- **白色 CTA 的柔光阴影**：主操作按钮不是普通白按钮，而是带有非常柔和的浅灰白光晕，像在暗色界面中被点亮的操作节点。

**核心设计理念**
- 背景必须退后，内容和控制区必须前置。
- 渐变只服务于“品牌识别”和“焦点引导”，不能变成页面噪音。
- Athena 的界面应当像“为长时间使用而设计”，而不是为了首屏惊艳。
- 桌面和移动端可以结构不同，但必须共享同一套审美语言。

### Priority Rules

当设计决策发生冲突时，按以下优先级裁决：
1. **先保留 Athena 的品牌签名**：Tag 渐变边框、白色 CTA 光晕、深色工作台气质优先于局部装饰创新。
2. **再保留克制感**：如果“更强视觉冲击”和“更安静的专业工具感”冲突，优先选择后者。
3. **再考虑层次强化**：需要提升层级时，优先增加明暗和结构，而不是新增颜色或特效。
4. **最后才允许局部变化**：新页面可以有新构图，但不能引入第二套视觉人格。

### Brand Signature Preservation

- 如果一个新页面只能保留一个 Athena 特征，优先保留 **Tag 渐变边框体系**。
- 如果一个页面存在明确主操作，优先保留 **白色 CTA + 柔光阴影**。
- 如果页面属于桌面主工作区，优先保留 **深灰主体 + 轻 teal 氛围壳层**。

---

## 2. Color Palette & Roles

### Primary Colors

| Color | Hex | Usage |
|-------|-----|-------|
| Surface Desktop | `#282828` | 桌面主工作区背景 |
| Surface Mobile | `#282F32` | 移动端主背景、sheet 背景 |
| Surface Deep | `#161616` | 深层容器、未选中标签内层、深色反白文字底 |
| Pure White | `#FFFFFF` | 主文字、主按钮底色、关键图标 |
| True Black | `#000000` | 白色圆形图标按钮中的图标 |

### Neutral Scale

| Level | Hex | Usage |
|-------|-----|-------|
| Gray 100 | `#F5F5F5` | 输入框文字、亮色内容文本 |
| Gray 200 | `#EAEAEA` | Tag 渐变边框起点、轻边缘高光 |
| Gray 300 | `#E0E0E0` | 选中 Tag 背景、浅色 code/container 填充 |
| Gray 400 | `#C2C2C2` | 占位符、边框、弱图标 |
| Gray 500 | `#ADADAD` | 输入框半透明背景基色 |
| Gray 600 | `#9E9E9E` | 次级辅助文字 |
| Gray 700 | `#757575` | 输入框描边、较强轮廓线 |
| Gray 800 | `#616161` | 移动端次级按钮背景、深层中性色块 |

### Accent Colors

| Color | Hex | Usage |
|-------|-----|-------|
| Athena Teal | `#6ABEB9` | 桌面背景氛围渐变、品牌级强调 |
| Sage | `#A7BA88` | 开关开启底色 |
| Slate | `#C2C9D1` | 开关关闭底色 |
| Glow White | `#CED2C7` | CTA 光晕阴影基色 |

### Semantic Principles

- **Athena Teal 不是通用按钮色**，它主要用于大背景氛围、轻强调和品牌识别。
- **白色是主操作色**，尤其用于 CTA、返回按钮、发送按钮、关键入口。
- **选中状态优先通过明暗反转表达**，而不是引入更多彩色。
- **如果一个界面已经有渐变边框或白色光晕，则不要再叠加第二种强装饰。**

### Opacity Usage

| Context | Opacity | Example |
|---------|---------|---------|
| 基础边框 | 20% | `rgba(255,255,255,0.2)` |
| 次级文字 | 80% | `rgba(255,255,255,0.8)` |
| Tag 渐变起点 | 17% | `rgba(234,234,234,0.17)` |
| 输入框背景 | 60% | `rgba(173,173,173,0.6)` |
| 桌面 teal 氛围层 | 20% | `rgba(106,190,185,0.2)` |
| CTA 光晕 | 50% | `rgba(206,210,199,0.5)` |

### Gradient Patterns

- **Desktop Atmosphere Gradient**：右上角 teal 氛围渐变向左下透明扩散，用于整个桌面壳层的轻品牌氛围。
- **Tag Border Gradient**：由浅灰白 `rgba(234,234,234,0.17)` 向透明过渡，形成轻量边缘发光，而不是实体描边。
- **CTA Halo**：不是多色渐变，而是白色主按钮外一圈非常柔和的浅白绿色阴影，让按钮像被暗环境衬亮。

### Token Governance

- 不新增新的品牌色；品牌级强调只能围绕 `Athena Teal`、白色 CTA 和既有中性色展开。
- 不新增第二套发光体系；所有发光都必须归属于 CTA 光晕或极轻的品牌氛围层。
- 不新增新的大圆角等级；优先复用 `8 / 24 / pill / circle`。
- 不新增与现有灰阶相近但难以区分的新灰色。
- 如果必须扩展 token，应先从现有 token 推导透明度、层级或尺寸变体，而不是新造一套视觉语言。

---

## 3. Typography Rules

### Font Family

- **UI / Body**：系统默认字体
- **Windows 优先**：`Microsoft YaHei`
- **Code / Technical**：等宽字体，可使用类似 Fira Code 的现代 monospace

### Typography Strategy

Athena 的排版不靠复杂字体系统取胜，而靠清晰层级和稳定密度：
- 标题不夸张，不做营销页式展示排版。
- 正文尺寸稳定，强调长时间阅读和对话浏览。
- 技术文本、代码、模型名、参数名可以使用 monospace，强化“工具感”。

### Hierarchy

| Role | Size | Weight | Line Height | Usage |
|------|------|--------|-------------|-------|
| Page / Dialog Title | 20px | 500 | 1.2 | 对话框标题、关键页面标题 |
| Section Title | 16px | 500 | 1.3 | 分区标题、功能模块标题 |
| App Bar Title | 14px | 400 | 1.2 | 顶栏标题 |
| Body | 14px | 400 | 1.5-1.7 | 主体内容、聊天文本、输入文本 |
| Label | 12px | 500 | 1.4-1.5 | 标签、Chip、小按钮 |
| Caption / Placeholder | 12-14px | 400 | 1.4-1.6 | 提示信息、空态、说明 |
| Mono Label | 11-12px | 400-500 | 1.4-1.6 | 代码片段、技术标签、模型参数 |

### Text Colors

| Context | Color |
|---------|-------|
| Primary text | `#FFFFFF` |
| Secondary text | `rgba(255,255,255,0.8)` |
| Placeholder | `#C2C2C2` |
| Input text | `#F5F5F5` |
| Dark text on light surface | `#161616` |

### Principles

- Athena 不依赖超大字和强对比标题建立品牌。
- 层级主要通过明暗、位置和间距建立，而不是很多种字号。
- 代码和模型信息应当更“技术化”，但不能抢正文的视觉中心。

---

## 4. Component Stylings

### Buttons

**Primary CTA**
- Background: `#FFFFFF`
- Text: `#161616`
- Shape: `StadiumBorder`
- Padding: `horizontal 12, vertical 16`
- Shadow: `0 0 16 rgba(206,210,199,0.5)`
- Character: 在深色背景中像被点亮的操作节点

**States**
- Default: 白底 + 柔光阴影
- Hover: 仅轻微强化亮度或阴影，不新增彩色描边
- Pressed: 保持白底，缩小光晕感，像被压下
- Disabled: 降低对比度，去掉光晕，不能再像可点击主操作

**Secondary Button**
- Background: transparent
- Border: `1px solid #C2C2C2`
- Text: `#FFFFFF`
- Shape: `StadiumBorder`
- Sizes:
  - Default: `20 x 16`
  - Medium: `24 x 12`
  - Small: `20 x 8`

**States**
- Default: 细边框 + 白字
- Hover: 允许轻微提亮边框或文字
- Pressed: 保持当前色系，不出现发光
- Disabled: 文字与边框同步减弱

**Text / Ghost Button**
- Background: transparent
- Text: `#FFFFFF`
- Shape: `StadiumBorder`
- Padding: `12 x 16`
- Use: 非主路径操作、轻工具操作

**States**
- Hover: 可以提亮文字，但不增加填充和阴影
- Pressed: 保持安静，不做视觉跳变

**Icon Button**
- Background: `#FFFFFF`
- Icon: `#000000`
- Shape: circle
- Padding: 12
- Use: 返回、确认、轻量单步操作

**States**
- Hover: 轻微提亮或提升存在感
- Pressed: 维持实体感，但不要出现 CTA 级光晕
- Disabled: 仍保留结构轮廓，但明显失去可操作感

### Inputs

**Canonical Input Style**
- Background: `rgba(173,173,173,0.6)`
- Border: `1px solid #757575`
- Radius: 24
- Text: `#F5F5F5`
- Placeholder: `#C2C2C2`
- Cursor: `#F5F5F5`
- Padding: `horizontal 20, vertical 15.5`

**States**
- Default: 半透明中灰背景 + 细描边
- Focus: 优先加强边框清晰度，不使用高饱和 focus ring
- Error: 在不破坏整体深色气质的前提下，使用更明确但克制的警示边界
- Disabled: 维持结构，但明显降低对比与可编辑感

**Mobile Input Adaptation**
- 保留相同色彩语言
- 可适度压缩内边距，但不要改变整体气质
- 不要切回默认 Material 白底输入框

### Tags / Chips

这是 Athena 的关键品牌组件，必须被高度统一。

- Outer border: 渐变边框，从 `rgba(234,234,234,0.17)` 到透明
- Inner radius: 44
- Unselected background: `#161616`
- Unselected text: `#FFFFFF`
- Selected background: `#E0E0E0`
- Selected text: `#161616`
- Default padding: `horizontal 36, vertical 13`
- Small padding: `horizontal 20, vertical 4`
- Animation: `300ms`

**Principle**
- Tag 的“亮边框”不是边框装饰，而是 Athena 的视觉签名。
- 任何角色列表、模型筛选、Sentinel 展示区都应优先沿用这套语言。

**States**
- Default: 深色内层 + 渐变边框
- Hover: 只允许轻微提升亮边缘存在感
- Selected: 浅色填充 + 深色文字，形成明确反转
- Disabled: 保留轮廓但显著降低存在感

### Switch / Toggle

- Width: 36
- Thumb: 16 x 16
- On: `#A7BA88`
- Off: `#C2C9D1`
- Thumb color: `#FFFFFF`
- Duration: `100ms`

### Dialogs & Sheets

**Desktop Dialog**
- Background: `#282F32`
- Radius: 8
- Width: `min 320 / max 520`
- Padding: 32
- Positioning: centered

**Mobile Sheet**
- Background: `#282F32`
- Presentation: bottom sheet
- Padding: `horizontal 24, vertical 12`
- Tone: 与桌面对话框一致，但更贴近触控上下文

### Component Coverage Rules

- 所有主路径操作按钮必须从 **Primary CTA** 派生。
- 所有筛选器、角色标签、模型标签、Sentinel 标签必须从 **Athena Tag / Chip** 派生。
- 所有文本输入和搜索输入必须从 **Canonical Input Style** 派生。
- 所有移动端临时操作面板必须优先使用 **Mobile Sheet** 语言。
- 所有桌面模态必须优先使用 **Desktop Dialog** 语言。
- 新页面如果完全没有使用 Athena 签名元素，应视为风格不足。

### Allowed Exceptions

- 代码块、技术输出、预览面板可以使用更中性的容器样式，但不能引入新的品牌色。
- 图片预览、媒体预览、系统级权限弹窗允许更弱的品牌化处理，但仍应保留基础深色体系。
- 例外组件只能弱化 Athena 风格，不能创造第二套风格。

### Cards & Surfaces

- 主体卡片尽量少做厚重投影
- 默认依靠深浅分层、边框、渐变边缘区分层级
- 如果一个卡片已经使用浅边缘渐变，就不要再叠加强卡片阴影

### Distinctive Components

**Sentinel Tag Wall**
- 以成组 pill 标签构成角色入口
- 重点展示渐变边框与深浅反转选中态
- 感觉应当轻盈、可收藏、像“角色胶囊库”

**Chat Composer**
- 是工作台核心控制区，不只是输入框
- 输入、发送、模型选择、角色选择、附加操作要形成一个稳定控制带
- 发送按钮应优先使用白色高亮操作节点

**Desktop Shell**
- 最外层用非常轻的 teal 氛围渐变建立品牌识别
- 内层保持深灰纯净工作区

---

## 5. Layout Principles

### Spacing System

| Token | Value | Usage |
|-------|-------|-------|
| space-xs | 4 | 微调、细间距 |
| space-sm | 8 | 紧凑控件间距 |
| space-md | 12 | 常规模块内间距 |
| space-lg | 16 | 页面常规留白 |
| space-xl | 20 | 输入框水平 padding、按钮舒适留白 |
| space-2xl | 24 | 大圆角、sheet padding |
| space-3xl | 32 | 桌面工作区 padding |

### Grid & Density

- Athena 应保持 **中高密度工具界面**
- 不走营销网站的大留白路线
- 也不走终端式极端压缩路线
- 信息密度要足够专业，但仍需呼吸感

### Desktop Layout

- Left sidebar width: `240px`
- Workspace padding: `horizontal 32, vertical 12`
- 顶栏、左栏、工作区应形成稳定三段式工作台结构

### Mobile Layout

- Horizontal padding: `16px`
- Vertical rhythm: `8px / 12px / 24px`
- 模块之间以清晰分段组织，不堆砌卡片
- 触控区域应当更明确、更圆润

### Border Radius Scale

| Size | Value | Use |
|------|-------|-----|
| Standard | 8px | dialog、card、轻容器 |
| Comfortable | 24px | 输入区、搜索框、大表单 |
| Full Pill | 44px+ | Tag、胶囊按钮、筛选器 |
| Circle | 50% | 返回按钮、图标按钮 |

### Whitespace Philosophy

- 空白不是为了“高级感展示”，而是为了让控制区和内容区分离。
- 深色界面中的留白应尽量通过结构间距体现，而不是大量空洞区域。
- 所有间距都应服务于可读性和操作流畅度。

### Page Archetypes

**Desktop Chat Workspace**
- 采用三段式工作台：导航/列表、主内容区、底部控制带
- 主内容区应最安静，控制区与列表区承担更多边界和功能提示
- 底部 composer 是页面最明确的交互核心

**Mobile Home**
- 首屏应突出 Athena 的品牌组件，尤其是 Sentinel Tag Wall
- 不做社交 feed 式大卡片流
- 模块应当像“工具入口集合”，而不是“内容消费列表”

**Settings / Configuration**
- 采用工具化、列表化、表单化布局
- 强调清晰层级，不强调装饰性卡片堆叠
- 行为操作要克制，避免多个同时抢眼的按钮

**Bottom Sheet Flow**
- 每个 sheet 应只服务一个短流程或一组紧密相关操作
- sheet 内优先使用 Athena Tag、Canonical Input、简洁 CTA
- 不在 sheet 内再堆叠复杂卡片体系

**Selection Surfaces**
- 模型选择、角色选择、过滤选择器优先通过 Tag / pill 体系建立统一感
- “选择”应更多依赖反转、边缘、明暗，而不是彩色高亮

---

## 6. Depth & Elevation

Athena 的层级系统应当克制。它更依赖：
- 深浅背景差
- 半透明边框
- 渐变边缘
- 少量关键发光

而不是大量 Material 式卡片阴影。

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat | 无阴影，仅背景层次 | 主页面背景、大多数内容区 |
| Border Ring | `rgba(255,255,255,0.2)` 细边 | 分割、输入框、工具区边界 |
| Gradient Edge | 浅灰到透明渐变边缘 | Tag、轻浮层、品牌性边缘 |
| CTA Glow | `0 0 16 rgba(206,210,199,0.5)` | 主按钮、关键发送按钮 |
| Ambient Brand Layer | `rgba(106,190,185,0.2)` 到透明 | 桌面壳层背景氛围 |

### Principles

- 发光只给“重要操作”，不要把所有可点击元素都做亮。
- 渐变边缘比实体描边更符合 Athena 的气质。
- 真正的视觉焦点应当很少，这样它们才有力量。

---

## 7. Do's and Don'ts

### Do

- 使用深灰和蓝灰黑作为稳定背景，保持沉浸式工作台气质
- 把 Tag 的渐变边框当作 Athena 的品牌语言持续复用
- 把白色 CTA 的柔光阴影作为主操作的专属视觉信号
- 让桌面端保持轻微 teal 氛围背景，但强度必须克制
- 通过圆角、边框、亮暗反转统一交互组件
- 让移动端延续桌面端的品牌感，而不是退回默认移动应用风格
- 在内容区和控制区之间保留清晰层次

### Don't

- 不要把 Athena 做成彩色 dashboard 或 neon cyberpunk
- 不要把 teal 扩散成全站主按钮色或大面积品牌底色
- 不要让渐变无处不在；渐变必须是稀缺资源
- 不要把白色光晕用于所有按钮；它只属于 CTA
- 不要引入大量不同半径，破坏组件家族感
- 不要使用默认 Material 风格白底输入框、蓝色按钮或系统原生弹窗视觉
- 不要把移动端做成“社交 feed”风格；它仍然是工具界面
- 不要让页面之间出现完全不同的交互控件气质

---

## 8. Responsive Behavior

### Shared Brand, Different Shell

Athena 的跨平台原则应当是：
- **品牌一致**
- **交互壳层适配平台**

也就是说，桌面和移动可以拥有不同布局和容器形式，但不能拥有不同视觉人格。

### Desktop

- 深灰工作台 + 轻 teal 氛围渐变
- 更强调分栏、长时间停留、信息并行
- 对话框采用居中浮层
- 输入区更像工具带的一部分

### Mobile

- 蓝灰黑主背景
- 更强调分段浏览和单任务流程
- 使用 bottom sheet 代替大多数模态居中弹窗
- 返回、确认等关键动作优先使用白色圆形 icon button

### Touch & Interaction

- 移动端 CTA 和 icon button 需要清晰、饱满、可单手识别
- 桌面端 hover 可以强化，但不能依赖 hover 才能理解状态
- 选中状态优先使用亮暗反转和标签填充变化表达

### Motion & State Principles

- 所有交互动效都应服务于“状态确认”，而不是制造炫技。
- hover 只做轻微强调，不改变组件类型。
- pressed 应更像“压下”，而不是“点亮”。
- disabled 应清晰可见但不吸引注意力。

---

## 9. Agent Prompt Guide

### Athena Visual Summary

- Deep dark AI workspace
- Minimal teal atmosphere on desktop only
- Pill-heavy control language
- Signature gradient-outline tags
- Signature white CTA with soft halo glow
- Calm, technical, non-marketing, non-social

### Quick Color Reference

| Use | Value |
|-----|-------|
| Desktop background | `#282828` |
| Mobile background | `#282F32` |
| Deep surface | `#161616` |
| Primary text | `#FFFFFF` |
| Secondary text | `rgba(255,255,255,0.8)` |
| Placeholder | `#C2C2C2` |
| Input background | `rgba(173,173,173,0.6)` |
| Input border | `#757575` |
| Brand teal | `#6ABEB9` |
| CTA glow | `rgba(206,210,199,0.5)` |
| Tag gradient start | `rgba(234,234,234,0.17)` |

### Prompt Fragments

**For Athena CTA**
"Create a primary CTA for a dark AI workspace: white background, dark text, StadiumBorder shape, soft white-green halo shadow (`rgba(206,210,199,0.5)` with 16px blur), calm and premium rather than loud."

**For Athena Tag**
"Create a pill-shaped tag with a subtle gradient border from `rgba(234,234,234,0.17)` to transparent, dark inner fill (`#161616`), white text by default, and a selected state with light fill (`#E0E0E0`) and dark text."

**For Athena Desktop Surface**
"Create a desktop AI workspace with a dark gray base (`#282828`) and a very subtle teal atmospheric gradient in the outer shell, keeping the center workspace clean and focused."

**For Athena Mobile Sheet**
"Create a mobile bottom sheet for an AI tool app using `#282F32` background, rounded geometry, white text, restrained spacing, and the same visual language as a professional desktop workspace."

### Final Instruction to Agents

当你为 Athena 设计页面时：
1. 先保证它像一个深色 AI 工作台，而不是普通 app。
2. 优先复用 Athena 的两个签名元素：渐变边框 Tag 与白色光晕 CTA。
3. 让品牌感来自少量高质量细节，而不是大量视觉特效。
4. 让桌面和移动共享气质，只改变结构，不改变人格。
5. 不新增新的品牌色、圆角体系或发光体系，先从现有 token 派生。
6. 如果多个方向都看起来合理，优先选择更克制、更工具化、更多 Athena 签名元素的方案。
