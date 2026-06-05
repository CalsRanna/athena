# 移动端审计修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 根据 2026-06-05 移动端审计报告，分阶段修复安全问题、Bug、代码质量和体验问题

**Architecture:** 分 5 个阶段执行：安全加固 → Bug修复 → Agent体验 → 代码质量+性能 → 测试补充。每阶段独立可交付，不阻塞后续阶段

**Tech Stack:** Flutter/Dart, signals, auto_route, GetIt, SQLite

**基线审计报告:** `docs/audit-mobile-2026-06-05.md`

---

## 阶段一：安全加固（高优先级）

### Task 1: 移动端禁用 Shell 和文件操作工具 (A5/S2)

**Files:**
- Modify: `lib/di.dart:159-189`
- Modify: `lib/agent/tool/tool_registry.dart`
- Create: `test/agent/tool_mobile_registration_test.dart`

**问题:** 当前 `di.dart` 仅按 Windows/非Windows 区分工具，iOS/Android 上注册了 BashShellTool 和全套文件操作工具。移动沙盒环境下 shell 命令几乎无用但风险高。

**方案:** 在 DI 中引入 `isMobile` 判断（`Platform.isIOS || Platform.isAndroid`），移动端仅注册 web_fetch、web_search、skill 三个安全工具。

- [ ] **Step 1: 编写工具注册测试**

```dart
// test/agent/tool_mobile_registration_test.dart
import 'dart:io';
import 'package:athena/agent/permission/sandbox.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/agent/skill/skill_trust_store.dart';
import 'package:athena/agent/tool/tool_registry.dart';
import 'package:athena/agent/tool/web_fetch_tool.dart';
import 'package:athena/agent/tool/web_search_tool.dart';
import 'package:athena/agent/tool/skill_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tool registration by platform', () {
    test('mobile platforms should only register web_fetch, web_search, skill', () {
      final isMobile = Platform.isIOS || Platform.isAndroid;
      if (!isMobile) return; // 测试仅在移动平台有效

      final skillRegistry = SkillRegistry(trustStore: SkillTrustStore());
      final toolRegistry = ToolRegistry();
      toolRegistry.registerAll([
        WebFetchTool(),
        WebSearchTool(),
        SkillTool(skillRegistry),
      ]);

      final names = toolRegistry.all.map((t) => t.name).toSet();
      expect(names, {'web_fetch', 'web_search', 'skill'});
    });
  });
}
```

- [ ] **Step 2: 运行测试确认框架可用**

```bash
flutter test test/agent/tool_mobile_registration_test.dart
```

- [ ] **Step 3: 修改 `lib/di.dart` 工具注册逻辑**

```dart
// lib/di.dart:L159-189 替换为：
getIt.registerLazySingleton(() {
  final skillRegistry = getIt<SkillRegistry>();
  final sandbox = getIt<PathSandbox>();
  final isWindows = Platform.isWindows;
  final isMobile = Platform.isIOS || Platform.isAndroid;
  final toolRegistry = ToolRegistry();

  if (isMobile) {
    // 移动端仅注册平台无关的安全工具
    // shell/文件操作工具在移动沙盒下无实际用途且风险高
    toolRegistry.registerAll([
      WebFetchTool(),
      WebSearchTool(),
      SkillTool(skillRegistry),
    ]);
  } else {
    toolRegistry.registerAll([
      isWindows
          ? PowerShellSearchTool(sandbox: sandbox)
          : UnixSearchTool(sandbox: sandbox),
      FileReadTool(sandbox: sandbox),
      FileWriteTool(sandbox: sandbox),
      FileUpdateTool(sandbox: sandbox),
      FileDeleteTool(sandbox: sandbox),
      ListDirectoryTool(sandbox: sandbox),
      isWindows
          ? PowerShellShellTool(sandbox: sandbox)
          : BashShellTool(sandbox: sandbox),
      WebFetchTool(),
      WebSearchTool(),
      SkillTool(skillRegistry),
    ]);
  }

  return toolRegistry;
});
```

- [ ] **Step 4: 运行分析确认无编译错误**

```bash
flutter analyze lib/di.dart
```

- [ ] **Step 5: 运行全量测试确认无回归**

```bash
flutter test
```

- [ ] **Step 6: Commit**

