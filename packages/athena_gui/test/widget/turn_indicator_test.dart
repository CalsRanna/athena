import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/page/desktop/home/component/chat_preview_card.dart';
import 'package:athena_gui/page/desktop/home/component/turn_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/turn_navigator.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/util/chat_turn_util.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 轮次条的两条硬要求：
/// 1. **一条 = 一轮**，长度与颜色共用同一套公式（[TurnIndicator.barWidthFor] /
///    [TurnIndicator.barColorFor]）；未加载的历史没有"更短 / 更淡"的专用档位。
/// 2. **整列最多 [TurnIndicator.maxBars] 条**：只画视口当前轮所在的那一页，
///    页内每条保持正常大小与间距、位置稳定，点哪条跳哪轮都精确；跨页时整列
///    才按新的当前轮重建。
void main() {
  const maxBarWidth = 20.0;
  const railLeft = 12.0;
  const background = Color(0xFFFFFFFF);
  const maxBars = TurnIndicator.maxBars;

  // 默认场景：整段会话 8 轮（不到一页），窗口只加载了最后 3 轮（下标 5、6、7）
  const totalTurns = 8;
  const firstTurnIndex = 5;
  const windowTurnCount = 3;
  const rows = totalTurns;

  List<ChatTurn> turnsOf(int from, int count) => [
    for (var i = from; i < from + count; i++)
      ChatTurn(
        user: MessageEntity(id: i, chatId: 1, role: 'user', content: 'user $i'),
        answer: 'answer $i',
      ),
  ];

  Future<TurnNavigator> pumpRail(
    WidgetTester tester, {
    required void Function(int absoluteTurnIndex) onTurnSelected,
    int total = totalTurns,
    int first = firstTurnIndex,
    int windowCount = windowTurnCount,
    int? windowCurrentTurn,
  }) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final navigator = TurnNavigator();
    if (windowCurrentTurn != null) {
      navigator.currentTurnIndex.value = windowCurrentTurn;
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        home: Scaffold(
          body: RepaintBoundary(
            child: ColoredBox(
              color: background,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: railLeft, top: railLeft),
                  // 与真机同形：宽度先收紧成 maxBarWidth（同 Positioned(width:)），
                  // 高度交给 Center 给**松**约束（0..可用高）
                  child: SizedBox(
                    width: maxBarWidth,
                    child: Center(
                      child: TurnIndicator(
                        turns: turnsOf(first, windowCount),
                        navigator: navigator,
                        maxBarWidth: maxBarWidth,
                        totalTurns: total,
                        firstTurnIndex: first,
                        onTurnSelected: onTurnSelected,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return navigator;
  }

  /// 整列画出来的那几条（一条一个 `Container`，从页首开始）。
  Finder bars() => find.descendant(
    of: find.byType(TurnIndicator),
    matching: find.byType(Container),
  );

  /// 整列的左缘、顶部与行高——从真实渲染结果量出来，不重复实现里的公式。
  ({double left, double top, double rowHeight}) geometry(WidgetTester tester) {
    final finder = find.byType(TurnIndicator);
    return (
      left: tester.getTopLeft(finder).dx,
      top: tester.getTopLeft(finder).dy,
      rowHeight: tester.getSize(finder).height / bars().evaluate().length,
    );
  }

  double barWidth(WidgetTester tester, int slot) =>
      tester.getSize(bars().at(slot)).width;

  Color barColor(WidgetTester tester, int slot) {
    final container = tester.widget<Container>(bars().at(slot));
    return (container.decoration! as BoxDecoration).color!;
  }

  /// 页内第 [slot] 条的中线（条列左缘往里 5px）。
  Offset rowCenter(WidgetTester tester, int slot) {
    final rail = geometry(tester);
    return Offset(rail.left + 5, rail.top + (slot + 0.5) * rail.rowHeight);
  }

  /// 泵几帧，让 120ms 的长度 / 颜色过渡走完（hover 回调也要等下一帧才落到控件上，
  /// 补间在这一帧只记起点，一次 `pump(200ms)` 拿不到过渡后的样子）。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<TestGesture> startHover(WidgetTester tester, Offset position) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(position);
    await settle(tester);
    return gesture;
  }

  test('条长只有一套公式：锚点在未加载那一段上时距离照算，窗口边界不切断', () {
    double width(int index, int? hovered) => TurnIndicator.barWidthFor(
      index: index,
      hoveredIndex: hovered,
      maxBarWidth: maxBarWidth,
    );

    expect(width(4, null), 10); // 没有 hover：一律静止长度（上限的一半）
    expect(width(4, 4), 20); // 锚点（这里是未加载的第 4 轮）自己最长
    expect(width(5, 4), 17.5); // 跨窗口边界，距离 1
    expect(width(3, 4), 17.5); // 同一个锚点另一侧的历史条，也是距离 1
    expect(width(6, 4), 15);
    expect(width(8, 4), 10); // 相隔 4 条及以上回静止长度
  });

  testWidgets('一页之内：整列每条一样长，未加载的与已加载的同款', (tester) async {
    await pumpRail(tester, onTurnSelected: (_) {});

    expect(bars(), findsNWidgets(rows)); // 8 轮 < 一页，整段都画
    for (var slot = 0; slot < rows; slot++) {
      expect(barWidth(tester, slot), 10);
    }
    expect(geometry(tester).rowHeight, TurnIndicator.barRowHeight);
  });

  testWidgets('hover 某条：它自己最长，两侧邻居按距离递减（跨已加载/未加载）', (tester) async {
    await pumpRail(tester, onTurnSelected: (_) {});

    // 停在窗口上面那一条（整段会话第 4 轮，未加载）
    await startHover(tester, rowCenter(tester, 4));

    expect(barWidth(tester, 4), 20); // 锚点自己最长
    expect(barWidth(tester, 3), 17.5); // 历史侧邻居
    expect(barWidth(tester, 5), 17.5); // 已加载侧邻居，同一套公式
    expect(barWidth(tester, 7), 12.5);
    expect(barWidth(tester, 0), 10); // 相隔 4 条及以上回静止长度
  });

  testWidgets('视口当前轮的高亮对的是整段会话的下标（窗口不在会话开头时）', (tester) async {
    final navigator = await pumpRail(
      tester,
      onTurnSelected: (_) {},
      windowCurrentTurn: 1,
    );
    final colors = buildAthenaThemeData(
      AthenaColorMode.light,
    ).extension<AthenaColors>()!;

    // 导航器报的是**窗口内**下标（宿主 _selectTurn 也按这个口径换算）：1 指的是
    // 整段会话的第 6 轮，高亮必须落在页内第 6 条上，不能落在整段第 1 条上
    expect(navigator.currentTurnIndex.value, 1);
    final resting = TurnIndicator.barColorFor(
      highlighted: false,
      colors: colors,
    );
    expect(barColor(tester, 6), colors.textRowLabel);
    expect(barColor(tester, 0), resting);
    expect(barColor(tester, 7), resting);
  });

  testWidgets('点某条报的是整段会话的下标', (tester) async {
    final selected = <int>[];
    await pumpRail(tester, onTurnSelected: selected.add);

    await tester.tapAt(rowCenter(tester, 2));
    expect(selected, [2]);
    await tester.tapAt(rowCenter(tester, 6));
    expect(selected, [2, 6]);
  });

  testWidgets('预览卡只给已加载的轮次：未加载的历史 hover 上去只变长', (tester) async {
    await pumpRail(tester, onTurnSelected: (_) {});

    final gesture = await startHover(tester, rowCenter(tester, 5));
    expect(find.byType(ChatPreviewCard), findsOneWidget);

    // 换到未加载那一条：卡片收起，长度照旧按同一套公式变
    await gesture.moveTo(rowCenter(tester, 4));
    await settle(tester);
    expect(find.byType(ChatPreviewCard), findsNothing);
    expect(barWidth(tester, 4), 20);
  });

  testWidgets('超过一页只画当前轮那一页：20 条、正常行高、下标仍精确', (tester) async {
    // 整段 60 轮（3 页），窗口从第 10 轮起，当前轮可由导航器指到窗口内任意一轮
    const total = 60;
    final selected = <int>[];
    final navigator = await pumpRail(
      tester,
      onTurnSelected: selected.add,
      total: total,
      first: 10,
      windowCount: 50,
      // 窗口内下标 10 → 整段第 20 轮，落在第 2 页 [20, 39]
      windowCurrentTurn: 10,
    );

    expect(bars(), findsNWidgets(maxBars)); // 60 轮也只画 20 条
    final rail = geometry(tester);
    expect(rail.rowHeight, TurnIndicator.barRowHeight); // 不压行高
    expect(rail.rowHeight * maxBars, 240);

    // 页首是整段第 20 轮：点页内首条 / 末条报的就是 20 / 39
    await tester.tapAt(rowCenter(tester, 0));
    await tester.tapAt(rowCenter(tester, maxBars - 1));
    expect(selected, [20, 39]);

    // 当前轮进到下一页：整列按新页重建，点的仍是它自己的整段下标
    navigator.currentTurnIndex.value = 40; // 整段第 50 轮 → 第 3 页 [40, 59]
    await settle(tester);
    expect(bars(), findsNWidgets(maxBars));
    selected.clear();
    await tester.tapAt(rowCenter(tester, 0));
    await tester.tapAt(rowCenter(tester, maxBars - 1));
    expect(selected, [40, 59]);

    // 页内位置稳定：再点一次同样的两条，报的完全一样
    selected.clear();
    await tester.tapAt(rowCenter(tester, 0));
    expect(selected, [40]);

    // 会话再长也只画一页
    await pumpRail(
      tester,
      onTurnSelected: (_) {},
      total: 1000,
      first: 990,
      windowCount: 10,
      windowCurrentTurn: 5,
    );
    expect(bars(), findsNWidgets(maxBars));
  });
}
