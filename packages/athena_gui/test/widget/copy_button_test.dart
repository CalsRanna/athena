import 'package:athena_gui/widget/copy_button.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 「已复制」3 秒后自动复原；按钮在这之前被卸载（切换对话、流式重建）
/// 时不能再对已销毁的 State 调 setState。
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: buildAthenaThemeData(AthenaColorMode.light),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('点击后 3 秒内被卸载：计时结束不报错', (tester) async {
    var copies = 0;
    await tester.pumpWidget(host(CopyButton(onTap: () => copies++)));

    await tester.tap(find.byType(CopyButton));
    await tester.pump();
    expect(copies, 1);

    await tester.pumpWidget(host(const SizedBox()));
    await tester.pump(const Duration(seconds: 4));

    expect(tester.takeException(), isNull);
  });

  testWidgets('3 秒后复原，可以再次复制', (tester) async {
    var copies = 0;
    await tester.pumpWidget(host(CopyButton(onTap: () => copies++)));

    await tester.tap(find.byType(CopyButton));
    await tester.pump();
    await tester.tap(find.byType(CopyButton));
    expect(copies, 1, reason: '「已复制」期间重复点击不再触发');

    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byType(CopyButton));
    expect(copies, 2);
  });
}
