import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 菜单面板必须贴合内容高：`DesktopContextMenu` 里的 `Column` 若拿到有界
/// 高度约束（`CustomSingleChildLayout` 给的是窗口尺寸）又没写
/// `mainAxisSize: MainAxisSize.min`，就会撑满整窗，向上展开的菜单还会被
/// 顶到窗顶。
void main() {
  const window = Size(800, 600);

  // 两条 38 高的条目 + 面板 4 内边距 = 84，远小于窗高
  const items = [
    DesktopContextMenuTile(text: 'Edit'),
    DesktopContextMenuTile(text: 'Delete'),
  ];

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    return hostContext;
  }

  /// 菜单面板 = `DesktopContextMenu` 下第一个 `DecoratedBox`（圆角阴影那层）。
  Finder panel() => find
      .descendant(
        of: find.byType(DesktopContextMenu),
        matching: find.byType(DecoratedBox),
      )
      .first;

  tearDown(() {
    // 用例断言失败时把残留菜单清掉，避免污染下一个用例
    DesktopContextMenuManager.instance.dismiss();
  });

  for (final item in [
    const DesktopContextMenuTile(text: 'Action'),
    const DesktopContextMenuSubItem(text: 'Action'),
    const DesktopContextMenuTileWithSubmenu(text: 'Action', submenuItems: []),
  ]) {
    testWidgets('${item.runtimeType} hover 底色渐变且不改变布局', (tester) async {
      final context = await pumpHost(tester);
      final colors = Theme.of(context).extension<AthenaColors>()!;
      DesktopContextMenuManager.instance.show(
        context,
        DesktopContextMenu(
          offset: const Offset(100, 100),
          width: 220,
          children: [item],
        ),
      );
      await tester.pump();
      final tile = find.byType(item.runtimeType);
      final rect = tester.getRect(tile);
      Color background() =>
          (tester
                      .widget<DecoratedBox>(
                        find
                            .descendant(
                              of: tile,
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      final resting = colors.surfaceHover.withValues(alpha: 0);
      expect(background(), resting);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(tile));
      await tester.pump();
      expect(background(), resting);
      await tester.pump(AthenaMotion.hover ~/ 2);
      expect(background(), Color.lerp(resting, colors.surfaceHover, 0.5));
      expect(tester.getRect(tile), rect);
      await tester.pump(AthenaMotion.hover ~/ 2);
      expect(background(), colors.surfaceHover);
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await tester.pump(AthenaMotion.hover);
      expect(background(), resting);
    });
  }

  testWidgets('downward menu hugs its content and sits at the anchor', (
    tester,
  ) async {
    final context = await pumpHost(tester);
    DesktopContextMenuManager.instance.show(
      context,
      const DesktopContextMenu(offset: Offset(100, 100), children: items),
    );
    await tester.pump();

    final rect = tester.getRect(panel());
    expect(rect.height, lessThan(120), reason: '面板应贴合内容高，不应撑满窗口');
    expect(rect.left, 100);
    expect(rect.top, 100);
  });

  testWidgets(
    'upward menu hugs its content and its bottom sits at the anchor',
    (tester) async {
      final context = await pumpHost(tester);
      DesktopContextMenuManager.instance.show(
        context,
        const DesktopContextMenu(
          offset: Offset(100, 500),
          upward: true,
          children: items,
        ),
      );
      await tester.pump();

      final rect = tester.getRect(panel());
      expect(rect.height, lessThan(120), reason: '面板应贴合内容高，不应撑满窗口');
      expect(rect.left, 100);
      expect(rect.bottom, closeTo(500, 0.5));
    },
  );

  testWidgets('menu near the window edge is shifted back inside', (
    tester,
  ) async {
    final context = await pumpHost(tester);
    DesktopContextMenuManager.instance.show(
      context,
      const DesktopContextMenu(offset: Offset(780, 590), children: items),
    );
    await tester.pump();

    final rect = tester.getRect(panel());
    expect(rect.height, lessThan(120), reason: '面板应贴合内容高，不应撑满窗口');
    expect(rect.right, lessThanOrEqualTo(window.width - 8));
    expect(rect.bottom, lessThanOrEqualTo(window.height - 8));
  });
}
