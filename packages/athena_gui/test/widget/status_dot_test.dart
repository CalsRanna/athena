import 'package:athena_gui/component/status_dot.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 状态点的两条口径：
/// 1. 静止 / hover / 重命名三态是静态档位（同色不同 alpha），不随时间变化；
/// 2. 运行中（`streaming`）循环**色相**，且相对亮度钉在 `accent` 上——所以每个采样
///    点的饱和度与 `computeLuminance()` 都必须等于 accent 的。用"颜色各不相同"当
///    唯一判据挡不住"随手换成一组别的颜色"，这两条断言才是这条口径的牙齿：
///    只转色相是为了不改语义（绿 / 橙 = 成功 / 警告），钉住亮度是为了不改视觉重量
///    （沿用 accent 的 HSL 明度时，黄绿相位对浅色画布只有 1.5:1 而 accent 是 4.3:1）。
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

  /// 读圆点当前画出来的填充色。
  Color dotColor(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(StatusDot),
        matching: find.byType(Container),
      ),
    );
    return (container.decoration! as BoxDecoration).color!;
  }

  void expectSameColor(Color actual, Color expected, {String? reason}) {
    expect(actual.r, closeTo(expected.r, 0.01), reason: reason);
    expect(actual.g, closeTo(expected.g, 0.01), reason: reason);
    expect(actual.b, closeTo(expected.b, 0.01), reason: reason);
  }

  /// 采一帧颜色，再前进 [step] 并重复 [samples] 次。
  Future<List<Color>> sample(
    WidgetTester tester, {
    int samples = 8,
    Duration step = const Duration(milliseconds: 300),
  }) async {
    final seen = <Color>[];
    for (var i = 0; i < samples; i++) {
      seen.add(dotColor(tester));
      await tester.pump(step);
    }
    return seen;
  }

  testWidgets('静止 / hover / 重命名是三档静态色，不随时间变化', (tester) async {
    await pumpDot(tester);
    expectSameColor(
      dotColor(tester),
      colors.iconSecondary.withValues(alpha: 0.45),
    );
    final idle = await sample(tester);
    expect(
      idle.every((c) => c == idle.first),
      isTrue,
      reason: '静止行不该有动画：$idle',
    );

    await pumpDot(tester, hover: true);
    expectSameColor(
      dotColor(tester),
      colors.iconSecondary.withValues(alpha: 0.75),
      reason: 'hover 只加深透明度',
    );

    await pumpDot(tester, renaming: true);
    expectSameColor(dotColor(tester), colors.statusWarning);
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
    final seen = await sample(tester);

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
    expectSameColor(dotColor(tester), colors.accent);
    final frozen = await sample(tester);
    expect(
      frozen.every((c) => c == frozen.first),
      isTrue,
      reason: '减弱动态效果下圆点应静止：$frozen',
    );
    expect(tester.binding.transientCallbackCount, 0);
  });
}
