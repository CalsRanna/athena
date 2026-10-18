import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/widget/press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: buildAthenaThemeData(AthenaColorMode.light),
    home: Scaffold(body: Center(child: child)),
  );

  double targetScale(WidgetTester tester) =>
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

  testWidgets('按下缩到 0.975，抬起回弹到 1', (tester) async {
    await tester.pumpWidget(
      host(const AthenaPressScale(child: SizedBox(width: 40, height: 40))),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AthenaPressScale)),
    );
    await tester.pump();
    expect(targetScale(tester), 0.975);

    await gesture.up();
    await tester.pump();
    expect(targetScale(tester), 1);
  });

  testWidgets('指针取消后也回到 1', (tester) async {
    await tester.pumpWidget(
      host(const AthenaPressScale(child: SizedBox(width: 40, height: 40))),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AthenaPressScale)),
    );
    await tester.pump();
    expect(targetScale(tester), 0.975);

    await gesture.cancel();
    await tester.pump();
    expect(targetScale(tester), 1);
  });

  testWidgets('enabled 为 false 时不缩放', (tester) async {
    await tester.pumpWidget(
      host(
        const AthenaPressScale(
          enabled: false,
          child: SizedBox(width: 40, height: 40),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AthenaPressScale)),
    );
    await tester.pump();
    expect(targetScale(tester), 1);

    await gesture.up();
  });

  testWidgets('不拦截子树的点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const AthenaPressScale(child: SizedBox(width: 40, height: 40)),
        ),
      ),
    );

    await tester.tap(find.byType(AthenaPressScale));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
