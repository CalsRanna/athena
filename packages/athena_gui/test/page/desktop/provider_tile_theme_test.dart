import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_gui/page/desktop/setting/provider/provider.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../test_utils/fakes.dart';

void main() {
  setUp(() {
    setupMobileTestDI();
  });

  testWidgets('provider tile 图标颜色随主题切换', (tester) async {
    final getIt = GetIt.instance;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [AthenaColors.light]),
      home: Scaffold(body: const DesktopSettingProviderPage()),
    ));
    await tester.pumpAndSettle();

    // fake repo 为空,页面 initState 的 initSignals 加载空列表后,再注入数据
    getIt<ProviderViewModel>().providers.value = [
      ProviderEntity(
        name: 'Deep Seek',
        baseUrl: 'https://api.deepseek.com/v1',
        apiKey: '',
        enabled: true,
        isPreset: true,
        createdAt: DateTime.now(),
      ),
    ];
    await tester.pumpAndSettle();

    Color lockIconColor() {
      final icon = tester.widget<Icon>(
        find.byIcon(HugeIcons.strokeRoundedCircleLock01).first,
      );
      return icon.color!;
    }

    final lightColor = lockIconColor();
    // index 0 为选中态:图标用 textSelected(与文字同色)
    expect(lightColor, AthenaColors.light.textSelected,
        reason: '浅色主题选中态图标应为文字色');

    // 切换为深色主题(真实 app 中由 MaterialApp.themeMode 驱动)
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [AthenaColors.dark]),
      home: Scaffold(body: const DesktopSettingProviderPage()),
    ));
    await tester.pumpAndSettle();

    final darkColor = lockIconColor();
    // 深色模式 iconSecondary(0xFFE0E0E0)与选中背景 tagSelectedBackground
    // 同色不可见,选中态必须用 textSelected(0xFF161616);
    // textSelected 深浅模式同值(选中背景亦同色),故与浅色值相同属正常
    expect(darkColor, AthenaColors.dark.textSelected,
        reason: '深色主题选中态图标应为文字色(修复同色不可见)');
    expect(darkColor, isNot(AthenaColors.dark.iconSecondary));
  });

  testWidgets('非选中态图标用 iconSecondary,切换选中后变文字色', (tester) async {
    final getIt = GetIt.instance;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [AthenaColors.dark]),
      home: Scaffold(body: const DesktopSettingProviderPage()),
    ));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    getIt<ProviderViewModel>().providers.value = [
      ProviderEntity(
        name: 'Deep Seek',
        baseUrl: 'https://api.deepseek.com/v1',
        apiKey: '',
        enabled: true,
        isPreset: true,
        createdAt: now,
      ),
      ProviderEntity(
        name: 'Open Router',
        baseUrl: 'https://openrouter.ai/api/v1',
        apiKey: '',
        enabled: true,
        isPreset: true,
        createdAt: now,
      ),
    ];
    await tester.pumpAndSettle();

    Color lockIconColor() {
      final icon = tester.widget<Icon>(
        find.byIcon(HugeIcons.strokeRoundedCircleLock01).first,
      );
      return icon.color!;
    }

    // 默认选中 index 0(Deep Seek):图标为文字色
    expect(lockIconColor(), AthenaColors.dark.textSelected);

    // 点击第二个 provider(index 1):第一个变为非选中态,图标恢复 iconSecondary
    await tester.tap(find.text('Open Router'));
    await tester.pumpAndSettle();
    expect(lockIconColor(), AthenaColors.dark.iconSecondary,
        reason: '非选中态图标应为次级图标色');
  });

  testWidgets('同一棵树中 themeMode 切换后图标颜色即时更新', (tester) async {
    final getIt = GetIt.instance;
    final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode,
        builder: (context, mode, _) => MaterialApp(
          theme: ThemeData(extensions: [AthenaColors.light]),
          darkTheme: ThemeData(extensions: [AthenaColors.dark]),
          themeMode: mode,
          home: Scaffold(body: const DesktopSettingProviderPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    getIt<ProviderViewModel>().providers.value = [
      ProviderEntity(
        name: 'Deep Seek',
        baseUrl: 'https://api.deepseek.com/v1',
        apiKey: '',
        enabled: true,
        isPreset: true,
        createdAt: DateTime.now(),
      ),
    ];
    await tester.pumpAndSettle();

    Color lockIconColor() {
      final icon = tester.widget<Icon>(
        find.byIcon(HugeIcons.strokeRoundedCircleLock01).first,
      );
      return icon.color!;
    }

    // 默认选中 index 0:图标为选中态文字色
    expect(lockIconColor(), AthenaColors.light.textSelected);

    // 同一棵 widget 树中切换主题(真实 app 中 SettingViewModel.themeMode 变化)
    themeMode.value = ThemeMode.dark;
    await tester.pumpAndSettle();

    expect(lockIconColor(), AthenaColors.dark.textSelected,
        reason: '主题切换后同一棵树中的图标应立即用新色');
  });
}
