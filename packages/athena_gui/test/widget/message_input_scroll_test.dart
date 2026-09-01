import 'package:athena_gui/page/desktop/home/component/message_input.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../test_utils/fakes.dart';

void main() {
  const colors = AthenaColors.dark;

  setUp(setupMobileTestDI);
  tearDown(() async {
    await GetIt.instance.reset();
  });

  ThemeData theme() => ThemeData(
        colorScheme: const ColorScheme.dark(),
        extensions: const [colors],
      );

  group('DesktopMessageInput 多行滚动', () {
    testWidgets('输入超过可视高度时滚动到光标的最新一行', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme(),
          home: Scaffold(
            body: DesktopMessageInput(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 输入超过 maxLines(4) 的多行文本，模拟用户连续输入
      final longText = List.generate(20, (i) => 'line $i').join('\n');
      await tester.enterText(find.byType(TextField), longText);
      await tester.pump();
      // postFrameCallback 中执行滚动
      await tester.pump();

      final scrollable = find.descendant(
        of: find.byType(TextField),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0),
          reason: '多行文本应使输入框内部产生可滚动区域');
      expect(position.pixels, position.maxScrollExtent,
          reason: '输入后应滚动到光标所在的最新一行');
    });

    testWidgets('Shift+Enter 插入换行后滚动到最新行', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme(),
          home: Scaffold(
            body: DesktopMessageInput(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 先填满可视区域，再通过 Shift+Enter 增加一行
      await tester.enterText(
        find.byType(TextField),
        List.generate(20, (i) => 'line $i').join('\n'),
      );
      await tester.pump();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      await tester.pump();

      final scrollable = find.descendant(
        of: find.byType(TextField),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.pixels, position.maxScrollExtent,
          reason: 'Shift+Enter 插入换行后应滚动到最新一行');
    });
  });
}
