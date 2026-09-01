import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/component/button.dart';
import 'package:athena_gui/component/message_list_tile.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

void main() {
  final sentinel = SentinelEntity(name: 'Test', avatar: 'T');

  Future<void> pumpMessage(
    WidgetTester tester, {
    required bool reasoning,
    required bool expanded,
    bool loading = false,
    String reasoningContent = 'reasoning details',
  }) async {
    final message = MessageEntity(
      chatId: 1,
      role: 'assistant',
      reasoningContent: reasoningContent,
      reasoning: reasoning,
      expanded: expanded,
      reasoningStartedAt: DateTime(2026),
      reasoningUpdatedAt: DateTime(2026).add(const Duration(seconds: 2)),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: const [AthenaColors.dark],
        ),
        home: Scaffold(
          body: SizedBox(
            width: 700,
            child: MessageListTile(
              message: message,
              sentinel: sentinel,
              loading: loading,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('完成后的推理卡使用透明弱色 Header 且没有状态图标', (tester) async {
    await pumpMessage(tester, reasoning: false, expanded: true);

    final titleFinder = find.text('Thought for 2.0 seconds');
    expect(titleFinder, findsOneWidget);
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(HugeIcons.strokeRoundedTick02), findsNothing);
    expect(find.byIcon(HugeIcons.strokeRoundedArrowRight01), findsNothing);
    expect(find.byIcon(HugeIcons.strokeRoundedArrowDown01), findsNothing);

    final title = tester.widget<Text>(titleFinder);
    expect(title.style?.color, AthenaColors.dark.textSecondaryOnRaised);

    final header = tester.widget<InkWell>(
      find.ancestor(of: titleFinder, matching: find.byType(InkWell)),
    );
    expect(header.mouseCursor, SystemMouseCursors.click);
    expect(
      header.overlayColor?.resolve({WidgetState.hovered}),
      Colors.transparent,
    );
    expect(header.child, isNot(isA<Padding>()));

    expect(
      find.ancestor(
        of: titleFinder,
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.color == Colors.transparent,
        ),
      ),
      findsOneWidget,
    );

    final contentContainer = tester
        .widgetList<Container>(
          find.ancestor(
            of: find.text('reasoning details'),
            matching: find.byType(Container),
          ),
        )
        .firstWhere(
          (container) =>
              container.margin == const EdgeInsets.fromLTRB(10, 2, 4, 4),
        );
    expect(contentContainer.decoration, isNull);
  });

  testWidgets('推理中的 Header 只使用 shimmer 表达运行状态', (tester) async {
    await pumpMessage(tester, reasoning: true, expanded: false, loading: true);

    expect(find.text('Thinking'), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(HugeIcons.strokeRoundedTick02), findsNothing);
    expect(find.byIcon(HugeIcons.strokeRoundedArrowRight01), findsNothing);
    expect(find.byIcon(HugeIcons.strokeRoundedArrowDown01), findsNothing);
    expect(find.text('reasoning details'), findsNothing);
  });

  testWidgets('首个 delta 前只显示 Working shimmer 且隐藏复制按钮', (tester) async {
    await pumpMessage(
      tester,
      reasoning: false,
      expanded: false,
      loading: true,
      reasoningContent: '',
    );

    expect(find.text('Working…'), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(CopyButton), findsNothing);
    expect(find.text('Thinking'), findsNothing);
  });
}
