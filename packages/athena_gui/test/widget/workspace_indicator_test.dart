import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/page/desktop/home/component/workspace_indicator.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../support/athena_test_scope.dart';

import 'package:athena_gui/theme/athena_material_theme.dart';

void main() {
  tearDown(() => DesktopContextMenuManager.instance.dismiss());

  Future<void> pumpIndicator(
    WidgetTester tester, {
    String? path,
    void Function()? onTap,
    void Function()? onClear,
  }) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AthenaMaterialTheme.buildAthenaThemeData(AthenaColorMode.light),
        builder: (context, child) => AthenaTestScope(child: child!),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: DesktopWorkspaceIndicator(
                path: path,
                onTap: onTap,
                onClear: onClear,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('图标区分是否已设置，点击弹出选择/清除菜单', (tester) async {
    var chosen = 0;
    var cleared = 0;
    await pumpIndicator(
      tester,
      path: '/tmp/work',
      onTap: () => chosen++,
      onClear: () => cleared++,
    );
    expect(find.byIcon(LucideIcons.folder), findsOneWidget);
    expect(find.byTooltip('/tmp/work'), findsOneWidget);

    await tester.tap(find.byType(DesktopWorkspaceIndicator));
    await tester.pumpAndSettle();
    expect(find.text('Choose folder'), findsOneWidget);
    expect(find.text('Clear folder'), findsOneWidget);

    await tester.tap(find.text('Clear folder'));
    await tester.pumpAndSettle();
    expect(cleared, 1);
    expect(find.byType(DesktopContextMenu), findsNothing);

    await tester.tap(find.byType(DesktopWorkspaceIndicator));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose folder'));
    await tester.pumpAndSettle();
    expect(chosen, 1);
  });

  testWidgets('未设置时用 folderX，清除项不可用', (tester) async {
    await pumpIndicator(tester);
    expect(find.byIcon(LucideIcons.folderX), findsOneWidget);
    expect(find.byTooltip('No working folder'), findsOneWidget);

    await tester.tap(find.byType(DesktopWorkspaceIndicator));
    await tester.pumpAndSettle();
    final clear = tester.widget<DesktopContextMenuTile>(
      find.widgetWithText(DesktopContextMenuTile, 'Clear folder'),
    );
    expect(clear.enabled, isFalse);
  });
}
