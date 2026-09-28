import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 密钥类字段的遮蔽行为。这条路径曾经出过问题：移动端的 Brave API Key
/// 没传 `obscureText`，密钥明文显示在页面上（桌面端同一字段是遮住的）。
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: buildAthenaThemeData(AthenaColorMode.light),
    home: Scaffold(body: Center(child: child)),
  );

  /// `obscureText` 最终落到 `EditableText`，这里读渲染出来的那个值。
  bool obscured(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).obscureText;

  testWidgets('不传 obscureText：明文，且没有眼睛键', (tester) async {
    final controller = TextEditingController(text: 'secret');
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(AthenaInput(controller: controller)));

    expect(obscured(tester), isFalse);
    expect(find.byIcon(LucideIcons.eye), findsNothing);
    expect(find.byIcon(LucideIcons.eyeOff), findsNothing);
  });

  testWidgets('obscureText: true：默认遮蔽，眼睛键可来回切换', (tester) async {
    final controller = TextEditingController(text: 'secret');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(AthenaInput(controller: controller, obscureText: true)),
    );

    expect(obscured(tester), isTrue, reason: '默认必须是遮住的');
    expect(find.byIcon(LucideIcons.eye), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.eye));
    await tester.pump();
    expect(obscured(tester), isFalse, reason: '点眼睛键后显示明文');
    expect(find.byIcon(LucideIcons.eyeOff), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.eyeOff));
    await tester.pump();
    expect(obscured(tester), isTrue, reason: '再点一次回到遮蔽');
    expect(find.byIcon(LucideIcons.eye), findsOneWidget);
  });

  testWidgets('额外的 suffix 与眼睛键共存', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        AthenaInput(
          controller: controller,
          obscureText: true,
          suffix: const Icon(Icons.star),
        ),
      ),
    );

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(LucideIcons.eye), findsOneWidget);
    expect(obscured(tester), isTrue);
  });
}
