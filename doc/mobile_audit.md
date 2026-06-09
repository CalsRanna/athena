# Athena 移动端审计报告

> 审计日期：2026-06-09  
> 审计范围：`lib/page/mobile/` 全部文件及相关依赖（路由、DI、Widget、ViewModel）  
> 代码行数：约 2500 行（移动端页面 + 组件）

---

## 一、架构与代码组织

### 1.1 硬编码用户名（严重）

**文件**: `lib/page/mobile/home/component/welcome.dart:82`

```dart
TextSpan(text: 'Cals', style: nameTextStyle),
```

用户名为硬编码的 `'Cals'`。应改为从系统用户信息或应用配置中获取。

**建议**：通过 `SettingViewModel` 暴露用户名配置项，或使用 `device_info_plus` 获取设备名作为默认值。

---

### 1.2 快捷键无实际差异化行为（中等）

**文件**: `lib/page/mobile/home/component/shortcut_list_view.dart:64-67`

```dart
'Food' => MobileChatRoute(),
'Code' => MobileChatRoute(),
```

"Food" 和 "Code" 快捷方式直接导航到普通聊天页，未注入任何特殊 prompt。`Shortcut` 模型中虽有 `prompt` 字段但未被使用。

**建议**：参考 Translation/Summary 的实现，为 Food/Code 创建专用页面，或至少在跳转聊天页时通过参数注入对应的 system prompt。

---

### 1.3 混用 MaterialPageRoute 与 AutoRoute（中等）

