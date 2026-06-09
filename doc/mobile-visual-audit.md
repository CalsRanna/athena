# 移动端视觉评审报告（对照 DESIGN.md）

> 审计日期：2026-06-10
> 审计范围：`lib/page/mobile/` 下全部 22 个页面及 `lib/widget/` 共享组件
> 参考规范：`/DESIGN.md`

---

## 总体评分：B+ — 骨架坚实，细节多处偏离

移动端的共享组件库（`AthenaScaffold`、`AthenaTag`、`AthenaPrimaryButton`、`AthenaInput`）忠实履行了 DESIGN.md，但若干页面级实现偏离了设计系统，尤其是以下三个高频主题：

- **Tag 签名缺席**：Sentinel 列表页使用了白色卡片，丢失了 Athena 最重要的品牌符号
- **字号层级越界**：Welcome 28px/700、SentinelPlaceholder 28px/700，远超 Page Title 20px/500 上限
- **Agent 设置页回退到 Material 默认风格**：OutlineInputBorder、Colors.grey、默认 SnackBar

---

## 🔴 高优先级问题（品牌签名受损）

### 1. Sentinel 列表页使用白色卡片，完全丢失 Tag 渐变边框签名

**文件**: `lib/page/mobile/sentinel/list.dart` → `_Tile` widget

**问题**: Sentinel 卡片采用 `#FFFFFF` 白色背景 + `#161616` 黑色文字 + 24px 圆角。这是 Material Design 卡片风格，与首页 `SentinelListView` 的 pill 标签体系完全割裂。

**DESIGN.md 要求**:

> "Sentinel Tag Wall 以成组 pill 标签构成角色入口，重点展示渐变边框与深浅反转选中态"
>
> "如果一个新页面只能保留一个 Athena 特征，优先保留 **Tag 渐变边框体系**"

**建议**: 将 Sentinel 列表页改为水平滚动的 Tag Wall（复用 `AthenaTag`/`AthenaTagButton`），与首页 `SentinelListView` 的 pill 标签体系保持一致。

```dart
// 现状（_Tile）：
BoxDecoration(borderRadius: BorderRadius.circular(24), color: ColorUtil.FFFFFFFF)

// 应改为:
AthenaTag(text: sentinel.name)  // 或带 description 的定制 Tag 变体
```

---

### 2. 聊天历史 Tile 使用白色 pill = 与 CTA 签名冲突

**文件**: `lib/page/mobile/home/component/chat_tile.dart`

**问题**: `ChatTile` 使用 `#FFFFFF` 白色背景 + `StadiumBorder`，恰好是 Athena CTA 的签名外观。用户会把历史聊天入口误认为主要操作按钮。

**DESIGN.md 要求**:

> "不要把白色光晕用于所有按钮；它只属于 CTA"

白色 + StadiumBorder + 光晕是 CTA 的专属组合。历史入口应使用 Tag 体系或 Secondary Button 体系。

**建议**: 改用 `AthenaTag` 的未选中态（`#161616` 内层 + 渐变边框）或 `AthenaSecondaryButton` 的透明风格。

```dart
// 现状：
ShapeDecoration(color: ColorUtil.FFFFFFFF, shape: StadiumBorder())

// 应改为 Tag 风格：
AthenaTag(text: chat.title.isNotEmpty ? chat.title.trim() : 'New Chat')
```

---

### 3. Agent 设置页完全回退到 Material 默认风格

**文件**: `lib/page/mobile/setting/agent_page.dart`

**问题汇总**:

| 元素 | 现状 | DESIGN.md 要求 |
|------|------|----------------|
| 输入框 | `OutlineInputBorder` (Material 默认) | `AthenaInput`: `rgba(173,173,173,0.6)` bg + radius 24 |
| 保存按钮 | `AthenaSecondaryButton.small` | 保存 = 主要操作，应为 CTA |
| 提示文字 | `Colors.grey` 硬编码 | `ColorUtil.FFC2C2C2` |
| Section 标题 | 18px/500 | 16px/500 或 20px/500 |
| SnackBar | 默认 Material 样式 | 应使用 Athena 深色体系 |

