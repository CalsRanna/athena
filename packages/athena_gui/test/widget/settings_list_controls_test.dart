import 'dart:io';

import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/storage/experience_repository.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/page/desktop/setting/component/panel.dart';
import 'package:athena_gui/page/desktop/setting/component/row.dart';
import 'package:athena_gui/page/desktop/setting/experience/experience_page.dart';
import 'package:athena_gui/page/desktop/setting/provider/provider_page.dart';
import 'package:athena_gui/page/desktop/setting/sentinel/sentinel_page.dart';
import 'package:athena_gui/page/desktop/setting/skill/skill_page.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_material_theme.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../support/athena_test_scope.dart';

void main() {
  late Directory home;

  setUp(() async {
    home = Directory.systemTemp.createTempSync('athena-settings-lists');
    DI.ensureInitialized(homeDirOverride: home.path);
    await GetIt.instance<FileStorage>().load();
  });

  tearDown(() async {
    DesktopContextMenuManager.instance.dismiss();
    await GetIt.instance.reset();
    home.deleteSync(recursive: true);
  });

  Future<void> showPage(
    WidgetTester tester,
    Widget page,
    String loaded, {
    double width = 820,
  }) async {
    tester.view.physicalSize = Size(width, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AthenaMaterialTheme.buildAthenaThemeData(AthenaColorMode.light)
            .copyWith(platform: TargetPlatform.macOS),
        builder: (_, child) => AthenaTestScope(child: child!),
        home: Material(child: page),
      ),
    );
    // Provider and experience lists load from the temporary file store.
    for (var i = 0; i < 300 && find.text(loaded).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text(loaded), findsOneWidget);
  }

  List<String> rows(WidgetTester tester) => tester
      .widgetList<AthenaSettingsListRow>(find.byType(AthenaSettingsListRow))
      .map((row) => row.label)
      .toList();

  Future<void> choose(WidgetTester tester, String tooltip, String label) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DesktopContextMenu),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
  }

  for (final (title, page) in [
    ('Providers', const DesktopSettingProviderPage()),
    ('Sentinels', const DesktopSettingSentinelPage()),
    ('Skills', const DesktopSettingSkillPage()),
    ('Experiences', const DesktopSettingExperiencePage()),
  ]) {
    testWidgets('$title restore list scroll after returning from details', (
      tester,
    ) async {
      await tester.runAsync(() async {
        for (var i = 0; i < 30; i++) {
          final name = 'Item ${i.toString().padLeft(2, '0')}';
          switch (title) {
            case 'Providers':
              await GetIt.instance<ProviderRepository>().storeProvider(
                ProviderEntity(
                  name: name,
                  enabled: true,
                  baseUrl: '',
                  apiKey: '',
                  createdAt: DateTime(2026),
                ),
              );
            case 'Sentinels':
              GetIt.instance<SentinelViewModel>().sentinels.add(
                SentinelEntity(id: '$i', name: name),
              );
            case 'Skills':
              await GetIt.instance<SkillViewModel>().createSkill(
                name: name,
                description: 'Scroll test skill',
                body: List.filled(40, 'Instructions.\n').join('\n'),
              );
            case 'Experiences':
              await GetIt.instance<ExperienceRepository>().save(
                lesson: name,
                sentinelId: 'owner',
                context: List.filled(40, 'Context.').join('\n'),
              );
          }
        }
      });
      await showPage(tester, page, switch (title) {
        'Providers' => 'Enabled · 30',
        'Experiences' => 'Active · 30',
        _ => 'Item 00',
      });
      final list = find.byType(ListView);
      final scrollable = find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first;

      for (var visit = 0; visit < 2; visit++) {
        await tester.drag(list, const Offset(0, -600));
        await tester.pumpAndSettle();
        final offset = tester
            .state<ScrollableState>(scrollable)
            .position
            .pixels;
        expect(offset, greaterThan(0));
        final row = find.byType(AthenaSettingsListRow).hitTestable().at(2);
        final label = tester.widget<AthenaSettingsListRow>(row).label;
        final rowTop = tester.getTopLeft(find.text(label)).dy;

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(AthenaSettingsBackLink), findsOneWidget);
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          0,
          reason: 'Details start at the top independently of the list',
        );
        await tester.drag(list, const Offset(0, -200));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(AthenaSettingsBackLink));
        await tester.pumpAndSettle();

        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          moreOrLessEquals(offset),
        );
        expect(
          tester.getTopLeft(find.text(label)).dy,
          moreOrLessEquals(rowTop),
        );
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'providers search models, reveal disabled matches and sort within status',
    (tester) async {
      await tester.runAsync(() async {
        final providers = GetIt.instance<ProviderRepository>();
        final date = DateTime(2026);
        for (final name in ['Alpha', 'Beta', 'Zulu']) {
          final id = await providers.storeProvider(
            ProviderEntity(
              name: name,
              enabled: name != 'Beta',
              baseUrl: '',
              apiKey: '',
              createdAt: date,
            ),
          );
          if (name == 'Alpha') continue;
          await GetIt.instance<ModelRepository>().createModel(
            ModelEntity(
              providerId: id,
              modelId: 'code-01',
              name: 'Coder',
              createdAt: date,
              updatedAt: date,
            ),
          );
        }
      });
      await showPage(tester, const DesktopSettingProviderPage(), '1 model');
      expect(rows(tester), ['Alpha', 'Zulu']);
      await choose(tester, 'Sort by Name', 'Model count');
      expect(rows(tester), ['Zulu', 'Alpha']);
      await search(tester, ' CODE-01 ');
      expect(rows(tester), ['Zulu', 'Beta']);
      await choose(tester, 'Filter by status: All statuses', 'Disabled');
      expect(rows(tester), ['Beta']);
      await search(tester, 'Alpha');
      expect(find.text('No matching providers'), findsOneWidget);
      await search(tester, '');
      expect(rows(tester), ['Beta']);
      await choose(tester, 'Filter by status: Disabled', 'All statuses');
      expect(rows(tester), ['Zulu', 'Alpha']);
    },
  );

  testWidgets(
    'sentinels combine tag search with source and retain sort after editing',
    (tester) async {
      GetIt.instance<SentinelViewModel>().sentinels.value = const [
        SentinelEntity(id: 'a', name: 'Alpha', description: 'Review code'),
        SentinelEntity(id: 'b', name: 'Athena', isPreset: true),
        SentinelEntity(id: 'z', name: 'Zulu', tags: 'review'),
      ];
      await showPage(
        tester,
        const DesktopSettingSentinelPage(),
        'Athena',
        width: 440,
      );
      await choose(tester, 'Sort by Name (A–Z)', 'Name (Z–A)');
      await search(tester, ' REVIEW ');
      expect(rows(tester), ['Zulu', 'Alpha']);
      await choose(tester, 'Filter by source: All sources', 'Built-in');
      expect(find.text('No matching Sentinels'), findsOneWidget);
      await choose(tester, 'Filter by source: Built-in', 'Your Sentinels');
      await tester.tap(find.text('Zulu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AthenaSettingsBackLink));
      await tester.pumpAndSettle();
      expect(rows(tester), ['Zulu', 'Alpha']);
      expect(find.text('Sentinels · 2'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        ' REVIEW ',
      );
    },
  );

  testWidgets(
    'experience range selection follows the searched and sorted rows',
    (tester) async {
      final repo = GetIt.instance<ExperienceRepository>();
      await tester.runAsync(() async {
        final alpha = await repo.save(lesson: 'Alpha', sentinelId: 'owner');
        for (final lesson in ['Hidden', 'Zulu', 'Archived lesson']) {
          final entry = await repo.save(
            lesson: lesson,
            sentinelId: 'owner',
            tags: lesson == 'Zulu' ? ['review'] : [],
          );
          if (lesson == 'Archived lesson') {
            await repo.update(
              id: entry.id,
              sentinelId: entry.sentinelId,
              status: ExperienceEntity.statusArchived,
            );
          }
        }
        await repo.update(
          id: alpha.id,
          sentinelId: alpha.sentinelId,
          context: 'Review notes',
        );
      });
      await showPage(tester, const DesktopSettingExperiencePage(), 'Hidden');
      expect(rows(tester), ['Zulu', 'Hidden', 'Alpha', 'Archived lesson']);
      await choose(tester, 'Sort by Newest first', 'Last edited');
      expect(rows(tester), ['Alpha', 'Zulu', 'Hidden', 'Archived lesson']);
      await choose(tester, 'Sort by Last edited', 'Lesson');
      expect(rows(tester), ['Alpha', 'Hidden', 'Zulu', 'Archived lesson']);
      await choose(tester, 'Filter by status: All statuses', 'Archived');
      expect(rows(tester), ['Archived lesson']);
      await search(tester, 'REVIEW');
      expect(find.text('No matching experiences'), findsOneWidget);
      await choose(tester, 'Filter by status: Archived', 'Active');
      expect(rows(tester), ['Alpha', 'Zulu']);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Alpha'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Zulu'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zulu'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(find.text('Archive 2'), findsOneWidget);
    },
  );
}
