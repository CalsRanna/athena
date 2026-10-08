import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  for (final mode in AthenaColorMode.values) {
    testWidgets('$mode 文字按钮前景和底色在 150ms 内渐变，移开还原', (tester) async {
      final theme = buildAthenaThemeData(mode);
      final colors = theme.extension<AthenaColors>()!;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: AthenaTextButton(text: 'Action', onTap: () {}),
            ),
          ),
        ),
      );
      final button = find.byType(AthenaTextButton);
      Color foreground() =>
          DefaultTextStyle.of(tester.element(find.text('Action'))).style.color!;
      Color background() =>
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: button,
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      final resting = colors.surfaceHover.withValues(alpha: 0);
      expect(foreground(), colors.textSecondary);
      expect(background(), resting);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(button));
      await tester.pump();
      expect(foreground(), colors.textSecondary);
      expect(background(), resting);
      await tester.pump(AthenaMotion.hover ~/ 2);
      expect(
        foreground(),
        Color.lerp(colors.textSecondary, colors.textPrimary, 0.5),
      );
      expect(background(), Color.lerp(resting, colors.surfaceHover, 0.5));
      await tester.pump(AthenaMotion.hover ~/ 2);
      expect(foreground(), colors.textPrimary);
      expect(background(), colors.surfaceHover);
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(foreground(), colors.textPrimary);
      await tester.pump(AthenaMotion.hover ~/ 2);
      expect(
        foreground(),
        Color.lerp(colors.textPrimary, colors.textSecondary, 0.5),
      );
      await tester.pump(AthenaMotion.hover ~/ 2);
      expect(foreground(), colors.textSecondary);
      expect(background(), resting);
    });
  }
  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets('${platform.name} 图标按钮保持桌面密度且边缘可点', (tester) async {
      var navigationTaps = 0;
      var ghostTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAthenaThemeData(
            AthenaColorMode.light,
          ).copyWith(platform: platform),
          home: Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AthenaIconButton(
                    icon: LucideIcons.plus,
                    onTap: () => navigationTaps++,
                  ),
                  AthenaGhostIconButton(
                    icon: LucideIcons.x,
                    onTap: () => ghostTaps++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final navigation = find.byType(AthenaIconButton);
      final ghost = find.byType(AthenaGhostIconButton);
      expect(tester.getSize(navigation), const Size(32, 32));
      expect(tester.getSize(ghost), const Size(28, 28));
      await tester.tapAt(tester.getTopLeft(navigation) + const Offset(1, 1));
      await tester.tapAt(tester.getTopLeft(ghost) + const Offset(1, 1));
      expect(navigationTaps, 1);
      expect(ghostTaps, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
