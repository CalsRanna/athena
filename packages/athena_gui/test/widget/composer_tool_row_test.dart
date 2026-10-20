import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/page/desktop/home/component/image_selector.dart';
import 'package:athena_gui/page/desktop/home/component/message_input.dart';
import 'package:athena_gui/page/desktop/home/component/token_indicator.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// composer 下方那一行控件（审批模式、图片加号、模型名、推理强度、token 圆环）
/// 的 hover 底必须长得一样：都是 28 高的圆角小方块，且都在文字行盒外面还留一圈
/// 内边距。
///
/// 这是**观感一致性**的回归护栏：图片加号与 token 圆环过去各自实现 hover，
/// 一个紧贴 16px 字形、一个根本没有底色，和旁边包着文字的小胶囊放在一起
/// 明显不像同一类按钮。三者现在都走 [AthenaGhostButton]。
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

  Future<void> pumpComposer(WidgetTester tester) async {
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
        home: Scaffold(
          body: DesktopMessageInput(controller: controller, focusNode: focus),
        ),
      ),
    );
    await tester.pump();
  }

  /// 控件内部那颗 ghost 按钮（加号与圆环自己就是 `AthenaGhostButton`，
  /// 文字类控件则是被它包住）。
  Finder ghostOf(Finder owner) =>
      find.descendant(of: owner, matching: find.byType(AthenaGhostButton));

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
}
