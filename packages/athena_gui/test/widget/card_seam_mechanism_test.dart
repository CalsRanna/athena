import 'dart:ui' as ui;

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/component/message_list_tile.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 助手消息卡面回归。
///
/// 设计决定：助手消息**不绘制卡片底板**，直接坐在页面底色上。
///
/// 历史成因（由下方"设计约束"用例直接复现）：卡片按消息切成多段、每段各画一次
/// 95% 白底时，段边界落在非整数物理像素上，上下两段在该像素行各只覆盖一部分，
/// 半透明叠加不满 → 露出页面底色，形成一条随滚动偏移时隐时现的 1 物理像素暗线。
///
/// 让"整卡一个列表项、只画一次背景"能消除接缝，但代价是视口碰到整卡就要构建并
/// 逐帧遍历整卡内容：实测流式增量 n=50/100/200/400 → 27/36/109/369ms，而逐消息
/// 一个列表项恒为 4-5ms。既不画底板，接缝问题与"整卡一个 item"的约束就一并消失。
///
/// 本文件守两条线：
/// 1) 段边界处没有底板，采样列全程是页面底色（含"先构建、再滚到非整数偏移"的
///    layer 复用路径）；
/// 2) 该接缝机制本身仍然存在——说明为什么不能随手把底板加回来。
void main() {
  const cardInnerX = 380; // 卡片右侧 16px 留白内，只有页面底色
  const pageGray = 40; // 页面底色 surface #282828

  Future<({List<int> grays, double boundaryTop})> sampleCard(
    WidgetTester tester, {
    required double buildOffset,
    required double sampleOffset,
  }) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    final colors = AthenaColors.dark;
    final messages = [
      MessageEntity(id: 1, chatId: 1, role: 'assistant', content: 'first'),
      MessageEntity(id: 2, chatId: 1, role: 'assistant', content: 'second'),
    ];
    final key = GlobalKey();
    final controller = ScrollController(initialScrollOffset: buildOffset);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [colors]),
        home: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: colors.surface,
            child: SizedBox(
              width: 400,
              height: 60, // 小于卡内容高度，保证真的能滚
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  MessageCardListSliver(
                    messages: messages,
                    sentinel: SentinelEntity(name: 'T', avatar: 'T'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    if (sampleOffset != buildOffset) {
      // 只改偏移：未变化的子项 layer 会被复用，不会重绘
      controller.jumpTo(sampleOffset);
      await tester.pump();
    }

    // 两条消息的交界：纯布局边界，界面上不该有任何被绘制的边
    final boundaryTop = tester
        .getRect(find.byKey(const ValueKey('assistant-card-segment-2')))
        .top;
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    late ui.Image image;
    await tester.runAsync(() async {
      image = await boundary.toImage(pixelRatio: 2);
    });
    final bytes = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    final width = image.width;
    int gray(int x, int y) {
      final i = (y * width + x) * 4;
      return (bytes.getUint8(i) +
              bytes.getUint8(i + 1) +
              bytes.getUint8(i + 2)) ~/
          3;
    }

    final deviceBoundary = boundaryTop * 2;
    final from = deviceBoundary.floor() - 8;
    final to = deviceBoundary.ceil() + 8;
    return (
      grays: [for (var y = from; y <= to; y++) gray(cardInnerX, y)],
      boundaryTop: boundaryTop,
    );
  }

  testWidgets('深色主题：助手消息之间没有底板，段边界处页面底色连续', (tester) async {
    var sawFractionalBoundary = false;
    for (final offset in <double>[0.0, 0.25, 0.5, 0.75]) {
      // (1) 直接在目标偏移下构建
      final direct = await sampleCard(
        tester,
        buildOffset: offset,
        sampleOffset: offset,
      );
      // (2) 先在整数偏移构建，再滚到目标偏移（layer 复用路径）
      final scrolled = await sampleCard(
        tester,
        buildOffset: 0,
        sampleOffset: offset,
      );
      for (final (label, result) in [('直接构建', direct), ('滚动后', scrolled)]) {
        final deviceY = result.boundaryTop * 2;
        if (deviceY != deviceY.roundToDouble()) sawFractionalBoundary = true;
        debugPrint(
          'scroll=$offset $label → 段边界 y=${result.boundaryTop}'
          '（设备像素 $deviceY）采样 ${result.grays.toSet()}'
          ' 明细 ${result.grays.asMap()}',
        );
        // 没有底板：采样列整段都是页面底色，不存在"更暗/更亮的一行"
        expect(result.grays.toSet(), {pageGray});
      }
    }
    expect(sawFractionalBoundary, isTrue, reason: '样本里必须出现过非整数边界');
  });

  testWidgets('设计约束：相邻同色半透明底板会留下 1 像素接缝', (tester) async {
    // 复现历史成因：说明"助手消息由多个各自绘制背景的矩形拼成"为何会出线，
    // 也说明"各外扩一点让两段重叠"为何不行（会让该行更亮）。这就是当前
    // "不画底板"这一决定的依据：把底板加回来就会把这个问题带回来。
    const dpr = 2.0;
    const boundaryLogical = 42.25; // → 设备像素 84.5
    final card95 = const Color(0xFFFFFFFF).withValues(alpha: 0.95);
    const surface = Color(0xFF282828);
    final key = GlobalKey();

    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: surface,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                height: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: boundaryLogical,
                      decoration: BoxDecoration(color: card95),
                    ),
                    Expanded(child: Container(color: card95)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    late ui.Image image;
    await tester.runAsync(() async {
      image = await boundary.toImage(pixelRatio: dpr);
    });
    final bytes = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    final width = image.width;
    int gray(int x, int y) {
      final i = (y * width + x) * 4;
      return (bytes.getUint8(i) +
              bytes.getUint8(i + 1) +
              bytes.getUint8(i + 2)) ~/
          3;
    }

    final seamRow = (boundaryLogical * dpr).floor();
    expect(gray(20, seamRow - 4), 244);
    expect(gray(20, seamRow), lessThan(220));
  });
}
