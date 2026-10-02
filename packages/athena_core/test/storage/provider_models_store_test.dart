import 'dart:io';

import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// 模型存在所属 provider 的文件里:改 provider 不丢模型、删 provider 连模型
/// 一起删、每次写入只落盘一次。
void main() {
  late Directory temp;
  late FileStorage storage;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_provider_models_');
    storage = FileStorage(root: Directory(p.join(temp.path, '.athena')));
  });
  tearDown(() => temp.delete(recursive: true));

  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  ProviderEntity provider(String name) => ProviderEntity(
    name: name,
    baseUrl: 'https://$name.example/v1',
    apiKey: 'sk-$name',
    createdAt: now,
  );

  ModelEntity model(String name, String providerId, {String? id}) =>
      ModelEntity(
        id: id,
        name: name,
        modelId: '$name-id',
        providerId: providerId,
        contextWindow: 1000,
        createdAt: now,
        updatedAt: now,
      );

  File providerFile(String id) =>
      File(p.join(storage.providersDir.path, '$id.yaml'));

  Future<Map> rawOf(String id) async =>
      loadYaml(await providerFile(id).readAsString()) as Map;

  test('模型写进 provider 文件的 models 段，providerId 取自文件名', () async {
    final pid = await storage.providerRepository.storeProvider(provider('p'));
    final mid = await storage.modelRepository.createModel(model('m', pid));

    final raw = await rawOf(pid);
    expect(raw['name'], 'p');
    expect(raw['models'], hasLength(1));
    expect((raw['models'] as List).single['id'], mid);
    expect((raw['models'] as List).single['modelId'], 'm-id');

    final read = (await storage.modelRepository.getModelById(mid))!;
    expect(read.providerId, pid);
    expect(read.contextWindow, 1000);
  });

  test('改 provider 的字段不会抹掉它的模型', () async {
    final pid = await storage.providerRepository.storeProvider(provider('p'));
    final mid = await storage.modelRepository.createModel(model('m', pid));

    // 仓储层到处是「copyWith 改一个字段再整体写回」,这些都不能丢模型
    var p0 = (await storage.providerRepository.getProviderById(pid))!;
    await storage.providerRepository.updateProvider(
      p0.copyWith(apiKey: 'sk-new', enabled: true),
    );
    p0 = (await storage.providerRepository.getProviderById(pid))!;
    await storage.providerRepository.syncApiFormat(
      id: pid,
      baseUrl: p0.baseUrl,
      apiFormat: p0.apiFormat,
    );

    expect((await rawOf(pid))['models'], hasLength(1));
    expect(await storage.modelRepository.getModelById(mid), isNotNull);
    expect((await rawOf(pid))['apiKey'], 'sk-new');
  });

  test('删 provider 连它的模型一起删（不再有孤儿）', () async {
    final pid = await storage.providerRepository.storeProvider(provider('p'));
    final mid = await storage.modelRepository.createModel(model('m', pid));

    await storage.providerRepository.deleteProvider(pid);

    expect(await storage.modelRepository.getModelById(mid), isNull);
    expect(await storage.modelRepository.getAllModels(), isEmpty);
    expect(await providerFile(pid).exists(), isFalse);
  });

  test('往不存在的 provider 建模型会报错，不留孤儿文件', () async {
    await expectLater(
      storage.modelRepository.createModel(model('m', 'ghost')),
      throwsA(isA<StateError>()),
    );
    expect(await providerFile('ghost').exists(), isFalse);
  });

  test('单个模型更新只动它自己，同 provider 的其余模型不受影响', () async {
    final pid = await storage.providerRepository.storeProvider(provider('p'));
    final m1 = await storage.modelRepository.createModel(model('one', pid));
    final m2 = await storage.modelRepository.createModel(model('two', pid));

    final updated = (await storage.modelRepository.getModelById(
      m1,
    ))!.copyWith(name: 'renamed');
    await storage.modelRepository.updateModel(updated);

    final all = await storage.modelRepository.getModelsByProviderId(pid);
    expect(all, hasLength(2));
    expect(all.firstWhere((m) => m.id == m1).name, 'renamed');
    expect(all.firstWhere((m) => m.id == m2).name, 'two');
  });

  test('删单个模型', () async {
    final pid = await storage.providerRepository.storeProvider(provider('p'));
    final m1 = await storage.modelRepository.createModel(model('one', pid));
    await storage.modelRepository.createModel(model('two', pid));

    await storage.modelRepository.deleteModel(m1);

    expect((await rawOf(pid))['models'], hasLength(1));
    expect(await storage.modelRepository.getModelById(m1), isNull);
  });

  test('手工编辑 provider 文件加一个模型，读得到', () async {
    final pid = await storage.providerRepository.storeProvider(provider('p'));
    providerFile(pid).writeAsStringSync('''
name: "p"
baseUrl: "https://p.example/v1"
apiKey: "sk-p"
models:
  - id: "hand-written"
    name: "Hand"
    modelId: "hand-model"
    contextWindow: 4096
''');

    final read = (await storage.modelRepository.getModelById('hand-written'))!;
    expect(read.name, 'Hand');
    expect(read.modelId, 'hand-model');
    expect(read.providerId, pid);
  });
}
