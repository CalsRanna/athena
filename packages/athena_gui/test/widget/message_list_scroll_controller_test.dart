import 'package:athena_gui/component/message_list_scroll_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpList(
    WidgetTester tester, {
    required MessageListScrollController controller,
    required ValueNotifier<int> itemCount,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: ValueListenableBuilder<int>(
              valueListenable: itemCount,
              builder: (context, count, _) {
                controller.maintainBottom();
                return NotificationListener<ScrollMetricsNotification>(
                  onNotification: controller.handleMetricsNotification,
                  child: ListView.builder(
                    controller: controller,
                    itemCount: count,
                    itemExtent: 50,
                    itemBuilder: (_, index) => Text('message $index'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('初次展示长对话时跳到列表底部', (tester) async {
    final controller = MessageListScrollController();
    final itemCount = ValueNotifier(20);
    addTearDown(() {
      itemCount.dispose();
      controller.dispose();
    });

    await pumpList(tester, controller: controller, itemCount: itemCount);

    expect(controller.position.maxScrollExtent, greaterThan(0));
    expect(controller.position.pixels, controller.position.maxScrollExtent);
  });

  testWidgets('用户向上滚动后内容增长不强制拉回底部', (tester) async {
    final controller = MessageListScrollController();
    final itemCount = ValueNotifier(20);
    addTearDown(() {
      itemCount.dispose();
      controller.dispose();
    });

    await pumpList(tester, controller: controller, itemCount: itemCount);
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    final offsetAfterUserScroll = controller.position.pixels;

    itemCount.value = 21;
    await tester.pump();
    await tester.pump();

    expect(controller.position.pixels, offsetAfterUserScroll);
    expect(
      controller.position.pixels,
      lessThan(controller.position.maxScrollExtent),
    );
  });

  testWidgets('发送消息后可重新启用底部跟随', (tester) async {
    final controller = MessageListScrollController();
    final itemCount = ValueNotifier(20);
    addTearDown(() {
      itemCount.dispose();
      controller.dispose();
    });

    await pumpList(tester, controller: controller, itemCount: itemCount);
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();

    controller.followBottom();
    itemCount.value = 21;
    await tester.pump();
    await tester.pump();

    expect(controller.position.pixels, controller.position.maxScrollExtent);
  });
}
