import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_gui/page/desktop/home/component/chat_preview_card.dart';
import 'package:athena_gui/page/desktop/home/component/turn_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/turn_navigator.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/util/chat_turn_util.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 轮次条的渲染分两条路径：窗口里那几轮各自是控件（要 hover 命中区、要弹卡），
/// 未加载的历史那几轮连成一段一次 `CustomPaint` 画完（条数可能上千，不为每条建
/// 控件）。**两条路径必须给出同一套长度与颜色**：未加载没有任何"更短 / 更淡"的
/// 专用档位，它们照样按 [TurnIndicator.barWidthFor] 伸缩，也照样能当 hover 的
/// 锚点。
///
/// 这里对控件那条路径用 `getSize` 量，对画出来那条路径抓像素量——后者没有控件
/// 可查，只能看画出来的长度。
void main() {
  const maxBarWidth = 20.0;
  const rowHeight = TurnIndicator.barRowHeight;
  const railLeft = 12.0;
  const railTop = 12.0;
  const background = Color(0xFFFFFFFF);

  // 整段会话 8 轮，窗口只加载了最后 3 轮（下标 5、6、7），前面 5 轮是未加载的历史
  const totalTurns = 8;
  const firstTurnIndex = 5;
  const windowTurnCount = 3;
  const rows = totalTurns;

  List<ChatTurn> windowTurns() => [
    for (var i = firstTurnIndex; i < firstTurnIndex + windowTurnCount; i++)
      ChatTurn(
        user: MessageEntity(id: i, chatId: 1, role: 'user', content: 'user $i'),
        answer: 'answer $i',
      ),
  ];

  /// 某一轮在条列里的中心 y（控件坐标）。
  double rowCenterY(int absoluteIndex) =>
      railTop + absoluteIndex * rowHeight + rowHeight / 2;

  final boundaryKey = GlobalKey();

  Future<TurnNavigator> pumpRail(
    WidgetTester tester, {
    required void Function(int absoluteTurnIndex) onTurnSelected,
  }) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final navigator = TurnNavigator();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: background,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: railLeft, top: railTop),
                  // 高度正好放下整列，行高就取满 12——行位置由本文件自己算得出来
                  child: SizedBox(
                    width: maxBarWidth,
                    height: rows * rowHeight,
                    child: TurnIndicator(
                      turns: windowTurns(),
                      navigator: navigator,
                      maxBarWidth: maxBarWidth,
                      totalTurns: totalTurns,
                      firstTurnIndex: firstTurnIndex,
                      onTurnSelected: onTurnSelected,
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

  /// 窗口里那 3 条（控件那条路径）。
  Finder loadedBars() => find.descendant(
    of: find.byType(TurnIndicator),
    matching: find.byType(Container),
  );

  /// 抓一片渲染结果，量出第 [absoluteIndex] 行那条**画出来**的长度：在这一行的
  /// 中线上，数从条列左缘起连续的非背景色像素。
  Future<double> paintedBarWidth(WidgetTester tester, int absoluteIndex) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    late ByteData pixels;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      image.dispose();
    });
    const imageWidth = 800;
    final y = rowCenterY(absoluteIndex).round();
    var width = 0;
    var started = false;
    for (var x = 0; x < imageWidth; x++) {
      final offset = (y * imageWidth + x) * 4;
      final isBackground =
          pixels.getUint8(offset) > 250 &&
          pixels.getUint8(offset + 1) > 250 &&
          pixels.getUint8(offset + 2) > 250;
      if (!isBackground) {
        started = true;
        width++;
      } else if (started) {
        break;
      }
    }
    return width.toDouble();
  }

  /// 泵几帧，让 120ms 的长度 / 颜色过渡走完。
  ///
  /// hover 回调要等下一帧才落到控件上，而补间在这一帧只记起点（值为 0），所以
  /// 一次 `pump(200ms)` 拿不到过渡后的样子——分几帧泵完。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// 把指针移到 [position]，泵到过渡与弹卡延时都走完。
  Future<void> hover(
    WidgetTester tester,
    TestGesture gesture,
    Offset position,
  ) async {
    await gesture.moveTo(position);
    await settle(tester);
  }

  Future<TestGesture> startHover(WidgetTester tester, Offset position) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await hover(tester, gesture, position);
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

  testWidgets('静止时未加载的历史条与窗口里的条一样长', (tester) async {
    await pumpRail(tester, onTurnSelected: (_) {});

    // 控件那条路径：窗口里的 3 条都是静止长度
    expect(loadedBars(), findsNWidgets(windowTurnCount));
    for (var i = 0; i < windowTurnCount; i++) {
      expect(tester.getSize(loadedBars().at(i)).width, 10);
    }
    // 画出来那条路径：未加载的历史条必须同长（早先它们画的是满宽 20，比窗口里
    // 的条长一倍）
    expect(await paintedBarWidth(tester, 0), closeTo(10, 1.5));
    expect(await paintedBarWidth(tester, 2), closeTo(10, 1.5));
    expect(await paintedBarWidth(tester, 4), closeTo(10, 1.5));
  });

  testWidgets('hover 未加载的历史条：它自己最长，两侧邻居按距离递减', (tester) async {
    await pumpRail(tester, onTurnSelected: (_) {});

    // 停在窗口上面那一条（整段会话第 4 轮，未加载）
    await startHover(tester, Offset(railLeft + 5, rowCenterY(4)));

    expect(await paintedBarWidth(tester, 4), closeTo(20, 1.5)); // 锚点自己最长
    expect(await paintedBarWidth(tester, 3), closeTo(17.5, 1.5)); // 邻居按距离递减
    // 窗口里的条（另一条渲染路径）给出的长度必须与上面一致
    expect(tester.getSize(loadedBars().at(0)).width, closeTo(17.5, 0.01));
    expect(tester.getSize(loadedBars().at(1)).width, closeTo(15, 0.01));
    expect(tester.getSize(loadedBars().at(2)).width, closeTo(12.5, 0.01));
  });

  testWidgets('视口当前轮的高亮对的是整段会话的下标（窗口不在会话开头时）', (tester) async {
    final navigator = await pumpRail(tester, onTurnSelected: (_) {});
    final colors = buildAthenaThemeData(
      AthenaColorMode.light,
    ).extension<AthenaColors>()!;

    // 导航器报的是**窗口内**下标（宿主 _selectTurn 也按这个口径换算）：1 指的是
    // 整段会话的第 6 轮，高亮必须落在窗口里第 2 条上，不能落在整段第 1 条上
    navigator.currentTurnIndex.value = 1;
    await settle(tester);

    Color barColor(int windowIndex) {
      final container = tester.widget<Container>(loadedBars().at(windowIndex));
      return (container.decoration! as BoxDecoration).color!;
    }

    final resting = TurnIndicator.barColorFor(
      highlighted: false,
      colors: colors,
    );
    expect(barColor(1), colors.textRowLabel);
    expect(barColor(0), resting);
    expect(barColor(2), resting);
  });

  testWidgets('未加载的历史条可点，报的是整段会话的下标', (tester) async {
    final selected = <int>[];
    await pumpRail(tester, onTurnSelected: selected.add);

    await tester.tapAt(Offset(railLeft + 5, rowCenterY(2)));
    expect(selected, [2]);
    await tester.tapAt(Offset(railLeft + 5, rowCenterY(6)));
    expect(selected, [2, 6]);
  });

  testWidgets('预览卡只给已加载的轮次：未加载的历史 hover 上去只变长', (tester) async {
    await pumpRail(tester, onTurnSelected: (_) {});

    final gesture = await startHover(
      tester,
      Offset(railLeft + 5, rowCenterY(5)),
    );
    expect(find.byType(ChatPreviewCard), findsOneWidget);

    // 换到未加载那一条：卡片收起，长度照旧按同一套公式变
    await hover(tester, gesture, Offset(railLeft + 5, rowCenterY(4)));
    expect(find.byType(ChatPreviewCard), findsNothing);
    expect(await paintedBarWidth(tester, 4), closeTo(20, 1.5));
  });
}
