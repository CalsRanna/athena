# 移动端审计报告

**日期**: 2026-06-05
**版本**: 3.1.2+613
**审计范围**: `lib/page/mobile/`、相关 ViewModel、Agent 系统移动端适配、路由、UI 组件

---

## 一、总体概况

移动端共 20 个页面文件、10 个组件文件，覆盖聊天、翻译、摘要、TRPG、提供商管理、Sentinel 管理、设置、关于 8 大模块。共享桌面端的全部 ViewModel、Agent 系统、服务层和数据层。

| 维度 | 评估 | 说明 |
|---|---|---|
| 功能完整度 | 中等 | 核心聊天功能完整，但多选、置顶、Memory、图片附件等缺失 |
| UI/UX 质量 | 良好 | 深色主题统一，但权限审批、工具调用展示体验不足 |
| 代码质量 | 中等 | 架构分层清晰，但存在 signals/setState 混用和 GetIt 直接调用 |
| Agent 集成 | 良好 | Agent 循环完整，权限系统可用，但工具调用无 UI 展示 |
| 性能 | 未验证 | 无移动端性能测试，长列表、大消息量场景未覆盖 |
| 测试覆盖 | 差 | 零移动端专属测试 |
| 安全性 | 中等 | SQLite 明文存储，移动端无生物认证保护 |
| 可维护性 | 良好 | 页面组件化拆分合理，但部分文件过长（chat.dart 555行） |

---

## 二、功能完整度分析

### 2.1 移动端已有功能（20 页面）

| 页面 | 文件 | 行数 | 状态 |
|---|---|---|---|
| 主页 | `home/home.dart` | 469 | 完成 |
| 聊天页 | `chat/chat.dart` | 555 | 完成 |
| 聊天列表 | `chat/list.dart` | 153 | 完成 |
| 聊天配置 | `chat/chat_configuration.dart` | - | 完成 |
| 聊天导出 | `chat/chat_export.dart` | - | 完成 |
| 翻译页 | `translation/translation_page.dart` | - | 完成 |
| 网页摘要 | `summary/summary_page.dart` | - | 完成 |
| 摘要详情 | `summary/summary_detail_page.dart` | - | 完成 |
| TRPG 游戏 | `trpg/trpg_page.dart` | - | 完成 |
| 提供商列表 | `provider/provider_list_page.dart` | - | 完成 |
| 提供商表单 | `provider/provider_form_page.dart` | - | 完成 |
| 新建提供商 | `provider/provider_name_page.dart` | - | 完成 |
| 模型表单 | `provider/model_form_page.dart` | - | 完成 |
| Sentinel 列表 | `sentinel/list.dart` | - | 完成 |
| Sentinel 表单 | `sentinel/form.dart` | - | 完成 |
| 设置主页 | `setting/setting.dart` | - | 完成 |
| Agent 设置 | `setting/agent_page.dart` | - | 完成 |
| 数据管理 | `setting/data_page.dart` | - | 完成 |
| 关于页 | `about/about_page.dart` | - | 完成 |
| 默认模型 | `default_model.dart/default_model_form_page.dart` | - | 完成 |

### 2.2 桌面端有、移动端缺失的功能

| 功能 | 桌面端实现 | 影响程度 | 建议 |
|---|---|---|---|
| **工具调用卡片展示** | `desktop/home/component/tool_card.dart` | 高 | 核心体验缺失，Agent 执行工具时用户看不到过程 |
| **Memory 长期记忆** | `desktop/setting/memory/memory.dart` | 中 | MemoryViewModel 已就绪，仅缺 UI 页面 |
| **高级设置** | `desktop/setting/advanced_page.dart` | 低 | 桌面端专有（窗口管理、快捷键等） |
| **聊天多选操作** | `chat_context_menu.dart` | 中 | ChatSelectionDelegate 已存在，仅缺移动端 UI |
| **聊天置顶** | 桌面端右键菜单 | 中 | `togglePin()` 方法存在但移动端无入口 |
| **图片附件** | `image_selector.dart` | 中 | 无法在消息中附加图片 |
| **右键上下文菜单** | `chat_context_menu.dart`, `message_context_menu.dart` | 低 | 移动端已用长按替代 |
| **审批弹窗** | `approval_dialog.dart` | 中 | 移动端用通用 Dialog 代替，体验不够好 |

### 2.3 移动端有、桌面端缺失的功能

| 功能 | 说明 |
|---|---|
| 翻译页面 | 独立的翻译模块，支持语言选择和流式翻译 |
| 网页摘要 | URL 内容解析和 AI 摘要生成 |
| TRPG 游戏 | AI 地下城主文字游戏 |
| 聊天导出图片 | 将聊天渲染为 PNG 并保存 |
| 模型墙视图 | 3 列网格展示模型 |
| Sentinel AI 生成 | 一键生成名称/描述/完整信息 |