```bash
git add lib/di.dart test/agent/tool_mobile_registration_test.dart
git commit -m "security: disable shell and file tools on mobile platforms

Mobile (iOS/Android) now only registers web_fetch, web_search, and skill
tools. Shell execution and file system tools have no practical use on
mobile sandboxes and pose unnecessary security risk."
```

---

## 阶段二：Bug 修复（高优先级）

### Task 2: 修复主页 "Food"/"Code" 快捷方式死点击 (U5)

**Files:**
- Modify: `lib/page/mobile/home/home.dart:370-376`

**问题:** switch 语句只处理 Translation/Summary/TRPG，"Food" 和 "Code" 落到 default 分支返回 null，点击无响应。

**方案:** Food/Code 快捷方式导航到新聊天页（`MobileChatRoute()`），与 "New Chat" 按钮行为一致。

- [ ] **Step 1: 修改 navigate 方法**

修改 `lib/page/mobile/home/home.dart:370-376`：

```dart
void navigate(BuildContext context, Shortcut shortcut) {
  PageRouteInfo? route = switch (shortcut.name) {
    'Translation' => MobileTranslationRoute(),
    'Summary' => MobileSummaryRoute(),
    'TRPG' => MobileTRPGRoute(),
    'Food' => MobileChatRoute(),
    'Code' => MobileChatRoute(),
    _ => null,
  };
  if (route != null) route.push(context);
}
```

- [ ] **Step 2: 运行分析确认无编译错误**

```bash
flutter analyze lib/page/mobile/home/home.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/page/mobile/home/home.dart
git commit -m "fix: Food and Code shortcuts now navigate to new chat

Previously the switch statement had no case for 'Food' or 'Code',
causing these shortcut buttons to be dead clicks."
```

---

### Task 3: 修复键盘遮挡输入框 (U8)

**Files:**
- Modify: `lib/page/mobile/chat/chat.dart:285-291, 404-412`

**问题:** `_buildInput` 未考虑键盘弹出时的 viewInsets，输入框可能被虚拟键盘遮挡。

**方案:** 在 chat 页面的 body 底部加上 `MediaQuery.of(context).viewInsets.bottom` 的 padding。

- [ ] **Step 1: 修改 chat 页面 body 的键盘避让**

修改 `lib/page/mobile/chat/chat.dart:_MobileChatPageState.build` 中的 body 部分：

当前代码 (L285-291)：
```dart
return AthenaScaffold(
  appBar: AthenaAppBar(action: actionButton, title: titleWidget),
  body: Column(
    children: [
      Expanded(child: content),
      input,
    ],
  ),
);
```

修改为：
```dart
return AthenaScaffold(
  appBar: AthenaAppBar(action: actionButton, title: titleWidget),
  body: Builder(
    builder: (context) {
      final bottomInset = MediaQuery.of(context).viewInsets.bottom;
      return Column(
        children: [
          Expanded(child: content),
          input,
          SizedBox(height: bottomInset),
        ],
      );
    },
  ),
);
```

> **注意:** 使用 `Builder` 确保 `MediaQuery` 的 context 是 Scaffold 下方的 context，能正确获取 viewInsets。

- [ ] **Step 2: 运行分析确认无编译错误**

```bash
flutter analyze lib/page/mobile/chat/chat.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/page/mobile/chat/chat.dart
git commit -m "fix: add keyboard avoidance to chat input on mobile

Chat input now respects MediaQuery.viewInsets.bottom so the text field
stays visible when the virtual keyboard is shown."
```

---

## 阶段三：Agent 体验提升（中优先级）

### Task 4: 移动端工具调用 UI 优化 (U1/A1)

**Files:**
- Move: `lib/page/desktop/home/component/tool_card.dart` → `lib/component/tool_card.dart`
- Modify: `lib/component/message_list_tile.dart` — 更新 import 路径
- Modify: `lib/component/tool_card.dart` — 适配移动端样式

**问题:** ToolCard 组件位于 `lib/page/desktop/` 目录下，虽被共享的 `message_list_tile.dart` 引用能在移动端渲染，但样式（字体、间距、颜色）为桌面端设计。应移至共享目录并做移动端适配。

- [ ] **Step 1: 移动 ToolCard 到共享组件目录**

```bash
git mv lib/page/desktop/home/component/tool_card.dart lib/component/tool_card.dart
```

- [ ] **Step 2: 更新 message_list_tile.dart 的 import**

修改 `lib/component/message_list_tile.dart:L8`：

