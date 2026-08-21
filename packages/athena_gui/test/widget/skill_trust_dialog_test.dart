import 'dart:io';

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/widget/skill_trust_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  // Skill 信任弹窗仅在桌面端走 showDialog 分支；移动端走 bottom sheet。
  // 这里只在桌面平台上验证桌面分支，避免平台分歧带来的脆弱性。
  if (!(Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
    return;
  }

  setUpAll(() {
    // 测试环境禁止运行时拉取字体，使用打包/回退字体。
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: router.navigatorKey,
        theme: ThemeData(extensions: [AthenaColors.dark]),
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
  }

  testWidgets('renders project dir and skill names, returns true on Trust',
      (tester) async {
    await pumpHost(tester);

    final future = showSkillTrustDialog(
      projectDir: '/tmp/demo-project',
      skillNames: const ['code-reviewer', 'migration-review'],
    );
    await tester.pumpAndSettle();

    expect(find.text('Trust project skills?'), findsOneWidget);
    expect(find.text('/tmp/demo-project'), findsOneWidget);
    expect(find.text('- code-reviewer'), findsOneWidget);
    expect(find.text('- migration-review'), findsOneWidget);

    await tester.tap(find.text('Trust'));
    await tester.pumpAndSettle();

    expect(await future, isTrue);
  });

  testWidgets('returns false on Skip', (tester) async {
    await pumpHost(tester);

    final future = showSkillTrustDialog(
      projectDir: '/tmp/demo-project',
      skillNames: const ['code-reviewer'],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(await future, isFalse);
  });
}
