import 'dart:ui' show ImageByteFormat;

import 'package:athena_gui/page/desktop/home/component/status_dot.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_material_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';

import '../support/athena_test_scope.dart';

/// 状态点的三条口径：
/// 1. 只有运行中 / 未读才挂这个组件，画成实心点（静止行没有圆点）；
/// 2. 运行中循环**色相**，且相对亮度钉在 `accent` 上——所以每个采样点的饱和度与
///    `computeLuminance()` 都必须落在 accent 的同一档里。用"颜色各不相同"当唯一判据
///    挡不住"随手换成一组别的颜色"，这两条断言才是这条口径的牙齿：只转色相是为了不改
///    语义（绿 / 橙 = 成功 / 警告），钉住亮度是为了不改视觉重量（沿用 accent 的 HSL
///    明度时，黄绿相位对浅色画布只有 1.5:1，而 accent 是 4.3:1）；
/// 3. 未读固定 accent、静止不动。
///
/// 容差不是 0：颜色表是按 96 档采样的，档与档之间做 RGB 直线插值（是弦不是弧），
/// 实测整圈最大偏差为饱和度 0.021、相对亮度 0.004（后者已是 8bit 量化下限）。
void main() {
  const colors = AthenaColors.light;

  Future<void> pumpDot(
    WidgetTester tester, {
    bool unread = false,
    bool disableAnimations = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AthenaMaterialTheme.buildAthenaThemeData(AthenaColorMode.light),
      builder: (context, child) => AthenaTestScope(
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
      ),
      home: Scaffold(
        body: Center(child: StatusDot(unread: unread)),
      ),
    ),
  );

  BoxDecoration decoration(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find.descendant(
                  of: find.byType(StatusDot),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .decoration
          as BoxDecoration;

  /// 实心点的填充色。
  Color fill(WidgetTester tester) => decoration(tester).color!;

  void expectSameColor(Color actual, Color expected, {String? reason}) {
    expect(actual.r, closeTo(expected.r, 0.01), reason: reason);
    expect(actual.g, closeTo(expected.g, 0.01), reason: reason);
    expect(actual.b, closeTo(expected.b, 0.01), reason: reason);
  }

  /// 采一帧颜色（[read] 决定从 decoration 里读什么），再前进 [step] 并重复 [samples] 次。
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

  testWidgets('运行中是实心点', (tester) async {
    await pumpDot(tester);
    final box = decoration(tester);
    expect(box.color, isNotNull, reason: '运行中的点必须是实心的');
    expect(box.border, isNull);
    expect(box.shape, BoxShape.circle);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('未读是固定 accent 色、不循环，也不占 ticker', (tester) async {
    await pumpDot(tester, unread: true);
    expectSameColor(fill(tester), colors.accent);
    final frozen = await sample(tester, read: fill);
    expect(
      frozen.every((c) => c == frozen.first),
      isTrue,
      reason: '未读态不该有色相循环：$frozen',
    );
    expect(tester.binding.transientCallbackCount, 0);

    // 运行结束时同一个位置会从运行态切成未读态，控制器要跟着停。
    await pumpDot(tester);
    expect(tester.binding.transientCallbackCount, 1);
    await pumpDot(tester, unread: true);
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(const SizedBox());
  });

  /// 像素级确认实心点真的画出来了（`decoration` 有填充不等于渲染出了颜色）。
  testWidgets('像素级：实心点中心不透明', (tester) async {
    const boundaryKey = ValueKey('dot-boundary');
    // 关掉循环再取像素：否则两次 runAsync 之间颜色会变，中心 alpha 不稳定。
    Future<int> centerAlpha() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AthenaMaterialTheme.buildAthenaThemeData(
            AthenaColorMode.light,
          ),
          builder: (context, child) => AthenaTestScope(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
          home: const Scaffold(
            body: Center(
              child: RepaintBoundary(key: boundaryKey, child: StatusDot()),
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

    expect(await centerAlpha(), 255, reason: '实心点的中心必须是不透明的');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('挂载时占一个 ticker，卸载后释放', (tester) async {
    await pumpDot(tester);
    expect(tester.binding.transientCallbackCount, 1, reason: '运行中应有一个循环动画');

    // 对话跑完时状态点会被摘掉：控制器必须一起释放，否则侧栏会一直空转。
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('运行中色相绕圈：颜色在变，但饱和度与相对亮度始终是 accent 的', (tester) async {
    await pumpDot(tester);
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
        closeTo(accentHsl.saturation, 0.03),
        reason: '只准换色相（容差=表格插值的弦误差）：$color',
      );
      expect(
        color.computeLuminance(),
        closeTo(accentLuminance, 0.006),
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
    await pumpDot(tester, disableAnimations: true);
    expectSameColor(fill(tester), colors.accent);
    final frozen = await sample(tester, read: fill);
    expect(
      frozen.every((c) => c == frozen.first),
      isTrue,
      reason: '减弱动态效果下圆点应静止：$frozen',
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  test('整圈 200 点采样：明暗恒定、色相在走（两个主题都查）', () {
    for (final palette in [AthenaColors.light, AthenaColors.dark]) {
      final accentHsl = HSLColor.fromColor(palette.accent);
      final accentLuminance = palette.accent.computeLuminance();
      final seen = <Color>{};
      for (var i = 0; i < 200; i++) {
        final color = StatusDot.colorAt(i / 200, palette);
        seen.add(color);
        expect(
          HSLColor.fromColor(color).saturation,
          closeTo(accentHsl.saturation, 0.03),
          reason: '$i/200 上的饱和度跑偏：$color',
        );
        expect(
          color.computeLuminance(),
          closeTo(accentLuminance, 0.006),
          reason: '$i/200 上的视觉重量跑偏：$color',
        );
      }
      expect(
        seen.length,
        greaterThan(100),
        reason: '整圈应该是一段连续的色相，而不是几个跳变的档：${seen.length}',
      );
    }
  });
}