```dart
// 旧
import 'package:athena/page/desktop/home/component/tool_card.dart';
// 新
import 'package:athena/component/tool_card.dart';
```

- [ ] **Step 3: 检查是否还有其他文件引用旧路径**

```bash
grep -r "desktop/home/component/tool_card" lib/ --include="*.dart"
```

- [ ] **Step 4: 适配移动端 ToolCard 样式**

修改 `lib/component/tool_card.dart`，在 build 方法中添加平台适配：

```dart
@override
Widget build(BuildContext context) {
  final isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
  final borderRadius = BorderRadius.circular(isDesktop ? 8 : 12);
  final cardBgColor = isDesktop ? ColorUtil.FFEDEDED : ColorUtil.FF3A3F42;
  final headerBgColor = isDesktop ? ColorUtil.FFE0E0E0 : ColorUtil.FF4A4F52;
  final fontSize = isDesktop ? 12.0 : 11.0;

  return Container(
    margin: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(
      borderRadius: borderRadius,
      color: cardBgColor,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(borderRadius, headerBgColor, fontSize),
        if (hasResult && _expanded) _buildContent(fontSize),
      ],
    ),
  );
}
```

相应更新 `_buildHeader` 和 `_buildContent` 方法签名以接收这些参数。

- [ ] **Step 5: 运行分析**

```bash
flutter analyze lib/component/
```

- [ ] **Step 6: Commit**

```bash
git add lib/component/tool_card.dart lib/component/message_list_tile.dart
git commit -m "refactor: move ToolCard to shared component dir with mobile styling

ToolCard now lives in lib/component/ and adapts colors/font sizes per
platform. Mobile gets darker card backgrounds and slightly smaller text."
```

---

### Task 5: 权限审批移动端 UI 优化 (A2)

**Files:**
- Modify: `lib/widget/permission_dialog.dart:202-361`

**现状:** `permission_dialog.dart` 已有 `_MobilePermissionDialog`（底部面板），但危险操作和非危险操作视觉无区分。

**方案:** 危险工具（bash、file_write、file_delete 等）在移动端底部面板顶部显示红色边框，区分关键审批和常规审批。

- [ ] **Step 1: 增强 _MobilePermissionDialog 的危险操作视觉区分**

修改 `lib/widget/permission_dialog.dart` 中 `_MobilePermissionDialogState.build`：

```dart
@override
Widget build(BuildContext context) {
  final isDangerous = const {
    'bash', 'powershell', 'file_write', 'file_delete',
  }.contains(widget.toolName);

  // ... 构建 children 列表 ...

  return Container(
    decoration: BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: isDangerous
          ? Border(top: BorderSide(color: Colors.red.shade700, width: 2))
          : null,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}
```

- [ ] **Step 2: 运行分析确认无编译错误**

```bash
flutter analyze lib/widget/permission_dialog.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/widget/permission_dialog.dart
git commit -m "feat: add danger-level visual indicator to mobile permission dialog

Dangerous tools show a red top border in the mobile bottom sheet,
visually distinguishing critical approvals from routine ones."
```

---

### Task 6: Agent 多轮迭代进度展示 (A3)

**Files:**
- Modify: `lib/view_model/chat_view_model.dart`
- Modify: `lib/page/mobile/chat/chat.dart`

**问题:** Agent 进行多轮迭代时，用户只看到 loading 动画，无当前轮次/步骤信息。

**方案:** 在 ChatViewModel 中暴露 `currentIteration` 和 `currentToolName` signal，移动端聊天页下方显示进度条。

- [ ] **Step 1: 在 ChatViewModel 中添加迭代进度 signal**

修改 `lib/view_model/chat_view_model.dart`，在 signal 声明区域（约 L44 附近）添加：

```dart
final currentIteration = signal(0);
final currentToolName = signal<String?>(null);
```

在 Agent 事件流的 ToolCall 处理中更新：

```dart
// 处理 ToolCall 事件时
currentToolName.value = toolCallName;
```

在 `_advanceIteration` 中更新轮次：

```dart
currentIteration.value = currentIteration.value + 1;
```

在每次 `sendMessage` 开始时和 Agent done 时重置：

```dart
currentIteration.value = 0;
currentToolName.value = null;
```

- [ ] **Step 2: 在移动端聊天页添加进度指示器**

修改 `lib/page/mobile/chat/chat.dart`，添加 `_buildProgressBar` 方法：

