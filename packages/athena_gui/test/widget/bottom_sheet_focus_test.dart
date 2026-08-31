import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 复现并验证:聊天输入框持焦时打开底部弹窗,点击弹窗外关闭后,
/// 焦点不应回落到输入框(否则键盘会自动弹出)。
///
/// 与 [AthenaDialog.show] 移动端分支(showModalBottomSheet + unfocus)
/// 保持一致的结构。
void main() {
  testWidgets('关闭底部弹窗后焦点不回落到输入框(键盘不会自动弹出)', (tester) async {
    late FocusNode inputFocus;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              inputFocus = FocusNode();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(focusNode: inputFocus),
                  TextButton(
                    onPressed: () {
                      // 与 AthenaDialog.show 移动端分支相同的修复:
                      // 打开弹窗前对实际持焦节点释放焦点。
                      FocusManager.instance.primaryFocus?.unfocus();
                      showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => const SizedBox(height: 120),
                      );
                    },
                    child: const Text('open sheet'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    // 用户先点击输入框(键盘弹出)。
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(inputFocus.hasFocus, isTrue);

    // 点击按钮打开底部弹窗。
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);

    // 点击弹窗外部区域关闭。
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);

    // 核心断言:焦点没有回到输入框。
    expect(inputFocus.hasFocus, isFalse,
        reason: '关闭弹窗后焦点不应回落到输入框(否则键盘会自动弹出)');
  });
}