**文件**: `lib/page/mobile/home/component/welcome.dart:39-43`

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const SettingPage()),
);
```

`SettingPage` 使用原始 `MaterialPageRoute.push`，而其他所有页面使用 AutoRoute。这绕过了路由系统的统一管理，且 SettingPage 未标注 `@RoutePage()`。

**建议**：为 `SettingPage` 添加 `@RoutePage()` 注解，并创建对应的 AutoRoute 声明，通过 `MobileSettingRoute().push(context)` 跳转。

---

### 1.4 移动端工具注册极简（信息）

**文件**: `lib/di.dart:136-142`

移动端仅注册 3 个工具（WebFetch、WebSearch、Skill），桌面端注册 11 个。移动端 Agent 无法进行任何文件操作、Shell 命令或代码搜索。

**说明**：这是有意的设计选择——移动端受限于沙箱环境无法执行 Shell 命令。但未来可考虑添加 `file_read` 工具让 Agent 读取应用沙箱内的文件。

---

## 二、状态管理

### 2.1 混淆 setState 与 Signals（中等）

CLAUDE.md 明确要求"页面 UI 统一用信号避免 setState/signals 混用"，但多处违反：

- `MobileChatConfigurationPage` — 用 `setState` 管理 `_context`/`temperature` 本地状态
- `MobileChatBottomSheet` — 用 `setState` 管理 `sentinelId`/`modelId`/`contextToken`/`temperature`
- `MobileTRPGPage` — 混用 `signal<TRPGPageState>` 与 `bool _isCreatingGame` + `setState`
- `MobileTranslationPage` — 用 `setState` 管理 `source`/`target`/`id`
- `MobileAgentPage` — 用 `setState` 管理表单输入

**建议**：将本地状态统一迁移为 `signal()`，UI 使用 `Watch` 响应。

---

### 2.2 late final 字段在声明时从 GetIt 解析（轻微）

**文件**: `lib/page/mobile/chat/chat.dart:38-42`

```dart
late final viewModel = GetIt.instance<ChatViewModel>();
late final modelViewModel = GetIt.instance<ModelViewModel>();
```

这些解析在 State 构造时（而非 `initState`）触发。因为都是 lazy singleton，风险较低，但不符合"初始化放 initState"的约定。

---

## 三、错误处理与健壮性

### 3.1 初始化无 try-catch（高）

**文件**: `lib/page/mobile/chat/chat.dart:139-146`、`lib/page/mobile/home/home.dart:31-35`

```dart
Future<void> _initializeViewModels() async {
  await GetIt.instance<SettingViewModel>().initSignals();
  await chatViewModel.getChats();
  await sentinelViewModel.getSentinels();
}
```

若数据库出错或网络超时，异常会直接传播到未捕获区域。`AthenaErrorBoundary` 只能捕获同步 build 异常，无法捕获异步初始化异常。

**建议**：添加 try-catch，在 catch 中调用 `AthenaDialog.error()` 提示用户。

---

### 3.2 三个 AI 生成方法完全重复调用（高）

**文件**: `lib/page/mobile/sentinel/form.dart:88-130`

```dart
Future<void> generateSentinel() async { ... }          // 生成 name + description
Future<void> generateSentinelDescription() async { ... } // 调用同一方法但只用 description
Future<void> generateSentinelName() async { ... }        // 调用同一方法但只用 name
```

三个方法 100% 重复调用 `viewModel.generateSentinel()`。点击"生成名称"会浪费 Token 同时生成描述和名称。

**建议**：在 ViewModel 层拆分 `generateSentinelName`、`generateSentinelDescription`、`generateSentinel` 三个独立 API；或至少在接受端只提取对应字段，避免重复请求。

---

### 3.3 数据操作无错误处理（中等）

多处直接调用 ViewModel 方法无 try-catch：
- `sendMessage`、`deleteChat`、`renameChatManually` 等
- 调用方未处理可能的数据库异常或网络异常

**建议**：在 ViewModel 层统一捕获异常并通过 signal 暴露错误状态，UI 层监听并展示。

---

### 3.4 loading dialog 可能未 dismiss（中等）

**文件**: `lib/page/mobile/sentinel/form.dart:95-102`

```dart
AthenaDialog.loading();
try {
  var sentinel = await viewModel.generateSentinel(...);
  AthenaDialog.dismiss();
} catch (error) {
  AthenaDialog.dismiss();
  AthenaDialog.error(error.toString());
}
```

若 `generateSentinel` 抛出非 Exception 的 `Error`（如 `AssertionError`），`catch` 可能漏掉，loading 永久显示。

**建议**：使用 `try { ... } finally { AthenaDialog.dismiss(); }` 确保 loading 必定关闭。

---

## 四、UI/UX 问题

### 4.1 键盘避让方案非标准（中等）

**文件**: `lib/page/mobile/chat/chat.dart:119-120`

```dart
final bottomInset = MediaQuery.of(context).viewInsets.bottom;
// ...
SizedBox(height: bottomInset),
```

使用 Builder + SizedBox 手动处理键盘，而非标准的 `Scaffold.resizeToAvoidBottomInset`。在动画过渡期间可能导致跳动。

**建议**：将 `AthenaScaffold.body` 包裹在 `SingleChildScrollView` 中，或使用 Flutter 标准键盘避让机制。

---

### 4.2 固定高度截断（轻微）

**文件**: `lib/page/mobile/home/home.dart:75`

```dart
SizedBox(height: 52, child: RecentChatListView(...))
```

聊天 tile 固定 52px 高度，长标题可能截断。

---

### 4.3 流式输入时行为不一致（轻微）

**文件**: `lib/page/mobile/chat/chat.dart:224-237`

流式响应期间输入框仍可编辑，发送按钮变为停止按钮。用户输入后按发送会**停止流式然后丢弃输入**。

**建议**：流式期间禁用输入框，或将当前输入缓存，终止流式后自动发送。

---

### 4.4 导出页面移动端无法滚动预览（轻微）

**文件**: `lib/page/mobile/chat/chat_export.dart:108`

```dart
physics: NeverScrollableScrollPhysics(),
```

用户无法预览完整导出内容，只能看到首屏。

---

### 4.5 桌面端死代码（轻微）

**文件**: `lib/page/mobile/summary/summary_detail_page.dart:119`

```dart
var isDesktop = Platform.isLinux || Platform.isMacOS || Platform.isWindows;
return SizedBox(width: isDesktop ? 48 : 24);
```

这是移动端专属页面，桌面端分支永远不会执行。可简化为 `SizedBox(width: 24)`。

---

### 4.6 未使用的方法（轻微）

**文件**: `lib/page/mobile/chat/component/chat_bottom_sheet.dart:124-127`

```dart
void navigateChatConfiguration() { ... }
```

定义了但从未被调用。可安全删除。

---

## 五、内存与性能

### 5.1 Watch 包裹大型 build（中等）

**文件**: `lib/page/mobile/chat/chat.dart:48`

整个 `MobileChatPage.build` 包裹在 `Watch` 中，任何 signals 变化都触发完整重建（包括 `MessageListView`、`UserInput` 等子组件）。

**建议**：将 `Watch` 下沉到最小粒度子组件，例如仅包裹 `titleWidget` 和 `_buildProgressBar`。

---

### 5.2 每次 build 过滤模型列表（轻微）

**文件**: `lib/page/mobile/provider/component/model_list_view.dart:24-26`

```dart
var models = modelViewModel.models.value
    .where((m) => m.providerId == provider.id)
    .toList();
