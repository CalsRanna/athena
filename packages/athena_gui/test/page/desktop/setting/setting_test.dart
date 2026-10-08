import 'dart:async';
import 'dart:io';

import 'package:athena_gui/di.dart';
import 'package:athena_gui/main.dart';
import 'package:athena_gui/page/desktop/setting/general_page.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempRoot;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Athena',
      packageName: 'com.athena',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('window_manager'),
          (_) async => null,
        );
    tempRoot = Directory.systemTemp.createTempSync(
      'athena_settings_theme_test',
    );
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
  });

  tearDown(() async {
    await GetIt.instance.reset();
    tempRoot.deleteSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
  });

  Future<void> settle(WidgetTester tester) async {
    // 首页初始化包含串行文件 I/O，交替推进真实异步与界面帧。
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  void expectTextColor(WidgetTester tester, String text, Color color) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)),
    );
    expect(paragraph.text.style!.color, color, reason: text);
  }

  testWidgets('open settings follow light and dark theme changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AthenaApp());
    await settle(tester);
    unawaited(
      router.push(
        const DesktopSettingRoute(children: [DesktopSettingGeneralRoute()]),
      ),
    );
    await settle(tester);
    final pageState = tester.state(find.byType(DesktopSettingGeneralPage));

    for (final (mode, colors) in [
      (ThemeMode.light, AthenaColors.light),
      (ThemeMode.dark, AthenaColors.dark),
      (ThemeMode.light, AthenaColors.light),
    ]) {
      await tester.tap(find.text(mode == ThemeMode.dark ? 'Dark' : 'Light'));
      await settle(tester);
      expect(GetIt.instance<SettingViewModel>().themeMode.value, mode);
      expect(
        find.text('Appearance'),
        findsOneWidget,
        reason: '切换到 ${mode.name} 后仍显示当前设置分区',
      );
      expectTextColor(tester, 'Appearance', colors.textPrimary);
      expectTextColor(tester, 'Theme', colors.textPrimary);
      expectTextColor(
        tester,
        'System follows the appearance selected on this device.',
        colors.textSecondary,
      );
      expectTextColor(tester, 'Show in Finder', colors.textPrimary);
      expectTextColor(
        tester,
        mode == ThemeMode.dark ? 'Dark' : 'Light',
        colors.textPrimary,
      );
      expectTextColor(
        tester,
        mode == ThemeMode.dark ? 'Light' : 'Dark',
        colors.textWeak,
      );
      expect(
        tester.state(find.byType(DesktopSettingGeneralPage)),
        same(pageState),
        reason: '主题切换保留设置页面状态',
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