**DESIGN.md 要求**:

> "所有文本输入和搜索输入必须从 Canonical Input Style 派生"
>
> "不要使用默认 Material 风格白底输入框、蓝色按钮或系统原生弹窗视觉"

**建议**: 完全重写 Agent 设置页，使用 `AthenaInput`、`AthenaPrimaryButton`、DESIGN.md 规定的排版层级。

---

## 🟡 中优先级问题（视觉一致性受损）

### 4. 首页欢迎语过度强调，违反克制原则

**文件**: `lib/page/mobile/home/component/welcome.dart`

**问题**:
- "Good morning!" 使用 `#A7BA88`（Sage 绿）—— Sage 是 Toggle 开关颜色，不是文字色
- 字号 28px weight 700 —— DESIGN.md 规定 Page Title 为 20px/500，远超最大层级
- 绿色在 Athena 中是操作反馈色，不应大面积用于品牌欢迎语

**DESIGN.md 要求**:

> "Athena Teal 不是通用按钮色，它主要用于大背景氛围"
>
> "标题不夸张，不做营销页式展示排版"
>
> "层级主要通过明暗、位置和间距建立"

**建议**: 改为 `#FFFFFF` 20px/500。如需品牌色，用 `#6ABEB9`（Athena Teal）而非 `#A7BA88`（Sage）。

---

### 5. 多个输入组件缺少 DESIGN.md 规定的描边

**文件**: `lib/widget/input.dart` (`AthenaInput`)、`lib/page/mobile/chat/component/user_input.dart`

**问题**: DESIGN.md 规定 Canonical Input 必须有 `1px solid #757575` 边框：

> "Border: `1px solid #757575`"

`AthenaInput` 没有应用此边框，`UserInput` 的 composer 也没有。

**建议**: 在 `AthenaInput.boxDecoration` 中加入 `border: Border.all(color: ColorUtil.FF757575)`。

---

### 6. SentinelPlaceholder 标题层级越界

**文件**: `lib/page/mobile/chat/component/sentinel_placeholder.dart`

**问题**: Sentinel 名称使用 28px/700。DESIGN.md Page Title 上限是 20px/500。

**建议**: 改为 20px/500，与 AppBar 标题层级一致。

---

### 7. ShortcutTile 视觉语言游离于 Tag/CTA 体系之外

**文件**: `lib/page/mobile/home/component/shortcut_tile.dart`

**问题**:
- `#616161` 实色背景 + 24px 圆角 + 图标/标题/描述垂直排列
- 这套视觉语言在 DESIGN.md 中没有对应物。`#616161` 是 "移动端次级按钮背景"，但这里用作卡片底色

**DESIGN.md 要求**:

> "Tag 的'亮边框'不是边框装饰，而是 Athena 的视觉签名"
>
> "任何角色列表、模型筛选、Sentinel 展示区都应优先沿用这套语言"

**建议**: Shortcut 入口可以改用 `AthenaTagButton` 的 pill 风格（带图标），或采用深色表面 + 渐变边框的卡片风格，避免引入独立视觉人格。

---

### 8. Mobile 端对话框输入框未使用 AthenaInput

**文件**: `lib/widget/dialog.dart` → `_InputDialog`

**问题**: `_InputDialog`（移动端重命名等场景）使用：

```dart
InputDecoration(
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  fillColor: ColorUtil.FF616161,
  ...
)
```

圆角 8px + `#616161` 填充，偏离 Canonical Input 规范（24px radius + `rgba(173,173,173,0.6)` bg）。

**建议**: 替换为 `AthenaInput` 或使其与 Canonical Input 视觉一致。

---

### 9. 翻译页语言选择器使用 CTA 风格造成主次不分

**文件**: `lib/page/mobile/translation/translation_page.dart`

