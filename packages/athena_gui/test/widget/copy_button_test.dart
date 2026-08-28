import 'package:athena_gui/component/button.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpButton(
    WidgetTester tester, {
    required AthenaColors colors,
    required Brightness brightness,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: brightness == Brightness.dark
              ? const ColorScheme.dark()
              : const ColorScheme.light(),
          extensions: [colors],
        ),
        home: const Scaffold(body: CopyButton()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<Color?> copiedColor(WidgetTester tester) async {
    await tester.tap(find.byType(CopyButton));
    await tester.pump();
    return tester.widget<Text>(find.text('Copied')).style?.color;
  }

  Future<void> finishCopiedState(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('Copied feedback follows the light and dark theme colors', (
    tester,
  ) async {
    if (!PlatformUtil.isDesktop) return;

    await pumpButton(
      tester,
      colors: AthenaColors.dark,
      brightness: Brightness.dark,
    );
    final darkColor = await copiedColor(tester);
    expect(darkColor, AthenaColors.dark.textSecondary);
    await finishCopiedState(tester);

    await pumpButton(
      tester,
      colors: AthenaColors.light,
      brightness: Brightness.light,
    );
    final lightColor = await copiedColor(tester);
    expect(lightColor, AthenaColors.light.textSecondary);
    expect(darkColor, isNot(lightColor));
    await finishCopiedState(tester);
  });
}
