import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/page/desktop/home/component/context_selector.dart';
import 'package:athena_gui/page/desktop/home/component/image_selector.dart';
import 'package:athena_gui/page/desktop/home/component/message_input.dart';
import 'package:athena_gui/page/desktop/home/component/sentinel_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/token_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/workspace_indicator.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/reasoning_effort.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../support/athena_test_scope.dart';

import 'package:athena_gui/theme/athena_material_theme.dart';

/// composer 的各个入口控件（输入容器内的图片加号与发送键，下方那一行的
/// 审批模式、Sentinel / 文件夹 / 上下文入口、模型名、推理强度、token 圆环）
/// 的 hover 底必须长得一样：都是 28 高的圆角小方块，且都在文字行盒外面还留
/// 一圈内边距。
///
/// 这是**观感一致性**的回归护栏：图片加号与 token 圆环过去各自实现 hover，
/// 一个紧贴 16px 字形、一个根本没有底色，和旁边包着文字的小胶囊放在一起
/// 明显不像同一类按钮。这些控件现在都走 [AthenaGhostButton]。
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
    tempRoot = Directory.systemTemp.createTempSync('athena_tool_row_test');
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
  });

  tearDown(() async {
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  Future<void> pumpComposer(
    WidgetTester tester, {
    bool reasoning = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final viewModel = GetIt.instance<ChatViewModel>();
    // 圆环要「有上下文占用 + 模型配了窗口」才渲染；两个信号直接给，省掉落盘。
    viewModel.currentModel.value = ModelEntity(
      id: 'm1',
      name: 'Model M',
      modelId: 'm1',
      providerId: 'p1',
      reasoning: reasoning,
      contextWindow: 200000,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    viewModel.currentChat.value = ChatEntity(
      id: 'c1',
      title: 'Chat',
      modelId: 'm1',
      sentinelId: ChatEntity.noSentinelId,
      contextTokens: 36000,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        builder: (context, child) => AthenaTestScope(child: child!),
        home: Scaffold(
          body: DesktopMessageInput(
            controller: controller,
            focusNode: focus,
            onReasoningEffortChange: viewModel.updateCurrentReasoningEffort,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 控件内部那颗 ghost 按钮（加号与圆环自己就是 `AthenaGhostButton`，
  /// 文字类控件则是被它包住）。
  Finder ghostOf(Finder owner) =>
      find.descendant(of: owner, matching: find.byType(AthenaGhostButton));

  testWidgets('推理强度菜单区分默认档和当前档，选中后关闭并更新指示器', (tester) async {
    await pumpComposer(tester, reasoning: true);
    GetIt.instance<SettingViewModel>().defaultReasoningEffort.value = 'low';
    final tiles = find.byType(DesktopContextMenuTile);
    Iterable<DesktopContextMenuTile> rows() => tester.widgetList(tiles);
    String selected() =>
        rows().singleWhere((tile) => tile.selected == true).text;

    await tester.tap(find.text('High'));
    await tester.pump();
    final heading = find.widgetWithText(
      DesktopContextMenuGroupLabel,
      'Reasoning effort',
    );
    expect(heading, findsOneWidget);
    expect(
      tester.getBottomLeft(heading).dy,
      lessThanOrEqualTo(tester.getTopLeft(tiles.first).dy),
    );
    expect(
      rows().map((tile) => tile.text),
      reasoningEffortOptions.map((o) => o.$2),
    );
    expect(selected(), 'High');
    expect(rows().singleWhere((tile) => tile.badge != null).text, 'Low');

    await tester.tap(find.text('Extra High'));
    await tester.pump();
    expect(tiles, findsNothing);
    expect(find.text('Extra High'), findsOneWidget);
    await tester.tap(find.text('Extra High'));
    await tester.pump();
    expect(selected(), 'Extra High');
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(tiles, findsNothing);
    expect(find.text('Extra High'), findsOneWidget);
  });

  testWidgets('图片加号与 token 圆环的 hover 底和其他控件同高', (tester) async {
    await pumpComposer(tester);

    final image = find.byType(DesktopImageSelector);
    final token = find.byType(DesktopTokenIndicator);
    expect(image, findsOneWidget);
    expect(token, findsOneWidget, reason: '有占用数据时圆环才渲染');

    final imageBox = ghostOf(image);
    final tokenBox = ghostOf(token);
    expect(imageBox, findsOneWidget, reason: '加号自己就是 ghost 按钮');
    expect(tokenBox, findsOneWidget, reason: '圆环也要有 hover 底');
    expect(
      tester.getSize(imageBox),
      tester.getSize(tokenBox),
      reason: '加号与圆环的 hover 底必须同尺寸',
    );
    expect(tester.getSize(imageBox).height, 28);
    expect(tester.getSize(tokenBox).height, 28);
  });

  testWidgets('上下文入口与图片加号同为 28 方盒、16 图标', (tester) async {
    await pumpComposer(tester);

    final owners = [
      find.byType(DesktopImageSelector),
      find.byType(DesktopSentinelIndicator),
      find.byType(DesktopWorkspaceIndicator),
      find.byType(DesktopContextSelector),
    ];
    for (final owner in owners) {
      expect(owner, findsOneWidget);
      final box = ghostOf(owner);
      expect(box, findsOneWidget, reason: '入口自己就是 ghost 按钮');
      expect(tester.getSize(box), const Size(28, 28));
      final icon = tester.widget<Icon>(
        find.descendant(of: owner, matching: find.byType(Icon)),
      );
      expect(icon.size, 16, reason: '图标统一取 regularSize');
    }
  });

  testWidgets('发送/停止键的 hover 底与其他 ghost 控件同档', (tester) async {
    await pumpComposer(tester);

    // 输入容器里有且只有两个 ghost 按钮：图片加号与发送键
    final inputBox = find
        .ancestor(
          of: find.byType(TextField),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    expect(
      find.descendant(of: inputBox, matching: find.byType(AthenaGhostButton)),
      findsNWidgets(2),
    );
    final send = find.ancestor(
      of: find.byIcon(LucideIcons.arrowUp),
      matching: find.byType(AthenaGhostButton),
    );
    expect(send, findsOneWidget);
    expect(
      tester.getSize(send),
      const Size(28, 28),
      reason: '容器外那一行的 ghost 都是 28 方盒，发送键不能比它们小',
    );
    // 输入容器的高度不能因为这一格变大而被撑开
    expect(
      tester.getSize(inputBox).height,
      lessThanOrEqualTo(48),
      reason: '28 方盒要落在容器内容区之内',
    );
  });

  testWidgets('圆环的 hover 底右缘与上方输入容器右缘对齐', (tester) async {
    await pumpComposer(tester);

    final ghostRect = tester.getRect(
      ghostOf(find.byType(DesktopTokenIndicator)),
    );
    // 输入容器：从输入框往上最近的带动画容器（`_ComposerInputBox`）
    final inputBox = tester.getRect(
      find
          .ancestor(
            of: find.byType(TextField),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(
      ghostRect.right,
      closeTo(inputBox.right, 0.5),
      reason: '圆环底要贴齐输入框右缘，悬出去或缩在里面都会和上方错开',
    );
  });

  testWidgets('没有会话时圆环照样显示，画一圈空轨道', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // 刻意不给 currentChat / currentModel：新建对话、还没跑过任何推理
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        builder: (context, child) => AthenaTestScope(child: child!),
        home: Scaffold(
          body: DesktopMessageInput(controller: controller, focusNode: focus),
        ),
      ),
    );
    await tester.pump();

    final token = find.byType(DesktopTokenIndicator);
    expect(token, findsOneWidget, reason: '圆环常驻，不随数据缺席消失');
    final ring = find.descendant(
      of: token,
      matching: find.byType(CircularProgressIndicator),
    );
    expect(ring, findsOneWidget);
    expect(
      tester.widget<CircularProgressIndicator>(ring).value,
      0,
      reason: '无数据画空轨道，而不是转圈的不确定态',
    );
    // 窗口也是 0（没有模型）：面板/占用条的除法不能被除零污染
    expect(tester.takeException(), isNull);
  });

  testWidgets('回退后 contextTokens = -1 按 0 展示，不出现负数', (tester) async {
    await pumpComposer(tester);
    final viewModel = GetIt.instance<ChatViewModel>();
    viewModel.currentChat.value = viewModel.currentChat.value!.copyWith(
      contextTokens: ChatEntity.unknownContextTokens,
      cachedTokens: ChatEntity.unknownContextTokens,
    );
    await tester.pump();

    final ring = tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: find.byType(DesktopTokenIndicator),
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    expect(ring.value, 0);
  });

  testWidgets('多行输入时加号与发送键贴着内容区底部', (tester) async {
    await pumpComposer(tester);
    await tester.enterText(
      find.byType(TextField),
      'a\nb\nc\nd\ne\nf\ng\nh\ni\nj\nk\nl',
    );
    await tester.pump();

    final inputBox = tester.getRect(
      find
          .ancestor(
            of: find.byType(TextField),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final imageGhost = tester.getRect(
      ghostOf(find.byType(DesktopImageSelector)),
    );
    final sendGhost = tester.getRect(
      find.ancestor(
        of: find.byIcon(LucideIcons.arrowUp),
        matching: find.byType(AthenaGhostButton),
      ),
    );
    // 容器 1px 描边 + 纵向 padding 8：内容区底部 = 容器底 - 9。居中对齐时
    // 多行会把图标留在整块高度中间，底缘远高于这里。
    expect(imageGhost.bottom, closeTo(inputBox.bottom - 9, 0.5));
    expect(sendGhost.bottom, closeTo(inputBox.bottom - 9, 0.5));
  });
}
