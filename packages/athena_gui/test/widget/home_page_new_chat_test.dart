import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/page/desktop/home/component/chat_list.dart';
import 'package:athena_gui/page/desktop/home/component/message_input.dart';
import 'package:athena_gui/page/desktop/home/component/sentinel_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/workspace_indicator.dart';
import 'package:athena_gui/page/desktop/home/home_page.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
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

  /// 交替「真实异步窗口 + pump」把一次 async 动作推完。页面里的 I/O 是一条
  /// 串行 await 链，只放一次 runAsync 只够第一段（原因见 [pumpHome]）。
  Future<void> settle(WidgetTester tester, {int rounds = 10}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
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
    // 焦点落进输入框不等于 init 链走完（composer 首帧就可能持焦），而草稿的
    // 角色/工作文件夹是链尾才设的信号：再走几轮，别让断言读到中间态。
    await settle(tester);
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

  /// 落一条"来源对话"：可选择挂自定义角色（不给就是"不用角色"）与工作文件夹。
  /// 页面挂起来之前调用，这样 initSignals 能把它读进侧栏。
  Future<ChatEntity> seedSourceChat(
    WidgetTester tester, {
    String? sentinelName,
    String? workspacePath,
  }) async {
    final sentinelRepo = GetIt.instance<SentinelRepository>();
    final chatRepo = GetIt.instance<ChatRepository>();
    late ChatEntity chat;
    await tester.runAsync(() async {
      var sentinelId = ChatEntity.noSentinelId;
      if (sentinelName != null) {
        sentinelId = await sentinelRepo.createSentinel(
          SentinelEntity(name: sentinelName, prompt: 'probe'),
        );
      }
      final id = await chatRepo.createChat(
        ChatEntity(
          title: 'Source chat',
          modelId: 1,
          sentinelId: sentinelId,
          workspacePath: workspacePath,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      chat = (await chatRepo.getChatById(id))!;
    });
    return chat;
  }

  /// 选中一条对话（等价于用户在侧栏点它）；此刻它就是"当前对话"。
  Future<void> selectSourceChat(WidgetTester tester, ChatEntity chat) async {
    await tester.runAsync(
      () => GetIt.instance<ChatViewModel>().selectChat(chat),
    );
    await settle(tester);
  }

  /// 点侧栏的 "New chat" 行。顶栏标题在草稿态也是 'New chat'，所以按侧栏子树
  /// 定位，避免命中标题。
  Future<void> tapSidebarNewChat(WidgetTester tester) async {
    var newChatButton = find.descendant(
      of: find.byType(DesktopChatListView),
      matching: find.text('New chat'),
    );
    expect(newChatButton, findsOneWidget);
    await tester.tap(newChatButton);
    await settle(tester);
  }

  /// composer 上下文条上的角色 chip 文案。
  Finder sentinelChipLabel(String label) => find.descendant(
    of: find.byType(DesktopSentinelIndicator),
    matching: find.text(label),
  );

  /// composer 上下文条上的工作文件夹 chip 文案（只显示目录名）。
  Finder workspaceChipLabel(String label) => find.descendant(
    of: find.byType(DesktopWorkspaceIndicator),
    matching: find.text(label),
  );

  testWidgets('启动落在草稿页：开屏焦点就在 composer', (tester) async {
    await pumpHome(tester);
    expect(composerFocused(tester), isTrue);
  });

  testWidgets('点侧栏 New chat：焦点落回 composer', (tester) async {
    await pumpHome(tester);
    await blurComposer(tester);

    await tapSidebarNewChat(tester);

    expect(composerFocused(tester), isTrue);
  });

  testWidgets('⌘N / Ctrl+N：焦点落回 composer', (tester) async {
    await pumpHome(tester);
    await blurComposer(tester);

    await pressNewChat(tester);
    await tester.pump();

    expect(composerFocused(tester), isTrue);
  });

  testWidgets('侧栏 New chat 的快捷键提示：静止没有，hover 才出现', (tester) async {
    await pumpHome(tester);
    // 提示文案按宿主平台只有一套（与 home_shortcuts.dart 的绑定同一条规则），
    // 这里按平台写死期望值——实现若在 macOS 上显示 Ctrl+N，这条会失败。
    var hintLabel = Platform.isMacOS ? '⌘N' : 'Ctrl+N';
    var row = find.descendant(
      of: find.byType(DesktopChatListView),
      matching: find.text('New chat'),
    );
    var hint = find.descendant(
      of: find.byType(DesktopChatListView),
      matching: find.text(hintLabel),
    );
    expect(row, findsOneWidget);
    expect(hint, findsNothing, reason: '静止的导航行没有尾部');

    var mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(row));
    await tester.pump();
    expect(hint, findsOneWidget, reason: 'hover 后才挂出提示');

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(hint, findsNothing, reason: '指针移开提示收回');
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

  testWidgets('从选中的对话新建：草稿继承它的角色与工作文件夹', (tester) async {
    var workspace = Directory.systemTemp.createTempSync('athena_inherit_ws');
    addTearDown(() {
      if (workspace.existsSync()) workspace.deleteSync(recursive: true);
    });

    // 先落一条带自定义角色与工作文件夹的对话，页面挂起来后选中它
    final source = await seedSourceChat(
      tester,
      sentinelName: 'Inherit Probe',
      workspacePath: workspace.path,
    );
    await pumpHome(tester);
    await selectSourceChat(tester, source);

    await tapSidebarNewChat(tester);

    expect(
      sentinelChipLabel('Inherit Probe'),
      findsOneWidget,
      reason: '草稿的角色应继承来源对话，而不是回到默认 Athena',
    );
    expect(
      workspaceChipLabel(p.basename(workspace.path)),
      findsOneWidget,
      reason: '草稿的工作文件夹应继承来源对话，否则新对话的 shell 会跑回主目录',
    );
    // 继承只是初值：模型/保留策略不跟着走（用户只要求角色与文件夹）
    expect(
      GetIt.instance<ChatViewModel>().currentRetention.value,
      ChatViewModel.defaultDraftRetention,
    );
  });

  testWidgets('来源对话「不用角色」时：草稿也是不用角色', (tester) async {
    // sentinel_id = 0 是保留值，继承时必须原样带过来（同样不落 sentinels 表），
    // 否则用户显式选的"直接对话"会被悄悄换成 Athena
    final source = await seedSourceChat(
      tester,
      sentinelName: null,
      workspacePath: null,
    );
    await pumpHome(tester);
    await selectSourceChat(tester, source);
    expect(sentinelChipLabel('No Sentinel'), findsOneWidget);

    await tapSidebarNewChat(tester);

    expect(sentinelChipLabel('No Sentinel'), findsOneWidget);
    expect(
      workspaceChipLabel('No folder'),
      findsOneWidget,
      reason: '来源没设工作文件夹时草稿也是"不指定"',
    );
  });

  testWidgets('启动即草稿（没有选中对话）：仍是默认角色与不指定文件夹', (tester) async {
    // 来源只来自"当前选中的对话"：没有它就回默认，而不是沿用上次看过的对话
    var workspace = Directory.systemTemp.createTempSync('athena_idle_ws');
    addTearDown(() {
      if (workspace.existsSync()) workspace.deleteSync(recursive: true);
    });
    await seedSourceChat(
      tester,
      sentinelName: 'Inherit Probe',
      workspacePath: workspace.path,
    );
    await pumpHome(tester);

    expect(sentinelChipLabel('Athena'), findsOneWidget);
    expect(workspaceChipLabel('No folder'), findsOneWidget);
  });
}
