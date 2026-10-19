import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 开关的视觉口径：胶囊轨道、滑块抬一层阴影、关闭态是中性的浅轨道。
///
/// 「关闭态不能是深色实心条」是这里最容易回退的一条：两态若在对比度上追平，
/// 状态就只能靠色相区分，扫视一串开关时读不出开还是关。
void main() {
  for (final mode in AthenaColorMode.values) {
    testWidgets('$mode 轨道是胶囊、滑块压 raised 阴影', (tester) async {
      final theme = buildAthenaThemeData(mode);
      final colors = theme.extension<AthenaColors>()!;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: AthenaSwitch(value: false, onChanged: (_) {}),
            ),
          ),
        ),
      );

      final containers = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .toList();
      final track = containers.first.decoration! as BoxDecoration;
      expect(
        track.borderRadius,
        BorderRadius.circular(AthenaRadius.pill),
        reason: '18 高的轨道用 8 圆角会留下 2px 直边，端头不是半圆',
      );
      expect(track.color, colors.switchTrackOff);

      final knob = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(AthenaSwitch),
              matching: find.byType(Container),
            ),
          )
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((decoration) => decoration.shape == BoxShape.circle);
      expect(knob.shape, BoxShape.circle);
      expect(
        knob.boxShadow,
        AthenaShadow.raised(colors.shadow),
        reason: 'DESIGN.md §5 把 raised 配给控件内的滑块',
      );
    });
  }

  testWidgets('关闭态轨道明显轻于开启态：不是两条同重量的深色条', (tester) async {
    Future<double> trackContrast(WidgetTester tester, {required bool value}) async {
      final theme = buildAthenaThemeData(AthenaColorMode.light);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            backgroundColor: colorsOf(AthenaColorMode.light).surface,
            body: Center(
              child: AthenaSwitch(value: value, onChanged: (_) {}),
            ),
          ),
        ),
      );
      final track =
          tester
                  .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
                  .first
                  .decoration!
              as BoxDecoration;
      return track.color!.computeLuminance();
    }

    final off = await trackContrast(tester, value: false);
    final on = await trackContrast(tester, value: true);
    expect(
      on,
      lessThan(off * 0.5),
      reason: '浅色画布上开启态是深青瓷、关闭态是浅中性轨道，明度必须拉开',
    );
  });

  testWidgets('点击在开与关之间切换', (tester) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => AthenaSwitch(
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AthenaSwitch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });
}
