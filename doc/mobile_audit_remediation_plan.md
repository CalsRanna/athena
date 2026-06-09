# Athena 移动端审计修复计划

> 基于审计报告 `doc/mobile_audit.md`（2026-06-09）  
> 计划制定日期：2026-06-09  
> 目标：分三阶段完成所有高/中/低优先级问题的修复

---

## 阶段概览

| 阶段 | 周期 | 目标 | 问题数 |
|------|------|------|--------|
| 第一阶段 | 第 1–2 周 | 安全和稳定性修复 | 7 项 |
| 第二阶段 | 第 3–5 周 | UX 和架构改进 | 9 项 |
| 第三阶段 | 第 6–8 周 | 质量工程和债务清偿 | 7 项 |

---

## 第一阶段：安全和稳定性修复（第 1–2 周）

> 目标：消除所有高优先级安全和稳定性隐患

---

### 1.1 API Key 明文显示 → 改为密文输入

- **问题**：`provider_form_page.dart:50` 的 API Key 输入框未使用 `obscureText`
- **文件**：`lib/page/mobile/provider/provider_form_page.dart`
- **方案**：

```dart
// 添加状态变量
var _obscureKey = true;

// 修改 API Key 输入框
AthenaInput(
  controller: keyController,
  obscureText: _obscureKey,
  suffix: GestureDetector(
    onTap: () => setState(() => _obscureKey = !_obscureKey),
    child: Icon(_obscureKey ? HugeIcons.strokeRoundedView : HugeIcons.strokeRoundedViewOff),
  ),
),
```

- **测试**：验证输入框默认密文、点击切换可见/不可见、切换不丢失输入内容
- **工期**：0.5 天

---

### 1.2 异步初始化添加 try-catch 错误处理

- **问题**：`chat.dart:139` 和 `home.dart:31` 的 `_initializeViewModels()` 无异常处理
- **涉及文件**：
  - `lib/page/mobile/chat/chat.dart`
  - `lib/page/mobile/home/home.dart`
- **方案**：

```dart
Future<void> _initializeViewModels() async {
  try {
    await GetIt.instance<SettingViewModel>().initSignals();
    await chatViewModel.getChats();
    await sentinelViewModel.getSentinels();
  } catch (e, stack) {
    LoggerUtil.error('Failed to initialize view models', e, stack);
    if (mounted) {
      AthenaDialog.error('Failed to load data. Please check your connection and try again.');
    }
  }
}
```

- **扩展**：同时检查 `MobileProviderListPage`、`MobileDefaultModelFormPage`、`MobileProviderFormPage` 中类似的初始化调用
- **工期**：1 天

---

### 1.3 AI 生成方法去重——拆分 ViewModel API

- **问题**：`sentinel/form.dart` 中 `generateSentinel`、`generateSentinelName`、`generateSentinelDescription` 完全重复调用同一个完整生成 API
- **涉及文件**：
  - `lib/view_model/sentinel_view_model.dart`（新增方法）
  - `lib/page/mobile/sentinel/form.dart`（简化调用）
  - `lib/service/sentinel_service.dart`（如需新增 API）
- **方案**：

1. 在 `SentinelService` 中新增两个单字段生成方法：
   ```dart
   Future<String> generateSentinelName(String prompt, {required int modelId});
   Future<String> generateSentinelDescription(String prompt, {required int modelId});
   ```

2. 在 `SentinelViewModel` 中暴露对应的 signal 方法：
   ```dart
   Future<String?> generateName(String prompt);
   Future<String?> generateDescription(String prompt);
   ```

3. 修改 `MobileSentinelFormPage` 中的三个按钮分别调用对应方法

4. 保留 `generateSentinel` 作为"一键生成全部"的快捷入口

- **工期**：2 天

---

### 1.4 loading dialog 改为 try-finally 确保关闭

- **问题**：`sentinel/form.dart:95` 中若异常未被 catch 捕获，loading 永久显示
- **涉及文件**：
  - `lib/page/mobile/sentinel/form.dart`
  - 审计发现的所有 `AthenaDialog.loading()` 调用点
- **方案**：

```dart
Future<void> generateSentinel() async {
  if (promptController.text.trim().isEmpty) {
    AthenaDialog.warning('Prompt is required');
    return;
  }
  AthenaDialog.loading();
  try {
    // ... 业务逻辑
  } finally {
    AthenaDialog.dismiss();
  }
}
```

