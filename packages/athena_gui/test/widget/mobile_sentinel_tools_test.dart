import 'dart:io';

import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/page/mobile/sentinel/sentinel_form_page.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_material_theme.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../support/athena_test_scope.dart';

void main() {
  late Directory home;

  setUp(() async {
    home = Directory.systemTemp.createTempSync('athena-mobile-sentinel-tools');
    DI.ensureInitialized(homeDirOverride: home.path);
    await GetIt.instance<FileStorage>().load();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    home.deleteSync(recursive: true);
  });

  testWidgets('移动端表单展示工具开关，内置角色也能单独切换', (tester) async {
    const sentinel = SentinelEntity(
      id: 'builtin',
      name: 'Athena',
      description: 'd',
      prompt: 'You are Athena.',
      isPreset: true,
    );
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAthenaThemeData(AthenaColorMode.light)
            .copyWith(platform: TargetPlatform.iOS),
        builder: (_, child) => AthenaTestScope(child: child!),
        home: const MobileSentinelFormPage(sentinel: sentinel),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Store'), findsOneWidget);
    expect(find.text('Generate'), findsNothing, reason: '内置角色的提示词不可重写');

    await tester.scrollUntilVisible(
      find.text('Web search'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    final row = find
        .ancestor(of: find.text('Web search'), matching: find.byType(Padding))
        .first;
    final toggle = find.descendant(
      of: row,
      matching: find.byType(AthenaSwitch),
    );
    expect(tester.widget<AthenaSwitch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<AthenaSwitch>(toggle).value, isFalse);
  });
}