```

无缓存，每次 signals 更新都重新过滤。对于少量模型影响可忽略，但若某 Provider 注册大量模型则有性能隐患。

**建议**：使用 `Computed` signal 在 ViewModel 层预计算分组，或使用 `didChangeDependencies` 缓存过滤结果。

---

### 5.3 AthenaScaffold 每次 build 做平台检测（轻微）

**文件**: `lib/widget/scaffold.dart:12`

```dart
var isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
```

路由已按平台分离（桌面端用 DesktopRoute，移动端用 AutoRoute），移动端页面绝不会进入桌面端分支。可考虑在编译时常量化或改用继承式 Scaffold。

---

## 六、平台适配

### 6.1 桌面 API 在移动端被调用（中等）

**文件**: `lib/main.dart:17-18`

```dart
await WindowUtil.instance.ensureInitialized();
await SystemTrayUtil.instance.ensureInitialized();
```

这两个调用在 iOS/Android 上会执行。虽然对应工具类可能在移动端做了 no-op 处理，但若不处理则可能抛出异常。

**建议**：添加平台守卫：

```dart
if (!Platform.isIOS && !Platform.isAndroid) {
  await WindowUtil.instance.ensureInitialized();
  await SystemTrayUtil.instance.ensureInitialized();
}
```

---

### 6.2 Cmd+W 快捷键在移动端注册（轻微）

**文件**: `lib/main.dart:68-76`

```dart
HardwareKeyboard.instance.addHandler(_handleKeyEvent);
```

键盘处理器在移动端无意义（移动设备无物理键盘 Meta+W 快捷键）。

---

### 6.3 iOS/Android 原生代码

- `MainActivity.kt` — 标准 Flutter 模板，无自定义逻辑
- `AppDelegate.swift` — 标准 Flutter 模板，无自定义逻辑
- 需确认 `Info.plist` 已配置 `NSAppTransportSecurity` 允许 HTTP（如果使用本地 LLM 服务）

---

## 七、国际化 (i18n)

### 7.1 完全缺失 i18n（高）

整个移动端零 i18n 支持。中英文混用：

| 位置 | 语言 | 示例 |
|------|------|------|
| `data_page.dart` | 中文 | `'导出成功'`、`'导入成功'`、`'重置成功'` |
| `chat_tile.dart` | 中文 | `'新的对话'` |
| `user_input.dart` | 英文 | `'Send a message'` |
| `welcome.dart` | 英文 | `'Good morning/afternoon/evening'` |
| `setting/agent_page.dart` | 英文 | 全部 UI 文案 |

**建议**：引入 Flutter `intl` 包，创建 `.arb` 文件，统一管理所有文案。

---

## 八、可访问性

### 8.1 完全缺失无障碍支持（高）

- 零 `Semantics` widget
- 零 `semanticLabel` 在图标按钮上（如 SendButton、More 按钮）
- 无 TalkBack/VoiceOver 支持
- 无焦点管理

**建议**：为核心交互元素添加 `Semantics` 标签，至少覆盖：
- 发送/停止按钮
- 聊天记录列表项
- 导航按钮

---

## 九、安全性

### 9.1 API Key 明文显示（高）

**文件**: `lib/page/mobile/provider/provider_form_page.dart:50`

```dart
AthenaInput(controller: keyController),
```

Provider 编辑页的 API Key 输入框未使用 `obscureText`，密钥明文可见。

对比 `MobileAgentPage` 中 Brave API Key 正确使用了 `obscureText: true`。

**建议**：为 `keyController` 对应的输入框添加 `obscureText: true` 和切换可见性按钮。

---

### 9.2 无应用锁/生物认证（中等）

存储 API Key 和聊天数据的移动应用无任何应用级安全锁。建议添加：
- 生物认证（Face ID / Touch ID / Fingerprint）
- 或至少 PIN 码锁定

---

## 十、测试覆盖

### 10.1 移动端 UI 测试为零（高）

测试目录中 32 个测试文件，**零个**针对移动端页面/组件。所有测试：

| 层级 | 测试文件数 |
|------|-----------|
| Agent（工具/Skill/权限） | 15 |
| Service | 5 |
| ViewModel | 5 |
| Database | 2 |
| Util/Extension/Widget | 5 |
| **Mobile UI** | **0** |

无 widget test 验证：
- 页面路由是否正确跳转
- 用户输入提交 → 消息发送流程
- 流式响应 UI 更新
- 错误状态展示与 Retry
- Dialog/BottomSheet 交互

**建议**：至少为 `MobileChatPage`、`MobileHomePage`、`MobileTranslationPage` 添加冒烟测试。

---

## 十一、代码质量

### 11.1 类名拼写错误（轻微）

**文件**: `lib/page/mobile/about/about_page.dart:15`

```dart
class _MobilAboutPageState  // 应为 _MobileAboutPageState
```

---

### 11.2 无用的 VisibilityDetector 需注释（轻微）

**文件**: `lib/page/mobile/home/component/welcome.dart:26-29`

```dart
VisibilityDetector(
  onVisibilityChanged: handleVisibilityChanged,  // 仅调 setState((){})
```

`handleVisibilityChanged` 仅调用空的 `setState(() {})`。实际作用是在页面重新可见时刷新问候语（基于 time-of-day 的动态内容）。应添加注释说明意图。

**建议**：添加注释 `// Rebuild to update time-based greeting when page becomes visible`.

---

### 11.3 未使用 import（轻微）

多个文件存在未使用的 import，如 `chat_export.dart` 中 `import 'package:athena/entity/sentinel_entity.dart';` 仅在局部使用。建议运行 `dart fix` 自动清理。

---

## 汇总建议优先级

| 优先级 | 问题 | 文件 |
|--------|------|------|
| 🔴 高 | API Key 明文显示 | `provider/provider_form_page.dart:50` |
| 🔴 高 | 零 i18n 支持 | 全部移动端文件 |
| 🔴 高 | 零无障碍支持 | 全部移动端文件 |
| 🔴 高 | 零移动端 UI 测试 | `test/` 目录 |
| 🔴 高 | AI 生成方法三重重复调用 | `sentinel/form.dart:88-130` |
| 🔴 高 | 异步初始化无异常处理 | `chat/chat.dart:139`、`home/home.dart:31` |
| 🟡 中 | 用户名硬编码 `'Cals'` | `home/component/welcome.dart:82` |
| 🟡 中 | Desktop API 在移动端未守卫 | `main.dart:17-18` |
| 🟡 中 | setState/signals 混用 | 多个文件 |
| 🟡 中 | 快捷键 `Food`/`Code` 无实际行为 | `shortcut_list_view.dart:64` |
| 🟡 中 | 混用 MaterialPageRoute 与 AutoRoute | `welcome.dart:39` |
| 🟡 中 | 键盘避让方案非标准 | `chat/chat.dart:119` |
| 🟡 中 | loading dialog 可能未 dismiss | `sentinel/form.dart:95` |
| 🟡 中 | 无应用锁/生物认证 | 全局安全 |
| 🟢 轻 | 类名拼写 `_MobilAboutPageState` | `about/about_page.dart:15` |
| 🟢 轻 | 未使用方法 `navigateChatConfiguration` | `chat_bottom_sheet.dart:124` |
| 🟢 轻 | 桌面端死代码 | `summary_detail_page.dart:119` |
| 🟢 轻 | VisibilityDetector 缺注释 | `welcome.dart:26` |
| 🟢 轻 | 未使用 import | 多个文件 |
