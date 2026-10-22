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
import 'package:athena_gui/view_model/chat_params_state.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import '../support/athena_test_scope.dart';
import 'package:athena_gui/theme/athena_material_theme.dart';

/// 首页"新建对话"整条链路的验收（页级）：点侧栏 New session、按 ⌘N / Ctrl+N
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
    final editable = composerInput();
    if (editable.evaluate().isEmpty) return false;
    return tester.widget<EditableText>(editable).focusNode.hasFocus;
  }

  /// 交替「真实异步窗口 + pump」把一次 async 动作推完。页面里的 I/O 是一条
  /// 串行 await 链，只放一次 runAsync 只够第一段（原因见 [pumpHome]）。
  ///
  /// 20 轮是按最长的单次动作（`prepareNewChatDraft`：读设置 → 取角色 → 落
  /// 草稿）实测定的，比它长再调；调小了会表现成「断言读到中间态」而不是报错。
  Future<void> settle(WidgetTester tester, {int rounds = 20}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  /// 交替「真实异步窗口 + pump」直到 [done] 为真。
  ///
  /// 不能把整个 Future 塞进一次 `runAsync` 去 await：这条链中间的 continuation
  /// 要等下一帧才排空（同 [pumpHome] 的道理），一次 runAsync 会永远等不到完成。
  Future<void> settleUntil(
    WidgetTester tester,
    bool Function() done, {
    int maxRounds = 200,
  }) async {
    for (var i = 0; i < maxRounds && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await settle(tester);
  }

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(
          AthenaColorMode.light,
        ).copyWith(platform: TargetPlatform.macOS),
        builder: (context, child) => AthenaTestScope(child: child!),
        home: const DesktopHomePage(),
      ),
    );
    // `_initState` 是一串真实文件 I/O（会话、设置、模型），而且一个接一个
    // await：只放一次真实异步窗口不够——每完成一段 I/O，它的 continuation 要等
    // 下一帧才排空，下一个 I/O 又需要新的真实异步窗口。所以交替「真实异步窗口
    // + pump」，把这条链推完。
    //
    // 等到「草稿默认值已经落好」为止：`_initState` 是 setting → chat（含
    // `prepareNewChatDraft` 的角色/工作文件夹）→ 焦点 的串行 await 链，链上
    // 每一段都要一整轮真实异步窗口 + pump 才推得动。按迭代次数卡上限时，预算
    // ≈链上的 await 段数：本地实测焦点要到第 53 轮才落位，整文件并发跑时
    // 66~73 轮，余量只剩十几次——CI runner 慢一点、又并发跑多个测试文件，
    // 多占几次就越过上限，断言便读到中间态（与 workspace_text_size_test 的
    // 修复口径一致，见 ee7fb66）。
    //
    // 条件用 `currentSentinel` 而不是焦点：焦点正是本文件要验证的东西，拿它当
    // 「init 走完」的标志，后面的断言就成了同义反复。`resetToDraftDefaults`
    // 设完它之后 `_initState` 才 `requestFocus`，正好是焦点之前的最后一个信号。
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (GetIt.instance<ChatViewModel>().currentSentinel.value == null &&
        DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(
      GetIt.instance<ChatViewModel>().currentSentinel.value,
      isNotNull,
      reason: '启动链没在预算内走完，下面的焦点断言就无从谈起',
    );
    // 焦点是在 `currentSentinel` 之后才请求的：再走几轮，让这次 requestFocus
    // 完成那一帧，别让断言抢在它前面。
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
    final platform = Theme.of(
      tester.element(find.byType(DesktopHomePage)),
    ).platform;
    final modifier = platform == TargetPlatform.macOS
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
          modelId: '1',
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
  /// 选中一条对话（等价于用户在侧栏点它）；此刻它就是"当前对话"。
  Future<void> selectSourceChat(WidgetTester tester, ChatEntity chat) async {
    var done = false;
    GetIt.instance<ChatViewModel>()
        .selectChat(chat)
        .whenComplete(() => done = true);
    await settleUntil(tester, () => done);
  }

  /// 点侧栏的 "New session" 行。顶栏标题在草稿态也是 'New session'，所以按侧栏子树
  /// 定位，避免命中标题。
  Future<void> tapSidebarNewChat(WidgetTester tester) async {
    final newChatButton = find.descendant(
      of: find.byType(DesktopChatListView),
      matching: find.text('New session'),
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

  testWidgets('点侧栏 New session：焦点落回 composer', (tester) async {
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

  testWidgets('从已打开的对话按 ⌘N：输入框仍连着平台的文本输入', (tester) async {
    // 这条覆盖"从对话回到草稿"的换槽场景：composer 的输入元素若在换对话时被
    // 重建（例如把它按 chatId 换 key），它承托的焦点节点还是同一个、焦点没有
    // 变化，新的 EditableText 不会重开文本输入连接——于是输入框看着还聚焦，
    // 真实平台上却打不进字，页里那次 requestFocus 也救不回来。
    final source = await seedSourceChat(tester);
    await pumpHome(tester);
    await selectSourceChat(tester, source);

    await tester.tap(composerInput());
    await tester.pump();
    expect(composerFocused(tester), isTrue, reason: '前置：composer 持焦');
    expect(
      tester.testTextInput.hasAnyClients,
      isTrue,
      reason: '前置：平台文本输入已连到这个输入框',
    );

    await pressNewChat(tester);
    await settle(tester);

    expect(composerFocused(tester), isTrue);
    // 只看 hasFocus 会漏掉这个回归：`tester.enterText` 内部会先 requestKeyboard
    // 把连接接回去，同样测不出来，所以这里直接断言连接还在。
    expect(
      tester.testTextInput.hasAnyClients,
      isTrue,
      reason: '⌘N 之后输入框必须仍连着平台文本输入，否则新对话里打字没有反应',
    );
  });

  testWidgets('侧栏 New session 的快捷键提示：静止没有，hover 才出现', (tester) async {
    await pumpHome(tester);
    // pumpHome 显式使用 macOS 主题，期望不再依赖运行测试的宿主系统。
    const hintLabel = '⌘N';
    final row = find.descendant(
      of: find.byType(DesktopChatListView),
      matching: find.text('New session'),
    );
    final hint = find.descendant(
      of: find.byType(DesktopChatListView),
      matching: find.text(hintLabel),
    );
    expect(row, findsOneWidget);
    double hintOpacity() => tester
        .widget<FadeTransition>(
          find.ancestor(of: hint, matching: find.byType(FadeTransition)).first,
        )
        .opacity
        .value;
    expect(hintOpacity(), 0, reason: '静止时提示不可见');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(row));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    expect(hintOpacity(), closeTo(0.5, 0.01));
    await tester.pump(const Duration(milliseconds: 75));
    expect(hintOpacity(), 1, reason: 'hover 后提示显形');

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(hintOpacity(), 0, reason: '指针移开提示收回');
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
    final workspace = Directory.systemTemp.createTempSync('athena_inherit_ws');
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
      ChatParamsState.defaultDraftRetention,
    );
  });

  testWidgets('来源对话「不用角色」时：草稿也是不用角色', (tester) async {
    // sentinel_id = null 表示不使用角色，继承时必须保留（不落 sentinels 表），
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
    final workspace = Directory.systemTemp.createTempSync('athena_idle_ws');
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
