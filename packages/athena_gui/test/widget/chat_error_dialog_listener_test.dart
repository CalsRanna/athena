import 'dart:async';

import 'package:athena_gui/component/chat_error_dialog_listener.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// ViewModel 不再弹 UI 之后，聊天失败靠这一层呈现。它只依赖 [Stream]，所以能脱离
/// 依赖图与 Router 单独测（`AthenaDialog` 内部取的是 router 的 navigatorKey）。
void main() {
  Future<void> pump(
    WidgetTester tester,
    Stream<String> errors,
    void Function(String) show,
  ) => tester.pumpWidget(
    ChatErrorDialogListener(
      errors: errors,
      show: show,
      child: const SizedBox(),
    ),
  );

  testWidgets('每次失败都呈现一次', (tester) async {
    final events = StreamController<String>.broadcast();
    addTearDown(events.close);
    final shown = <String>[];
    await pump(tester, events.stream, shown.add);

    events.add('第一次失败');
    await tester.pump();
    events.add('第二次失败');
    await tester.pump();

    expect(shown, ['第一次失败', '第二次失败']);
  });

  testWidgets('同一句话连报两次也呈现两次', (tester) async {
    // 这正是事件流与状态信号的分界：换成监听 error 信号的话，第二次因为「状态
    // 没变」不会触发——用户会以为重试成功了。
    final events = StreamController<String>.broadcast();
    addTearDown(events.close);
    final shown = <String>[];
    await pump(tester, events.stream, shown.add);

    events.add('同样的失败');
    await tester.pump();
    events.add('同样的失败');
    await tester.pump();

    expect(shown, ['同样的失败', '同样的失败']);
  });

  testWidgets('拆掉之后不再呈现', (tester) async {
    final events = StreamController<String>.broadcast();
    addTearDown(events.close);
    final shown = <String>[];
    await pump(tester, events.stream, shown.add);

    // 换掉整棵树 → dispose
    await tester.pumpWidget(const SizedBox());
    events.add('拆掉之后才失败');
    await tester.pump();

    expect(shown, isEmpty);
  });

  testWidgets('换事件源后改听新的，不再听旧的', (tester) async {
    final first = StreamController<String>.broadcast();
    final second = StreamController<String>.broadcast();
    addTearDown(first.close);
    addTearDown(second.close);
    final shown = <String>[];
    await pump(tester, first.stream, shown.add);

    await pump(tester, second.stream, shown.add);
    first.add('旧源');
    second.add('新源');
    await tester.pump();

    expect(shown, ['新源']);
  });
}