> **建议**: 翻译、摘要、TRPG 三个功能模块理论上与平台无关，后续应统一到共享 UI，同时适配桌面端和移动端。

---

## 三、UI/UX 审计

### 3.1 优点

- **统一的深色主题**: 背景色 `FF282F32`，白色文字 + 灰色副文字体系一致
- **响应式状态绑定**: 使用 `Watch` widget 自动响应 signals 变化
- **安全区域适配**: `SafeArea` + `MediaQuery.padding.top` 处理刘海屏
- **触觉反馈**: 长按操作使用 `HapticFeedback.heavyImpact()`
- **底部操作面板**: 聊天配置使用 `AthenaDialog.show()` 展示底部面板
- **胶囊形按钮**: 大量使用 `StadiumBorder` 风格统一

### 3.2 问题

| # | 问题 | 严重程度 | 位置 | 建议 |
|---|---|---|---|---|
| U1 | 工具调用无 UI 卡片展示 | 高 | `chat/chat.dart` | 实现移动端 ToolCard 组件，在消息流中内联展示工具调用状态 |
| U2 | 权限审批用通用 Dialog | 中 | `agent/permission/` | 设计移动端专用审批底部面板，区分危险/安全操作 |
| U3 | 聊天标题栏重命名无视觉反馈（仅 loading 图标） | 低 | `chat/chat.dart:L246-265` | AI 重命名时显示进度动画或骨架屏 |
| U4 | Sentinel 占位页过于简陋 | 低 | `chat/chat.dart:L459-491` | 仅显示名称和描述，可增加能力列表或建议问题 |
| U5 | 主页快捷方式 "Food" 和 "Code" 点击无响应 | 中 | `home/home.dart:L370-376` | switch 语句只有 Translation/Summary/TRPG 三个路由，"Food" 和 "Code" 映射到 null，点击无效 |
| U6 | 无下拉刷新 | 低 | `chat/list.dart` | 聊天列表页无法下拉刷新 |
| U7 | 无滑动返回手势冲突处理 | 低 | 全局 | iOS 滑动返回可能与聊天内滑动冲突 |
| U8 | 键盘弹起时输入框可能被遮挡 | 中 | `chat/chat.dart` | 未使用 `MediaQuery.viewInsets` 处理键盘避让 |
| U9 | 无平板/折叠屏适配 | 低 | 全局 | 大屏设备未利用额外空间，完全是手机布局 |
| U10 | 无横屏布局 | 低 | 全局 | 所有页面均按竖屏设计 |

### 3.3 U5 详查：主页快捷方式死点击

```dart
// home/home.dart:L370-376
PageRouteInfo? route = switch (shortcut.name) {
  'Translation' => MobileTranslationRoute(),
  'Summary' => MobileSummaryRoute(),
  'TRPG' => MobileTRPGRoute(),
  _ => null,  // "Food" 和 "Code" 走到这里，点击无效
};
if (route != null) route.push(context);
```

"Food" 和 "Code" 快捷方式定义了图标和描述，但点击后不做任何事情。应移除或创建对应的聊天快捷入口。

---

## 四、代码质量审计

### 4.1 架构分层

```
UI (page/mobile/) → ViewModel → Service → Repository → Database
                 → Agent (AgentService/Tool/Permission/Skill)
```

架构分层清晰，与桌面端共享完整的业务逻辑层，移动端仅负责 UI 展示。

### 4.2 问题

| # | 问题 | 严重程度 | 位置 | 建议 |
|---|---|---|---|---|
| C1 | **signals/setState 混用** | 中 | `chat/chat.dart:L341` | `sendMessage()` 中用 `setState` 更新 `_currentChatId`，应用 signal 替代 |
| C2 | **直接调用 GetIt.instance** | 中 | 全部移动端页面 | ViewModel 未通过构造注入，直接使用 GetIt 服务定位器。这与桌面端已完成的构造注入重构不一致 |
| C3 | **chat.dart 过长 (555行)** | 中 | `chat/chat.dart` | 包含 6 个类定义，应拆分为独立文件 |
| C4 | **_MessageListView 通过 GetIt 获取 ViewModel** | 低 | `chat/chat.dart:L53-54` | 作为独立 StatefulWidget 仍直接获取 GetIt，应通过参数传入 |
| C5 | **home.dart 内联 6 个私有 Widget 类** | 低 | `home/home.dart` | 应将 `_ChatTile`、`_SentinelTile`、`_ShortcutTile` 等提取到 component/ |
| C6 | **翻译/摘要/TRPG ViewModel 未在桌面端复用** | 低 | `lib/view_model/` | 这些 ViewModel 本身是平台无关的，但桌面端没有对应 UI |
| C7 | **未使用 `const` 构造函数优化** | 低 | 多处 | 部分可声明为 const 的构造函数未声明 |
| C8 | **缺少错误边界处理** | 中 | 全部移动端页面 | Widget 无 error boundary，ViewModel 异常可能直接导致页面崩溃 |

