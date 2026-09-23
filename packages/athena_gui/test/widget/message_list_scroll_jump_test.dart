import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/component/message_list_scroll_controller.dart';
import 'package:athena_gui/component/message_sliver.dart';
import 'package:athena_gui/page/desktop/home/component/turn_navigator.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 点轮次条跳转的两条硬要求：
///
/// 1. **目标轮落在视口顶部**——跨一整段懒加载列表时要靠「按估算粗跳 + 复测」
///    走过去，途中必然建出新项、滚动范围必然变；
/// 2. 跳转**不被贴底跟随吃掉**：列表刚打开（切会话 / 发消息）时处于跟随态
///    （`followBottom`），跟随会在每次尺寸变化时把偏移拉回底部，跳上去的视口会被
///    立刻拽回来——表现为闪一下又停在原处。落点不在底部时跟随随之解除。
void main() {
  const turnCount = 30;
  const targetTurn = 2;

  /// 长短不一的正文：懒加载列表的总高度估算会随已构建项变化，跟真机同形。
  List<MessageEntity> messagesOf() => [
    for (var i = 0; i < turnCount; i++) ...[
      MessageEntity(id: i * 2, chatId: 1, role: 'user', content: 'user $i'),
      MessageEntity(
        id: i * 2 + 1,
        chatId: 1,
        role: 'assistant',
        content: 'answer $i\n${'detail $i. ' * (2 + i % 7)}',
      ),
    ],
  ];

  Future<(MessageListScrollController, TurnNavigator)> pumpList(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = MessageListScrollController();
    addTearDown(controller.dispose);
    final navigator = TurnNavigator();
    addTearDown(navigator.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        home: Scaffold(
          body: CustomScrollView(
            controller: controller,
            slivers: [
              MessageCardListSliver(
                messages: messagesOf(),
                sentinel: SentinelEntity(name: 'Athena'),
                navigator: navigator,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return (controller, navigator);
  }

  /// 跳转是异步的（粗跳之间要等下一帧、末段还有 240ms 补间）。
  Future<void> pumpJump(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  void expectLandedOnTurn(WidgetTester tester, int turn) {
    // 目标轮那一行必须已经在视口里、且贴着视口顶（剩下的只有列表自己的留白）
    expect(
      tester.getTopLeft(find.text('user $turn')).dy,
      lessThan(32),
      reason: '第 ${turn + 1} 轮应该停在视口顶部',
    );
  }

  testWidgets('刚进入会话（还在贴底跟随态）点轮次条也跳得过去', (tester) async {
    final (controller, navigator) = await pumpList(tester);
    // 切会话 / 发消息都会这样把列表钉在底部
    controller.followBottom();
    await tester.pump();
    await tester.pump();
    expect(controller.position.pixels, controller.position.maxScrollExtent);

    navigator.scrollToTurn(targetTurn);
    await pumpJump(tester);

    expectLandedOnTurn(tester, targetTurn);
    expect(
      controller.position.pixels,
      lessThan(controller.position.maxScrollExtent - 1000),
      reason: '视口不能还停在底部',
    );
    expect(
      controller.shouldStickToBottom,
      isFalse,
      reason: '落到别处之后跟随应解除，否则下一次尺寸变化又会被拉回底部',
    );
  });

  testWidgets('用户自己向上滚过之后点轮次条照常跳（跟随已解除的路径）', (tester) async {
    final (controller, navigator) = await pumpList(tester);
    controller.followBottom();
    await tester.pump();
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 200));
    await tester.pump();

    navigator.scrollToTurn(targetTurn);
    await pumpJump(tester);

    expectLandedOnTurn(tester, targetTurn);
  });
}