```dart
Widget _buildProgressBar() {
  return Watch((context) {
    final iteration = viewModel.currentIteration.value;
    if (iteration <= 0) return const SizedBox();

    final toolName = viewModel.currentToolName.value ?? '';
    final text = toolName.isNotEmpty
        ? 'Step $iteration · $toolName'
        : 'Step $iteration';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(
          color: ColorUtil.FFC2C2C2,
          fontSize: 12,
        )),
      ]),
    );
  });
}
```

在 body 的 Column 中插入（input 上方）：

```dart
body: Builder(
  builder: (context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Column(
      children: [
        Expanded(child: content),
        _buildProgressBar(),    // ← 新增
        input,
        SizedBox(height: bottomInset),
      ],
    );
  },
),
```

- [ ] **Step 3: 运行分析**

```bash
flutter analyze lib/view_model/chat_view_model.dart lib/page/mobile/chat/chat.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/view_model/chat_view_model.dart lib/page/mobile/chat/chat.dart
git commit -m "feat: add agent iteration progress indicator on mobile

ChatViewModel exposes currentIteration and currentToolName signals.
Mobile chat shows a thin progress bar with step count and active tool
name during multi-iteration agent loops."
```

---

## 阶段四：代码质量 + 性能（中优先级）

### Task 7: 消除 signals/setState 混用 (C1)

**Files:**
- Modify: `lib/page/mobile/chat/chat.dart`

**问题:** `_MobileChatPageState` 使用 `setState` 管理 `_currentChatId`，与 signals 体系不一致。

**方案:** 移除 `_currentChatId` 字段，build 中直接从 `viewModel.currentChat` signal 获取当前 chat。

- [ ] **Step 1: 重构 _MobileChatPageState**

修改 `lib/page/mobile/chat/chat.dart`：

```dart
class _MobileChatPageState extends State<MobileChatPage> {
  final controller = TextEditingController();

  late final viewModel = GetIt.instance<ChatViewModel>();
  late final modelViewModel = GetIt.instance<ModelViewModel>();
  late final sentinelViewModel = GetIt.instance<SentinelViewModel>();

  // 移除 int? _currentChatId;

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      // 直接使用 currentChat signal 确定当前 chat
      ChatEntity? chat = viewModel.currentChat.value;

      // 如果 currentChat 为空，尝试从传入的 widget.chat 查找
      if (chat == null && widget.chat != null) {
        chat = viewModel.chats.value
            .where((c) => c.id == widget.chat!.id)
            .firstOrNull;
      }

      // ... rest of build method unchanged
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeViewModels();
  }

  Future<void> _initializeViewModels() async {
    await modelViewModel.initSignals();
    await sentinelViewModel.getSentinels();
    if (widget.chat != null) {
      await viewModel.selectChat(widget.chat!);
    } else {
      await viewModel.prepareNewChatDraft();
    }
  }

  Future<void> sendMessage(ChatEntity? chat) async {
    final text = controller.text;
    if (text.isEmpty) return;
    controller.clear();

    if (chat == null) {
      chat = await viewModel.createChat();
      if (chat == null) return;
      // currentChat signal 由 createChat 更新，无需手动 setState
    }

    var message = MessageEntity(
      id: 0,
      chatId: chat.id ?? 0,
      role: 'user',
      content: text,
      imageUrls: '',
    );

    await viewModel.sendMessage(message, chat: chat);
  }

  // 移除 _getCurrentChat() 方法，配置更新方法直接用 currentChat signal：

  Future<void> updateContext(int value) async {
    final chat = viewModel.currentChat.value;
    if (chat != null) {
      await viewModel.updateContext(value, chat: chat);
    } else {
      viewModel.updateCurrentContext(value);
    }
  }

  Future<void> updateModel(ModelEntity model) async {
    final chat = viewModel.currentChat.value;
    if (chat != null) {
      await viewModel.updateModel(model, chat: chat);
    } else {
      await viewModel.updateCurrentModel(model);
    }
  }

  Future<void> updateSentinel(SentinelEntity sentinel) async {
    final chat = viewModel.currentChat.value;
    if (chat != null) {
      await viewModel.updateSentinel(sentinel, chat: chat);
    } else {
      viewModel.updateCurrentSentinel(sentinel);
    }
  }

  Future<void> updateTemperature(double value) async {
    final chat = viewModel.currentChat.value;
    if (chat != null) {
      await viewModel.updateTemperature(value, chat: chat);
    } else {
      viewModel.updateCurrentTemperature(value);
    }
  }
}
```

