import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 桌面对话框的按钮行。抽这个组件是为了收掉三处各自拼的 `Row`
/// （确认、输入、设置表单），并让移动端 sheet 不再手搓按钮 ——
/// 手搓版没有 hover 反馈，也不跟随全站按钮的尺度。
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: buildAthenaThemeData(AthenaColorMode.light),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('次要在左、主操作在最右，且都是全站按钮', (tester) async {
    await tester.pumpWidget(
      host(
        AthenaDialogActions(
          onCancel: () {},
          onConfirm: () {},
          confirmLabel: 'Save',
        ),
      ),
    );

    expect(find.byType(AthenaSecondaryButton), findsOneWidget);
    expect(find.byType(AthenaPrimaryButton), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    final cancelX = tester.getCenter(find.byType(AthenaSecondaryButton)).dx;
    final confirmX = tester.getCenter(find.byType(AthenaPrimaryButton)).dx;
    expect(cancelX, lessThan(confirmX), reason: '次要在左、主操作在最右');
  });

  testWidgets('右对齐', (tester) async {
    await tester.pumpWidget(
      host(
        const SizedBox(
          width: 400,
          child: AthenaDialogActions(cancelLabel: 'Cancel'),
        ),
      ),
    );

    final rowRight = tester.getRect(find.byType(AthenaDialogActions)).right;
    final confirmRight = tester.getRect(find.byType(AthenaPrimaryButton)).right;
    expect(confirmRight, closeTo(rowRight, 0.5), reason: '主操作贴右边缘');
  });

  testWidgets('回调各自触发', (tester) async {
    var cancelled = 0;
    var confirmed = 0;
    await tester.pumpWidget(
      host(
        AthenaDialogActions(
          onCancel: () => cancelled++,
          onConfirm: () => confirmed++,
        ),
      ),
    );

    await tester.tap(find.text('Cancel'));
    expect(cancelled, 1);
    expect(confirmed, 0);

    await tester.tap(find.text('Confirm'));
    expect(confirmed, 1);
  });
}
