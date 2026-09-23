import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/component/step_card.dart';
import 'package:athena_gui/component/step_primitives.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/util/message_display_util.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

/// 工具步骤头部的两条口径：
/// 1. **文案只认 call_description**：解析得出就用模型自述，解析不出（缺该字段，
///    或参数还是流式中的半截 JSON）一律 `Using a tool`，不把原始参数摆到头部。
/// 2. **组头图标跟随当前步骤**：进行中且当前步是工具调用时用它自己的图标——文案
///    可能只是通用的 `Using a tool`，图标负责说明是哪个工具；结束态是汇总文案，
///    仍用通用图标。
void main() {
  ToolCallStep tool(
    String arguments, {
    String name = 'file_read',
    String? result = 'ok',
  }) => ToolCallStep(
    id: 'call-1',
    toolName: name,
    arguments: arguments,
    result: result,
  );

  ReasoningStep reasoning() => ReasoningStep(
    MessageEntity(chatId: 1, role: 'assistant', reasoningContent: '想想'),
  );

  Future<void> pumpCard(
    WidgetTester tester,
    List<AssistantStep> steps, {
    bool live = true,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildAthenaThemeData(AthenaColorMode.light),
      home: Scaffold(
        body: StepCard(steps: steps, live: live),
      ),
    ),
  );

  group('currentLabel', () {
    test('有 call_description 时用模型自述', () {
      expect(
        StepCard.currentLabel(tool('{"call_description":"读取配置文件"}')),
        '读取配置文件',
      );
    });

    test('缺 call_description 时退回通用文案', () {
      expect(StepCard.currentLabel(tool('{"path":"a.dart"}')), 'Using a tool');
      expect(StepCard.currentLabel(tool('{}')), 'Using a tool');
      expect(StepCard.currentLabel(tool('')), 'Using a tool');
      expect(
        StepCard.currentLabel(tool('{"call_description":"   "}')),
        'Using a tool',
      );
    });

    test('流式半截 JSON 解析不出时同样退回通用文案', () {
      expect(
        StepCard.currentLabel(tool('{"call_description":"读取配')),
        'Using a tool',
      );
    });
  });

  group('组头（多步）', () {
    testWidgets('当前步缺 call_description：文案通用、图标是该工具的图标', (tester) async {
      await pumpCard(tester, [reasoning(), tool('{"path":"a.dart"}')]);

      expect(find.text('Using a tool'), findsOneWidget);
      expect(find.byIcon(HugeIcons.strokeRoundedFile01), findsOneWidget);
      expect(find.byIcon(HugeIcons.strokeRoundedTools), findsNothing);
    });

    testWidgets('当前步有 call_description：文案是自述，图标仍是该工具的图标', (tester) async {
      await pumpCard(tester, [
        reasoning(),
        tool(
          '{"call_description":"抓取文档","url":"https://x"}',
          name: 'web_search',
        ),
      ]);

      expect(find.text('抓取文档'), findsOneWidget);
      expect(find.byIcon(HugeIcons.strokeRoundedSearch01), findsOneWidget);
    });

    testWidgets('结束态是汇总文案，仍用通用图标', (tester) async {
      await pumpCard(tester, [
        reasoning(),
        tool('{"path":"a.dart"}'),
      ], live: false);

      expect(find.textContaining('Used 1 tool'), findsOneWidget);
      expect(find.byIcon(HugeIcons.strokeRoundedTools), findsOneWidget);
      expect(find.byIcon(HugeIcons.strokeRoundedFile01), findsNothing);
    });
  });

  group('头部 hover 提亮', () {
    /// 头部静止是次级文字色，hover 提亮到正文色（`textPrimary`）——与
    /// `AthenaTextButton` 的 `textSecondary → textPrimary` 同一口径。
    ///
    /// 断言的是前景取值口径，不涉及画面：运行中的头会被 shimmer 的 `srcIn`
    /// 整块改色，那时提亮本来看不见。
    Color? labelColor(WidgetTester tester, String label) =>
        tester.widget<Text>(find.text(label)).style?.color;

    Color? iconColor(WidgetTester tester, IconData icon) =>
        tester.widget<Icon>(find.byIcon(icon)).color;

    AthenaColors colorsOf(WidgetTester tester) => Theme.of(
      tester.element(find.byType(StepHeader)),
    ).extension<AthenaColors>()!;

    Future<TestGesture> movePointerTo(
      WidgetTester tester,
      Offset position,
    ) async {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(position);
      await tester.pump();
      return gesture;
    }

    testWidgets('可点头部：图标与文案一起提亮，移开还原', (tester) async {
      await pumpCard(tester, [
        tool('{"call_description":"读取配置文件"}'),
      ], live: false);
      final colors = colorsOf(tester);
      expect(labelColor(tester, '读取配置文件'), colors.textSecondary);
      expect(
        iconColor(tester, HugeIcons.strokeRoundedFile01),
        colors.textSecondary,
      );

      final gesture = await movePointerTo(
        tester,
        tester.getCenter(find.byType(StepHeader)),
      );
      expect(labelColor(tester, '读取配置文件'), colors.textPrimary);
      expect(
        iconColor(tester, HugeIcons.strokeRoundedFile01),
        colors.textPrimary,
      );

      await gesture.moveTo(const Offset(0, 0));
      await tester.pump();
      expect(labelColor(tester, '读取配置文件'), colors.textSecondary);
      expect(
        iconColor(tester, HugeIcons.strokeRoundedFile01),
        colors.textSecondary,
      );
    });

    testWidgets('不可点头部（结果未返回）：hover 不提亮，仍是次级色', (tester) async {
      await pumpCard(tester, [
        tool('{"call_description":"读取配置文件"}', result: null),
      ], live: false);
      final colors = colorsOf(tester);

      await movePointerTo(tester, tester.getCenter(find.byType(StepHeader)));
      expect(labelColor(tester, '读取配置文件'), colors.textSecondary);
      expect(
        iconColor(tester, HugeIcons.strokeRoundedFile01),
        colors.textSecondary,
      );
    });
  });
}