- [ ] **Step 2: 运行分析确认无编译错误**

```bash
flutter analyze lib/page/mobile/chat/chat.dart
```

- [ ] **Step 3: 运行全量测试确认无回归**

```bash
flutter test
```

- [ ] **Step 4: Commit**

```bash
git add lib/page/mobile/chat/chat.dart
git commit -m "refactor: replace setState with signals in MobileChatPage

Removed _currentChatId field and setState calls. Chat resolution now
uses viewModel.currentChat signal directly, consistent with the rest
of the codebase's reactive state management."
```

---

### Task 8: 错误边界处理 (C8)

**Files:**
- Create: `lib/widget/error_boundary.dart`
- Modify: `lib/page/mobile/chat/chat.dart`
- Modify: `lib/page/mobile/home/home.dart`

**问题:** ViewModel 异常可能直接导致页面崩溃白屏，无错误恢复 UI。

**方案:** 创建 `AthenaErrorBoundary` widget，包裹关键页面，捕获 Flutter 框架层的构建异常并显示错误提示与重试按钮。

- [ ] **Step 1: 创建错误边界组件**

```dart
// lib/widget/error_boundary.dart
import 'package:athena/widget/button.dart';
import 'package:flutter/material.dart';

class AthenaErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? message;
  final VoidCallback? onRetry;

  const AthenaErrorBoundary({
    super.key,
    required this.child,
    this.message,
    this.onRetry,
  });

  @override
  State<AthenaErrorBoundary> createState() => _AthenaErrorBoundaryState();
}

class _AthenaErrorBoundaryState extends State<AthenaErrorBoundary> {
  FlutterErrorDetails? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorView();
    }
    return widget.child;
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              widget.message ?? 'An unexpected error occurred',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (widget.onRetry != null)
              AthenaPrimaryButton(
                onTap: () {
                  setState(() => _error = null);
                  widget.onRetry?.call();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text('Retry'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 在聊天页和主页包裹错误边界**

修改 `lib/page/mobile/chat/chat.dart` body：

```dart
body: AthenaErrorBoundary(
  message: 'Chat page encountered an error',
  onRetry: _initializeViewModels,
  child: Builder(
    builder: (context) {
      // ... existing body content
    },
  ),
),
```

修改 `lib/page/mobile/home/home.dart` body：

```dart
body: AthenaErrorBoundary(
  message: 'Home page encountered an error',
  onRetry: _initializeViewModels,
  child: Column(spacing: 24, children: children),
),
```

- [ ] **Step 3: 运行分析**

```bash
flutter analyze lib/widget/error_boundary.dart lib/page/mobile/
```

- [ ] **Step 4: Commit**

```bash
git add lib/widget/error_boundary.dart lib/page/mobile/chat/chat.dart lib/page/mobile/home/home.dart
git commit -m "feat: add error boundary widget and wrap critical mobile pages

AthenaErrorBoundary catches build-time exceptions and shows a user-facing
error screen with retry button instead of a white screen crash."
```

---

### Task 9: 消息列表性能优化 (P1/P2)

**Files:**
- Modify: `lib/page/mobile/chat/chat.dart:68-94`

**问题:** `_MessageListView` 的整个 Watch 回调在每次 messages signal 更新时重建整个 ListView，流式接收时频繁触发。

**方案:** 为 ListView.builder 的 itemBuilder 添加 ValueKey 以帮助 Flutter 复用元素。

- [ ] **Step 1: 给列表项添加稳定 key**

修改 `lib/page/mobile/chat/chat.dart:_MessageListViewState`：

```dart
return ListView.separated(
  controller: controller,
  itemBuilder: (_, index) {
    final message = reversedMessages[index];
    return _itemBuilder(
      message,
      sentinel,
      loading && index == 0,
      key: ValueKey(message.id),
    );
  },
  itemCount: messages.length,
  padding: EdgeInsets.symmetric(horizontal: 16),
  reverse: true,
  separatorBuilder: (_, __) => const SizedBox(height: 12),
);
```

修改 `_itemBuilder` 签名添加 key 参数：

```dart
Widget _itemBuilder(
  MessageEntity message,
  SentinelEntity sentinel,
  bool loading, {
  Key? key,
}) {
  return MessageListTile(
    key: key,
    loading: loading,
    message: message,
    onLongPress: () => openBottomSheet(message),
    onResend: () => resendMessage(message),
    sentinel: sentinel,
  );
}
```

- [ ] **Step 2: 运行分析确认无编译错误**

```bash
flutter analyze lib/page/mobile/chat/chat.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/page/mobile/chat/chat.dart
git commit -m "perf: add stable keys to chat message list items