**问题**: 语言选择按钮使用 `AthenaPrimaryButton`（白色 CTA + 光晕）。DESIGN.md 要求 CTA 是稀缺资源：

> "发光只给'重要操作'"
>
> "真正的视觉焦点应当很少"

一个页面不应有两个紧邻的白色 CTA（语言选择器 + Translate 按钮）。

**建议**: 语言选择器改用 `AthenaSecondaryButton` 或 `AthenaTagButton` 风格。

---

## 🟢 低优先级问题（细节打磨）

### 10. 模型选择器的分组标题颜色可以用更明确的层级色

**文件**: `lib/page/mobile/chat/component/model_selector.dart`

使用 `#E0E0E0`（Gray 300）—— 这个颜色是 DESIGN.md 中 "选中 Tag 背景" 的颜色。用作分组标题时，建议用 `#C2C2C2`（占位符色）或 `#9E9E9E`（次级辅助文字色）以区分层级。

---

### 11. Provider 名称页面使用原生 TextField

**文件**: `lib/page/mobile/provider/provider_name_page.dart`

使用 `InputDecoration.collapsed` 的纯文字输入，缺少 `AthenaInput` 的 `rgba(173,173,173,0.6)` 背景容器。虽然装饰较少可以接受，但建议至少保留底部边框或背景色以与其他输入保持一致。

---

### 12. Chat 配置滑块 inactiveColor 使用 `#FFFFFF` 可能过亮

**文件**: `lib/page/mobile/chat/component/chat_configuration_dialog.dart`、`lib/page/mobile/chat/chat_configuration.dart`

Slider 的 `inactiveColor: ColorUtil.FFFFFFFF` 在深色背景上对比过于强烈。建议使用 `#616161` 或 `#757575` 作为非活跃轨道色，与 Athena 的中性色体系一致。

---

## ✅ 合规亮点（值得肯定的设计执行）

| 组件/页面 | 合规项 |
|-----------|--------|
| `AthenaScaffold` | Mobile `#282F32` bg，Desktop `#282828` + teal 渐变 ✅ |
| `AthenaTag` / `AthenaTagButton` | 渐变边框 `rgba(234,234,234,0.17)`→透明，`#161616`/`#E0E0E0` 反转，300ms 动画 ✅ |
| `AthenaPrimaryButton` | 白色 + `#CED2C7` 50% 光晕 + StadiumBorder ✅ |
| `AthenaIconButton` | 白色圆形 + `#000000` 图标 + 12px padding ✅ |
| `AthenaSecondaryButton` | `StadiumBorder` + `#C2C2C2` 描边 + 白字，三档尺寸 ✅ |
| `AthenaTextButton` | 透明背景 + `StadiumBorder` + 白字 ✅ |
| `MobileAppBar` | 20px 白色标题 + 白色圆形返回按钮 ✅ |
| `NewChatButton` | 完美 CTA：白色 pill + 柔光阴影 + 20px/500 ✅ |
| `SentinelTile` (首页) | 完美 Tag：渐变边框 + `#161616` 内层 + 白色文字 12px/500 ✅ |
| `SendButton` | CTA 光晕：白色 bg + `#CED2C7` 阴影 + streaming 状态切换 ✅ |
| `UserInput` | `rgba(173,173,173,0.6)` bg + radius 24 + `#F5F5F5` 文字 ✅ |
| TRPG 页面 | Tag 风格按钮、CTA、Canonical Input 风格 composer、DM 气泡 ✅ |
| `ModelWallView` | 使用 `AthenaTag` 展示模型 ✅ |
| `AthenaDialog` (移动端) | Bottom sheet `#282F32` bg，Confirm 用 CTA + secondary ✅ |
| `AthenaDialog` (桌面端) | 居中浮层 `#282F32` bg，radius 8，min 320 / max 520 ✅ |
| `ChatListPage` | 白色文字层级、`rgba(255,255,255,0.2)` 分割线、16px padding ✅ |
| `DefaultModelFormPage` | Canonical Input 风格下拉框、20px/500 标题层级 ✅ |
| `SummaryPage` | `AthenaInput` radius 36、24px/500 section 标题 ✅ |
| `TranslationPage` | Canonical Input、`rgba(255,255,255,0.2)` 分割线 ✅ |
| `MobileModelListView` | `AthenaTag.small` 用于模型 ID、清晰的文字层级 ✅ |