- **全局排查**：搜索整个 `lib/page/mobile/` 目录，确保所有 `AthenaDialog.loading()` 都有 `finally { dismiss(); }`
- **工期**：0.5 天

---

### 1.5 桌面 API 在移动端调用加平台守卫

- **问题**：`main.dart:17-18` 中 `WindowUtil` 和 `SystemTrayUtil` 初始化在移动端不适用
- **文件**：`lib/main.dart`
- **方案**：

```dart
if (!Platform.isIOS && !Platform.isAndroid) {
  await WindowUtil.instance.ensureInitialized();
  await SystemTrayUtil.instance.ensureInitialized();
}
```

- **同步检查**：`_handleKeyEvent` 中的 `Cmd+W` 快捷键监听也加同等守卫
- **工期**：0.5 天

---

### 1.6 全局排查中文/英文硬编码字符串并建立 i18n 骨架

- **注意**：完整 i18n 实现在第三阶段完成，第一阶段仅建立骨架并修复硬编码用户名
- **文件**：
  - `lib/page/mobile/home/component/welcome.dart` —— 硬编码 `'Cals'`
  - `lib/page/mobile/home/component/chat_tile.dart` —— `'新的对话'`
  - `lib/page/mobile/setting/data_page.dart` —— `'导出成功'` 等
- **第一阶段方案**：

1. 将硬编码 `'Cals'` 替换为 `settingViewModel.userName.value`
2. 在 `SettingViewModel` 中新增 `userName` signal，默认值尝试从设备名获取
3. 将 `'新的对话'` 替换为 `'New Chat'`（统一英文，等待 i18n 后多语言）
4. 将 `data_page.dart` 中的中文提示改为英文，保持和其他页面一致

- **工期**：1 天

---

## 第二阶段：UX 和架构改进（第 3–5 周）

> 目标：消除所有中优先级架构和体验问题

---

### 2.1 setState/signals 混用治理

- **问题**：6 个页面同时使用 setState 和 signals
- **涉及文件**：
  - `lib/page/mobile/chat/chat_configuration.dart`
  - `lib/page/mobile/chat/component/chat_bottom_sheet.dart`
  - `lib/page/mobile/chat/component/chat_configuration_dialog.dart`
  - `lib/page/mobile/trpg/trpg_page.dart`
  - `lib/page/mobile/translation/translation_page.dart`
  - `lib/page/mobile/setting/agent_page.dart`
- **方案**：

1. **`MobileChatConfigurationPage`**：`_context`/`temperature` 改为 `signal<double>`，UI 用 `Watch` 响应
   ```dart
   final _context = signal<double>(0);
   final _temperature = signal<double>(1.0);
   ```

2. **`MobileChatBottomSheet`**：`sentinelId`/`modelId`/`contextToken`/`temperature` 改为 `signal<int/double>`

3. **`MobileTRPGPage`**：`_isCreatingGame`/`_isLoadingGame` 改为 `signal<bool>`

4. **`MobileTranslationPage`**：`source`/`target`/`id` 改为 `signal<String>`

5. **`MobileAgentPage`**：输入状态（不需要响应式，保留 `TextEditingController`，无需改）

- **重构原则**：对外部 ViewModel 数据用 `Watch` 订阅；本地 UI 状态用 `signal()`；一次性表单输入保留 Controller
- **工期**：3 天

---

### 2.2 快捷键 Food/Code 注入专用 prompt

- **问题**：`shortcut_list_view.dart` 中 Food/Code 仅跳转聊天页无差异化行为
- **文件**：`lib/page/mobile/home/component/shortcut_list_view.dart`、`lib/model/shortcut.dart`
- **方案**：

1. 为每个 Shortcut 预定义专用的 system prompt
2. 修改 `MobileChatRoute` 支持传递 `initialPrompt` 参数
3. 路由跳转时注入：

```dart
'Food' => MobileChatRoute(initialPrompt: shortcut.prompt),
'Code' => MobileChatRoute(initialPrompt: shortcut.prompt),
```

4. 在 `ChatViewModel.prepareNewChatDraft` 中接受可选的初始 prompt，作为首条用户消息自动发送

- **工期**：1.5 天

---

### 2.3 统一路由方式——SettingPage 接入 AutoRoute

- **问题**：`welcome.dart` 使用 `MaterialPageRoute` 跳转 `SettingPage`，绕过 AutoRoute
- **文件**：
  - `lib/page/mobile/setting/setting.dart`（添加 `@RoutePage()`）
  - `lib/router/router.dart`（注册路由）
  - `lib/page/mobile/home/component/welcome.dart`（修改跳转方式）
