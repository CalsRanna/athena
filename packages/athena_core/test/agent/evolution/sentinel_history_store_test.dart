import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/evolution/sentinel_history_store.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:test/test.dart';

/// 锁定 sentinel 变更历史的存储：save/list/load 往返、
/// 特殊字符名称编码、损坏文件容忍。
void main() {
  late Directory tempDir;
  late String rootHome;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sentinel_history_test');
    rootHome = '${tempDir.path}/athena-data';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  SentinelEntity sentinel({
    String name = 'Athena',
    String prompt = 'role prompt',
  }) =>
      SentinelEntity(
        id: 1,
        name: name,
        prompt: prompt,
        description: 'desc',
        avatar: '🧠',
        tags: 'a,b',
      );

  test('save → list → load 往返完整', () async {
    final store = SentinelHistoryStore(homeDir: rootHome);
    final before = sentinel(prompt: 'old prompt');
    final id = await store.save('Athena', before, reason: 'improve tone');

    final metas = await store.list('Athena');
    expect(metas, hasLength(1));
    expect(metas.single.id, id);
    expect(metas.single.reason, 'improve tone');

    final loaded = await store.load('Athena', id);
    expect(loaded, isNotNull);
    expect(loaded!.prompt, 'old prompt');
    expect(loaded.description, 'desc');
    expect(loaded.avatar, '🧠');
  });

  test('list 按时间倒序（最新快照在前）', () async {
    final store = SentinelHistoryStore(homeDir: rootHome);
    final first = await store.save('Athena', sentinel(prompt: 'v1'), reason: 'r1');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final second = await store.save('Athena', sentinel(prompt: 'v2'), reason: 'r2');

    final metas = await store.list('Athena');
    expect(metas, hasLength(2));
    expect(metas.first.id, second, reason: 'revert 默认回滚到最近快照');
    expect(metas.last.id, first);
  });

  test('名称含特殊字符时目录编码安全', () async {
    final store = SentinelHistoryStore(homeDir: rootHome);
    const weirdName = '雅典娜 Athena 🧠 / #tag?';
    final id = await store.save(weirdName, sentinel(name: weirdName));

    final metas = await store.list(weirdName);
    expect(metas.single.id, id);
    final loaded = await store.load(weirdName, id);
    expect(loaded!.name, weirdName);
  });

  test('不同 sentinel 的历史互不串扰', () async {
    final store = SentinelHistoryStore(homeDir: rootHome);
    await store.save('A', sentinel(name: 'A', prompt: 'a'), reason: 'x');
    await store.save('B', sentinel(name: 'B', prompt: 'b'), reason: 'y');

    expect(await store.list('A'), hasLength(1));
    expect(await store.list('B'), hasLength(1));
  });

  test('目录缺失时 list/load 返回空（不抛异常）', () async {
    final store = SentinelHistoryStore(homeDir: rootHome);
    expect(await store.list('NoSuch'), isEmpty);
    expect(await store.load('NoSuch', 'any'), isNull);
  });

  test('损坏文件：list 跳过、load 返回 null', () async {
    final store = SentinelHistoryStore(homeDir: rootHome);
    final id = await store.save('Athena', sentinel());
    // 写入一条损坏快照
    final dir =
        Directory('$rootHome/.athena/sentinels/Athena/history');
    File('${dir.path}/corrupt.json').writeAsStringSync('{not json');

    final metas = await store.list('Athena');
    expect(metas.map((m) => m.id), [id]); // 只有一条有效快照

    expect(await store.load('Athena', 'corrupt'), isNull);
  });

  test('快照文件内容含完整 sentinel 字段', () async {
    final store = SentinelHistoryStore(homeDir: rootHome);
    final id =
        await store.save('Athena', sentinel(prompt: 'p1'), reason: 'why');
    final dir = Directory('$rootHome/.athena/sentinels/Athena/history');
    final json = jsonDecode(
      File('${dir.path}/$id.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(json['reason'], 'why');
    final entity = json['sentinel'] as Map<String, dynamic>;
    expect(entity['prompt'], 'p1');
    expect(entity['is_preset'], 0);
  });
}
