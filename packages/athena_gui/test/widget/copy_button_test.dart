import 'package:athena_gui/widget/copy_button.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 「已复制」3 秒后自动复原；按钮在这之前被卸载（切换对话、流式重建）
/// 时不能再对已销毁的 State 调 setState。
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: buildAthenaThemeData(
      AthenaColorMode.light,
    ).copyWith(platform: TargetPlatform.macOS),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('点击后 3 秒内被卸载：计时结束不报错', (tester) async {
    var copies = 0;
    await tester.pumpWidget(host(CopyButton(onTap: () => copies++)));

    await tester.tap(find.byType(CopyButton));
    await tester.pump();
    expect(copies, 1);

    await tester.pumpWidget(host(const SizedBox()));
    await tester.pump(const Duration(seconds: 4));

    expect(tester.takeException(), isNull);
  });

  testWidgets('3 秒后复原，可以再次复制', (tester) async {
    var copies = 0;
    await tester.pumpWidget(host(CopyButton(onTap: () => copies++)));

    await tester.tap(find.byType(CopyButton));
    await tester.pump();
    await tester.tap(find.byType(CopyButton));
    expect(copies, 1, reason: '「已复制」期间重复点击不再触发');

    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byType(CopyButton));
    expect(copies, 2);
  });

  testWidgets('点击后换成勾 + Copied，3 秒后复原', (tester) async {
    await tester.pumpWidget(host(CopyButton(onTap: () {})));

    expect(find.byIcon(LucideIcons.copy), findsOneWidget);
    expect(find.text('Copied'), findsNothing);

    await tester.tap(find.byType(CopyButton));
    // 切换走 AnimatedSwitcher，旧图标这时还在淡出：等「图标两态切换」的
    // AthenaMotion.hover 走完再断言终态。
    await tester.pump(AthenaMotion.hover);
    await tester.pump();
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    expect(find.text('Copied'), findsOneWidget);
    expect(find.byIcon(LucideIcons.copy), findsNothing);

    // 「已复制」的时长与切换动画无关，按 AthenaMotion.linger 复原
    await tester.pump(AthenaMotion.linger);
    await tester.pump(AthenaMotion.hover);
    await tester.pump();
    expect(find.byIcon(LucideIcons.copy), findsOneWidget);
    expect(find.text('Copied'), findsNothing);
  });

  // 代码块语言条整行走正文档；这个键与那行文案同号，不再是容器比例的 12。
  testWidgets('图标与「Copied」文案与同行文案同号', (tester) async {
    await tester.pumpWidget(host(CopyButton(onTap: () {})));

    expect(
      tester.widget<Icon>(find.byIcon(LucideIcons.copy)).size,
      AthenaIcon.inlineSize,
    );

    await tester.tap(find.byType(CopyButton));
    await tester.pump(AthenaMotion.hover);
    await tester.pump();
    expect(
      tester.widget<Icon>(find.byIcon(LucideIcons.check)).size,
      AthenaIcon.inlineSize,
    );
    expect(
      tester.widget<Text>(find.text('Copied')).style?.fontSize,
      AthenaTextStyle.body.fontSize,
    );
  });

  for (final platform in TargetPlatform.values) {
    testWidgets('复制反馈按主题平台 $platform 显示文案', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAthenaThemeData(
            AthenaColorMode.light,
          ).copyWith(platform: platform),
          home: const Scaffold(body: CopiedLabel(color: Colors.black)),
        ),
      );
      final isDesktop = {
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }.contains(platform);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(find.text('Copied'), isDesktop ? findsOneWidget : findsNothing);
    });
  }
}
