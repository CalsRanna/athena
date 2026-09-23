import 'dart:io';

import 'package:athena_gui/di.dart';
import 'package:athena_gui/page/desktop/home/component/chat_list.dart';
import 'package:athena_gui/page/desktop/home/component/message_input.dart';
import 'package:athena_gui/page/desktop/home/home_page.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 首页"新建对话"整条链路的验收（页级）：点侧栏 New chat、按 ⌘N / Ctrl+N
/// 之后，焦点必须真的落在 composer 输入框上——也就是
/// `_DesktopHomePageState.startNewChat` 里那次 `requestFocus` 真的执行到了。
///
/// 为什么放在页级而不是 [DesktopMessageInput] 级：`home_shortcuts_test.dart`
/// 只证明"按键会触发回调"，用的是桩 TextField；把 requestFocus 从页里删掉它
/// 照样通过。这里挂真实的 `DesktopHomePage`，能拦住这类回归。
///
/// 依赖图直接走 [DI.ensureInitialized]，数据根由 `homeDirOverride` 指到临时
/// 目录：既不碰真实的 `~/.athena`，也不必在测试里复刻一份 DI 装配。
void main() {
  late Directory tempRoot;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Athena',
      packageName: 'com.athena',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
    tempRoot = Directory.systemTemp.createTempSync('athena_home_page_test');
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
  });

  tearDown(() async {
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  /// composer 的输入框。按 [DesktopMessageInput] 定位而不是取第一个
  /// `EditableText`：页里将来多一个输入框也不会让断言指错控件。
  Finder composerInput() => find.descendant(
    of: find.byType(DesktopMessageInput),
    matching: find.byType(EditableText),
  );

  bool composerFocused(WidgetTester tester) {
    var editable = composerInput();
    if (editable.evaluate().isEmpty) return false;
    return tester.widget<EditableText>(editable).focusNode.hasFocus;
  }

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        home: const DesktopHomePage(),
      ),
    );
    // `_initState` 是一串真实文件 I/O（会话、设置、模型），而且一个接一个
    // await：只放一次真实异步窗口不够——每完成一段 I/O，它的 continuation 要等
    // 下一帧才排空，下一个 I/O 又需要新的真实异步窗口。所以交替「真实异步窗口
    // + pump」，直到焦点落进输入框（那就是 init 走完的标志）。
    for (var i = 0; i < 50 && !composerFocused(tester); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  /// 模拟桌面端点画布：焦点离开输入框。此后快捷键仍须可用（页里那层
  /// `FocusScope` 负责把焦点留在页面内部）。
  Future<void> blurComposer(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(composerFocused(tester), isFalse, reason: '这条断言保证测试真的失焦了');
  }

  Future<void> pressNewChat(WidgetTester tester) async {
    // 激活键按宿主平台只注册一个（macOS ⌘，其余 Ctrl），与实现同一规则
    var modifier = Platform.isMacOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(modifier);
    await tester.pump();
  }

  testWidgets('启动落在草稿页：开屏焦点就在 composer', (tester) async {
    await pumpHome(tester);
    expect(composerFocused(tester), isTrue);
  });

  testWidgets('点侧栏 New chat：焦点落回 composer', (tester) async {
    await pumpHome(tester);
    await blurComposer(tester);

    // 顶栏标题在草稿态也是 'New chat'，所以按侧栏子树定位
    var newChatButton = find.descendant(
      of: find.byType(DesktopChatListView),
      matching: find.text('New chat'),
    );
    expect(newChatButton, findsOneWidget);
    await tester.tap(newChatButton);
    await tester.pump();
    await tester.pump();

    expect(composerFocused(tester), isTrue);
  });

  testWidgets('⌘N / Ctrl+N：焦点落回 composer', (tester) async {
    await pumpHome(tester);
    await blurComposer(tester);

    await pressNewChat(tester);
    await tester.pump();

    expect(composerFocused(tester), isTrue);
  });

  testWidgets('已经在草稿页时按 ⌘N：焦点照样回到 composer', (tester) async {
    await pumpHome(tester);
    // 草稿态不重置草稿（可能已经换过角色/打了半句话），但焦点要放回输入框
    await blurComposer(tester);
    await pressNewChat(tester);
    await tester.pump();
    expect(composerFocused(tester), isTrue);

    await blurComposer(tester);
    await pressNewChat(tester);
    await tester.pump();
    expect(composerFocused(tester), isTrue);
  });
}