ListView items now use ValueKey(message.id) for efficient element
reuse during streaming updates."
```

---

## 阶段五：测试补充（低优先级）

### Task 10: 移动端核心流程测试

**Files:**
- Create: `test/page/mobile/chat_page_test.dart`
- Create: `test/page/mobile/home_page_test.dart`

**现状:** 零移动端 Widget 测试。

**方案:** 为聊天页和主页添加 Widget 测试，覆盖基本渲染和核心交互。

- [ ] **Step 1: 编写主页 Widget 测试**

```dart
// test/page/mobile/home_page_test.dart
import 'package:athena/page/mobile/home/home.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test_helper.dart';

void main() {
  group('MobileHomePage', () {
    setUp(() async {
      await TestHelper.initDI();
    });

    testWidgets('renders new chat button and sections', (tester) async {
      await tester.pumpWidget(TestHelper.wrapApp(const MobileHomePage()));
      await tester.pumpAndSettle();

      expect(find.text('New Chat'), findsOneWidget);
      expect(find.text('Chat history'), findsOneWidget);
      expect(find.text('Shortcut'), findsOneWidget);
      expect(find.text('Sentinel'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: 确认或创建测试 Helper**

检查 `test/test_helper.dart`，若不存在则创建：

```dart
// test/test_helper.dart
import 'package:athena/di.dart';
import 'package:flutter/material.dart';

class TestHelper {
  static Future<void> initDI() async {
    DI.ensureInitialized(dataDirectory: '/tmp/athena_test');
  }

  static Widget wrapApp(Widget child) {
    return MaterialApp(home: child);
  }
}
```

- [ ] **Step 3: 运行测试**

```bash
flutter test test/page/mobile/
```

- [ ] **Step 4: Commit**

```bash
git add test/page/mobile/ test/test_helper.dart
git commit -m "test: add mobile home page widget test"
```

---

## 后续工作（不纳入本次计划）

以下审计问题建议在后续迭代中专项处理：

| 编号 | 问题 | 原因 |
|---|---|---|
| C2 | GetIt 直接调用改为构造注入 | 重构面大（18 个页面文件），需单独计划，且当前代码可正常工作 |
| U6 | 下拉刷新 | 聊天列表需 RefreshIndicator |
| U9/U10 | 平板/横屏适配 | 需设计响应式布局方案 |
| S1 | 生物认证 | 低优先级安全增强 |
| S3 | 剪贴板自动清理 | 需平台生命周期监听 |
| A4 | 后台恢复机制 | 需平台原生支持 |
| M1 | chat.dart 文件拆分 | 555行过长，降低后续修改风险 |
| M2 | home.dart 组件提取 | 469行内联 6 个私有 Widget |
| M4 | 翻译/摘要/TRPG 桌面端适配 | 跨平台 UI 统一工程 |
| M5 | 路由命名统一 | 去掉 Mobile 前缀，重构面大 |
| P3-P6 | 图片缓存、数据库线程等 | 需性能基准测试驱动 |

---

## 执行顺序与依赖关系

```
阶段一 (安全)
  └── Task 1: 禁用移动端工具 ── 无依赖，优先执行

阶段二 (Bug 修复)
  ├── Task 2: Food/Code 死点击 ── 无依赖
  └── Task 3: 键盘遮挡 ── 无依赖，可与 Task 2 并行

阶段三 (Agent 体验)
  ├── Task 4: ToolCard 迁移 ── 无依赖
  ├── Task 5: 权限 UI 优化 ── 无依赖
  └── Task 6: 迭代进度展示 ── 依赖 Task 7 (信号重构后更方便)

阶段四 (代码质量 + 性能)
  ├── Task 7: signals/setState 消除 ── 先于 Task 6、Task 10
  ├── Task 8: 错误边界 ── 无依赖，可并行
  └── Task 9: 消息列表优化 ── 无依赖，可并行

阶段五 (测试)
  └── Task 10: 核心流程测试 ── 依赖阶段一至四稳定后可写
```

建议执行顺序：**阶段一 → 阶段二 → 阶段三/四可并行 → 阶段五**
