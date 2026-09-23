import 'dart:ui' show ImageByteFormat;

import 'package:athena_gui/component/status_dot.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';

/// 状态点的三条口径：
/// 1. **形状分状态**：不在跑（静止 / hover / 重命名）是 1px 描边的圆环，
///    运行中是实心点——形状是一条不依赖颜色的状态线索；
/// 2. 不在跑的三态是静态档位（同色不同 alpha），不随时间变化；
/// 3. 运行中循环**色相**，且相对亮度钉在 `accent` 上——所以每个采样点的饱和度与
///    `computeLuminance()` 都必须等于 accent 的。用"颜色各不相同"当唯一判据挡不住
///    "随手换成一组别的颜色"，这两条断言才是这条口径的牙齿：只转色相是为了不改语义
///    （绿 / 橙 = 成功 / 警告），钉住亮度是为了不改视觉重量（沿用 accent 的 HSL 明度时，
///    黄绿相位对浅色画布只有 1.5:1，而 accent 是 4.3:1）。
void main() {
  const colors = AthenaColors.light;

  Future<void> pumpDot(
    WidgetTester tester, {
    bool hover = false,
    bool streaming = false,
    bool renaming = false,
    bool disableAnimations = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildAthenaThemeData(AthenaColorMode.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: StatusDot(
            hover: hover,
            streaming: streaming,
            renaming: renaming,
          ),
        ),
      ),
    ),
  );

  BoxDecoration decoration(WidgetTester tester) =>
      tester
              .widget<Container>(
                find.descendant(
                  of: find.byType(StatusDot),
                  matching: find.byType(Container),
                ),
              )
              .decoration!
          as BoxDecoration;

  /// 实心点的填充色（运行中）。
  Color fill(WidgetTester tester) => decoration(tester).color!;

  /// 圆环的描边色（不在跑的三态）。
  Color stroke(WidgetTester tester) => decoration(tester).border!.top.color;

  void expectSameColor(Color actual, Color expected, {String? reason}) {
    expect(actual.r, closeTo(expected.r, 0.01), reason: reason);
    expect(actual.g, closeTo(expected.g, 0.01), reason: reason);
    expect(actual.b, closeTo(expected.b, 0.01), reason: reason);
  }

  /// 采一帧颜色（[read] 决定读填充还是描边），再前进 [step] 并重复 [samples] 次。
  Future<List<Color>> sample(
    WidgetTester tester, {
    required Color Function(WidgetTester) read,
    int samples = 8,
    Duration step = const Duration(milliseconds: 300),
  }) async {
    final seen = <Color>[];
    for (var i = 0; i < samples; i++) {
      seen.add(read(tester));
      await tester.pump(step);
    }
    return seen;
  }

  testWidgets('不在跑的三态是圆环：1px 描边的三档静态色，不随时间变化', (tester) async {
    await pumpDot(tester);
    var box = decoration(tester);
    expect(box.color, isNull, reason: '圆环不该有填充');
    expect(box.border!.top.width, 1);
    expectSameColor(
      box.border!.top.color,
      colors.iconSecondary.withValues(alpha: 0.45),
    );
    expect(box.shape, BoxShape.circle, reason: '圆环的外形仍是直径 6 的圆，不能变成方角');
    final idle = await sample(tester, read: stroke);
    expect(
      idle.every((c) => c == idle.first),
      isTrue,
      reason: '静止行不该有动画：$idle',
    );

    await pumpDot(tester, hover: true);
    expectSameColor(
      stroke(tester),
      colors.iconSecondary.withValues(alpha: 0.75),
      reason: 'hover 只加深透明度，形状不变',
    );

    await pumpDot(tester, renaming: true);
    expectSameColor(stroke(tester), colors.statusWarning);
  });

  testWidgets('运行中是实心点，不是圆环', (tester) async {
    await pumpDot(tester, streaming: true);
    final box = decoration(tester);
    expect(box.color, isNotNull, reason: '运行中必须是实心点，实心/空心是状态线索');
    expect(box.border, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  /// 像素级确认"空心 / 实心"真的画出来了（`decoration` 有 border 不等于渲染成了圆环）。
  testWidgets('像素级：圆环中心透明，实心点中心不透明', (tester) async {
    const boundaryKey = ValueKey('dot-boundary');
    Future<int> centerAlpha({
      required bool streaming,
      required bool disableAnimations,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAthenaThemeData(AthenaColorMode.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: StatusDot(
                  hover: false,
                  streaming: streaming,
                  renaming: false,
                ),
              ),
            ),
          ),
        ),
      );
      // 取的整个过程都必须在 runAsync 里：像素读取走的是引擎侧异步，留在
      // 测试的 fake async 区里永远不会完成（会直接把整个测试挂住）。
      final centerAlpha = await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ImageByteFormat.rawRgba);
        final pixels = data!.buffer.asUint8List();
        final side = image.width;
        final center = ((side ~/ 2) * side + side ~/ 2) * 4;
        final alpha = pixels[center + 3]; // alpha
        image.dispose();
        return alpha;
      });
      return centerAlpha!;
    }

    expect(await centerAlpha(streaming: false, disableAnimations: false), 0);
    expect(
      await centerAlpha(streaming: true, disableAnimations: true),
      255,
      reason: '实心点的中心必须是不透明的',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('静止行不占 ticker，运行中才占', (tester) async {
    await pumpDot(tester);
    expect(
      tester.binding.transientCallbackCount,
      0,
      reason: '静止的侧栏行（常驻、数量多）不该持续重绘',
    );

    await pumpDot(tester, streaming: true);
    expect(tester.binding.transientCallbackCount, 1, reason: '运行中应有一个循环动画');

    // 丢掉运行态再断言一次：控制器必须随状态结束，否则侧栏会一直空转。
    await pumpDot(tester);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('运行中色相绕圈：颜色在变，但饱和度与相对亮度始终是 accent 的', (tester) async {
    await pumpDot(tester, streaming: true);
    final accentHsl = HSLColor.fromColor(colors.accent);
    final accentLuminance = colors.accent.computeLuminance();
    final seen = await sample(tester, read: fill);

    expect(
      seen.toSet().length,
      greaterThan(3),
      reason: '一个周期内应采到多个不同颜色：${seen.toSet().length}',
    );
    for (final color in seen) {
      expect(
        HSLColor.fromColor(color).saturation,
        closeTo(accentHsl.saturation, 0.01),
        reason: '只准换色相：$color',
      );
      expect(
        color.computeLuminance(),
        closeTo(accentLuminance, 0.01),
        reason: '整圈必须是同一视觉重量（= accent 对画布的对比度）：$color',
      );
    }

    // 绕满一圈回到起点：不是"越飘越远"，而是闭合循环。
    expectSameColor(
      StatusDot.colorAt(0, colors),
      colors.accent,
      reason: '循环起点必须就是 accent 本身，否则关闭动画会跳色',
    );
    expectSameColor(StatusDot.colorAt(1, colors), colors.accent);

    // 收尾：让仍在 repeat 的控制器随 widget 一起释放。
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disableAnimations 时停在 accent 原色，不再循环', (tester) async {
    await pumpDot(tester, streaming: true, disableAnimations: true);
    expectSameColor(fill(tester), colors.accent);
    final frozen = await sample(tester, read: fill);
    expect(
      frozen.every((c) => c == frozen.first),
      isTrue,
      reason: '减弱动态效果下圆点应静止：$frozen',
    );
    expect(tester.binding.transientCallbackCount, 0);
  });
}
