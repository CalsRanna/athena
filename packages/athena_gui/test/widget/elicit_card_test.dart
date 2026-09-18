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

  testWidgets('未作答时提交按钮禁用，点击不产生答案', (tester) async {
    final answers = await pumpCard(tester, questions: [question()]);

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(answers(), isNull);
  });

  testWidgets('单选：回传所选 label，推荐项原样回传', (tester) async {
    final answers = await pumpCard(tester, questions: [question()]);

    await tester.tap(find.text('详细 (Recommended)'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(answers(), {'输出用哪种格式？': '详细 (Recommended)'});
  });

  testWidgets('多选：多个 label 用 ", " 连接', (tester) async {
    final answers = await pumpCard(
      tester,
      questions: [question(multiSelect: true)],
    );

    await tester.tap(find.text('摘要'));
    await tester.pump();
    await tester.tap(find.text('详细 (Recommended)'));
    await tester.pump();
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

  testWidgets('自由输入与选项互斥：输入文本后已选选项被清空', (tester) async {
    final answers = await pumpCard(tester, questions: [question()]);

    await tester.tap(find.text('摘要'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '表格');
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    // 若两者并存，答案会变成 "摘要, 表格" 这类歧义值
    expect(answers(), {'输出用哪种格式？': '表格'});
  });

  testWidgets('每个问题都必须作答才可提交', (tester) async {
    final answers = await pumpCard(
      tester,
      questions: [
        question(text: '第一个问题？'),
        // 两题用不同选项标签，避免 finder 命中多个同名文本
        question(
          text: '第二个问题？',
          options: const [
            ElicitOption(label: '甲', description: '第一个选项'),
            ElicitOption(label: '乙', description: '第二个选项'),
          ],
        ),
      ],
    );

    await tester.tap(find.text('摘要'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(answers(), isNull);

    // 第二个问题的选项可能在卡片可视区之外，先滚动到可见再点
    final secondOption = find.text('甲');
    await tester.ensureVisible(secondOption);
    await tester.pump();
    await tester.tap(secondOption);
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(answers(), {'第一个问题？': '摘要', '第二个问题？': '甲'});
  });

  testWidgets('超出最大高度时报错滚动而不是溢出', (tester) async {
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
