import 'dart:io';

import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// 每 provider 一个文件的存储：身份取自文件名、损坏隔离、按名字排序、
/// 并发编辑不同 provider 互不覆盖。
void main() {
  late Directory temp;
  late FileStorage storage;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_provider_store_');
    storage = FileStorage(root: Directory(p.join(temp.path, '.athena')));
  });
  tearDown(() => temp.delete(recursive: true));

  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  ProviderEntity provider(String name, {String key = 'k'}) => ProviderEntity(
    name: name,
    baseUrl: 'https://$name.example/v1',
    apiKey: key,
    createdAt: now,
  );

  File providerFile(String id) =>
      File(p.join(storage.providersDir.path, '$id.yaml'));

  test('文件名就是身份：手工放一个文件即得到一个 provider', () async {
    // 内容里的 id 与文件名不同，读出来应以文件名为准
    providerFile('my-gateway')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'id: "something-else"\nname: "My Gateway"\n'
        'baseUrl: "https://gw.example/v1"\napiKey: "sk-1"\nenabled: true\n',
      );

    final all = await storage.providerRepository.getAllProviders();
    expect(all.single.id, 'my-gateway');
    expect(all.single.name, 'My Gateway');
    expect(all.single.apiKey, 'sk-1');
    expect(all.single.enabled, isTrue);
  });

  test('列表按名字排序，大小写不敏感且稳定', () async {
    for (final name in ['zeta', 'Alpha', 'middle', 'Beta']) {
      await storage.providerRepository.storeProvider(provider(name));
    }
    final names = (await storage.providerRepository.getAllProviders())
        .map((p) => p.name)
        .toList();
    expect(names, ['Alpha', 'Beta', 'middle', 'zeta']);
  });

  test('删除一个 provider 不影响其他，也不留下文件', () async {
    final a = await storage.providerRepository.storeProvider(provider('a'));
    final b = await storage.providerRepository.storeProvider(provider('b'));

    await storage.providerRepository.deleteProvider(a);

    expect((await storage.providerRepository.getAllProviders()).single.id, b);
    expect(await providerFile(a).exists(), isFalse);
    expect(await providerFile(b).exists(), isTrue);
  });

  test('单个文件损坏只丢它自己，其余 provider 照常读出', () async {
    await storage.providerRepository.storeProvider(provider('good'));
    providerFile(
      'broken',
    ).writeAsStringSync('name: "x"\napiKey: "unterminated\n');

    final all = await storage.providerRepository.getAllProviders();
    expect(all.map((p) => p.name), ['good']);
    expect(await storage.providerRepository.getProvidersCount(), 1);
    expect(await storage.providerRepository.getProviderById('broken'), isNull);
  });

  test('并发编辑同一个 provider：凭据编辑不被格式同步的旧快照盖回', () async {
    // 只有预设 provider 参与格式同步（见 syncApiFormat 的守卫）
    final id = await storage.providerRepository.storeProvider(
      provider('p').copyWith(isPreset: true),
    );
    final other = FileStorage(root: storage.root);
    final edited = (await other.providerRepository.getProviderById(
      id,
    ))!.copyWith(apiKey: 'new-key', enabled: true);

    await Future.wait([
      other.providerRepository.updateProvider(edited),
      storage.providerRepository.syncApiFormat(
        id: id,
        baseUrl: edited.baseUrl,
        apiFormat: ApiFormat.responses,
      ),
    ]);
    // 再同步一次，覆盖「格式同步先落地、编辑后写」这一交错
    await storage.providerRepository.syncApiFormat(
      id: id,
      baseUrl: edited.baseUrl,
      apiFormat: ApiFormat.responses,
    );

    final saved = (await other.providerRepository.getProviderById(id))!;
    expect(saved.apiKey, 'new-key');
    expect(saved.enabled, isTrue);
    expect(saved.apiFormat, ApiFormat.responses);
  });

  test('getProviderById 只读目标文件，不解析整个目录', () async {
    final id = await storage.providerRepository.storeProvider(provider('a'));
    // 另一个文件损坏，读取 a 不受影响
    providerFile('broken').writeAsStringSync('::: not yaml :::\n');

    final found = await storage.providerRepository.getProviderById(id);
    expect(found!.name, 'a');
  });

  test('读写路径拒绝对路径穿越的 id', () async {
    expect(
      await storage.providerRepository.getProviderById('../escape'),
      isNull,
    );
    await storage.providerRepository.deleteProvider('../escape');
    // 数据文件与锁文件都不该被写到 providers/ 之外（这里什么都没写过，
    // 目录不存在即为最干净的通过形态）
    final leaked = storage.root.existsSync()
        ? storage.root.listSync().whereType<File>().where(
            (f) => p.basenameWithoutExtension(f.path).startsWith('escape'),
          )
        : const <File>[];
    expect(leaked, isEmpty);
  });
}