### 4.3 C2 详查：GetIt 直接调用模式

```dart
// 当前移动端模式（服务定位器）
final chatViewModel = GetIt.instance<ChatViewModel>();

// 桌面端已改为构造注入
// lib/page/desktop/home/home_page.dart 通过构造参数接收 ViewModel
```

桌面端已完成从 GetIt 服务定位器到构造注入的重构（commit `33086ce`），但移动端页面尚未跟进。

### 4.4 C1 详查：signals/setState 混用

```dart
// chat/chat.dart:L332-344
Future<void> sendMessage(ChatEntity? chat) async {
  final text = controller.text;
  if (text.isEmpty) return;
  controller.clear();

  if (chat == null) {
    chat = await viewModel.createChat();
    if (chat == null) return;
    setState(() {  // ← 这里用 setState
      _currentChatId = chat!.id;
    });
  }
  // ...
}
```

`_currentChatId` 用于追踪当前聊天 ID，但使用 `setState` 而非 signal。在桌面端改造成 signal 或直接利用 `viewModel.currentChat` signal 即可消除。

---

## 五、Agent 系统移动端适配

### 5.1 当前状态

Agent 系统（AgentService、ToolRegistry、PermissionService、SkillRegistry）是平台无关的共享代码，移动端完整继承了以下能力：

- 完整的 Agent 推理循环（多轮迭代）
- 11 个内置工具（按平台选择 bash/powershell 和 unix_search/powershell_search）
- 三层权限模型（工具等级 × Skill 硬下限 × 用户规则）
- Skill 系统（三级渐进式加载 + 信任模型）
- 流式响应（Reasoning/Text/ToolCall/ToolResult/Done 事件）

### 5.2 移动端特有问题

| # | 问题 | 严重程度 | 建议 |
|---|---|---|---|
| A1 | 工具调用无 UI 展示 | 高 | 实现移动端 ToolCard，显示工具名、参数、执行状态、结果 |
| A2 | 权限审批缺乏移动端优化 | 中 | 桌面端有专用 ApprovalDialog，移动端用通用底部面板，应设计移动端审批 UI |
| A3 | 长推理无进度展示 | 中 | Agent 多轮迭代时用户仅看到加载状态，无当前步骤信息 |
| A4 | 后台被杀后无恢复机制 | 中 | AI 推理可能耗时较长，App 进入后台或被杀后对话状态丢失 |
| A5 | Shell 工具在移动端权限过高 | 高 | iOS/Android 上 bash/powershell 工具几乎无实际用途但有安全风险，应平台禁用 |
| A6 | 文件操作工具在移动端受限 | 中 | Android/iOS 沙盒限制下文件操作语义不同，需适配 |
| A7 | web_search 需要 API Key | 低 | Brave Search API Key 在移动端需手动配置，无引导 |

### 5.3 A5 详查：Shell 工具在移动端的风险

当前工具注册（`di.dart:L170-186`）仅按 Windows/非Windows 区分 shell 和 search 工具：

```dart
isWindows
    ? PowerShellShellTool(sandbox: sandbox)
    : BashShellTool(sandbox: sandbox),
```

iOS/Android 上会注册 `BashShellTool`，但移动端沙盒环境下 shell 命令执行能力极为有限且风险较高。建议在移动端禁用 shell 和文件操作工具，或将其危险等级提升为 `forbidden`。

---

## 六、性能审计

### 6.1 潜在问题

| # | 问题 | 影响 | 位置 |
|---|---|---|---|
| P1 | 消息列表无虚拟化优化 | 长会话（>100条消息）可能卡顿 | `chat/chat.dart:ListView` |
| P2 | `Watch` 重建范围过大 | 整个聊天页在一个 Watch 下重建 | `chat/chat.dart:L192` |
| P3 | 图片资源无缓存策略 | 头像、图标重复加载 | - |
| P4 | 数据库主线程操作 | 大量消息查询可能阻塞 UI | ViewModel 层 |
| P5 | 翻译历史无分页 | 翻译记录增多后列表变慢 | `translation_page.dart` |
| P6 | 摘要历史无分页 | 同上 | `summary_page.dart` |

### 6.2 P1/P2 详查：消息列表性能

```dart
// chat/chat.dart:L68-94 - 整个消息列表在一个 Watch 下
return Watch((context) {
  // 每次任何 signal 更新都重建整个列表
  var messages = viewModel.messages.value
      .where((m) => m.chatId == widget.chat.id)
      .toList();
  // ...
  return ListView.separated(/* ... */);
});
```

