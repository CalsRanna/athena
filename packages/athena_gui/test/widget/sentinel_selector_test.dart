import 'dart:io';

import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/page/desktop/home/component/sentinel_selector.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../support/athena_test_scope.dart';

import 'package:athena_gui/theme/athena_material_theme.dart';

void main() {
  late Directory tempRoot;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Athena',
      packageName: 'com.athena',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
    tempRoot = Directory.systemTemp.createTempSync('athena_sentinel_menu_test');
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
  });

  tearDown(() async {
    DesktopContextMenuManager.instance.dismiss();
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  testWidgets('菜单末尾的 No Sentinel 清掉当前角色', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const sentinel = SentinelEntity(id: 's1', name: 'Athena');
    GetIt.instance<SentinelViewModel>().sentinels.value = [sentinel];
    GetIt.instance<ChatViewModel>().currentSentinel.value = sentinel;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light),
        builder: (context, child) => AthenaTestScope(child: child!),
        home: const Scaffold(),
      ),
    );

    SentinelEntity? selected;
    DesktopContextMenuManager.instance.show(
      tester.element(find.byType(Scaffold)),
      DesktopSentinelMenu(
        anchor: const Rect.fromLTWH(100, 400, 28, 28),
        onSelected: (sentinel) => selected = sentinel,
      ),
    );
    await tester.pumpAndSettle();

    const directLabel = SentinelViewModel.directChatOptionLabel;
    expect(find.text(directLabel), findsOneWidget);

    await tester.tap(find.text(directLabel));
    await tester.pumpAndSettle();

    expect(selected, same(SentinelViewModel.directChatSentinel));
    expect(find.byType(DesktopContextMenu), findsNothing);
  });
}
