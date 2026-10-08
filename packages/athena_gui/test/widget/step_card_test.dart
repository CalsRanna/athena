import 'package:athena_core/entity/compaction_step.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/component/step_card.dart';
import 'package:athena_gui/component/step_primitives.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/util/message_display_util.dart';
import 'package:athena_gui/widget/workspace_text_size.dart';
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
    String id = 'call-1',
  }) => ToolCallStep(
    id: id,
    toolName: name,
    arguments: arguments,
    result: result,
  );

  /// 默认耗时 0：构造用固定时刻，汇总里的 `Thought X seconds` 才是定值。
  ReasoningStep reasoning({Duration thought = Duration.zero}) {
    final startedAt = DateTime(2026);
    return ReasoningStep(
      MessageEntity(
        chatId: '1',
        role: 'assistant',
        reasoningContent: '想想',
        reasoningStartedAt: startedAt,
        reasoningUpdatedAt: startedAt.add(thought),
      ),
    );
  }

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

  /// 把鼠标移进某个组件：hover 相关的断言都靠它进入 hover 态。
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

  group('runningLabel（进行中的组头）', () {
    test('当前步是工具调用：描述后接累计用量（含正在跑的那一个）', () {
      expect(
        StepCard.runningLabel([
          reasoning(thought: const Duration(milliseconds: 3200)),
          tool('{"call_description":"运行测试"}'),
        ]),
        '运行测试 · Used 1 tool · Thought 3.2 seconds',
      );
    });

    test('当前步是推理：Thinking 后接已结算的用量，正在跑的这段不算进耗时', () {
      expect(
        StepCard.runningLabel([
          tool('{"call_description":"运行测试"}'),
          reasoning(),
        ]),
        'Thinking · Used 1 tool',
      );
    });

    test('当前步是压缩：状态后接已结算的用量，正在跑的这次不算进次数', () {
      expect(
        StepCard.runningLabel([reasoning(), compaction()]),
        '正在压缩上下文… · Thought 0.0 seconds',
      );
    });

    test('还没有任何已结算步骤：只有当前步自己的文案', () {
      expect(StepCard.runningLabel([reasoning()]), 'Thinking');
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
        expect(
          header.label,
          grouped ? '$expected · Used 1 tool · Thought 0.0 seconds' : expected,
          reason: '组头在运行中接上截至此刻的汇总，单步卡只有自己的文案',
        );
        expect(header.label, isNot(contains('/tmp/config')));
      }

      await pumpCard(tester, [
        if (grouped) thought,
        tool(completeArgs),
      ], live: grouped);
      expect(
        tester.widget<StepHeader>(find.byType(StepHeader)).label,
        grouped
            ? '$description · Used 1 tool · Thought 0.0 seconds'
            : description,
      );

      if (grouped) {
        await tester.tap(find.byType(StepHeader));
        await tester.pump();
        final headers = tester.widgetList<StepHeader>(find.byType(StepHeader));
        expect(
          headers.first.label,
          '$description · Used 1 tool · Thought 0.0 seconds',
        );
        expect(
          headers.last.label,
          description,
          reason: '展开后的子项只写自己的文案，不重复组头的汇总',
        );
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

      expect(
        find.text('Using a tool · Used 1 tool · Thought 0.0 seconds'),
        findsOneWidget,
      );
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

      expect(
        find.text('抓取文档 · Used 1 tool · Thought 0.0 seconds'),
        findsOneWidget,
      );
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

    testWidgets('当前步是工具调用：描述后接累计用量，含正在跑的那一个', (tester) async {
      final thought = reasoning(thought: const Duration(milliseconds: 3200));
      final running = tool(
        '{"call_description":"运行测试"}',
        name: 'bash',
        id: 'call-2',
        result: null,
      );
      await pumpCard(tester, [
        thought,
        tool('{"call_description":"读取配置文件"}'),
        running,
      ]);
      expect(
        find.text('运行测试 · Used 2 tools · Thought 3.2 seconds'),
        findsOneWidget,
      );

      // 它返回后数字不跳：进行中就已经把正在跑的那个算进去了
      await pumpCard(tester, [
        thought,
        tool('{"call_description":"读取配置文件"}'),
        tool('{"call_description":"运行测试"}', name: 'bash', id: 'call-2'),
      ]);
      expect(
        find.text('运行测试 · Used 2 tools · Thought 3.2 seconds'),
        findsOneWidget,
      );
    });

    testWidgets('展开后的子项只写自己，不重复组头的汇总', (tester) async {
      await pumpCard(tester, [
        reasoning(thought: const Duration(milliseconds: 3200)),
        tool('{"call_description":"读取配置文件"}', result: null),
      ]);
      await tester.tap(find.byType(StepHeader));
      await tester.pump();

      expect(
        tester
            .widgetList<StepHeader>(find.byType(StepHeader))
            .map((header) => header.label),
        [
          '读取配置文件 · Used 1 tool · Thought 3.2 seconds',
          'Thought 3.2 seconds',
          '读取配置文件',
        ],
      );
    });

    testWidgets('工具后转入推理和压缩时切换图标，结束后恢复汇总', (tester) async {
      final completedTool = tool('{}');
      final thought = reasoning();
      await pumpCard(tester, [completedTool, thought]);

      expect(find.text('Thinking · Used 1 tool'), findsOneWidget);
      expect(find.byIcon(LucideIcons.sparkles), findsOneWidget);
      expect(find.byIcon(LucideIcons.wrench), findsNothing);
      expect(
        find.textContaining('Thought'),
        findsNothing,
        reason: '正在跑的那段推理不计入自己的耗时',
      );

      await pumpCard(tester, [completedTool, thought, compaction()]);

      expect(
        find.text('正在压缩上下文… · Used 1 tool · Thought 0.0 seconds'),
        findsOneWidget,
      );
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
      expect(labelColor(tester, '读取配置文件'), colors.textSecondary);
      await tester.pump(AthenaMotion.hover ~/ 2);
      expect(
        labelColor(tester, '读取配置文件'),
        Color.lerp(colors.textSecondary, colors.textPrimary, 0.5),
      );
      expect(iconColor(tester, LucideIcons.file), labelColor(tester, '读取配置文件'));
      await tester.pump(AthenaMotion.hover ~/ 2);
      expect(labelColor(tester, '读取配置文件'), colors.textPrimary);
      expect(iconColor(tester, LucideIcons.file), colors.textPrimary);

      await gesture.moveTo(const Offset(0, 0));
      await tester.pump();
      expect(labelColor(tester, '读取配置文件'), colors.textPrimary);
      await tester.pump(AthenaMotion.hover ~/ 2);
      expect(
        labelColor(tester, '读取配置文件'),
        Color.lerp(colors.textPrimary, colors.textSecondary, 0.5),
      );
      await tester.pump(AthenaMotion.hover ~/ 2);
      expect(labelColor(tester, '读取配置文件'), colors.textSecondary);
      expect(iconColor(tester, LucideIcons.file), colors.textSecondary);
    });

    testWidgets('不可点头部（没有正文）：hover 不提亮，仍是次级色', (tester) async {
      // 今天三种步骤都有正文，这条契约在组件层验证：没有正文的头不该可点。
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAthenaThemeData(AthenaColorMode.light),
          home: const Scaffold(
            body: StepHeader(icon: LucideIcons.wrench, label: 'Using a tool'),
          ),
        ),
      );
      final colors = colorsOf(tester);

      await movePointerTo(tester, tester.getCenter(find.byType(StepHeader)));
      expect(labelColor(tester, 'Using a tool'), colors.textSecondary);
      expect(iconColor(tester, LucideIcons.wrench), colors.textSecondary);
    });
  });

  group('字号档位', () {
    // 卡片里的文字与消息正文同档**同重**。折叠头与推理正文曾在两次排版重构的
    // 交接处落到 `caption` 档（12），折叠头还一度挂在 `label` 档的 w500 上——
    // 同一处漂移发生过两次，钉在这里。
    testWidgets('折叠头跟随 Text size 档位，字重是正文档', (tester) async {
      for (final size in AthenaTextSize.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAthenaThemeData(AthenaColorMode.light),
            home: Scaffold(
              body: AthenaWorkspaceTextSize(
                size: size,
                child: StepCard(
                  steps: [tool('{"call_description":"读取配置文件"}')],
                  live: false,
                ),
              ),
            ),
          ),
        );

        final header = tester.widget<Text>(find.text('读取配置文件'));
        expect(header.style?.fontSize, size.prose.fontSize);
        expect(header.style?.fontWeight, AthenaTextStyle.body.fontWeight);
      }
    });

    testWidgets('推理正文与消息正文同档同重（跟随 Text size）', (tester) async {
      await pumpCard(tester, [reasoning()]);
      await tester.tap(find.byType(StepHeader));
      // 运行中的头带循环 shimmer，pumpAndSettle 不会收敛
      await tester.pump();

      final body = tester.widget<Text>(find.text('想想'));
      expect(body.style?.fontSize, AthenaTextSize.medium.prose.fontSize);
      expect(body.style?.fontWeight, AthenaTextStyle.body.fontWeight);
      expect(
        body.style!.height! * body.style!.fontSize!,
        closeTo(AthenaTextSize.medium.lineHeight, 0.001),
      );
    });
  });

  group('展开提示（箭头）', () {
    AnimatedRotation rotation(WidgetTester tester) =>
        tester.widget<AnimatedRotation>(
          find.ancestor(
            of: find.byIcon(LucideIcons.chevronRight),
            matching: find.byType(AnimatedRotation),
          ),
        );

    /// 显隐由 opacity 表达，不是加删组件——隐藏时仍占位。
    double arrowOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byIcon(LucideIcons.chevronRight),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    testWidgets('静止不显示，hover 显形，展开后保持可见并转向下', (tester) async {
      await pumpCard(tester, [
        tool('{"call_description":"读取配置文件"}'),
      ], live: false);

      expect(arrowOpacity(tester), 0);
      expect(rotation(tester).turns, 0, reason: '收起时指向右');

      await movePointerTo(tester, tester.getCenter(find.byType(StepHeader)));
      expect(arrowOpacity(tester), 1);

      await tester.tap(find.byType(StepHeader));
      await tester.pump();
      expect(rotation(tester).turns, 0.25, reason: '展开后指向下');
      expect(arrowOpacity(tester), 1, reason: '展开后不再依赖 hover');
    });

    testWidgets('没有正文的头不给箭头（组件层契约）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAthenaThemeData(AthenaColorMode.light),
          home: const Scaffold(
            body: StepHeader(icon: LucideIcons.wrench, label: 'Using a tool'),
          ),
        ),
      );

      await movePointerTo(tester, tester.getCenter(find.byType(StepHeader)));
      expect(find.byIcon(LucideIcons.chevronRight), findsNothing);
    });
  });

  testWidgets('运行中的工具也能展开：正文是一句占位，不铺参数', (tester) async {
    const args = '{"call_description":"读取配置文件","path":"/tmp/config.json"}';
    await pumpCard(tester, [tool(args, result: null)]);

    expect(find.text(StepCard.usingToolLabel), findsNothing, reason: '折叠时只有头部');

    await tester.tap(find.byType(StepHeader));
    // 运行中的头带循环 shimmer，pumpAndSettle 不会收敛
    await tester.pump();
    expect(find.text(StepCard.usingToolLabel), findsOneWidget);
    expect(find.textContaining('/tmp/config.json'), findsNothing);
  });

  testWidgets('结果返回后正文是结果本身，不再铺开参数', (tester) async {
    const args = '{"call_description":"读取配置文件","path":"/tmp/config.json"}';
    await pumpCard(tester, [tool(args)], live: false);

    await tester.tap(find.byType(StepHeader));
    await tester.pump();
    expect(find.textContaining('/tmp/config.json'), findsNothing);
    expect(find.text('ok'), findsOneWidget);
  });
}
