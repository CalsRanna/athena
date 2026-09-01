import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/page/desktop/setting/provider/provider.dart';
import 'package:athena_gui/page/desktop/setting/sentinel/sentinel.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/menu.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../../test_utils/fakes.dart';

void main() {
  setUp(setupMobileTestDI);

  tearDown(() {
    DesktopContextMenuManager.instance.dismiss();
  });

  testWidgets('删除当前 provider 后选择上一项', (tester) async {
    await _pumpPage(tester, const DesktopSettingProviderPage());

    final providers = List.generate(
      4,
      (index) => ProviderEntity(
        id: index + 1,
        name: 'Provider ${index + 1}',
        baseUrl: 'https://provider-${index + 1}.example.com',
        apiKey: '',
        createdAt: DateTime(2026),
      ),
    );
    final viewModel = GetIt.instance<ProviderViewModel>();
    viewModel.providers.value = providers;
    await tester.pump();

    await tester.tap(find.text('Provider 3'));
    await tester.pump();
    expect(_menuTile(tester, 'Provider 3').active, isTrue);

    await _deleteSelectedItem(tester, 'Provider 3');

    expect(viewModel.providers.value.map((provider) => provider.id), [1, 2, 4]);
    expect(_menuTile(tester, 'Provider 2').active, isTrue);
    expect(_menuTile(tester, 'Provider 1').active, isFalse);
  });

  testWidgets('删除当前 sentinel 后选择上一项', (tester) async {
    await _pumpPage(tester, const DesktopSettingSentinelPage());

    final sentinels = List.generate(
      4,
      (index) => SentinelEntity(id: index + 1, name: 'Sentinel ${index + 1}'),
    );
    final viewModel = GetIt.instance<SentinelViewModel>();
    viewModel.sentinels.value = sentinels;
    await tester.pump();

    await tester.tap(find.text('Sentinel 3'));
    await tester.pump();
    expect(_menuTile(tester, 'Sentinel 3').active, isTrue);

    await _deleteSelectedItem(tester, 'Sentinel 3');

    expect(viewModel.sentinels.value.map((sentinel) => sentinel.id), [1, 2, 4]);
    expect(_menuTile(tester, 'Sentinel 2').active, isTrue);
    expect(_menuTile(tester, 'Sentinel 1').active, isFalse);
  });
}

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: router.navigatorKey,
      theme: ThemeData(extensions: [AthenaColors.dark]),
      home: Scaffold(
        body: Row(
          children: [
            const SizedBox(width: 240),
            Expanded(child: page),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _deleteSelectedItem(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first, buttons: kSecondaryMouseButton);
  await tester.pump();
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Confirm').last);
  await tester.pumpAndSettle();
}

DesktopMenuTile _menuTile(WidgetTester tester, String label) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is DesktopMenuTile && widget.label == label,
  );
  return tester.widget<DesktopMenuTile>(finder);
}
