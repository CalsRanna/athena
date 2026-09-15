import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_gui/page/desktop/setting/experience/experience.dart';
import 'package:athena_gui/page/desktop/setting/provider/provider.dart';
import 'package:athena_gui/page/desktop/setting/sentinel/sentinel.dart';
import 'package:athena_gui/page/desktop/setting/skill/skill.dart';
import 'package:athena_gui/page/desktop/setting/skill/component/skill_form_dialog.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/experience_view_model.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/menu.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  for (final kind in ['provider', 'sentinel', 'skill', 'experience']) {
    testWidgets(
      '$kind supports modifier selection and one batch confirmation',
      (tester) async {
        await _prepareList(tester, kind);
        await _modifiedTap(tester, '$kind-2', LogicalKeyboardKey.metaLeft);
        expect(_menuTile(tester, '$kind-2').active, isTrue);
        await _modifiedTap(tester, '$kind-2', LogicalKeyboardKey.metaLeft);
        expect(_menuTile(tester, '$kind-2').active, isFalse);
        await _modifiedTap(tester, '$kind-2', LogicalKeyboardKey.metaLeft);
        await _modifiedTap(tester, '$kind-4', LogicalKeyboardKey.controlLeft);

        await _openDeleteMenu(tester, '$kind-4');
        final action = kind == 'experience' ? 'Archive' : 'Edit';
        expect(_contextMenuItem(tester, action).enabled, kind == 'experience');
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Do you want to delete 2 ${kind}s?'), findsOneWidget);
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect(_labels(kind), ['$kind-1', '$kind-2', '$kind-3', '$kind-4']);
        expect(_menuTile(tester, '$kind-2').active, isFalse);
        expect(_menuTile(tester, '$kind-4').active, isFalse);

        await _modifiedTap(tester, '$kind-2', LogicalKeyboardKey.metaLeft);
        await _modifiedTap(tester, '$kind-4', LogicalKeyboardKey.controlLeft);
        await _deleteSelectedItem(tester, '$kind-4');
        expect(_labels(kind), ['$kind-1', '$kind-3']);
        expect(_menuTile(tester, '$kind-1').active, isTrue);
        expect(_menuTile(tester, '$kind-3').active, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$kind shift-select deletes range and restores previous item', (
      tester,
    ) async {
      await _prepareList(tester, kind);
      await tester.tap(find.text('$kind-2').first);
      await tester.pump();
      await _modifiedTap(tester, '$kind-4', LogicalKeyboardKey.shiftLeft);
      expect(_menuTile(tester, '$kind-3').active, isTrue);
      await _deleteSelectedItem(tester, '$kind-4');
      expect(_labels(kind), ['$kind-1']);
      expect(_menuTile(tester, '$kind-1').active, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$kind can delete every unprotected item without stale details',
      (tester) async {
        await _prepareList(tester, kind);
        await tester.tap(find.text('$kind-1').first);
        await tester.pump();
        await _modifiedTap(tester, '$kind-4', LogicalKeyboardKey.shiftLeft);
        await _deleteSelectedItem(tester, '$kind-4');
        expect(_labels(kind), isEmpty);
        expect(find.byType(DesktopMenuTile), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$kind batch deletion keeps the last active item in bounds', (
      tester,
    ) async {
      await _prepareList(tester, kind);
      await tester.tap(find.text('$kind-4').first);
      await tester.pump();
      await _modifiedTap(tester, '$kind-2', LogicalKeyboardKey.metaLeft);
      await _modifiedTap(tester, '$kind-4', LogicalKeyboardKey.metaLeft);
      await _deleteSelectedItem(tester, '$kind-4');
      expect(_labels(kind), ['$kind-1', '$kind-3']);
      expect(_menuTile(tester, '$kind-3').active, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  for (final kind in ['provider', 'sentinel', 'skill']) {
    testWidgets('$kind skips protected items in modifier and range selection', (
      tester,
    ) async {
      await _prepareList(tester, kind, protectFirst: true);
      await tester.tap(find.text('$kind-2').first);
      await tester.pump();
      await _modifiedTap(tester, '$kind-1', LogicalKeyboardKey.metaLeft);
      expect(_menuTile(tester, '$kind-1').active, isFalse);
      await _modifiedTap(tester, '$kind-4', LogicalKeyboardKey.shiftLeft);
      await _deleteSelectedItem(tester, '$kind-4');
      expect(_labels(kind), ['$kind-1']);
      expect(_menuTile(tester, '$kind-1').active, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ordinary click clears selection before opening another item', (
    tester,
  ) async {
    await _prepareList(tester, 'provider');
    await _modifiedTap(tester, 'provider-2', LogicalKeyboardKey.metaLeft);
    await _modifiedTap(tester, 'provider-4', LogicalKeyboardKey.metaLeft);
    await tester.tap(find.text('provider-3').first);
    await tester.pump();
    expect(_menuTile(tester, 'provider-2').active, isFalse);
    expect(_menuTile(tester, 'provider-4').active, isFalse);
    expect(_menuTile(tester, 'provider-3').active, isTrue);
    await _deleteSelectedItem(tester, 'provider-3');
    expect(_labels('provider'), ['provider-1', 'provider-2', 'provider-4']);
  });

  testWidgets('batch failure keeps remaining records and stops deleting', (
    tester,
  ) async {
    final getIt = GetIt.instance;
    await getIt.unregister<ProviderViewModel>();
    getIt.registerSingleton<ProviderViewModel>(
      _FailingProviderViewModel(
        repository: getIt<ProviderRepository>(),
        modelViewModel: getIt<ModelViewModel>(),
      ),
    );
    await _prepareList(tester, 'provider');
    await tester.tap(find.text('provider-2').first);
    await tester.pump();
    await _modifiedTap(tester, 'provider-4', LogicalKeyboardKey.shiftLeft);
    await _deleteSelectedItem(tester, 'provider-4');
    expect(_labels('provider'), ['provider-1', 'provider-3', 'provider-4']);
    expect(find.text('Deletion failed'), findsOneWidget);
    expect(_menuTile(tester, 'provider-1').active, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
    'batch Archive skips archived records and preserves single Restore',
    (tester) async {
      final repository = _MemoryExperienceRepository();
      await _prepareList(
        tester,
        'experience',
        experienceRepository: repository,
      );
      final viewModel = GetIt.instance<ExperienceViewModel>();
      await viewModel.archiveExperience(viewModel.experiences.value[1]);
      repository.updatedIds.clear();
      await tester.pump();
      await _modifiedTap(tester, 'experience-2', LogicalKeyboardKey.metaLeft);
      await _modifiedTap(tester, 'experience-4', LogicalKeyboardKey.metaLeft);
      await _openDeleteMenu(tester, 'experience-2');
      expect(_contextMenuItem(tester, 'Archive').enabled, isTrue);
      expect(find.text('Restore'), findsNothing);
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(repository.updatedIds, ['3']);
      expect(repository.records.map((item) => item.status), [
        'active',
        'archived',
        'active',
        'archived',
      ]);
      expect(_menuTile(tester, 'experience-2').active, isFalse);
      expect(_menuTile(tester, 'experience-4').active, isFalse);

      await _modifiedTap(tester, 'experience-2', LogicalKeyboardKey.metaLeft);
      await _modifiedTap(tester, 'experience-4', LogicalKeyboardKey.metaLeft);
      await _openDeleteMenu(tester, 'experience-4');
      expect(_contextMenuItem(tester, 'Archive').enabled, isFalse);
      DesktopContextMenuManager.instance.dismiss();
      await tester.pump();
      await tester.tap(find.text('experience-4').first);
      await tester.pump();
      await _openDeleteMenu(tester, 'experience-4');
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(repository.records[3].status, 'active');
      expect(tester.takeException(), isNull);
    },
  );

  for (final fail in [false, true]) {
    testWidgets(
      'range Archive handles ${fail ? 'failure' : 'all selected records'}',
      (tester) async {
        final repository = _MemoryExperienceRepository()
          ..failUpdateId = fail ? '2' : null;
        await _prepareList(
          tester,
          'experience',
          experienceRepository: repository,
        );
        await tester.tap(find.text('experience-2').first);
        await tester.pump();
        await _modifiedTap(
          tester,
          'experience-4',
          LogicalKeyboardKey.shiftLeft,
        );
        await _openDeleteMenu(tester, 'experience-4');
        await tester.tap(find.text('Archive'));
        await tester.pumpAndSettle();
        expect(repository.records.map((item) => item.status), [
          'active',
          'archived',
          fail ? 'active' : 'archived',
          fail ? 'active' : 'archived',
        ]);
        expect(repository.updatedIds, fail ? ['1', '2'] : ['1', '2', '3']);
        expect(_menuTile(tester, 'experience-2').active, isTrue);
        expect(_menuTile(tester, 'experience-4').active, isFalse);
        if (fail) {
          expect(find.text('Experience not found'), findsOneWidget);
          await tester.pump(const Duration(seconds: 4));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Skill Edit saves the description and preserves the hidden instructions',
    (tester) async {
      await _prepareList(tester, 'skill');
      await _openDeleteMenu(tester, 'skill-3');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Skill'), findsOneWidget);
      final fields = find.descendant(
        of: find.byType(DesktopSkillFormDialog),
        matching: find.byType(TextField),
      );
      expect(fields, findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(DesktopSkillFormDialog),
          matching: find.text('Instructions'),
        ),
        findsNothing,
      );
      expect(
        tester.widget<TextField>(fields.at(0)).controller!.text,
        'skill-3',
      );
      expect(tester.widget<TextField>(fields.at(0)).enabled, isFalse);
      expect(
        tester.widget<TextField>(fields.at(1)).controller!.text,
        'Description 2',
      );
      await tester.enterText(fields.at(1), 'Edited description');
      await tester.tap(find.text('Store').last);
      await tester.pumpAndSettle();
      expect(find.byType(DesktopSkillFormDialog), findsNothing);
      final skills = GetIt.instance<SkillViewModel>().skills.value;
      final edited = skills.firstWhere((skill) => skill.name == 'skill-3');
      expect(edited.description, 'Edited description');
      expect(edited.body, 'Instructions 2');
      expect(
        skills.firstWhere((skill) => skill.name == 'skill-1').description,
        'Description 0',
      );
      expect(_menuTile(tester, 'skill-3').active, isTrue);
      expect(find.text('Edited description'), findsOneWidget);
      expect(find.text('Instructions 2'), findsOneWidget);
      await GetIt.instance<SkillViewModel>().load();
      expect(
        GetIt.instance<SkillRegistry>().get('skill-3')!.body,
        'Instructions 2',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Skill Edit cancellation leaves content unchanged and built-ins have no Edit',
    (tester) async {
      await _prepareList(tester, 'skill', protectFirst: true);
      await _openDeleteMenu(tester, 'skill-1');
      expect(find.text('Edit'), findsNothing);
      await _openDeleteMenu(tester, 'skill-2');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(DesktopSkillFormDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(1), 'Unsaved');
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(
        GetIt.instance<SkillRegistry>().get('skill-2')!.description,
        'Description 1',
      );
      expect(_menuTile(tester, 'skill-1').active, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Skill form still creates a new skill', (tester) async {
    await _pumpPage(tester, const DesktopSkillFormDialog());
    expect(find.text('Add Skill'), findsOneWidget);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    expect(tester.widget<TextField>(fields.first).enabled, isTrue);
    await tester.enterText(fields.first, 'new-skill');
    await tester.enterText(fields.last, 'New description');
    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();
    final skill = GetIt.instance<SkillRegistry>().get('new-skill');
    expect(skill!.description, 'New description');
    expect(skill.body, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _prepareList(
  WidgetTester tester,
  String kind, {
  bool protectFirst = false,
  _MemoryExperienceRepository? experienceRepository,
}) async {
  final getIt = GetIt.instance;
  switch (kind) {
    case 'provider':
      await _pumpPage(tester, const DesktopSettingProviderPage());
      getIt<ProviderViewModel>().providers.value = List.generate(
        4,
        (index) => ProviderEntity(
          id: index + 1,
          name: 'provider-${index + 1}',
          baseUrl: 'https://example.com',
          apiKey: '',
          isPreset: protectFirst && index == 0,
          createdAt: DateTime(2026),
        ),
      );
    case 'sentinel':
      await _pumpPage(tester, const DesktopSettingSentinelPage());
      getIt<SentinelViewModel>().sentinels.value = List.generate(
        4,
        (index) => SentinelEntity(
          id: index + 1,
          name: 'sentinel-${index + 1}',
          isPreset: protectFirst && index == 0,
        ),
      );
    case 'skill':
      await getIt.unregister<SkillViewModel>();
      getIt.registerSingleton<SkillViewModel>(
        _OrderedSkillViewModel(skillRegistry: getIt<SkillRegistry>()),
      );
      final viewModel = getIt<SkillViewModel>();
      for (var index = 0; index < 4; index++) {
        if (protectFirst && index == 0) {
          getIt<SkillRegistry>().registerBuiltin(
            const Skill(
              name: 'skill-1',
              description: 'Built in',
              body: 'Instructions',
              sourcePath: '(builtin)',
            ),
          );
        } else {
          await viewModel.createSkill(
            name: 'skill-${index + 1}',
            description: 'Description $index',
            body: 'Instructions $index',
          );
        }
      }
      await _pumpPage(tester, const DesktopSettingSkillPage());
    case 'experience':
      final repository = experienceRepository ?? _MemoryExperienceRepository();
      await getIt.unregister<ExperienceViewModel>();
      getIt.registerSingleton<ExperienceViewModel>(
        _DelayedExperienceViewModel(
          experienceRepository: repository,
          sentinelRepository: getIt<SentinelRepository>(),
        ),
      );
      await _pumpPage(tester, const DesktopSettingExperiencePage());
  }
  await tester.pumpAndSettle();
}

List<String> _labels(String kind) {
  final getIt = GetIt.instance;
  return switch (kind) {
    'provider' =>
      getIt<ProviderViewModel>().providers.value.map((e) => e.name).toList(),
    'sentinel' =>
      getIt<SentinelViewModel>().sentinels.value.map((e) => e.name).toList(),
    'skill' => getIt<SkillViewModel>().skills.value.map((e) => e.name).toList(),
    _ =>
      getIt<ExperienceViewModel>().experiences.value
          .map((e) => e.lesson)
          .toList(),
  };
}

Future<void> _modifiedTap(
  WidgetTester tester,
  String label,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(key);
  await tester.tap(find.text(label).first);
  await tester.sendKeyUpEvent(key);
  await tester.pump();
}

Future<void> _openDeleteMenu(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first, buttons: kSecondaryMouseButton);
  await tester.pump();
}

class _MemoryExperienceRepository extends ExperienceRepository {
  final updatedIds = <String>[];
  String? failUpdateId;
  final records = List.generate(
    4,
    (index) => ExperienceEntity(
      id: '$index',
      sentinelId: 'shared',
      scope: 'shared',
      lesson: 'experience-${index + 1}',
      createdAt: DateTime(2026),
    ),
  );

  @override
  Future<List<ExperienceEntity>> listAll({
    bool includeArchived = false,
  }) async => [...records];

  @override
  Future<bool> delete(String sentinelId, String id) async {
    records.removeWhere((e) => e.sentinelId == sentinelId && e.id == id);
    return true;
  }

  @override
  Future<ExperienceEntity?> update({
    required String sentinelId,
    required String id,
    String? lesson,
    String? context,
    List<String>? tags,
    String? scope,
    String? status,
  }) async {
    updatedIds.add(id);
    if (id == failUpdateId) return null;
    final index = records.indexWhere(
      (item) => item.sentinelId == sentinelId && item.id == id,
    );
    if (index < 0) return null;
    final updated = ExperienceEntity.fromJson({
      ...records[index].toJson(),
      if (status != null) 'status': status,
    });
    records[index] = updated;
    return updated;
  }
}

class _FailingProviderViewModel extends ProviderViewModel {
  _FailingProviderViewModel({
    required super.repository,
    required super.modelViewModel,
  });

  @override
  Future<void> deleteProvider(ProviderEntity provider) async {
    if (provider.id == 3) {
      error.value = 'Deletion failed';
      return;
    }
    await super.deleteProvider(provider);
  }
}

// Keep the fixture order stable across reloads, independent of disk ordering.
class _OrderedSkillViewModel extends SkillViewModel {
  _OrderedSkillViewModel({required super.skillRegistry});

  void _sort() {
    skills.value = [...skills.value]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<void> load() async {
    await super.load();
    _sort();
  }

  @override
  Future<bool> deleteSkill(Skill skill) async {
    final result = await super.deleteSkill(skill);
    _sort();
    return result;
  }
}

class _DelayedExperienceViewModel extends ExperienceViewModel {
  _DelayedExperienceViewModel({
    required super.experienceRepository,
    required super.sentinelRepository,
  });

  @override
  Future<bool> deleteExperience(ExperienceEntity entity) async {
    final result = await super.deleteExperience(entity);
    // Model the async gap while owner names reload after the list changes.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return result;
  }
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
  // The last owner-name refresh can still be pending when the list is empty.
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

DesktopMenuTile _menuTile(WidgetTester tester, String label) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is DesktopMenuTile && widget.label == label,
  );
  return tester.widget<DesktopMenuTile>(finder);
}

DesktopContextMenuTile _contextMenuItem(WidgetTester tester, String label) {
  return tester.widget<DesktopContextMenuTile>(
    find.byWidgetPredicate(
      (widget) => widget is DesktopContextMenuTile && widget.text == label,
    ),
  );
}
