import 'package:athena_gui/theme/athena_scroll_behavior.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 渲染一棵可滚动的树并返回其 [ScrollPosition]。
///
/// 平台用 `ThemeData.platform` 指定（而不是 `debugDefaultTargetPlatformOverride`），
/// 这正是 [AthenaScrollBehavior] 判定所用的信号——换个平台取值必须不同，断言也就不
/// 依赖宿主操作系统（CI 在 Linux 上跑同样成立）。
///
/// 每个平台都必须起一棵新树：physics 由 `ScrollableState.didChangeDependencies`
/// 解析一次，在同一棵元素树上换 `ThemeData.platform` 不会重新解析（实测第二次
/// pump 仍报上一个平台的 physics），复用同一棵树会得到假结果。
Future<ScrollPosition> _pumpScrollable(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      scrollBehavior: const AthenaScrollBehavior(),
      home: Scaffold(
        body: ListView(
          children: [
            for (var i = 0; i < 40; i++)
              SizedBox(height: 80, child: Text('row $i')),
          ],
        ),
      ),
    ),
  );
  return tester.state<ScrollableState>(find.byType(Scrollable)).position;
}

/// 展开 physics 链。[ScrollView] 会在链头套一层 [AlwaysScrollableScrollPhysics]，
/// 所以不能只比较最外层类型，要看整条链上有没有目标 physics。
List<ScrollPhysics> _physicsChain(ScrollPhysics physics) {
  final chain = <ScrollPhysics>[];
  for (ScrollPhysics? current = physics; current != null; current = current.parent) {
    chain.add(current);
  }
  return chain;
}

const _desktopPlatforms = [
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.linux,
];

void main() {
  for (final platform in _desktopPlatforms) {
    testWidgets('$platform 桌面端滚动不带 iOS 回弹的 physics', (tester) async {
      final chain = _physicsChain(
        (await _pumpScrollable(tester, platform)).physics,
      );
      expect(
        chain,
        anyElement(isA<ClampingScrollPhysics>()),
        reason: '$platform 应使用 ClampingScrollPhysics',
      );
      expect(
        chain,
        isNot(anyElement(isA<BouncingScrollPhysics>())),
        reason: '$platform 上不应出现 BouncingScrollPhysics',
      );
      expect(
        chain,
        anyElement(isA<RangeMaintainingScrollPhysics>()),
        reason: '内容尺寸变化时的位置校正不能丢（消息列表贴底跟随依赖它）',
      );
    });
  }

  testWidgets('iOS 保留系统默认的回弹', (tester) async {
    final chain = _physicsChain(
      (await _pumpScrollable(tester, TargetPlatform.iOS)).physics,
    );
    expect(
      chain,
      anyElement(isA<BouncingScrollPhysics>()),
      reason: 'iOS 的回弹是系统预期，不该被这次改动波及',
    );
  });

  testWidgets('Android 仍是 Flutter 默认的 clamping', (tester) async {
    final chain = _physicsChain(
      (await _pumpScrollable(tester, TargetPlatform.android)).physics,
    );
    expect(chain, anyElement(isA<ClampingScrollPhysics>()));
    expect(chain, isNot(anyElement(isA<BouncingScrollPhysics>())));
  });

  testWidgets('桌面端拖到边界不越界（越界正是回弹的观感）', (tester) async {
    final position = await _pumpScrollable(tester, TargetPlatform.macOS);
    expect(
      position.maxScrollExtent,
      greaterThan(0),
      reason: '列表必须真的可滚动，否则下面的断言是空转',
    );

    // 指针必须在按下状态下断言：回弹会在松手后弹回边界，
    // 只在 settle 之后比较就区分不出两种 physics。
    Future<void> dragBeyondBoundary(Offset delta) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      await gesture.moveBy(delta);
      await tester.pump();
      expect(
        position.pixels,
        inInclusiveRange(position.minScrollExtent, position.maxScrollExtent),
        reason: '拖动越过边界时偏移不得越界（越界即回弹）',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    }

    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    await dragBeyondBoundary(const Offset(0, -120));

    position.jumpTo(position.minScrollExtent);
    await tester.pump();
    await dragBeyondBoundary(const Offset(0, 120));
  });
}
