import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/widget/settings/panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  for (final withHeader in [true, false]) {
    testWidgets(
      'settings scroll stays below fixed title band (header: $withHeader)',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var closed = false;
        var returned = false;
        var saved = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAthenaThemeData(AthenaColorMode.light),
            home: AthenaSettingsPanel(
              onClose: () => closed = true,
              nav: const SizedBox(width: AthenaSettings.navWidth),
              content: AthenaSettingsPane(
                header: withHeader
                    ? AthenaSettingsBackLink(
                        label: 'Sentinels',
                        onTap: () => returned = true,
                      )
                    : null,
                footer: withHeader
                    ? AthenaSettingsSaveBar(onSave: () => saved = true)
                    : null,
                children: [
                  for (var i = 0; i < 30; i++)
                    SizedBox(
                      height: 56,
                      child: Text('Long settings content $i'),
                    ),
                ],
              ),
            ),
          ),
        );
        final pane = tester.getRect(find.byType(AthenaSettingsPane));
        final close = tester.getRect(find.byIcon(LucideIcons.x));
        final header = withHeader
            ? tester.getRect(find.byType(AthenaSettingsBackLink))
            : null;
        final footer = withHeader
            ? tester.getRect(find.byType(AthenaSettingsSaveBar))
            : null;
        expect(
          tester.getTopLeft(find.text('Long settings content 0')).dy,
          pane.top +
              AthenaSettings.paneTopPadding +
              AthenaSettings.panePadding,
          reason: '首项内容与标题栏底边之间保留顶部内边距',
        );

        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();

        final viewport = tester.getRect(find.byType(Viewport));
        expect(
          viewport.top,
          pane.top + AthenaSettings.paneTopPadding,
          reason: '滚动内容的可绘制区域必须从固定标题带下方开始',
        );
        expect(close.bottom, lessThan(viewport.top));
        expect(tester.getRect(find.byIcon(LucideIcons.x)), close);
        final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
        expect(scroll.position.pixels, greaterThan(0));

        if (withHeader) {
          expect(header!.bottom, lessThan(viewport.top));
          expect(tester.getRect(find.byType(AthenaSettingsBackLink)), header);
          expect(tester.getRect(find.byType(AthenaSettingsSaveBar)), footer);
          expect(viewport.bottom, footer!.top);
          await tester.tap(find.text('Sentinels'));
          await tester.tap(find.text('Save'));
          expect(returned, isTrue);
          expect(saved, isTrue);
        }
        await tester.tap(find.byIcon(LucideIcons.x));
        expect(closed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
