import 'package:athena_gui/component/message_list_scroll_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 固定高度列表：视口高 240，每条高 50。
  ///
  /// 构建回调模拟消息列表页的调用方式：会话首次渲染调用 [followBottom]
  /// （切换会话跳到底部），其后每次构建调用 [maintainBottom]；[working]
  /// 模拟 agent 的流式状态。
  Future<void> pumpList(
    WidgetTester tester, {
    required MessageListScrollController controller,
    required ValueNotifier<int> itemCount,
    required ValueNotifier<bool> working,
  }) async {
    var displayedChatId = 0;
    const chatId = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: ValueListenableBuilder<int>(
              valueListenable: itemCount,
              builder: (context, count, _) => ValueListenableBuilder<bool>(
                valueListenable: working,
                builder: (context, isWorking, _) {
                  controller.isWorking = isWorking;
                  if (displayedChatId != chatId) {
                    displayedChatId = chatId;
                    controller.followBottom();
                  } else {
                    controller.maintainBottom();
                  }
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
      ),
    );
    await tester.pump();
  }

  /// 末条高度可变的列表，用于模拟流式增长。
  ///
  /// 视口高 240，普通消息高 50，末条高度由 [lastItemHeight] 控制。
  Future<void> pumpGrowingList(
    WidgetTester tester, {
    required MessageListScrollController controller,
    required ValueNotifier<int> itemCount,
    required ValueNotifier<double> lastItemHeight,
    required ValueNotifier<bool> working,
  }) async {
    var displayedChatId = 0;
    const chatId = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: ValueListenableBuilder<int>(
              valueListenable: itemCount,
              builder: (context, count, _) => ValueListenableBuilder<bool>(
                valueListenable: working,
                builder: (context, isWorking, _) =>
                    ValueListenableBuilder<double>(
                      valueListenable: lastItemHeight,
                      builder: (context, height, _) {
                        controller.isWorking = isWorking;
                        if (displayedChatId != chatId) {
                          displayedChatId = chatId;
                          controller.followBottom();
                        } else {
                          controller.maintainBottom();
                        }
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
                    ),
              ),
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
    final working = ValueNotifier(false);
    addTearDown(() {
      itemCount.dispose();
      working.dispose();
      controller.dispose();
    });

    await pumpList(
      tester,
      controller: controller,
      itemCount: itemCount,
      working: working,
    );

    expect(controller.position.maxScrollExtent, greaterThan(0));
    expect(controller.position.pixels, controller.position.maxScrollExtent);
  });

  testWidgets('用户向上滚动后内容增长不强制拉回底部', (tester) async {
    final controller = MessageListScrollController();
    final itemCount = ValueNotifier(20);
    final working = ValueNotifier(false);
    addTearDown(() {
      itemCount.dispose();
      working.dispose();
      controller.dispose();
    });

    await pumpList(
      tester,
      controller: controller,
      itemCount: itemCount,
      working: working,
    );
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
    final working = ValueNotifier(false);
    addTearDown(() {
      itemCount.dispose();
      working.dispose();
      controller.dispose();
    });

    await pumpList(
      tester,
      controller: controller,
      itemCount: itemCount,
      working: working,
    );
    await tester.drag(find.byType(ListView), const Offset(0, 40));
    await tester.pumpAndSettle();
    final offsetAfterUserScroll = controller.position.pixels;
    final distanceFromBottom =
        controller.position.maxScrollExtent - offsetAfterUserScroll;

    expect(distanceFromBottom, greaterThan(0));
    expect(distanceFromBottom, lessThan(80));

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

    var firstBuild = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: ValueListenableBuilder<List<int>>(
              valueListenable: items,
              builder: (context, values, _) {
                if (firstBuild) {
                  firstBuild = false;
                  controller.followBottom();
                } else {
                  controller.maintainBottom();
                }
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
    final working = ValueNotifier(false);
    addTearDown(() {
      itemCount.dispose();
      working.dispose();
      controller.dispose();
    });

    await pumpList(
      tester,
      controller: controller,
      itemCount: itemCount,
      working: working,
    );
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
    final working = ValueNotifier(true);
    addTearDown(() {
      itemCount.dispose();
      lastItemHeight.dispose();
      working.dispose();
      controller.dispose();
    });

    await pumpGrowingList(
      tester,
      controller: controller,
      itemCount: itemCount,
      lastItemHeight: lastItemHeight,
      working: working,
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
    final working = ValueNotifier(true);
    addTearDown(() {
      itemCount.dispose();
      lastItemHeight.dispose();
      working.dispose();
      controller.dispose();
    });

    await pumpGrowingList(
      tester,
      controller: controller,
      itemCount: itemCount,
      lastItemHeight: lastItemHeight,
      working: working,
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

  testWidgets('agent 工作中，未滚到最底部时内容增长不会被吸附', (tester) async {
    final controller = MessageListScrollController();
    final itemCount = ValueNotifier(6);
    final lastItemHeight = ValueNotifier(50.0);
    final working = ValueNotifier(true);
    addTearDown(() {
      itemCount.dispose();
      lastItemHeight.dispose();
      working.dispose();
      controller.dispose();
    });

    await pumpGrowingList(
      tester,
      controller: controller,
      itemCount: itemCount,
      lastItemHeight: lastItemHeight,
      working: working,
    );

    // 先滚到顶部，再向下滚一段，停在距底部几十像素（旧阈值 80 以内）
    // 但并未真正到底的位置。
    await tester.drag(find.byType(ListView), const Offset(0, 100));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -40));
    await tester.pumpAndSettle();
    final offsetNearBottom = controller.position.pixels;
    final distanceFromBottom =
        controller.position.maxScrollExtent - offsetNearBottom;
    expect(distanceFromBottom, greaterThan(0));
    expect(distanceFromBottom, lessThan(80));

    lastItemHeight.value = 200;
    await tester.pump();
    await tester.pump();

    expect(controller.position.pixels, offsetNearBottom);
    expect(
      controller.position.pixels,
      lessThan(controller.position.maxScrollExtent),
    );
  });

  testWidgets('agent 工作中，重新滚回最底部后内容增长继续跟随', (tester) async {
    final controller = MessageListScrollController();
    final itemCount = ValueNotifier(6);
    final lastItemHeight = ValueNotifier(50.0);
    final working = ValueNotifier(true);
    addTearDown(() {
      itemCount.dispose();
      lastItemHeight.dispose();
      working.dispose();
      controller.dispose();
    });

    await pumpGrowingList(
      tester,
      controller: controller,
      itemCount: itemCount,
      lastItemHeight: lastItemHeight,
      working: working,
    );

    await tester.drag(find.byType(ListView), const Offset(0, 100));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(controller.position.pixels, controller.position.maxScrollExtent);

    lastItemHeight.value = 200;
    await tester.pump();

    expect(controller.position.pixels, controller.position.maxScrollExtent);
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('item5'))).dy,
      closeTo(240, 0.01),
    );
  });

  testWidgets('agent 空闲时，回到最底部后内容增长不自动吸附，恢复工作后继续跟随', (tester) async {
    final controller = MessageListScrollController();
    final itemCount = ValueNotifier(6);
    final lastItemHeight = ValueNotifier(50.0);
    final working = ValueNotifier(false);
    addTearDown(() {
      itemCount.dispose();
      lastItemHeight.dispose();
      working.dispose();
      controller.dispose();
    });

    await pumpGrowingList(
      tester,
      controller: controller,
      itemCount: itemCount,
      lastItemHeight: lastItemHeight,
      working: working,
    );

    await tester.drag(find.byType(ListView), const Offset(0, 100));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final maxExtentAtBottom = controller.position.maxScrollExtent;
    expect(controller.position.pixels, maxExtentAtBottom);

    // agent 空闲：即使用户停在最底部，内容增长也不自动贴底。
    lastItemHeight.value = 200;
    await tester.pump();
    await tester.pump();
    expect(controller.position.pixels, maxExtentAtBottom);
    expect(
      controller.position.pixels,
      lessThan(controller.position.maxScrollExtent),
    );

    // agent 开始工作后恢复跟随。
    working.value = true;
    await tester.pump();
    await tester.pump();
    expect(controller.position.pixels, controller.position.maxScrollExtent);
  });
}