- **方案**：

1. 给 `SettingPage` 添加 `@RoutePage()` 注解
2. 在 `router.dart` 中注册 `MobileSettingRoute`
3. 运行 `flutter pub run build_runner build` 生成路由
4. 修改跳转：
   ```dart
   onTap: () => MobileSettingRoute().push(context),
   ```

- **工期**：1 天

---

### 2.4 键盘避让改为标准方案

- **问题**：`chat.dart:119` 手动计算 `viewInsets.bottom` 并用 SizedBox 避让
- **文件**：`lib/page/mobile/chat/chat.dart`
- **方案**：
  1. 移除 Builder + `MediaQuery.viewInsets.bottom` 的 SizedBox 方案
  2. 将 `resizeToAvoidBottomInset: true` 设置在 `AthenaScaffold._MobileScaffold` 的 `Scaffold` 上
  3. 验证各页面（Chat、TRPG、Translation）键盘弹出时内容正确滚动
- **工期**：1 天

---

### 2.5 为核心图标按钮添加 semanticLabel

- **问题**：全部图标按钮无 `semanticLabel`，无障碍完全缺失
- **注意**：完整无障碍在第三阶段完成，第二阶段先覆盖核心交互
- **方案**：

为以下组件添加 `semanticLabel`：

| 组件 | semanticLabel |
|------|--------------|
| `SendButton`（发送态） | `'Send message'` |
| `SendButton`（停止态） | `'Stop generating'` |
| `NewChatButton` | `'Start new chat'` |
| `SectionTitle` 的 more 箭头 | `'View all $title'` |
| Model 选择器图标 | `'Select model'` |
| 聊天列表 more 按钮 | `'Chat options'` |
| TRPG 刷新按钮 | `'Resend message'` |

- **工期**：0.5 天

---

### 2.6 清理桌面端死代码和未使用方法

- **涉及项**：
  1. `summary_detail_page.dart:119` — `isDesktop` 分支永远不会执行 → 简化为固定值
  2. `chat_bottom_sheet.dart:124` — 删除未使用的 `navigateChatConfiguration`
  3. 全局运行 `dart fix --apply` 清理未使用 import
- **工期**：0.5 天

---

### 2.7 Watch 粒度优化——ChatPage

- **问题**：`MobileChatPage.build` 整个方法包裹在 `Watch` 中
- **文件**：`lib/page/mobile/chat/chat.dart`
- **方案**：

将 `Watch` 下沉到最小依赖粒度：

```dart
@override
Widget build(BuildContext context) {
  final chat = viewModel.currentChat.value;  // 初始值，不 Watch
  // ...
  return AthenaScaffold(
    appBar: AthenaAppBar(
      action: actionButton,
      title: Watch((_) => _buildTitle(chat)),  // 仅 title 响应式
    ),
    body: AthenaErrorBoundary(
      child: Column(
        children: [
          Expanded(child: content),
          Watch((_) => _buildProgressBar()),  // 仅进度条响应式
          _buildInput(chat),
        ],
      ),
    ),
  );
}
```

- **工期**：1 天

---

### 2.8 添加应用锁基础架构（生物认证）

- **问题**：存储敏感数据无应用级安全锁
- **方案**：

1. 添加 `local_auth` 依赖到 `pubspec.yaml`
2. 创建 `lib/util/biometric_util.dart` 封装认证逻辑
3. 在 `SettingViewModel` 中新增 `biometricEnabled` signal
4. 在 `MobileAgentPage` 中添加生物认证开关
5. 在 `AthenaApp` 中添加 `AppLifecycleState` 监听，进入后台超过 N 秒后锁定
6. 锁定状态显示遮罩页面，要求认证后解锁

- **工期**：3 天

---

## 第三阶段：质量工程和债务清偿（第 6–8 周）

> 目标：建立持续质量保障体系

---

### 3.1 完整 i18n 国际化

- **第一阶段成果**：英文统一 + 硬编码用户名消除
- **第三阶段方案**：

1. 在 `pubspec.yaml` 中添加 `flutter_localizations` 和 `intl` 依赖
2. 创建 `lib/l10n/` 目录：
   ```
   lib/l10n/
   ├── app_en.arb       # 英文
   ├── app_zh.arb       # 简体中文
   └── l10n.dart        # 生成的本地化委托
   ```
