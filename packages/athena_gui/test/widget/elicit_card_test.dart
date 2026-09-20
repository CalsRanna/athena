import 'dart:async';

import 'package:athena_core/agent/elicit/elicit_prompt.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena_gui/widget/elicit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ElicitQuestion question({
  String text = '输出用哪种格式？',
  String header = '格式',
  bool multiSelect = false,
  List<ElicitOption>? options,
}) => ElicitQuestion(
  question: text,
  header: header,
  multiSelect: multiSelect,
  options:
      options ??
      const [
        ElicitOption(label: '摘要', description: '简短概览'),
        ElicitOption(label: '详细 (Recommended)', description: '完整说明'),
      ],
);

/// 第二个问题用不同选项标签，避免 finder 命中多个同名文本。
ElicitQuestion secondQuestion({
  String text = '第二个问题？',
  bool multiSelect = false,
}) => question(
  text: text,
  multiSelect: multiSelect,
  options: const [
    ElicitOption(label: '甲', description: '第一个选项'),
    ElicitOption(label: '乙', description: '第二个选项'),
  ],
);

void main() {
  ElicitRequest makeRequest([List<ElicitQuestion>? questions]) => ElicitRequest(
    chatId: 1,
    questions: questions ?? [question()],
    completer: Completer<Map<String, String>?>(),
  );

  /// 渲染卡片并返回「提交回调收到的答案」的读取器。
  Future<Map<String, String>? Function()> pumpCard(
    WidgetTester tester, {
    required List<ElicitQuestion> questions,
    TargetPlatform platform = TargetPlatform.macOS,
    double maxHeight = 400,
  }) async {
    Map<String, String>? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          platform: platform,
          extensions: [AthenaColors.dark],
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: ElicitCard(
              request: makeRequest(questions),
              maxHeight: maxHeight,
              onSubmit: (answers) => submitted = answers,
            ),
          ),
        ),
      ),
    );
    return () => submitted;
  }

  testWidgets('未作答时确认按钮禁用，点击不产生答案', (tester) async {
    final answers = await pumpCard(tester, questions: [question()]);

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(answers(), isNull);
  });

  testWidgets('单选：点选即提交，不需要再按确认按钮', (tester) async {
    final answers = await pumpCard(tester, questions: [question()]);

    await tester.tap(find.text('详细 (Recommended)'));
    await tester.pump();

    expect(answers(), {'输出用哪种格式？': '详细 (Recommended)'});
  });

  testWidgets('多选：点选不提交，确认按钮才提交', (tester) async {
    final answers = await pumpCard(
      tester,
      questions: [question(multiSelect: true)],
    );

    await tester.tap(find.text('摘要'));
    await tester.pump();
    await tester.tap(find.text('详细 (Recommended)'));
    await tester.pump();

    // 多选可能还要继续勾选，点一下就提交会打断用户
    expect(answers(), isNull);

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(answers(), {'输出用哪种格式？': '摘要, 详细 (Recommended)'});
  });

  testWidgets('自由输入：回传自填文本本身，而不是 "Other"', (tester) async {
    final answers = await pumpCard(tester, questions: [question()]);

    await tester.enterText(find.byType(TextField), '你觉得哪个好就用哪个');
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(answers(), {'输出用哪种格式？': '你觉得哪个好就用哪个'});
  });

  testWidgets('自由输入：回车即提交', (tester) async {
    final answers = await pumpCard(tester, questions: [question()]);

    await tester.enterText(find.byType(TextField), '表格');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(answers(), {'输出用哪种格式？': '表格'});
  });

  testWidgets('自由输入与选项互斥：输入文本后已选选项被清空', (tester) async {
    final answers = await pumpCard(
      tester,
      questions: [question(multiSelect: true)],
    );

    await tester.tap(find.text('摘要'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '表格');
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    // 若两者并存，答案会变成 "摘要, 表格" 这类歧义值
    expect(answers(), {'输出用哪种格式？': '表格'});
  });

  testWidgets('自由输入框沿用全局输入样式：半透明填充 + 24 圆角', (tester) async {
    await pumpCard(tester, questions: [question()]);

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('elicit-other-0')),
    );
    final decoration = container.decoration! as BoxDecoration;
    final field = tester.widget<TextField>(find.byType(TextField));

    expect(
      decoration.color,
      AthenaColors.dark.inputBackground.withValues(alpha: 0.6),
    );
    expect(decoration.borderRadius, BorderRadius.circular(24));
    // 文字与提示用白卡家族的颜色，而不是深色页面上的 textInput / border
    expect(field.style?.color, AthenaColors.dark.textOnRaised);
    expect(
      field.decoration?.hintStyle?.color,
      AthenaColors.dark.textSecondaryOnRaised,
    );
    // 尺度取卡片尺度：字号 14，最少与卡片内的按钮同档
    expect(field.style?.fontSize, 14);
    expect(field.minLines, 1);
    expect(field.maxLines, 3);
    final inputHeight = tester
        .getSize(find.byKey(const ValueKey('elicit-other-0')))
        .height;
    final buttonHeight = tester
        .getSize(
          find
              .ancestor(
                of: find.text('Submit'),
                matching: find.byType(Container),
              )
              .first,
        )
        .height;
    expect(inputHeight, greaterThanOrEqualTo(buttonHeight - 2));
  });

  testWidgets('自由输入框随内容自增高，长答案不会挤在一行里', (tester) async {
    await pumpCard(tester, questions: [question()]);

    final field = find.byKey(const ValueKey('elicit-other-0'));
    final single = tester.getSize(field).height;

    await tester.enterText(find.byType(TextField), '这是一段比较长的自填答案，' * 10);
    await tester.pump();

    expect(tester.getSize(field).height, greaterThan(single));
  });

  testWidgets('多问：一次只展示一个问题，问题前标出 1 / 2', (tester) async {
    await pumpCard(
      tester,
      questions: [
        question(text: '第一个问题？'),
        secondQuestion(),
      ],
    );

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('第一个问题？'), findsOneWidget);
    expect(find.text('第二个问题？'), findsNothing);
    // 位置由步骤展示承载，卡片标题不再报数量
    expect(find.text('Question'), findsOneWidget);
  });

  testWidgets('单问：不显示步骤展示', (tester) async {
    await pumpCard(tester, questions: [question()]);

    expect(find.textContaining(' / '), findsNothing);
  });

  testWidgets('多问：未作答的步骤无法前进', (tester) async {
    final answers = await pumpCard(
      tester,
      questions: [
        question(text: '第一个问题？'),
        secondQuestion(),
      ],
    );

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(answers(), isNull);
  });

  testWidgets('多问全单选：点选自动进入下一步，最后一步点选即提交', (tester) async {
    final answers = await pumpCard(
      tester,
      questions: [
        question(text: '第一个问题？'),
        secondQuestion(),
      ],
    );

    await tester.tap(find.text('摘要'));
    await tester.pump();

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('第一个问题？'), findsNothing);
    expect(answers(), isNull);

    await tester.tap(find.text('甲'));
    await tester.pump();

    expect(answers(), {'第一个问题？': '摘要', '第二个问题？': '甲'});
  });

  testWidgets('多问含多选：多选步骤按 Next 前进，最后一步单选点选即提交', (tester) async {
    final answers = await pumpCard(
      tester,
      questions: [
        question(text: '第一个问题？', multiSelect: true),
        secondQuestion(),
      ],
    );

    await tester.tap(find.text('摘要'));
    await tester.pump();

    // 多选还要继续勾：点选既不前进也不提交
    expect(find.text('1 / 2'), findsOneWidget);
    expect(answers(), isNull);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.text('甲'));
    await tester.pump();

    expect(answers(), {'第一个问题？': '摘要', '第二个问题？': '甲'});
  });

  testWidgets('多问：Back 回到上一步且已答内容保留', (tester) async {
    final answers = await pumpCard(
      tester,
      questions: [
        question(text: '第一个问题？'),
        secondQuestion(),
      ],
    );

    await tester.tap(find.text('摘要'));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pump();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('第一个问题？'), findsOneWidget);

    // 第一题仍是已答状态：直接再前进即可，不必重选
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(answers(), isNull);
  });

  testWidgets('超出最大高度时滚动而不是溢出', (tester) async {
    final answers = await pumpCard(
      tester,
      questions: [for (var i = 0; i < 4; i++) question(text: '问题 $i？')],
      maxHeight: 220,
    );

    expect(
      tester.getSize(find.byType(ElicitCard)).height,
      lessThanOrEqualTo(220),
    );
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
    expect(answers(), isNull);
  });
}
