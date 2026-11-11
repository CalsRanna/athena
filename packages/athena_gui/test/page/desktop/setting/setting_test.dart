import 'dart:async';
import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/page/desktop/home/component/chat_list.dart';
import 'package:athena_gui/page/desktop/home/component/sidebar_footer.dart';
import 'package:athena_gui/page/desktop/setting/component/control.dart';
import 'package:athena_gui/page/desktop/setting/component/nav.dart';
import 'package:athena_gui/page/desktop/setting/component/panel.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/main.dart';
import 'package:athena_gui/page/desktop/setting/appearance_page.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:athena_gui/theme/athena_theme.dart';

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

  /// 等 [condition] 成立再继续：设置项先落盘再更新 signal，CI 慢盘上
  /// 固定次数的 [settle] 可能赶不上。
  Future<void> settleUntil(
    WidgetTester tester,
    bool Function() condition,
  ) async {
    for (var i = 0; i < 200 && !condition(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      // 带时长 pump：真实 I/O 靠 runAsync 推进，fake 计时器靠这里推进。
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();
  }

  void expectTextColor(
    WidgetTester tester,
    String text,
    Color color, {
    Finder? within,
  }) {
    final textFinder = within == null
        ? find.text(text)
        : find.descendant(of: within, matching: find.text(text));
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: textFinder, matching: find.byType(RichText)),
    );
    expect(paragraph.text.style!.color, color, reason: text);
  }

  testWidgets('open settings follow light and dark theme changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // router 是全局单例：断言失败会跳过测试末尾的清理，把设置页漏给下一个测试。
    addTearDown(() => AthenaRouter.router.maybePop());
    await tester.pumpWidget(const AthenaApp());
    await settle(tester);
    unawaited(
      AthenaRouter.router.push(
        const DesktopSettingRoute(children: [DesktopSettingAppearanceRoute()]),
      ),
    );
    await settle(tester);
    final pageState = tester.state(find.byType(DesktopSettingAppearancePage));
    final content = find.byType(DesktopSettingAppearancePage);

    for (final (mode, colors) in [
      (AthenaThemeMode.light, AthenaColors.light),
      (AthenaThemeMode.dark, AthenaColors.dark),
      (AthenaThemeMode.light, AthenaColors.light),
    ]) {
      // 下拉：点开控件，再从菜单里选档位。
      await tester.tap(find.byType(AthenaSettingsSelect).first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DesktopContextMenu),
          matching: find.text(mode == AthenaThemeMode.dark ? 'Dark' : 'Light'),
        ),
      );
      await settleUntil(
        tester,
        () => GetIt.instance<SettingViewModel>().themeMode.value == mode,
      );
      expect(GetIt.instance<SettingViewModel>().themeMode.value, mode);
      expect(
        find.descendant(of: content, matching: find.text('Appearance')),
        findsOneWidget,
        reason: '切换到 ${mode.name} 后仍显示当前设置分区',
      );
      expectTextColor(
        tester,
        'Appearance',
        colors.textPrimary,
        within: content,
      );
      expectTextColor(tester, 'Theme', colors.textPrimary);
      expectTextColor(
        tester,
        'System follows the appearance selected on this device.',
        colors.textSecondary,
      );
      expectTextColor(
        tester,
        mode == AthenaThemeMode.dark ? 'Dark' : 'Light',
        colors.textPrimary,
      );
      expect(
        find.text(mode == AthenaThemeMode.dark ? 'Light' : 'Dark'),
        findsNothing,
        reason: '未选中的档位只在菜单里',
      );
      expect(
        tester.state(find.byType(DesktopSettingAppearancePage)),
        same(pageState),
        reason: '主题切换保留设置页面状态',
      );
      expect(tester.takeException(), isNull);
    }
    await AthenaRouter.router.maybePop();
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets(
    'New session opens a draft from the home sidebar after settings close',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const AthenaApp());
      final chats = GetIt.instance<ChatViewModel>();
      // 等首页初始化好启动草稿，再选中已有会话。
      for (var i = 0; i < 20 && chats.currentSentinel.value == null; i++) {
        await settle(tester);
      }
      expect(chats.currentSentinel.value, isNotNull);
      await tester.runAsync(() async {
        final repo = GetIt.instance<ChatRepository>();
        final now = DateTime.now();
        final id = await repo.createChat(
          ChatEntity(
            title: 'Existing session',
            modelId: '1',
            sentinelId: ChatEntity.noSentinelId,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await chats.selectChat((await repo.getChatById(id))!);
      });
      await settle(tester);
      expect(chats.currentChat.value?.title, 'Existing session');
      await tester.tap(find.byType(DesktopSidebarFooter));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await settle(tester);
      final nav = find.byType(AthenaSettingsNav);
      await tester.tap(
        find.descendant(of: nav, matching: find.text('Appearance')),
      );
      await settle(tester);
      expect(find.byType(DesktopSettingAppearancePage), findsOneWidget);
      expect(
        find.descendant(of: nav, matching: find.text('New session')),
        findsNothing,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AthenaSettingsPanel),
          matching: find.byIcon(LucideIcons.x),
        ),
      );
      await settle(tester);
      expect(nav, findsNothing);
      expect(chats.currentChat.value?.title, 'Existing session');
      await tester.tap(
        find.descendant(
          of: find.byType(DesktopChatListView),
          matching: find.text('New session'),
        ),
      );
      await settle(tester);
      expect(chats.currentChat.value, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );
}