3. 提取所有硬编码字符串到 `.arb` 文件：
   - 问候语：`goodMorning`、`goodAfternoon`、`goodEvening`
   - 按钮：`newChat`、`sendMessage`、`stop`、`translate`、`summarize`
   - 提示：`exportSuccess`、`importSuccess`、`resetSuccess`
   - 表单：`nameRequired`、`descriptionRequired`、`promptRequired`
   - Section 标题：`chatHistory`、`sentinel`、`shortcut`
4. 在 `MaterialApp.router` 中配置 `localizationsDelegates` 和 `supportedLocales`
5. 逐页面替换硬编码字符串 → `AppLocalizations.of(context)!.xxx`
6. 添加语言切换入口（设置页）

- **工期**：5 天

---

### 3.2 完整无障碍（Accessibility）支持

- **第二阶段成果**：核心图标按钮已有 semanticLabel
- **第三阶段方案**：

1. **消息列表无障碍**：
   - 每条消息标记为 `Semantics(label: 'Message from $role: $preview')`
   - 工具调用卡片标记为 `Semantics(label: 'Tool call: $toolName')`
   - 工具结果标记为 `Semantics(label: 'Tool result')`

2. **导航无障碍**：
   - AppBar 标题合并到 `Semantics(header: true)`
   - 列表使用 `Semantics(container: true)` 分组

3. **表单无障碍**：
   - 所有输入框关联 `Semantics(label: '...', hint: '...')`
   - 错误提示使用 `Semantics(liveRegion: true)`

4. **状态通知**：
   - 流式生成开始/完成 → `SemanticsService.announce()`
   - 错误发生 → `SemanticsService.announce('Error: $message')`

- **工期**：4 天

---

### 3.3 移动端 UI 测试体系建立

- **目标**：建立至少覆盖核心流程的 widget test 套件

| 测试文件 | 覆盖内容 | 优先级 |
|---------|---------|--------|
| `test/page/mobile/chat_page_test.dart` | 发送消息流程、流式响应 UI、停止/重发、错误状态 | P0 |
| `test/page/mobile/home_page_test.dart` | 聊天列表加载、Sentinel 列表、导航跳转 | P0 |
| `test/page/mobile/translation_page_test.dart` | 语言选择、翻译提交、历史列表 | P1 |
| `test/page/mobile/summary_page_test.dart` | 链接输入、摘要生成、详情页展示 | P1 |
| `test/page/mobile/trpg_page_test.dart` | 创建游戏、加载存档、发送行动 | P1 |
| `test/page/mobile/sentinel_form_test.dart` | 表单验证、AI 生成按钮、提交创建 | P1 |
| `test/page/mobile/provider_form_test.dart` | API Key 密文输入、模型 CRUD | P2 |
| `test/page/mobile/setting_page_test.dart` | 设置页导航、数据导出/导入/重置 | P2 |

- **测试基础设施**：
  1. 创建 `test/test_utils/` 目录，抽取共享 helper：
     - `mock_view_models.dart` — 使用 fake ViewModel 实现
     - `test_app.dart` — 最小化 MaterialApp 包装器
     - `pump_utils.dart` — await 信号稳定的 pump helper
  2. Mock 策略：ViewModels 构造参数均接受可选注入，测试时传 fake，不通真实网络

- **工期**：5 天

---

### 3.4 修复拼写错误和代码规范

- **涉及项**：
  1. `_MobilAboutPageState` → `_MobileAboutPageState`
  2. `MobileHomeWelcome.handleVisibilityChanged` 添加注释说明空 setState 意图
  3. 全项目运行 `dart analyze` 并修复所有 warning
  4. 全项目运行 `dart format .` 统一代码风格
  5. 确保 CI pipeline 中加入 `flutter analyze` 和 `flutter test`
- **工期**：1 天

---

### 3.5 模型列表过滤性能优化

- **问题**：`model_list_view.dart` 和 `model_wall_view.dart` 每次 build 过滤模型
- **方案**：

1. 在 `ModelViewModel` 中新增 `Computed` signal：
   ```dart
   late final modelsByProvider = computed(() {
     final map = <int, List<ModelEntity>>{};
     for (final m in models.value) {
       map.putIfAbsent(m.providerId, () => []).add(m);
     }
     return map;
   });
   ```

2. UI 层直接使用 `modelViewModel.modelsByProvider.value[provider.id] ?? []`

- **工期**：0.5 天

---

## 修复对照表

