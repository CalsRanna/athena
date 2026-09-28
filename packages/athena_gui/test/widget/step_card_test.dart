import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/component/step_card.dart';
import 'package:athena_gui/component/step_primitives.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/util/message_display_util.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 工具步骤头部的两条口径：
/// 1. **文案只认 call_description**：解析得出就用模型自述，解析不出（缺该字段，
///    或参数还是流式中的半截 JSON）一律 `Using a tool`，不把原始参数摆到头部。
/// 2. **组头图标跟随当前步骤**：进行中使用当前工具 / 推理 / 压缩自己的图标；
///    工具文案可能只是通用的 `Using a tool`，图标负责说明是哪个工具；结束态是
///    汇总文案，仍用通用图标。
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
    MessageEntity(chatId: '1', role: 'assistant', reasoningContent: '想想'),
  );

  ContextCompactionStep compaction({bool live = true}) => ContextCompactionStep(
    step: CompactionStep(
      messageId: 'compaction-1',
      seq: 1,
      chatId: '1',
      runId: 1,
      phase: live ? CompactionPhase.summarizing : CompactionPhase.completed,
      startedAt: DateTime(2026),
      beforeTokens: 1000,
    ),
    isLive: live,
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

  for (final grouped in [false, true]) {
    testWidgets('${grouped ? '分组' : '单步'}工具头从占位变为描述，不泄露参数', (tester) async {
      const description = '读取配置文件';
      const completeArgs =
          '{"call_description":"读取配置文件","path":"/tmp/config.json"}';
      const stages = [
        ('', 'Using a tool'),
        ('{"path":"/tmp/config', 'Using a tool'),
        ('{"path":"/tmp/config.json"}', 'Using a tool'),
        ('{"call_description":"   "}', 'Using a tool'),
        ('{"call_description":"读取配', 'Using a tool'),
        (completeArgs, description),
      ];
      final thought = reasoning();
      for (final (arguments, expected) in stages) {
        await pumpCard(tester, [
          if (grouped) thought,
          tool(arguments, result: null),
        ]);

        final header = tester.widget<StepHeader>(find.byType(StepHeader));
        expect(header.label, expected);
        expect(header.label, isNot(contains('/tmp/config')));
      }

      await pumpCard(tester, [
        if (grouped) thought,
        tool(completeArgs),
      ], live: grouped);
      expect(
        tester.widget<StepHeader>(find.byType(StepHeader)).label,
        description,
      );

      if (grouped) {
        await tester.tap(find.byType(StepHeader));
        await tester.pump();
        final headers = tester.widgetList<StepHeader>(find.byType(StepHeader));
        expect(headers.first.label, description);
        expect(headers.last.label, description);
      }
    });
  }

  testWidgets('已完成分组中的工具项缺少描述时仍不展示参数', (tester) async {
    await pumpCard(tester, [
      reasoning(),
      tool('{"path":"/tmp/config.json"}'),
    ], live: false);
    await tester.tap(find.byType(StepHeader));
    await tester.pump();

    expect(
      tester.widgetList<StepHeader>(find.byType(StepHeader)).last.label,
      'Using a tool',
    );
    expect(find.textContaining('/tmp/config.json'), findsNothing);
  });

  group('组头（多步）', () {
    testWidgets('当前步缺 call_description：文案通用、图标是该工具的图标', (tester) async {
      await pumpCard(tester, [reasoning(), tool('{"path":"a.dart"}')]);

      expect(find.text('Using a tool'), findsOneWidget);
      expect(find.byIcon(LucideIcons.file), findsOneWidget);
      expect(find.byIcon(LucideIcons.wrench), findsNothing);
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
      expect(find.byIcon(LucideIcons.search), findsOneWidget);
    });

    testWidgets('结束态是汇总文案，仍用通用图标', (tester) async {
      await pumpCard(tester, [
        reasoning(),
        tool('{"path":"a.dart"}'),
      ], live: false);

      expect(find.textContaining('Used 1 tool'), findsOneWidget);
      expect(find.byIcon(LucideIcons.wrench), findsOneWidget);
      expect(find.byIcon(LucideIcons.file), findsNothing);
    });

    testWidgets('工具后转入推理和压缩时切换图标，结束后恢复汇总', (tester) async {
      final completedTool = tool('{}');
      final thought = reasoning();
      await pumpCard(tester, [completedTool, thought]);

      expect(find.text('Thinking'), findsOneWidget);
      expect(find.byIcon(LucideIcons.sparkles), findsOneWidget);
      expect(find.byIcon(LucideIcons.wrench), findsNothing);

      await pumpCard(tester, [completedTool, thought, compaction()]);

      expect(find.text('正在压缩上下文…'), findsOneWidget);
      expect(find.byIcon(LucideIcons.fileArchive), findsOneWidget);
      expect(find.byIcon(LucideIcons.wrench), findsNothing);

      await pumpCard(tester, [
        completedTool,
        thought,
        compaction(live: false),
      ], live: false);

      expect(find.textContaining('Compacted once'), findsOneWidget);
      expect(find.byIcon(LucideIcons.wrench), findsOneWidget);
      expect(find.byIcon(LucideIcons.fileArchive), findsNothing);
    });

    testWidgets('没有工具的步骤组在压缩中也使用压缩图标', (tester) async {
      await pumpCard(tester, [reasoning(), compaction()]);

      expect(find.byIcon(LucideIcons.fileArchive), findsOneWidget);
      expect(find.byIcon(LucideIcons.sparkles), findsNothing);
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
      expect(iconColor(tester, LucideIcons.file), colors.textSecondary);

      final gesture = await movePointerTo(
        tester,
        tester.getCenter(find.byType(StepHeader)),
      );
      expect(labelColor(tester, '读取配置文件'), colors.textPrimary);
      expect(iconColor(tester, LucideIcons.file), colors.textPrimary);

      await gesture.moveTo(const Offset(0, 0));
      await tester.pump();
      expect(labelColor(tester, '读取配置文件'), colors.textSecondary);
      expect(iconColor(tester, LucideIcons.file), colors.textSecondary);
    });

    testWidgets('不可点头部（结果未返回）：hover 不提亮，仍是次级色', (tester) async {
      await pumpCard(tester, [
        tool('{"call_description":"读取配置文件"}', result: null),
      ], live: false);
      final colors = colorsOf(tester);

      await movePointerTo(tester, tester.getCenter(find.byType(StepHeader)));
      expect(labelColor(tester, '读取配置文件'), colors.textSecondary);
      expect(iconColor(tester, LucideIcons.file), colors.textSecondary);
    });
  });
}
