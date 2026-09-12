import 'package:athena_gui/page/desktop/setting/agent_page.dart';
import 'package:athena_gui/page/mobile/setting/agent_page.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_utils/fakes.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setupMobileTestDI();
  });

  for (final mobile in [false, true]) {
    testWidgets('AI review switch saves and reloads (mobile=$mobile)', (
      tester,
    ) async {
      tester.view.physicalSize = mobile
          ? const Size(390, 844)
          : const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final viewModel = GetIt.instance<SettingViewModel>();
      Widget page() => MaterialApp(
        navigatorKey: router.navigatorKey,
        theme: ThemeData(extensions: [AthenaColors.dark]),
        home: Scaffold(
          body: mobile
              ? const MobileAgentPage()
              : const DesktopSettingAgentPage(),
        ),
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('AI Auto Review'), findsOneWidget);
      expect(
        tester.widget<AthenaSwitch>(find.byType(AthenaSwitch)).value,
        isTrue,
      );
      await tester.ensureVisible(find.byType(AthenaSwitch));
      await tester.tap(find.byType(AthenaSwitch));
      await tester.pumpAndSettle();
      expect(viewModel.aiApprovalEnabled.value, isTrue);
      await tester.ensureVisible(find.text('Save').first);
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      expect(viewModel.aiApprovalEnabled.value, isFalse);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(
        tester.widget<AthenaSwitch>(find.byType(AthenaSwitch)).value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