| # | 优先级 | 审计问题 | 修复计划 | 阶段 | 工期 |
|---|--------|---------|---------|------|------|
| 1 | 🔴 | API Key 明文显示 | 改为密文输入 + 可见性切换 | 一 | 0.5d |
| 2 | 🔴 | 初始化无 try-catch | 全局添加异常处理 | 一 | 1d |
| 3 | 🔴 | AI 生成三重重复 | 拆分 ViewModel API | 一 | 2d |
| 4 | 🔴 | loading 可能不 dismiss | try-finally 保底 | 一 | 0.5d |
| 5 | 🔴 | 无 i18n（第一阶段） | 英文统一 + 用户名配置化 | 一 | 1d |
| 6 | 🔴 | 无 i18n（完整） | intl + .arb + 逐页替换 | 三 | 5d |
| 7 | 🔴 | 无无障碍（第一阶段） | 图标按钮 semanticLabel | 二 | 0.5d |
| 8 | 🔴 | 无无障碍（完整） | Semantics + 语音播报 | 三 | 4d |
| 9 | 🔴 | 无 UI 测试 | Widget test 套件建立 | 三 | 5d |
| 10 | 🟡 | 用户名硬编码 | SettingViewModel.userName | 一 | (含#5) |
| 11 | 🟡 | Desktop API 未守卫 | 平台条件编译 | 一 | 0.5d |
| 12 | 🟡 | setState/signals 混用 | 改为 signal() | 二 | 3d |
| 13 | 🟡 | 快捷键无差异化 | 注入专用 prompt | 二 | 1.5d |
| 14 | 🟡 | 混用路由方式 | SettingPage 接入 AutoRoute | 二 | 1d |
| 15 | 🟡 | 键盘避让非标准 | 改为标准方案 | 二 | 1d |
| 16 | 🟡 | 无应用锁 | 生物认证 + 后台锁定 | 二 | 3d |
| 17 | 🟡 | Watch 大粒度包裹 | 下沉到最小子组件 | 二 | 1d |
| 18 | 🟡 | 模型过滤无缓存 | Computed signal 预计算 | 三 | 0.5d |
| 19 | 🟢 | 类名拼写 | 重命名 | 三 | (含#21) |
| 20 | 🟢 | 未使用方法 | 删除 | 二 | 0.5d |
| 21 | 🟢 | 桌面端死代码 | 清理 | 二 | (含#20) |
| 22 | 🟢 | VisibilityDetector 缺注释 | 添加注释 | 三 | (含#21) |
| 23 | 🟢 | 未使用 import | dart fix --apply | 三 | (含#21) |

---

## 风险与依赖

| 风险 | 影响 | 缓解 |
|------|------|------|
| `SentinelService` 不支持单字段生成 API | 阶段一 #3 需要后端改动 | 先行评估 API 设计，必要时仅做客户端拆分（提取字段而非重复请求） |
| `local_auth` 插件兼容性 | 阶段二 #8 部分设备不支持生物认证 | 降级到 PIN 码输入，提供"跳过"选项 |
| 测试 Mock 复杂度高 | 阶段三 #9 可能超期 | 优先覆盖 P0 用例，P1/P2 可后续追加 |
| i18n 字符串提取工作量大 | 阶段三 #6 涉及所有页面 | 分模块逐页替换，每页替换后立即测试 |

---

## 验收标准

### 第一阶段完成标准
- [ ] API Key 输入框默认密文，可切换可见
- [ ] 首页/Chat 页初始化失败时显示错误提示并支持重试
- [ ] Sentinel 表单各生成按钮独立工作，不重复请求
- [ ] 所有 loading 异常情况下能正常关闭
- [ ] 移动端启动不因 WindowUtil/SystemTrayUtil 报错
- [ ] 用户名字段可配置，默认不为 `'Cals'`

### 第二阶段完成标准
- [ ] setState/signals 混用页面 ≤ 1 个（仅 AgentPage 保留 Controller）
- [ ] Food/Code 快捷方式发送专用 prompt
- [ ] SettingPage 通过 AutoRoute 跳转
- [ ] 键盘弹起时 Chat/TRPG 页面行为正确
- [ ] TalkBack 可朗读核心按钮功能
- [ ] 应用进入后台超时后要求认证

### 第三阶段完成标准
- [ ] 中英文切换正常，所有文案无硬编码
- [ ] TalkBack 可完整导航所有页面
- [ ] 核心 widget test 通过（≥ 8 个测试文件）
- [ ] `flutter analyze` 零 warning
- [ ] CI 流水线包含 analyze + test
