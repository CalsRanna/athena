import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 菜单面板必须贴合内容高：`DesktopContextMenu` 里的 `Column` 若拿到有界
/// 高度约束（`CustomSingleChildLayout` 给的是窗口尺寸）又没写
/// `mainAxisSize: MainAxisSize.min`，就会撑满整窗，向上展开的菜单还会被
/// 顶到窗顶。
void main() {
  const window = Size(800, 600);

  // 两条约 32 高的条目 + 面板 4 内边距 ≈ 72，远小于窗高
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

  testWidgets('upward menu hugs its content and its bottom sits at the anchor', (
    tester,
  ) async {
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
  });

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
