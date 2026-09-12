import 'dart:io';

import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_gui/view_model/experience_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSentinelRepository implements SentinelRepository {
  @override
  Future<List<SentinelEntity>> getAllSentinels() async => [
    SentinelEntity(id: 7, name: 'Athena', prompt: 'p'),
  ];
  @override
  Future<SentinelEntity?> getSentinelById(int id) async => null;
  @override
  Future<int> createSentinel(SentinelEntity sentinel) async => 1;
  @override
  Future<void> updateSentinel(SentinelEntity sentinel) async {}
  @override
  Future<void> deleteSentinel(int id) async {}
  @override
  Future<int> getSentinelsCount() async => 1;
  @override
  Future<void> batchCreateSentinels(List<SentinelEntity> sentinels) async {}
  @override
  Future<SentinelEntity?> getSentinelByName(String name) async => null;
  @override
  Future<void> importSentinels(List<SentinelEntity> sentinels) async {}
}

void main() {
  late Directory tmp;
  late ExperienceRepository repository;
  late ExperienceViewModel viewModel;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('experience_vm_test');
    repository = ExperienceRepository(homeDir: tmp.path);
    viewModel = ExperienceViewModel(
      experienceRepository: repository,
      sentinelRepository: _FakeSentinelRepository(),
    );
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('load 汇总私有与 shared，并映射归属名', () async {
    await repository.save(lesson: 'private lesson', sentinelId: '7');
    await repository.save(
      lesson: 'shared lesson',
      scope: 'shared',
      sentinelId: '7',
    );

    await viewModel.load();

    expect(viewModel.experiences.value, hasLength(2));
    final priv =
        viewModel.experiences.value.firstWhere((e) => e.scope == 'self');
    final shared =
        viewModel.experiences.value.firstWhere((e) => e.scope == 'shared');
    expect(viewModel.ownerLabel(priv), 'Athena');
    expect(viewModel.ownerLabel(shared), 'Shared');
  });

  test('archive/restore 切换状态，归档项始终展示', () async {
    await repository.save(lesson: 'lesson a', sentinelId: '7');
    await viewModel.load();
    final entity = viewModel.experiences.value.single;

    expect(await viewModel.archiveExperience(entity), isTrue);
    expect(
      viewModel.experiences.value.single.status,
      ExperienceEntity.statusArchived,
      reason: '归档项仍展示在列表中',
    );

    expect(
      await viewModel.restoreExperience(viewModel.experiences.value.single),
      isTrue,
    );
    expect(
      viewModel.experiences.value.single.status,
      ExperienceEntity.statusActive,
    );
  });

  test('deleteExperience 永久删除', () async {
    await repository.save(lesson: 'bye', sentinelId: '7');
    await viewModel.load();
    final entity = viewModel.experiences.value.single;

    expect(await viewModel.deleteExperience(entity), isTrue);
    expect(viewModel.experiences.value, isEmpty);
  });
}
