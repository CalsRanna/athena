import 'dart:io';

import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/sentinel_store.dart';
import 'package:test/test.dart';

void main() {
  test('enabledTools 在 YAML 中往返；缺失表示不限制', () {
    const sentinel = SentinelEntity(
      id: 's1',
      name: 'Reviewer',
      prompt: 'p',
      enabledTools: ['file_read', 'web_search'],
    );
    final encoded = SentinelStore.encode(sentinel);
    expect(encoded['enabledTools'], ['file_read', 'web_search']);
    expect(SentinelStore.parse('s1', encoded).enabledTools, [
      'file_read',
      'web_search',
    ]);

    expect(SentinelStore.parse('s2', {'name': 'Athena'}).enabledTools, isNull);
  });

  test('空列表是显式的「一个都不启用」', () {
    final parsed = SentinelStore.parse('s1', {
      'name': 'x',
      'enabledTools': const <String>[],
    });
    expect(parsed.enabledTools, isEmpty);
  });

  test('copyWith 区分「保留」与「显式清空」', () {
    const sentinel = SentinelEntity(name: 'x', enabledTools: ['file_read']);
    expect(sentinel.copyWith().enabledTools, ['file_read']);
    expect(sentinel.copyWith(enabledTools: null).enabledTools, isNull);
  });

  test('旧 JSON 迁移缺失 enabled_tools 时按不限制处理', () {
    final entity = SentinelEntity.fromJson({'name': 'Athena'});
    expect(entity.enabledTools, isNull);

    final json = const SentinelEntity(
      name: 'Athena',
      enabledTools: ['file_read'],
    ).toJson();
    expect(json['enabled_tools'], ['file_read']);
  });

  test('真实 YAML 落盘后能读回白名单，空列表与缺失保持区分', () async {
    final temp = await Directory.systemTemp.createTemp(
      'athena_sentinel_tools_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final store = SentinelStore(
      directory: Directory.fromUri(temp.uri.resolve('sentinels')),
      locks: LockRegistry(temp),
    );

    await store.write(
      const SentinelEntity(
        id: 's1',
        name: 'Reviewer',
        prompt: 'p',
        enabledTools: ['file_read', 'web_search'],
      ),
    );
    expect((await store.read('s1'))?.enabledTools, ['file_read', 'web_search']);

    await store.write(
      const SentinelEntity(
        id: 's2',
        name: 'Nothing',
        prompt: 'p',
        enabledTools: [],
      ),
    );
    expect((await store.read('s2'))?.enabledTools, isEmpty);

    await store.write(const SentinelEntity(id: 's3', name: 'All', prompt: 'p'));
    expect((await store.read('s3'))?.enabledTools, isNull);
  });
}
