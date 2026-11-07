import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_core/storage/experience_repository.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// 经验库是唯一会随使用时长无限增长的持久化状态：可见范围、写法与清理
/// 一旦悄悄退化，用户看到的是「经验莫名其妙消失/串台」。
void main() {
  late Directory temp;
  late ExperienceRepository repo;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_experience_');
    repo = ExperienceRepository(homeDir: temp.path);
  });

  tearDown(() => temp.delete(recursive: true));

  File fileOf(String sentinelId, String id) =>
      File('${temp.path}/.athena/experiences/$sentinelId/$id.json');

  test('经验来源落盘后可读回，修订、迁移作用域和归档保留最初来源', () async {
    final created = await repo.save(
      lesson: 'original',
      sentinelId: '1',
      sourceChatId: 'chat-1',
      sourceMessageId: 'message-1',
    );
    final saved = (await repo.listPrivate('1')).single;
    expect(saved.sourceChatId, 'chat-1');
    expect(saved.sourceMessageId, 'message-1');

    await repo.update(
      sentinelId: '1',
      id: created.id,
      lesson: 'revised',
      scope: 'shared',
    );
    await repo.update(
      sentinelId: '1',
      id: created.id,
      status: ExperienceEntity.statusArchived,
    );
    final archived = (await repo.listShared(includeArchived: true)).single;
    expect(archived.sourceChatId, 'chat-1');
    expect(archived.sourceMessageId, 'message-1');
    expect(archived.lesson, 'revised');
  });

  test('旧经验没有来源字段时仍可读取，不补造来源', () async {
    final created = await repo.save(lesson: 'legacy', sentinelId: '1');
    final json = created.toJson()
      ..remove('source_chat_id')
      ..remove('source_message_id')
      ..remove('workspace_path');
    fileOf('1', created.id).writeAsStringSync(jsonEncode(json));
    final saved = (await repo.listPrivate('1')).single;
    expect(saved.sourceChatId, isNull);
    expect(saved.sourceMessageId, isNull);
    expect(saved.workspacePath, isNull);
    expect(saved.lesson, 'legacy');
    expect(
      (await repo.listForSentinel(
        '1',
        workspacePath: p.join(temp.path, 'A'),
      )).single.id,
      created.id,
    );
  });

  test('同角色不同项目精确隔离，shared 与无项目经验保持跨项目可见', () async {
    final a = p.join(temp.path, 'A');
    final b = p.join(temp.path, 'B');
    final inA = await repo.save(
      lesson: 'project rule A',
      sentinelId: '1',
      workspacePath: a,
    );
    await repo.save(
      lesson: 'project rule B',
      sentinelId: '1',
      workspacePath: b,
    );
    final general = await repo.save(lesson: 'general', sentinelId: '1');
    final shared = await repo.save(
      lesson: 'shared preference',
      sentinelId: '1',
      scope: 'shared',
      workspacePath: a,
    );
    expect(shared.workspacePath, isNull);
    expect(
      (await repo.listForSentinel('1', workspacePath: a)).map((e) => e.id),
      unorderedEquals([inA.id, general.id, shared.id]),
    );
    expect(
      (await repo.listForSentinel('1')).map((e) => e.id),
      unorderedEquals([general.id, shared.id]),
    );
    expect(
      (await repo.listForSentinel('2', workspacePath: a)).map((e) => e.id),
      [shared.id],
    );
    expect(await repo.getForSentinel('1', inA.id, workspacePath: b), isNull);
    expect(
      await repo.searchForSentinel('1', inA.id, workspacePath: b),
      isEmpty,
    );
    expect(await repo.searchPrivate('1', inA.id, workspacePath: b), isEmpty);
    expect(
      (await repo.searchPrivate(
        '1',
        inA.id,
        workspacePath: a,
      )).single.workspacePath,
      a,
    );
    expect(await repo.listAll(), hasLength(4));
  });

  test('规范化等价目录，父子目录与名字相近的项目不自动合并', () async {
    final a = p.join(temp.path, 'A');
    final created = await repo.save(
      lesson: 'scoped',
      sentinelId: '1',
      workspacePath: p.join(a, 'sub', '..'),
    );
    expect(created.workspacePath, a);
    expect(
      (await repo.listPrivate('1', workspacePath: p.join(a, '.'))).single.id,
      created.id,
    );
    for (final path in [temp.path, p.join(a, 'sub'), '${a}2']) {
      expect(await repo.listForSentinel('1', workspacePath: path), isEmpty);
    }
  });

  test('普通修订保留项目，转 shared 解除限制，转回私有绑定当前项目', () async {
    final a = p.join(temp.path, 'A');
    final b = p.join(temp.path, 'B');
    final original = await repo.save(
      lesson: 'original',
      sentinelId: '1',
      workspacePath: a,
    );
    final updated = await repo.update(
      sentinelId: '1',
      id: original.id,
      lesson: 'revised',
      workspacePath: b,
    );
    expect(updated!.workspacePath, a);
    final shared = await repo.update(
      sentinelId: '1',
      id: original.id,
      scope: 'shared',
    );
    expect(shared!.workspacePath, isNull);
    expect(
      (await repo.listForSentinel('2', workspacePath: b)).single.id,
      original.id,
    );
    final private = await repo.update(
      sentinelId: '1',
      id: original.id,
      scope: 'self',
      workspacePath: b,
    );
    expect(private!.workspacePath, b);
    await repo.update(sentinelId: '1', id: original.id, status: 'archived');
    expect(await repo.listForSentinel('1', workspacePath: b), isEmpty);
    expect(
      await repo.listForSentinel('1', workspacePath: a, includeArchived: true),
      isEmpty,
    );
    expect((await repo.listAll(includeArchived: true)).single.workspacePath, b);
  });

  test('私有经验只对所属 Sentinel 可见，shared 对所有角色可见', () async {
    await repo.save(lesson: 'mine only', sentinelId: '1');
    await repo.save(lesson: 'everyone', scope: 'shared', sentinelId: '1');

    final forOne = await repo.listForSentinel('1');
    final forTwo = await repo.listForSentinel('2');

    expect(forOne.map((e) => e.lesson), containsAll(['mine only', 'everyone']));
    expect(forTwo.map((e) => e.lesson), ['everyone']);
  });

  test('归档项默认不出现在检索结果里，但仍留在磁盘上', () async {
    final created = await repo.save(lesson: 'retired', sentinelId: '1');
    await repo.update(
      sentinelId: '1',
      id: created.id,
      status: ExperienceEntity.statusArchived,
    );

    expect(await repo.listForSentinel('1'), isEmpty);
    expect(
      (await repo.listForSentinel('1', includeArchived: true)).single.status,
      ExperienceEntity.statusArchived,
    );
  });

  test('损坏的经验文件只跳过该条，并保留其余条目', () async {
    final good = await repo.save(lesson: 'readable', sentinelId: '1');
    fileOf('1', 'broken').writeAsStringSync('{ not json');

    final listed = await repo.listForSentinel('1');

    expect(listed.map((e) => e.id), [good.id]);
  });

  test('更新整文件原子替换：写入中途失败不会留下截断内容', () async {
    final created = await repo.save(
      lesson: 'original lesson',
      context: 'original context',
      tags: ['a', 'b'],
      sentinelId: '1',
    );

    await repo.update(sentinelId: '1', id: created.id, lesson: 'revised');

    // 临时文件不应残留，原文件必须是完整可解析的 JSON。
    final dir = Directory('${temp.path}/.athena/experiences/1');
    expect(dir.listSync().map((e) => e.path.split('/').last), [
      contains(created.id),
    ]);
    final json =
        jsonDecode(fileOf('1', created.id).readAsStringSync())
            as Map<String, dynamic>;
    expect(json['lesson'], 'revised');
    expect(json['context'], 'original context');
  });

  test('scope 改为 shared 时文件迁移到 shared 目录，旧文件不残留', () async {
    final created = await repo.save(lesson: 'promote me', sentinelId: '1');

    final updated = await repo.update(
      sentinelId: '1',
      id: created.id,
      scope: 'shared',
    );

    expect(updated!.scope, 'shared');
    expect(updated.sentinelId, 'shared');
    expect(fileOf('1', created.id).existsSync(), isFalse);
    expect(
      File(
        '${temp.path}/.athena/experiences/shared/${created.id}.json',
      ).existsSync(),
      isTrue,
    );
  });

  test('删除角色的私有经验不影响 shared 与别的角色', () async {
    await repo.save(lesson: 'private of 1', sentinelId: '1');
    await repo.save(lesson: 'private of 2', sentinelId: '2');
    await repo.save(lesson: 'shared', scope: 'shared', sentinelId: '1');

    await repo.deleteAllPrivate('1');

    expect(await repo.listPrivate('1'), isEmpty);
    expect((await repo.listPrivate('2')).single.lesson, 'private of 2');
    expect((await repo.listShared()).single.lesson, 'shared');
  });

  test('lesson 去重只在同一可见范围内比较', () async {
    await repo.save(lesson: 'same text', sentinelId: '1');
    await repo.save(lesson: 'same text', sentinelId: '2');

    expect((await repo.listPrivate('1')).single.lesson, 'same text');
    expect((await repo.listPrivate('2')).single.lesson, 'same text');
  });
}
