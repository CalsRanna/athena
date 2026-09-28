import 'package:athena_gui/page/mobile/chat/component/send_button.dart';
import 'package:athena_gui/page/mobile/chat/component/user_input.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in AthenaColorMode.values) {
    testWidgets('mobile composer focus and blur keep its layout in $mode', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var submitted = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAthenaThemeData(mode),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: UserInput(
                  controller: controller,
                  isStreaming: false,
                  onSubmitted: () => submitted++,
                ),
              ),
            ),
          ),
        ),
      );
      final colors = colorsOf(mode);
      final composer = find.byType(UserInput);
      final shell = find.descendant(
        of: composer,
        matching: find.byType(AnimatedContainer),
      );
      Border border() =>
          (tester.widget<AnimatedContainer>(shell).decoration! as BoxDecoration)
                  .border!
              as Border;
      final initialSize = tester.getSize(composer);
      expect(border().top.color, colors.neutralBorder);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(border().top.color, colors.accent);
      expect(border().top.width, 1);
      expect(tester.getSize(composer), initialSize);

      await tester.enterText(find.byType(TextField), '整理设计规范');
      await tester.tap(find.byType(SendButton));
      expect(submitted, 1);
      expect(controller.text, '整理设计规范');

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(border().top.color, colors.neutralBorder);
      expect(tester.getSize(composer), initialSize);

      // 持焦时移除组件也必须正确清理监听器。
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}
