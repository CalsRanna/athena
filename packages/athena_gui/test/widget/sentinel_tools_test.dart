import 'dart:io';

import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/page/desktop/setting/component/row.dart';
import 'package:athena_gui/page/desktop/setting/sentinel/sentinel_page.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_material_theme.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../support/athena_test_scope.dart';

void main() {
  late Directory home;

  setUp(() async {
    home = Directory.systemTemp.createTempSync('athena-sentinel-tools');
    DI.ensureInitialized(homeDirOverride: home.path);
    await GetIt.instance<FileStorage>().load();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    home.deleteSync(recursive: true);
  });

  testWidgets('内置 Sentinel 可单独关闭工具并保存，身份与提示词保持只读', (tester) async {
    const sentinel = SentinelEntity(
      id: 'builtin',
      name: 'Athena',
      description: 'd',
      prompt: 'You are Athena.',
      isPreset: true,
    );
    final viewModel = GetIt.instance<SentinelViewModel>();
    viewModel.sentinels.value = const [sentinel];

    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: router.navigatorKey,
        theme: buildAthenaThemeData(AthenaColorMode.light)
            .copyWith(platform: TargetPlatform.macOS),
        builder: (_, child) => AthenaTestScope(child: child!),
        home: const Material(child: DesktopSettingSentinelPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Athena'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Web search'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    final row = find.ancestor(
      of: find.text('Web search'),
      matching: find.byType(AthenaSettingsRow),
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byType(AthenaSwitch)),
    );
    await tester.pumpAndSettle();

    expect(find.text('You have unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Save'));
    // 保存会真正写角色文件：widget 测试的 fake async 不推进磁盘 I/O，
    // 需要 runAsync 让写盘完成后再读回信号。
    for (var i = 0; i < 100 && viewModel.isLoading.value; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    // 成功提示的浮层自带 3 秒 timer：让它走完，测试结束时不能有 pending timer。
    await tester.pump(AthenaMotion.linger);
    await tester.pumpAndSettle();

    final saved = viewModel.sentinels.value.single;
    expect(saved.enabledTools, isNotNull);
    expect(saved.enabledTools, isNot(contains('web_search')));
    expect(saved.enabledTools, contains('file_read'));
    expect(saved.enabledTools, contains('skill'), reason: '常开工具必须保留');
    expect(saved.name, 'Athena', reason: '内置角色的名字仍只读');
    expect(saved.prompt, 'You are Athena.');
  });
}
