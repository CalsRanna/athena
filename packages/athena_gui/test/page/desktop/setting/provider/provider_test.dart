import 'dart:io';

import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/page/desktop/setting/provider/provider_page.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/widget/settings/panel.dart';
import 'package:athena_gui/widget/settings/row.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  late Directory tempRoot;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('athena_provider_test');
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
  });

  tearDown(() async {
    await GetIt.instance.reset();
    tempRoot.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    // 页面初始化与启停操作会串行读写临时仓储。窗口数决定「能让多少个真实
    // 文件 I/O 完成」:widget 测试跑在 fake-async 里,只有 runAsync 的窗口
    // 内真实 Future 才会推进,而 provider 列表现在要逐个解析目录下的文件
    // (一个 provider 一个文件),比旧的单个 models.json/整表数组多出若干倍
    // 次 I/O。给足余量,不然表现成「initSignals 永久挂起」。
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Iterable<AthenaSettingsRow> providerRows(WidgetTester tester) => tester
      .widgetList<AthenaSettingsRow>(find.byType(AthenaSettingsRow))
      .where((row) => row.label.startsWith('Provider '));

  for (final mode in AthenaColorMode.values) {
    testWidgets(
      '${mode.name}: grouped selection and toggling follow visible order',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.runAsync(() async {
          await GetIt.instance<FileStorage>().load();
          final repository = GetIt.instance<ProviderRepository>();
          // 仓储顺序交错，确保 Shift 范围取的是显示顺序；key 不决定分组。
          for (final (name, enabled, key) in [
            ('A', false, ''),
            ('B', true, ''),
            ('C', false, 'test-key'),
            ('D', true, 'test-key'),
          ]) {
            await repository.storeProvider(
              ProviderEntity(
                name: 'Provider $name',
                baseUrl: 'https://example.com/v1',
                apiKey: key,
                enabled: enabled,
                createdAt: DateTime(2026, 1, 1),
              ),
            );
          }
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAthenaThemeData(mode),
            home: const AthenaSettingsPanel(
              nav: SizedBox(width: AthenaSettings.navWidth),
              content: DesktopSettingProviderPage(),
            ),
          ),
        );
        await settle(tester);
        expect(find.text('Enabled · 2'), findsOneWidget);
        expect(find.text('Disabled · 2'), findsOneWidget);
        expect(providerRows(tester).map((row) => row.label), [
          'Provider B',
          'Provider D',
          'Provider A',
          'Provider C',
        ]);
        final colors = colorsOf(mode);
        expect(
          tester.widget<Text>(find.text('Provider B')).style!.color,
          colors.textPrimary,
        );
        expect(
          tester.widget<Text>(find.text('Provider A')).style!.color,
          colors.textSecondary,
        );

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(find.text('Provider B'));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.tap(find.text('Provider A'));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(
          providerRows(
            tester,
          ).where((row) => row.selected).map((row) => row.label),
          ['Provider B', 'Provider D', 'Provider A'],
        );

        await tester.tap(find.text('Provider A'));
        await tester.pumpAndSettle();
        expect(find.text('API key'), findsOneWidget);
        expect(
          tester.widget<AthenaSwitch>(find.byType(AthenaSwitch)).value,
          isFalse,
        );
        // 点击触发文件锁与多步写入，需要在真实异步上下文中推进。
        await tester.runAsync(() => tester.tap(find.byType(AthenaSwitch)));
        await settle(tester);
        await tester.tap(find.byType(AthenaSettingsBackLink));
        await tester.pumpAndSettle();
        expect(find.text('Enabled · 3'), findsOneWidget);
        expect(find.text('Disabled · 1'), findsOneWidget);
        expect(providerRows(tester).map((row) => row.label), [
          'Provider A',
          'Provider B',
          'Provider D',
          'Provider C',
        ]);
        expect(
          tester.widget<Text>(find.text('Provider A')).style!.color,
          colors.textPrimary,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
