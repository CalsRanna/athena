import 'package:athena_gui/page/desktop/setting/advanced_page.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_utils/fakes.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setupMobileTestDI();
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets('Advanced page follows the settings master-detail structure', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1040, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_testApp(const DesktopSettingAdvancedPage()));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsNWidgets(2));
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('Export configuration'), findsNothing);

    await tester.tap(find.text('Data'));
    await tester.pumpAndSettle();

    expect(find.text('Data'), findsNWidgets(2));
    expect(find.text('Export configuration'), findsOneWidget);
    expect(find.text('Import configuration'), findsOneWidget);
    expect(find.text('Reset Athena'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Appearance choice updates the persisted theme signal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1040, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = GetIt.instance<SettingViewModel>();

    await tester.pumpWidget(_testApp(const DesktopSettingAdvancedPage()));
    await tester.pumpAndSettle();

    expect(viewModel.themeMode.value, ThemeMode.dark);
    await tester.tap(find.byKey(const ValueKey('theme-mode-light')));
    await tester.pumpAndSettle();

    expect(viewModel.themeMode.value, ThemeMode.light);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AthenaColors.dark.surface,
      extensions: const [AthenaColors.dark],
    ),
    home: Scaffold(body: child),
  );
}
