import 'package:athena_gui/page/desktop/home/component/context_selector.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  Future<void> pumpHost(
    WidgetTester tester,
    ValueNotifier<int> retention, {
    AthenaColorMode colorMode = AthenaColorMode.light,
  }) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(retention.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(colorMode),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ValueListenableBuilder<int>(
                valueListenable: retention,
                builder: (context, value, child) => DesktopContextSelector(
                  currentRetention: value,
                  onSelected: (value) => retention.value = value,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder panel() => find
      .descendant(
        of: find.byType(DesktopContextMenu),
        matching: find.byType(DecoratedBox),
      )
      .first;

  Finder selectedOption() => find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        widget.properties.button == true &&
        widget.properties.selected == true,
  );

  tearDown(() => DesktopContextMenuManager.instance.dismiss());

  testWidgets(
    'context selection updates history mode and closes anchored menu',
    (tester) async {
      final retention = ValueNotifier(-1);
      await pumpHost(tester, retention);

      expect(find.text('Context on'), findsOneWidget);
      expect(find.byIcon(LucideIcons.clock4), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget, reason: '入口只有状态图标，无下拉箭头');
      final anchor = tester.getRect(find.byType(DesktopContextSelector));

      await tester.tap(find.text('Context on'));
      await tester.pumpAndSettle();

      expect(find.byType(DesktopContextMenu), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Temperature'), findsNothing);
      expect(find.byType(Slider), findsNothing);
      final menu = tester.getRect(panel());
      expect(menu.right, closeTo(anchor.right, 0.5));
      expect(menu.bottom, closeTo(anchor.top - 8, 0.5));
      expect(menu.height, lessThan(260), reason: '菜单高度贴合两项内容');
      expect(
        find.descendant(
          of: selectedOption(),
          matching: find.text('Use chat history'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Current message only'));
      await tester.pumpAndSettle();

      expect(retention.value, 0, reason: '关闭历史必须映射到零上下文策略');
      expect(find.byType(DesktopContextMenu), findsNothing);
      expect(find.text('Context off'), findsOneWidget);
      expect(find.byIcon(LucideIcons.clockFading), findsOneWidget);
      expect(find.byIcon(LucideIcons.clock4), findsNothing);

      await tester.tap(find.text('Context off'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: selectedOption(),
          matching: find.text('Current message only'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Use chat history'));
      await tester.pumpAndSettle();

      expect(retention.value, -1, reason: '重新开启历史必须恢复自动管理策略');
      expect(find.byType(DesktopContextMenu), findsNothing);
      expect(find.text('Context on'), findsOneWidget);
      expect(find.byIcon(LucideIcons.clock4), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'external history changes refresh icon and dismissal keeps value',
    (tester) async {
      final retention = ValueNotifier(0);
      await pumpHost(tester, retention, colorMode: AthenaColorMode.dark);

      expect(find.text('Context off'), findsOneWidget);
      expect(find.byIcon(LucideIcons.clockFading), findsOneWidget);

      // 对话切换会从外部更新策略，入口不能缓存之前的选择。
      retention.value = -1;
      await tester.pumpAndSettle();
      expect(find.text('Context on'), findsOneWidget);
      expect(find.byIcon(LucideIcons.clock4), findsOneWidget);

      await tester.tap(find.text('Context on'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(16, 16));
      await tester.pumpAndSettle();

      expect(find.byType(DesktopContextMenu), findsNothing);
      expect(retention.value, -1, reason: '点击弹窗外只关闭菜单，不应改变保留策略');
      expect(tester.takeException(), isNull);
    },
  );
}