---

## 优先级修复路线

### 立即修（品牌签名缺失）

| # | 文件 | 改动 |
|---|------|------|
| 1 | `lib/page/mobile/sentinel/list.dart` | `_Tile` 白色卡片 → `AthenaTag` / Tag Wall 布局 |
| 2 | `lib/page/mobile/home/component/chat_tile.dart` | 白色 pill → Tag 风格（`#161616` + 渐变边框） |
| 3 | `lib/page/mobile/setting/agent_page.dart` | 全面替换为 `AthenaInput`、`AthenaPrimaryButton`、Athena 排版 |

### 尽快修（一致性受损）

| # | 文件 | 改动 |
|---|------|------|
| 4 | `lib/page/mobile/home/component/welcome.dart` | 文字色 `#A7BA88`→`#FFFFFF`，28px→20px，w700→w500 |
| 5 | `lib/widget/input.dart` | 加 `1px solid #757575` 边框 |
| 6 | `lib/page/mobile/chat/component/sentinel_placeholder.dart` | 28px→20px，w700→w500 |
| 7 | `lib/page/mobile/home/component/shortcut_tile.dart` | `#616161` 卡片 → Tag/渐变边框体系 |
| 8 | `lib/widget/dialog.dart` `_InputDialog` | `OutlineInputBorder` → `AthenaInput` 规范 |
| 9 | `lib/page/mobile/translation/translation_page.dart` | 语言选择器去 CTA 化 |

### 计划修（细节打磨）

| # | 文件 | 改动 |
|---|------|------|
| 10 | `lib/page/mobile/chat/component/model_selector.dart` | 分组标题 `#E0E0E0` → `#C2C2C2` |
| 11 | `lib/page/mobile/provider/provider_name_page.dart` | 纯 TextField → 带 `AthenaInput` 背景容器 |
| 12 | `lib/page/mobile/chat/component/chat_configuration_dialog.dart` | 滑块 `inactiveColor` `#FFFFFF` → `#616161` |
| 12 | `lib/page/mobile/chat/chat_configuration.dart` | 同上 |

---

## 审计覆盖范围

已审计全部 22 个移动端页面文件及其 12 个共享组件：

**页面**: `home.dart`, `welcome.dart`, `sentinel_list_view.dart`, `sentinel_tile.dart`, `new_chat_button.dart`, `section_title.dart`, `recent_chat_list_view.dart`, `chat_tile.dart`, `shortcut_list_view.dart`, `shortcut_tile.dart`, `chat.dart`, `send_button.dart`, `user_input.dart`, `message_list_view.dart`, `model_selector.dart`, `sentinel_selector.dart`, `sentinel_placeholder.dart`, `chat_bottom_sheet.dart`, `chat_configuration_dialog.dart`, `edit_message_dialog.dart`, `list.dart`, `chat_export.dart`, `chat_configuration.dart`, `sentinel/list.dart`, `sentinel/form.dart`, `provider_list_page.dart`, `provider_form_page.dart`, `model_form_page.dart`, `model_list_view.dart`, `model_wall_view.dart`, `provider_name_page.dart`, `default_model_form_page.dart`, `setting.dart`, `agent_page.dart`, `data_page.dart`, `about_page.dart`, `summary_page.dart`, `summary_detail_page.dart`, `translation_page.dart`, `trpg_page.dart`

**共享组件**: `scaffold.dart`, `app_bar.dart`, `button.dart`, `tag.dart`, `input.dart`, `dialog.dart`, `bottom_sheet_tile.dart`, `color_util.dart`, `tile.dart`, `checkbox.dart`, `form_tile_label.dart`, `divider.dart`
