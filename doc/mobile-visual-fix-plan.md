# 移动端视觉修复计划

> 基于 `doc/mobile-visual-audit.md` 审计报告
> 规划日期：2026-06-10
> 参考规范：`/DESIGN.md`

---

## 目录

1. [修复原则](#1-修复原则)
2. [阶段一：共享组件修复（影响全域）](#2-阶段一共享组件修复影响全域)
3. [阶段二：品牌签名修复（高优先级页面）](#3-阶段二品牌签名修复高优先级页面)
4. [阶段三：一致性修复（中优先级页面）](#4-阶段三一致性修复中优先级页面)
5. [阶段四：细节打磨（低优先级）](#5-阶段四细节打磨低优先级)
6. [执行依赖图](#6-执行依赖图)
7. [测试清单](#7-测试清单)
8. [工时估算](#8-工时估算)

---

## 1. 修复原则

每项修复遵循以下优先级裁决（与 DESIGN.md Priority Rules 对齐）：

1. **先保留 Athena 的品牌签名**：Tag 渐变边框、白色 CTA 光晕优先于局部装饰。
2. **再保留克制感**：当"更强视觉冲击"和"更安静的专业工具感"冲突时，选后者。
3. **再考虑层次强化**：优先增加明暗和结构，而非新增颜色。
4. **不新增 token**：所有修复仅使用现有 ColorUtil 常量、现有圆角等级、现有组件变体。

每项修复标注：

- **影响范围**：单文件 / 多文件 / 全域
- **回归风险**：低（纯视觉）/ 中（行为耦合）/ 高（结构重写）
- **验收标准**：可量化的视觉对比

---

## 2. 阶段一：共享组件修复（影响全域）

> 先修共享组件，再修页面。共享组件变更自动惠及所有引用方，减少后续重复工作。

---

### 修复 5：`AthenaInput` 添加 Canonical 描边

- **文件**: `lib/widget/input.dart`
- **影响范围**: 全域（所有使用 `AthenaInput` 的页面）
- **回归风险**: 低（纯视觉，加一行 border）
- **审计编号**: #5

**现状**:
```dart
var boxDecoration = BoxDecoration(
  color: ColorUtil.FFADADAD.withValues(alpha: 0.6),
  borderRadius: BorderRadius.circular(widget.radius ?? 24),
);
```

**目标**:
```dart
var boxDecoration = BoxDecoration(
  color: ColorUtil.FFADADAD.withValues(alpha: 0.6),
  borderRadius: BorderRadius.circular(widget.radius ?? 24),
  border: Border.all(color: ColorUtil.FF757575),
);
```

**DESIGN.md 依据**:
> "Border: `1px solid #757575`"

**验收标准**:
- `AthenaInput` 在所有页面上都显示 1px `#757575` 实线边框
- 不影响 `AthenaInput` 的功能属性（focus、onSubmitted、obscureText 等）

**注意事项**:
- `UserInput`（chat composer）使用独立的 `ShapeDecoration`，不经过 `AthenaInput`，需单独修复或保留例外（DESIGN.md 明确允许 Composer Input 例外）
- 确认 `DefaultModelFormPage` 中的 `_ModelDropdown` 不受影响（它手动构造了同色 BoxDecoration，并非复用 AthenaInput）

---

### 修复 8：`_InputDialog` 改用 `AthenaInput`

- **文件**: `lib/widget/dialog.dart` → `_InputDialog` 类
- **影响范围**: 所有使用 `AthenaDialog.input()` 的移动端场景（重命名聊天、重命名 Sentinel 等）
- **回归风险**: 中（需保留 autofocus、初始值、确认/取消逻辑）
- **审计编号**: #8

**现状**:
```dart
var inputDecoration = InputDecoration(
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: ColorUtil.FF616161),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: ColorUtil.FF616161),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: ColorUtil.FFFFFFFF),
  ),
  filled: true,
  fillColor: ColorUtil.FF616161,
  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
);
var textField = TextField(
  controller: controller,
  autofocus: true,
  decoration: inputDecoration,
  style: TextStyle(color: ColorUtil.FFFFFFFF),
);
```

**目标**: 用 `AthenaInput` 替换整个 `TextField` + `InputDecoration`：
```dart
var input = AthenaInput(
  controller: controller,
  autoFocus: true,
);
```

**完整 diff**: `_InputDialog.build()` 内，将 `textField` 变量替换为 `input`。`children` 列表中的 `textField` 引用同步替换。

**验收标准**:
- 重命名聊天：底部弹窗中的输入框使用 `rgba(173,173,173,0.6)` 背景 + radius 24
- autofocus 行为不变
- 确认/取消按钮交互不变
- 初始值回填不变

**注意事项**:
- 同时检查和同步修复桌面端的 `_DesktopInputDialog`（它已使用 `AthenaInput`，无需改动 ✅）
- `AthenaInput` 需要确认支持 `autoFocus`（当前已有 `autoFocus` 参数 ✅）

---

### 修复 12：Slider `inactiveColor` 统一调整

- **文件**:
  - `lib/page/mobile/chat/component/chat_configuration_dialog.dart`
  - `lib/page/mobile/chat/chat_configuration.dart`
- **影响范围**: 2 个文件
- **回归风险**: 低
- **审计编号**: #12

**现状**: 两处 Slider 均使用：
```dart
inactiveColor: ColorUtil.FFFFFFFF,
```

**目标**: 改为与深色 Athena 界面协调的中性灰色：
```dart
inactiveColor: ColorUtil.FF757575,
```

**验收标准**:
- Slider 非活跃轨道在 `#282F32` 背景上不再刺眼
- 活跃轨道 `#A7BA88` 与 thumb `#A7BA88` 保持不变

---

## 3. 阶段二：品牌签名修复（高优先级页面）

---

### 修复 1：Sentinel 列表页改为 Tag Wall 布局

- **文件**: `lib/page/mobile/sentinel/list.dart`
- **影响范围**: 单文件（`_Tile` widget 重写 + 父级布局调整）
- **回归风险**: 中（布局从 MasonryGridView 改为 Tag Wall 水平滚动）
- **审计编号**: #1

**设计决策**: Sentinel 列表页需要同时展示 name + description，标准 `AthenaTag` 只支持单行文字。两种可行方案：

| 方案 | 优点 | 缺点 |
|------|------|------|
| A: `AthenaTagButton` + child Column | 复用既有 Tag 组件，完整渐变边框 | child 内文字固定 12px，description 可能太小 |
| B: 新建 `SentinelTag` 组件 | 完全控制内部排版 | 需要新增一个组件（违背不新增 token 原则） |

**推荐方案 A**：用 `AthenaTagButton`，child 传入 name+description 的 Column，description 使用 `DefaultTextStyle.merge` 覆盖字号。这是 `AthenaTagButton` 的设计意图——它接受任意 child。

**现状** (`_Tile.build()` core):
```dart
const nameTextStyle = TextStyle(
  color: Colors.black,     // ❌ 白色卡片 + 黑色文字
  fontSize: 14,
  fontWeight: FontWeight.w500,
);
const descriptionTextStyle = TextStyle(
  color: ColorUtil.FF616161,
  fontSize: 12,
);
var children = [
  Text(sentinel.name, style: nameTextStyle),
  Text(sentinel.description, style: descriptionTextStyle),
];
var column = Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: children,
);
var boxDecoration = BoxDecoration(
  borderRadius: BorderRadius.circular(24),
  color: ColorUtil.FFFFFFFF,   // ❌ 白色卡片
);
var container = Container(
  decoration: boxDecoration,
  padding: EdgeInsets.all(12),
  child: column,
);
```

**目标**:
```dart
var nameText = Text(
  sentinel.name,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
);
var descriptionText = Text(
  sentinel.description,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
  style: TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.4,
  ),
);
var column = Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [nameText, const SizedBox(height: 4), descriptionText],
);
// AthenaTagButton 自适应 child 内容，自带渐变边框 + 深浅反转
var tag = AthenaTagButton(
  onTap: () => editSentinel(context),   // 保留 tap 导航
  child: column,
);
```

**父级布局调整**: `_buildData()` 中 `MasonryGridView.count` → `ListView` + `Wrap` 或水平滚动 `SingleChildScrollView` + `Row` + `Wrap`。Sentinel 数量通常有限（<20），用 Wrap 自动换行即可：

```dart
Widget _buildData(List<SentinelEntity> sentinels) {
  return SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: sentinels.map((s) => _Tile(sentinel: s)).toList(),
    ),
  );
}
```

**longPress 保留**: `AthenaTagButton` 需要额外包装 `GestureDetector` 处理 longPress：
```dart
return GestureDetector(
  behavior: HitTestBehavior.opaque,
  onLongPress: () => openBottomSheet(context),
  child: tag,
);
```

**验收标准**:
- Sentinel 列表页每个条目显示为渐变边框 pill 标签（深色内层 + 白色文字）
- Tap 导航到编辑页，LongPress 弹出操作菜单（与现状行为一致）
- 视觉效果与首页 `SentinelListView` 的 `SentinelTile` pill 标签风格一致
- "Add a sentinel" 按钮保持不变（已合规）

---

### 修复 2：`ChatTile` 改为 Tag 风格

- **文件**: `lib/page/mobile/home/component/chat_tile.dart`
- **影响范围**: 单文件
- **回归风险**: 低（直接替换为 `AthenaTag`，行为不变）
- **审计编号**: #2

**现状**:
```dart
const shapeDecoration = ShapeDecoration(
  color: ColorUtil.FFFFFFFF,     // ❌ CTA 白底
  shape: StadiumBorder(),
);
final body = Container(
  decoration: shapeDecoration,
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  child: Text(chat.title.isNotEmpty ? chat.title.trim() : 'New Chat'),
);
```

**目标**:
```dart
final body = AthenaTag(
  text: chat.title.isNotEmpty ? chat.title.trim() : 'New Chat',
);
```

**完整变更**: 删掉 `shapeDecoration`、`Container`、内层 `Text`，替换为 `AthenaTag`。保留外层 `GestureDetector` 的 `onTap` 和 `onLongPress` 逻辑不变。

**验收标准**:
- `ChatTile` 显示为深色内层 + 渐变边框的 pill 标签（与 `SentinelTile` 在首页的外观统一）
- Tap 进入聊天、LongPress 弹出重命名/删除菜单（行为不变）
- 不再被误认为 CTA 主操作按钮

---

### 修复 3：Agent 设置页全面 Athena 化

- **文件**: `lib/page/mobile/setting/agent_page.dart`
- **影响范围**: 单文件（几乎全部重写 build 方法 + 反馈方式）
- **回归风险**: 中（行为逻辑保留，视觉和反馈方式改变）
- **审计编号**: #3

**变更清单**:

#### 3a. 输入框：`TextField` + `OutlineInputBorder` → `AthenaInput`

三处输入（Max Iterations / Max Retries / Brave API Key）统一替换。

**现状**（以 Max Iterations 为例）:
```dart
TextField(
  controller: iterationsController,
  keyboardType: TextInputType.number,
  decoration: const InputDecoration(
    hintText: '100',
    border: OutlineInputBorder(),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  ),
),
```

**目标**:
```dart
AthenaInput(
  controller: iterationsController,
),
```

注意：当前 `AthenaInput` 不支持 `keyboardType` 参数。Max Iterations / Max Retries 需要数字键盘。有两种策略：
- **策略 A**: 给 `AthenaInput` 增加可选的 `keyboardType` 参数（推荐，改动小）
- **策略 B**: 不使用数字键盘，接受默认文本键盘（折中，输入校验证会兜底）

**推荐策略 A**：在 `lib/widget/input.dart` 中给 `AthenaInput` 增加：
```dart
final TextInputType? keyboardType;
// 在 TextField 中传递：
keyboardType: widget.keyboardType,
```

#### 3b. 保存按钮：`AthenaSecondaryButton.small` → `AthenaPrimaryButton`

三处 "Save" 按钮统一改为主要操作样式。

**现状**:
```dart
AthenaSecondaryButton.small(
  onTap: _saveIterations,
  child: const Text('Save'),
),
```

**目标**:
```dart
AthenaPrimaryButton(
  onTap: _saveIterations,
  showShadow: true,
  child: const Center(child: Text('Save')),
),
```

注意：`AthenaPrimaryButton` 的 child 不会自动居中，需要包 `Center`。

**可选优化**：将三个独立的 Save 按钮合并为页面底部的一个统一 Save 按钮（类似 Sentinel Form 的设计），但这属于交互改动，非视觉修复范围，建议保持现状。

#### 3c. 提示文字：`Colors.grey` → `ColorUtil.FFC2C2C2`

三处描述文字替换。

**现状**:
```dart
const Text(
  'Maximum number of agent loop iterations (default: 100)',
  style: TextStyle(fontSize: 13, color: Colors.grey),
),
```

**目标**:
```dart
const Text(
  'Maximum number of agent loop iterations (default: 100)',
  style: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: ColorUtil.FFC2C2C2,
  ),
),
```

#### 3d. Section 标题：18px/500 → 16px/500

**现状**:
```dart
const Text(
  'Max Iterations',
  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
),
```

**目标**:
```dart
const Text(
  'Max Iterations',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: ColorUtil.FFFFFFFF,
    height: 1.3,
  ),
),
```

#### 3e. SnackBar：默认 Material → `AthenaDialog.message`

三处 `ScaffoldMessenger.of(context).showSnackBar(...)` 替换为 `AthenaDialog.warning()` / `AthenaDialog.success()`。

**现状**:
```dart
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Please enter a valid number (minimum 1)')),
);
```

**目标**:
```dart
AthenaDialog.warning('Please enter a valid number (minimum 1)');
```

注意：`AthenaDialog.warning` 不需要 `mounted` 检查（方法内部无 context 依赖，通过 overlay 插入），但调用处如果之前有 `if (!mounted) return` 守卫则保留。

#### 3f. import 调整

新增 import：
```dart
import 'package:athena/util/color_util.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/input.dart';
```

移除不再需要的 import（如不再直接使用 `ScaffoldMessenger`，但仍需 `material.dart`）。

**验收标准**:
- 所有输入框使用 `AthenaInput` 规范外观
- 所有保存按钮为白色 CTA + 柔光阴影
- 所有文字使用 Athena token 色值（`#FFFFFF` / `#C2C2C2`）
- 成功/错误反馈使用 Athena 品牌 snackbar/message
- 页面的功能逻辑（保存、校验）不变

---

## 4. 阶段三：一致性修复（中优先级页面）

---

### 修复 4：Welcome 文字去品牌色 + 降层级

- **文件**: `lib/page/mobile/home/component/welcome.dart`
- **影响范围**: 单文件
- **回归风险**: 低
- **审计编号**: #4

**现状**:
```dart
const welcomeTextStyle = TextStyle(
  color: ColorUtil.FFA7BA88,      // ❌ Sage 绿
  fontSize: 28,                    // ❌ 远超 20px 上限
  fontWeight: FontWeight.w700,     // ❌ 远超 500 上限
);
```

**目标**:
```dart
const welcomeTextStyle = TextStyle(
  color: ColorUtil.FFFFFFFF,
  fontSize: 20,
  fontWeight: FontWeight.w500,
);
```

**验收标准**:
- 欢迎语使用白色 20px/500，与 AppBar 标题层级协调
- 不再有颜色喧宾夺主
- 时段判断逻辑（morning/afternoon/evening）保持不变

---

### 修复 6：SentinelPlaceholder 标题降层级

- **文件**: `lib/page/mobile/chat/component/sentinel_placeholder.dart`
- **影响范围**: 单文件
- **回归风险**: 低
- **审计编号**: #6

**现状**:
```dart
const nameTextStyle = TextStyle(
  color: ColorUtil.FFFFFFFF,
  fontSize: 28,                    // ❌ 远超 20px 上限
  fontWeight: FontWeight.w700,
);
```

**目标**:
```dart
const nameTextStyle = TextStyle(
  color: ColorUtil.FFFFFFFF,
  fontSize: 20,
  fontWeight: FontWeight.w500,
);
```

**验收标准**:
- 空聊天占位中的 Sentinel 名称使用 20px/500 白色文字
- 视觉上与 AppBar 标题大小一致

---

### 修复 7：ShortcutTile 切换到 Tag 体系

- **文件**: `lib/page/mobile/home/component/shortcut_tile.dart`
- **影响范围**: 单文件
- **回归风险**: 低
- **审计编号**: #7

**设计决策**: ShortcutTile 当前是 160×160 的方形卡片（`#616161` 背景），展示图标 + 标题 + 描述。要融入 Tag 体系，需要改变容器形状和色彩。

**方案**: 用 `AthenaTagButton` 包装内容列，内部文本颜色由 `AthenaTagButton` 的 `DefaultTextStyle.merge` 自动管理。调整宽度为自适应（不再固定 160×160），让 pill 自然包裹内容。

**现状**:
```dart
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(24),
    color: ColorUtil.FF616161,    // ❌ 独立视觉人格
  ),
  padding: EdgeInsets.all(12),
  height: 160,                     // ❌ 固定尺寸
  width: 160,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: ColorUtil.FFFFFFFF),
      const SizedBox(height: 4),
      Text(shortcut.name, style: ...),
      const SizedBox(height: 4),
      Expanded(
        child: Text(shortcut.description, style: ...),
      ),
    ],
  ),
)
```

**目标**: 使用 `AthenaTagButton`（child 传入内容列），图标/标题/描述垂直排列于 pill 内。保留水平滚动的 `ListView` 父布局，但去掉 `height: 160` 固定高度限制。

```dart
var content = Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Icon(icon, size: 20),          // 颜色由 AthenaTagButton 的 IconTheme 统一管理
    const SizedBox(height: 4),
    Text(shortcut.name),
    const SizedBox(height: 2),
    Text(
      shortcut.description,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  ],
);
var tag = AthenaTagButton(
  onTap: onTap,
  padding: const EdgeInsets.all(12),
  child: content,
);
```

`ShortcutListView` 中需要移除固定 `SizedBox(height: 160)` 约束，让 pill 自适应高度。

**验收标准**:
- Shortcut 入口显示为深色内层 + 渐变边框 pill，与 `SentinelTile`、`ChatTile` 形成统一的 Tag 家族
- 点击行为不变（导航到对应功能页）
- 文本颜色自动适配（未选中态白色文字）

---

### 修复 9：翻译页语言选择器去 CTA 化

- **文件**: `lib/page/mobile/translation/translation_page.dart`
- **影响范围**: 单文件（`_buildLanguageButton` 方法）
- **回归风险**: 低
- **审计编号**: #9

**现状**:
```dart
return AthenaPrimaryButton(
  onTap: () => openLanguageSelector(type),
  showShadow: false,
  child: row,
);
```

**目标**:
```dart
return AthenaSecondaryButton(
  onTap: () => openLanguageSelector(type),
  child: row,
);
```

**验收标准**:
- 语言选择器使用透明背景 + `#C2C2C2` 细边框
- 翻译按钮（底部 CTA）保持为唯一的白色光晕按钮
- 页面主次操作清晰：选择 = 次要，翻译 = 主要

---

## 5. 阶段四：细节打磨（低优先级）

---

### 修复 10：模型选择器分组标题颜色

- **文件**: `lib/page/mobile/chat/component/model_selector.dart`
- **影响范围**: 单文件
- **回归风险**: 低
- **审计编号**: #10

**现状**:
```dart
var titleTextStyle = TextStyle(
  color: ColorUtil.FFE0E0E0,   // Gray 300 = 选中 Tag 背景色
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.5,
);
```

**目标**:
```dart
var titleTextStyle = TextStyle(
  color: ColorUtil.FFC2C2C2,   // 占位符色，视觉层级更轻
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.5,
);
```

**验收标准**:
- 分组标题（如 "OpenAI"）视觉层级低于下方的模型条目
- 与 `#C2C2C2` 占位符文字的系统语义一致（低优先信息）

---

### 修复 11：Provider 名称页添加输入背景容器

- **文件**: `lib/page/mobile/provider/provider_name_page.dart`
- **影响范围**: 单文件
- **回归风险**: 低
- **审计编号**: #11

**现状**:
```dart
var textField = TextField(
  controller: controller,
  cursorColor: ColorUtil.FFFFFFFF,
  decoration: const InputDecoration.collapsed(hintText: 'Name'),
  focusNode: focusNode,
  maxLines: null,
  style: const TextStyle(color: ColorUtil.FFFFFFFF),
);
return AthenaScaffold(
  ...
  body: Padding(padding: const EdgeInsets.all(16), child: textField),
);
```

**目标**:
```dart
var input = AthenaInput(
  controller: controller,
  autoFocus: true,
  placeholder: 'Name',
);
```

注意：移除不再需要的 `focusNode` 声明和相关逻辑（`AthenaInput` 内部管理 focusNode）。

**验收标准**:
- 名称输入框使用 `rgba(173,173,173,0.6)` 半透明背景 + 24px 圆角
- autofocus 行为不变
- 提交逻辑不变

---

## 6. 执行依赖图

```
阶段一（共享组件，无依赖）
├── 修复 5: AthenaInput 加边框 ──────────────────────┐
├── 修复 8: _InputDialog → AthenaInput ──────────────┤
└── 修复 12: Slider inactiveColor ───────────────────┤
                                                      │
阶段二（品牌签名，依赖阶段一）                          │
├── 修复 1: Sentinel 列表 Tag Wall ──────────────────┤
├── 修复 2: ChatTile → Tag ──────────────────────────┤
└── 修复 3: Agent 设置页 Athena 化 ────── 依赖修复 5 ─┘
    └── 3a 需要 AthenaInput.keyboardType 扩展          │
                                                      │
阶段三（一致性，独立于阶段二）                          │
├── 修复 4: Welcome 文字                              │
├── 修复 6: SentinelPlaceholder                       │
├── 修复 7: ShortcutTile                              │
└── 修复 9: Translation 语言选择器                     │
                                                      │
阶段四（细节，完全独立）                                │
├── 修复 10: Model selector 标题色                     │
├── 修复 11: Provider name 页                         │
└── (修复 12 已在阶段一完成)                            │
```

**建议执行顺序**:
1. 修复 5 → 修复 8 → 修复 12（阶段一，一次性提交）
2. 修复 3（含 3a 的 `AthenaInput.keyboardType` 扩展） → 修复 2 → 修复 1（阶段二，逐个提交）
3. 修复 4 + 6 + 7 + 9（阶段三，可合并为一个提交）
4. 修复 10 + 11（阶段四，可合并为一个提交）

---

## 7. 测试清单

### 视觉回归测试

| 测试项 | 涉及修复 | 检查要点 |
|--------|----------|----------|
| 所有 `AthenaInput` 实例出现 `#757575` 边框 | 修复 5 | 设置页、Sentinel 表单、Provider 表单、Summary 页等 |
| Chat Composer 输入框不受边框影响 | 修复 5 | Composer 保持 `rgba(173,173,173,0.6)` 无边框（例外） |
| 重命名弹窗输入框风格一致 | 修复 8 | 聊天重命名、Sentinel 重命名 |
| Slider 轨道在深色背景上不刺眼 | 修复 12 | 聊天配置页、聊天配置弹窗 |
| Sentinel 列表页显示为 Tag Wall | 修复 1 | 渐变边框 pill，白色文字 |
| 聊天历史 pill 不再白色 | 修复 2 | 深色内层 + 渐变边框，与 SentinelTile 统一 |
| Agent 设置页全 Athena 化 | 修复 3 | AthenaInput、CTA 按钮、`#C2C2C2` 提示文字 |
| 首页欢迎语白色 20px | 修复 4 | 不再出现 Sage 绿色 28px |
| 空聊天占位 Sentinel 名 20px | 修复 6 | 与 AppBar 标题同层级 |
| Shortcut 入口显示为 pill | 修复 7 | 渐变边框，自适应宽度 |
| 翻译页语言按钮为 secondary 风格 | 修复 9 | 透明背景 + 细框，非白色 CTA |
| 模型选择器分组标题 `#C2C2C2` | 修复 10 | 视觉层级低于模型条目 |
| Provider 名称页输入有背景容器 | 修复 11 | `rgba(173,173,173,0.6)` bg |

### 行为回归测试

| 测试项 | 涉及修复 | 检查要点 |
|--------|----------|----------|
| Sentinel 列表 Tap 跳转编辑 | 修复 1 | 点击标签进入编辑页 |
| Sentinel 列表 LongPress 弹出菜单 | 修复 1 | 长按弹出编辑/删除 |
| 聊天历史 Tap 进入聊天 | 修复 2 | 点击聊天 pill 进入聊天 |
| 聊天历史 LongPress 弹出菜单 | 修复 2 | 长按弹出重命名/删除 |
| Agent 设置保存成功 | 修复 3 | Max Iterations/Retries/API Key 保存后生效 |
| Agent 设置输入校验 | 修复 3 | 非法输入弹出 warning |
| 重命名弹窗确认/取消 | 修复 8 | 确认返回新名称，取消返回 null |
| 翻译语言选择 | 修复 9 | 选择语言后按钮文字更新 |
| Provider 名称提交 | 修复 11 | 输入名称后提交创建成功 |

### 平台测试矩阵

| 平台 | 重点测试 |
|------|----------|
| iOS | 底部 safe area、sheet 弹出高度、键盘弹起时输入框位置 |
| Android | 底部 safe area、Material 默认样式残留 |
| macOS | 对话框输入框（`_DesktopInputDialog` 已用 `AthenaInput`，应无回退） |
| Linux | 同上 |
| Windows | 微软雅黑字体渲染 |

---

## 8. 工时估算

| 阶段 | 修复项 | 预估工时 | 说明 |
|------|--------|----------|------|
| 一 | 修复 5: AthenaInput 边框 | 15 min | 一行代码 |
| 一 | 修复 8: _InputDialog | 30 min | 替换 TextField→AthenaInput，验证 autofocus |
| 一 | 修复 12: Slider 颜色 | 15 min | 两处改一行 |
| 二 | 修复 3a: AthenaInput.keyboardType 扩展 | 20 min | 新增参数 + 传递 |
| 二 | 修复 3: Agent 设置页 | 1.5 h | 重写 build，替换输入/按钮/文字/反馈 |
| 二 | 修复 2: ChatTile | 20 min | 替换为 AthenaTag |
| 二 | 修复 1: Sentinel 列表 | 1 h | _Tile 重写 + 布局从 Masonry→Wrap |
| 三 | 修复 4: Welcome | 10 min | TextStyle 改三个值 |
| 三 | 修复 6: SentinelPlaceholder | 10 min | TextStyle 改两个值 |
| 三 | 修复 7: ShortcutTile | 45 min | 重写为 AthenaTagButton + 父布局调整 |
| 三 | 修复 9: Translation | 10 min | PrimaryButton→SecondaryButton |
| 四 | 修复 10: Model selector | 5 min | 色值替换 |
| 四 | 修复 11: Provider name | 15 min | TextField→AthenaInput |
| — | 全量回归测试 | 2 h | 按测试清单逐项验证 |
| **合计** | | **~7.5 h** | 约 1 人天 |

---

## 附录：涉及文件清单

| 文件路径 | 修复编号 |
|----------|----------|
| `lib/widget/input.dart` | #5, #3a |
| `lib/widget/dialog.dart` | #8 |
| `lib/page/mobile/chat/component/chat_configuration_dialog.dart` | #12 |
| `lib/page/mobile/chat/chat_configuration.dart` | #12 |
| `lib/page/mobile/sentinel/list.dart` | #1 |
| `lib/page/mobile/home/component/chat_tile.dart` | #2 |
| `lib/page/mobile/setting/agent_page.dart` | #3 |
| `lib/page/mobile/home/component/welcome.dart` | #4 |
| `lib/page/mobile/chat/component/sentinel_placeholder.dart` | #6 |
| `lib/page/mobile/home/component/shortcut_tile.dart` | #7 |
| `lib/page/mobile/home/component/shortcut_list_view.dart` | #7 (联动) |
| `lib/page/mobile/translation/translation_page.dart` | #9 |
| `lib/page/mobile/chat/component/model_selector.dart` | #10 |
| `lib/page/mobile/provider/provider_name_page.dart` | #11 |
