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

  /// 构建末条高度可变的列表，用于模拟流式增长。
  ///
  /// 视口高 240，普通消息高 50，末条高度由 [lastItemHeight] 控制。
  Future<void> pumpGrowingList(
    WidgetTester tester, {
    required MessageListScrollController controller,
    required ValueNotifier<int> itemCount,
    required ValueNotifier<double> lastItemHeight,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: ValueListenableBuilder<int>(
              valueListenable: itemCount,
              builder: (context, count, _) {
                return ValueListenableBuilder<double>(
                  valueListenable: lastItemHeight,
                  builder: (context, height, _) {
                    controller.maintainBottom();
                    return NotificationListener<ScrollMetricsNotification>(
                      onNotification: controller.handleMetricsNotification,
                      child: ListView.builder(
                        controller: controller,
                        itemCount: count,
                        itemBuilder: (_, index) => SizedBox(
                          key: ValueKey('item$index'),
                          height: index == count - 1 ? height : 50,
                          child: Text('message $index'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
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

  testWidgets('用户在底部小幅向上滚动后也停止底部跟随', (tester) async {
    final controller = MessageListScrollController();
    final itemCount = ValueNotifier(20);
    addTearDown(() {
      itemCount.dispose();
      controller.dispose();
    });

    await pumpList(tester, controller: controller, itemCount: itemCount);
    await tester.drag(find.byType(ListView), const Offset(0, 40));
    await tester.pumpAndSettle();
    final offsetAfterUserScroll = controller.position.pixels;
    final distanceFromBottom =
        controller.position.maxScrollExtent - offsetAfterUserScroll;

    expect(distanceFromBottom, greaterThan(0));
    expect(distanceFromBottom, lessThan(controller.bottomThreshold));

    itemCount.value = 21;
    await tester.pump();
    await tester.pump();

    expect(controller.position.pixels, offsetAfterUserScroll);
  });

  testWidgets('列表头部插入旧消息后保持当前可见内容位置', (tester) async {
    final controller = MessageListScrollController();
    final items = ValueNotifier<List<int>>(List.generate(20, (index) => index));
    addTearDown(() {
      items.dispose();
      controller.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: ValueListenableBuilder<List<int>>(
              valueListenable: items,
              builder: (context, values, _) {
                controller.maintainBottom();
                return ListView.builder(
                  controller: controller,
                  itemCount: values.length,
                  itemExtent: 50,
                  findChildIndexCallback: (key) {
                    if (key is! ValueKey<int>) return null;
                    final index = values.indexOf(key.value);
                    return index < 0 ? null : index;
                  },
                  itemBuilder: (_, index) => SizedBox(
                    key: ValueKey(values[index]),
                    child: Text('message ${values[index]}'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    final offsetBeforePrepend = controller.position.pixels;
    final maxExtentBeforePrepend = controller.position.maxScrollExtent;

    final preserveFuture = controller.preservePositionWhilePrepending(() async {
      items.value = [-5, -4, -3, -2, -1, ...items.value];
      return 5;
    });
    expect(items.value, hasLength(25));
    await tester.pumpAndSettle();
    await preserveFuture;

    expect(
      controller.position.maxScrollExtent,
      closeTo(maxExtentBeforePrepend + 250, 0.01),
    );
    expect(
      controller.position.pixels,
      closeTo(offsetBeforePrepend + 250, 0.01),
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

  testWidgets('跟随底部时，内容增长的那一帧就已经贴底', (tester) async {
    final controller = MessageListScrollController();
    final itemCount = ValueNotifier(6);
    final lastItemHeight = ValueNotifier(50.0);
    addTearDown(() {
      itemCount.dispose();
      lastItemHeight.dispose();
      controller.dispose();
    });

    await pumpGrowingList(
      tester,
      controller: controller,
      itemCount: itemCount,
      lastItemHeight: lastItemHeight,
    );

    // 该回调注册在帧外，早于 build 期注册的控制器回调，读到的是布局期
    // 校正之后、post-frame 校正之前的值。
    double? pixelsAtGrowthFrame;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pixelsAtGrowthFrame = controller.position.pixels;
    });

    lastItemHeight.value = 200; // 内容 300 -> 450，maxScrollExtent 60 -> 210
    await tester.pump();

    expect(pixelsAtGrowthFrame, controller.position.maxScrollExtent);
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('item5'))).dy,
      closeTo(240, 0.01),
    );
  });

  testWidgets('用户向上滚动后，内容增长不会被布局期拉回底部', (tester) async {
    final controller = MessageListScrollController();
    final itemCount = ValueNotifier(6);
    final lastItemHeight = ValueNotifier(50.0);
    addTearDown(() {
      itemCount.dispose();
      lastItemHeight.dispose();
      controller.dispose();
    });

    await pumpGrowingList(
      tester,
      controller: controller,
      itemCount: itemCount,
      lastItemHeight: lastItemHeight,
    );
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    final offsetAfterUserScroll = controller.position.pixels;
    expect(
      offsetAfterUserScroll,
      lessThan(controller.position.maxScrollExtent),
    );

    double? pixelsAtGrowthFrame;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pixelsAtGrowthFrame = controller.position.pixels;
    });

    lastItemHeight.value = 200;
    await tester.pump();

    expect(pixelsAtGrowthFrame, offsetAfterUserScroll);
    expect(controller.position.pixels, offsetAfterUserScroll);
  });
}
