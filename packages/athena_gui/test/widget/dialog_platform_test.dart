import 'dart:async';
import 'dart:io';

import 'package:athena_gui/di.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `AthenaDialog` 的平台分派走 `ThemeData.platform`，两端分支都要能在测试里
/// 走通。这条路径原先读 `PlatformUtil`（`dart:io` 的 `Platform`），测试里
/// 恒为宿主平台，移动端分支进不去——所以移动端的确认/输入面板一直没被覆盖。
///
/// 这里用 `theme.copyWith(platform:)` 显式指定，宿主平台无关。
void main() {
  late Directory tempRoot;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
    tempRoot = Directory.systemTemp.createTempSync('athena_dialog_test');
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
  });

  tearDown(() async {
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
  });

  /// 挂真实 router（`AthenaDialog` 从 `router.navigatorKey` 取 context）。
  /// 路由的初始页由平台决定，所以两端的宿主页面不同，但都只作背景。
  ///
  /// 窗口取 1200 × 900：路由在桌面平台会挂 `DesktopHomePage`，它的 composer
  /// 在窄窗下会 assert 溢出（与本次改动无关，是宿主页面的最小宽度要求）。
  Future<void> pumpHost(WidgetTester tester, TargetPlatform platform) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildAthenaThemeData(
          AthenaColorMode.light,
        ).copyWith(platform: platform),
        routerConfig: router.config(),
        scaffoldMessengerKey: scaffoldMessengerKey,
      ),
    );
    // 首页初始化是一串串行的真实文件 I/O，要交替给真实异步窗口再 pump。
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// 弹出的菜单/弹层要等用户操作才结束，这里明确不等待它。
  void fire(Future<Object?> future) {
    unawaited(future.catchError((Object _) => null));
  }

  group('桌面平台', () {
    testWidgets('confirm 走对话框而非底部 sheet', (tester) async {
      await pumpHost(tester, TargetPlatform.macOS);

      fire(AthenaDialog.confirm('Delete this chat?'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget, reason: '桌面走 showDialog');
      expect(find.byType(BottomSheet), findsNothing);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('移动平台', () {
    testWidgets('confirm 走底部 sheet 而非对话框', (tester) async {
      await pumpHost(tester, TargetPlatform.android);

      fire(AthenaDialog.confirm('Delete this chat?'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget, reason: '移动走 sheet');
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('confirm 点确认回传 true', (tester) async {
      await pumpHost(tester, TargetPlatform.iOS);

      bool? result;
      fire(AthenaDialog.confirm('Proceed?').then((v) => result = v));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('input 走底部 sheet 并回传输入值', (tester) async {
      await pumpHost(tester, TargetPlatform.android);

      String? result;
      fire(
        AthenaDialog.input(
          'Rename',
          initialValue: 'old',
        ).then((v) => result = v),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);

      // 限定在 sheet 内找输入框：宿主页面的 composer 也有 TextField。
      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'new name',
      );
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(result, 'new name');
    });
  });
}
