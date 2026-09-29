import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final mode in AthenaColorMode.values) {
      testWidgets('${platform.name} $mode 窄屏顶栏容纳两个操作，外圈点击仍有效', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var refreshed = 0;
        var added = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAthenaThemeData(mode).copyWith(platform: platform),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: Column(
                          children: [
                            AthenaAppBar(
                              title: const Text('Provider settings'),
                              action: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AthenaIconButton(
                                    icon: LucideIcons.refreshCw,
                                    onTap: () => refreshed++,
                                  ),
                                  const SizedBox(width: 8),
                                  AthenaIconButton(
                                    icon: LucideIcons.plus,
                                    onTap: () => added++,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open settings'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();

        final buttons = find.byType(AthenaIconButton);
        expect(buttons, findsNWidgets(3));
        for (final button in buttons.evaluate()) {
          final finder = find.byWidget(button.widget);
          expect(tester.getSize(finder), const Size(48, 48));
          final visibleBox = find.descendant(
            of: finder,
            matching: find.byType(Container),
          );
          expect(tester.getSize(visibleBox), const Size(32, 32));
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
        }
        final title = tester.getRect(find.text('Provider settings'));
        expect(title.width, greaterThan(0));
        expect(
          title.left,
          greaterThanOrEqualTo(tester.getRect(buttons.first).right),
        );
        expect(
          title.right,
          lessThanOrEqualTo(tester.getRect(buttons.at(1)).left),
        );
        expect(tester.takeException(), isNull);

        // 点击可见底板外侧，验证扩大的区域实际参与命中测试。
        await tester.tapAt(
          tester.getTopLeft(buttons.at(1)) + const Offset(2, 2),
        );
        await tester.tapAt(
          tester.getTopLeft(buttons.at(2)) + const Offset(2, 2),
        );
        expect(refreshed, 1);
        expect(added, 1);

        final back = find.ancestor(
          of: find.byIcon(AthenaIcons.back),
          matching: find.byType(AthenaIconButton),
        );
        await tester.tapAt(tester.getTopLeft(back) + const Offset(2, 2));
        await tester.pumpAndSettle();
        expect(find.text('Open settings'), findsOneWidget);
        expect(find.byType(AthenaAppBar), findsNothing);
      });
    }
  }
}
