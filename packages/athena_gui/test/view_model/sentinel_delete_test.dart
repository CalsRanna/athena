import 'dart:io';

import 'package:athena_core/agent/evolution/sentinel_history_store.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/storage/experience_repository.dart';
import 'package:athena_gui/di.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 删除角色必须把它名下的私有经验与演进快照一起带走。
///
/// 角色 id 是 UUIDv7、不会被复用：留下的经验再也进不了任何角色的检索范围，
/// 快照也再没有回滚入口，只在管理页显示成一串裸 id。shared 经验不属于任何
/// 角色，必须保留。
void main() {
  late Directory tempRoot;
  late SentinelViewModel viewModel;
  late ExperienceRepository experiences;
  late SentinelHistoryStore history;
  late SentinelRepository sentinels;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Athena',
      packageName: 'com.athena',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
    tempRoot = Directory.systemTemp.createTempSync('athena_sentinel_delete');
    DI.ensureInitialized(homeDirOverride: tempRoot.path);
    viewModel = GetIt.instance<SentinelViewModel>();
    experiences = GetIt.instance<ExperienceRepository>();
    history = GetIt.instance<SentinelHistoryStore>();
    sentinels = GetIt.instance<SentinelRepository>();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  test('删除角色连带清理私有经验与演进快照，shared 经验保留', () async {
    final doomedId = await sentinels.createSentinel(
      const SentinelEntity(name: 'Doomed', prompt: 'v1'),
    );
    final keptId = await sentinels.createSentinel(
      const SentinelEntity(name: 'Kept', prompt: 'v1'),
    );
    final doomed = (await sentinels.getSentinelById(doomedId))!;
    final kept = (await sentinels.getSentinelById(keptId))!;

    await experiences.save(lesson: 'private to doomed', sentinelId: doomedId);
    await experiences.save(lesson: 'private to kept', sentinelId: keptId);
    await experiences.save(
      lesson: 'shared lesson',
      scope: 'shared',
      sentinelId: doomedId,
    );
    await history.save(doomed, reason: 'before evolve');
    await history.save(kept, reason: 'before evolve');

    await viewModel.getSentinels();
    await viewModel.deleteSentinel(doomed);

    expect(await sentinels.getSentinelById(doomedId), isNull);
    expect(await experiences.listPrivate(doomedId), isEmpty);
    expect(await history.list(doomed), isEmpty);
    // 别的角色与 shared 经验都不受影响。
    expect(
      (await experiences.listPrivate(keptId)).single.lesson,
      'private to kept',
    );
    expect((await experiences.listShared()).single.lesson, 'shared lesson');
    expect(await history.list(kept), hasLength(1));
  });

  test('删除失败时角色与附件都保持原样，错误可读', () async {
    final id = await sentinels.createSentinel(
      const SentinelEntity(name: 'Kept', prompt: 'v1'),
    );
    final entity = (await sentinels.getSentinelById(id))!;
    await experiences.save(lesson: 'still here', sentinelId: id);
    await viewModel.getSentinels();

    // 没有 id 的实体无法定位要删的角色：直接拒绝，不误删别的数据。
    await viewModel.deleteSentinel(
      const SentinelEntity(name: 'Kept', prompt: 'v1'),
    );

    expect(await sentinels.getSentinelById(id), isNotNull);
    expect((await experiences.listPrivate(id)).single.lesson, 'still here');
    expect(entity.name, 'Kept');
  });
}