当流式接收消息时，`messages` signal 频繁更新，导致整个列表重建。应使用 `itemBuilder` 级别的细粒度 Watch 或 `ListView.builder` 的 key 优化。

---

## 七、测试覆盖审计

### 7.1 现状

- 项目共 32 个测试文件
- **零移动端专属测试**
- 零 Widget/UI 测试
- 测试主要集中在 Agent 系统和服务层

### 7.2 建议补充的测试

| 优先级 | 测试类型 | 范围 |
|---|---|---|
| 高 | ChatViewModel 集成测试 | 移动端路径的 sendMessage 流程 |
| 高 | 移动端路由测试 | 所有 Mobile*Route 的导航逻辑 |
| 中 | 移动端页面 Widget 测试 | 核心页面（chat/home/list）的渲染 |
| 中 | 权限审批 UI 测试 | 移动端权限交互流程 |
| 低 | Golden 测试 | 关键页面的视觉回归 |

---

## 八、安全性审计

| # | 问题 | 严重程度 | 建议 |
|---|---|---|---|
| S1 | 无生物认证保护 | 低 | 打开 App 无 FaceID/指纹保护 |
| S2 | Shell 工具在移动端可用 | 高 | 见 A5，应平台禁用 |
| S3 | 剪贴板无自动清理 | 低 | 聊天内容可能包含敏感信息，应定时清理剪贴板 |

> **关于数据存储安全:** API Key 和 SQLite 数据库存储在应用沙盒私有目录中，iOS/Android 系统级沙盒已阻止其他 App 访问。对于本地 AI 聊天应用，现有保护足够，无需引入 flutter_secure_storage 或 sqlcipher。

---

## 九、可维护性

### 9.1 优点

- 页面按功能模块目录组织清晰
- 组件（component/）与页面分离
- 共享 Widget 系统（`lib/widget/`）设计合理
- 路由使用 auto_route 声明式管理

### 9.2 改进建议

| # | 建议 |
|---|---|
| M1 | `chat/chat.dart` (555行) 拆分为 `chat_page.dart` + `message_list.dart` + `user_input.dart` + `send_button.dart` + `sentinel_placeholder.dart` |
| M2 | `home/home.dart` (469行) 中的私有 Widget 提取到 `home/component/` |
| M3 | 移动端页面统一构造注入 ViewModel，消除 GetIt 直接调用 |
| M4 | 共享业务功能（翻译、摘要、TRPG）的 UI 抽象为跨平台组件 |
| M5 | 统一移动端/桌面端路由命名（去掉 Mobile 前缀，通过路由参数区分平台） |

---

## 十、问题优先级汇总

### 高优先级（建议立即处理）

| 编号 | 问题 | 类别 |
|---|---|---|
| A5 | Shell 工具在移动端应禁用 | 安全 |
| U1 | 工具调用无 UI 卡片展示 | 体验 |
| U5 | 主页 "Food"/"Code" 快捷方式点击无效 | Bug |

### 中优先级（建议近期处理）

| 编号 | 问题 | 类别 |
|---|---|---|
| C1 | signals/setState 混用 | 代码质量 |
| C2 | GetIt 直接调用未改为构造注入 | 代码质量 |
| A2 | 权限审批缺乏移动端优化 | 体验 |
| U8 | 键盘弹起时输入框可能被遮挡 | 体验 |
| P1 | 消息列表无虚拟化优化 | 性能 |
| U2 | 工具调用 UI 缺失 | 体验 |
| C8 | 缺少错误边界处理 | 代码质量 |

### 低优先级（后续迭代处理）

| 编号 | 问题 | 类别 |
|---|---|---|
| U9 | 无平板/折叠屏适配 | 体验 |
| U10 | 无横屏布局 | 体验 |
| S3 | 无生物认证保护 | 安全 |
| P3-P6 | 图片缓存、数据库线程等 | 性能 |
| 测试 | 零移动端测试覆盖 | 质量保障 |
| M1-M5 | 可维护性改进 | 技术债务 |

---

## 十一、总结

移动端功能骨架完整，核心聊天能力和 Agent 系统已可用。主要短板集中在三个方面：

1. **Agent 工具调用的 UI 展示缺失** — Agent 在移动端执行工具时用户看不到任何过程，这是最影响体验的缺陷
2. **Shell/文件工具在移动端未禁用** — iOS/Android 上注册了 BashShellTool 等桌面端工具，无实际用途但有安全风险
3. **代码质量与桌面端差距** — 桌面端已完成构造注入重构，但移动端仍使用 GetIt 服务定位器模式，且存在 signals/setState 混用

建议按高→中→低优先级分三批处理，先解决安全和明显 Bug，再逐步提升体验和完善代码质量。
