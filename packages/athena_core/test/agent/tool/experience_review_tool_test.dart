import 'dart:io';

import 'package:athena_core/agent/tool/experience_review_tool.dart';
import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:test/test.dart';

/// 锁定 experience_review：用户验证信号（confirm/refute）的写入行为。
void main() {
  late Directory tempDir;
  late String rootHome;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('experience_review_test');
    rootHome = '${tempDir.path}/athena-data';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  ExperienceRepository newRepo() => ExperienceRepository(homeDir: rootHome);

  ExperienceReviewTool newReviewTool() =>
      ExperienceReviewTool(repository: newRepo());

  Future<String> seedExperience(String lesson) async {
    final repo = newRepo();
    final e =
        await repo.save(lesson: lesson, sentinelId: 's1');
    return e.id;
  }

  test('confirm 记录用户认可', () async {
    final id = await seedExperience('lesson');
    final result = await newReviewTool().execute({
      'action': 'confirm',
      'experience_id': id,
      'note': 'The user said this is exactly right',
      '_sentinel_id': 's1',
    });
    expect(result, contains('user-confirmed'));

    final all = await newRepo().listForSentinel('s1');
    expect(all.single.userVerdict, ExperienceEntity.verdictConfirmed);
  });

  test('refute 记录用户证伪并提示归档', () async {
    final id = await seedExperience('lesson');
    final result = await newReviewTool().execute({
      'action': 'refute',
      'experience_id': id,
      '_sentinel_id': 's1',
    });
    expect(result, contains('user-refuted'));
    expect(result, contains('archive'));

    final all = await newRepo().listForSentinel('s1');
    expect(all.single.userVerdict, ExperienceEntity.verdictRefuted);
  });

  test('无效 action 报错', () async {
    final tool = newReviewTool();
    final result =
        await tool.execute({'action': 'maybe', 'experience_id': 'x'});
    expect(result, contains('must be "confirm" or "refute"'));
  });

  test('缺 experience_id 报错', () async {
    final tool = newReviewTool();
    final result = await tool.execute({'action': 'confirm'});
    expect(result, contains('experience_id is required'));
  });

  test('不存在的经验报错', () async {
    final tool = newReviewTool();
    final result = await tool.execute({
      'action': 'confirm',
      'experience_id': 'nope_123',
      '_sentinel_id': 's1',
    });
    expect(result, contains('not found'));
  });
}
