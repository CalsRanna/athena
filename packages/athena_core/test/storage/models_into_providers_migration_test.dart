import 'dart:convert';
import 'dart:io';

import 'package:athena_core/storage/file_storage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// `models.json` 按 `provider_id` 分发进各 provider 文件、原文件退场。
void main() {
  late Directory temp;
  late FileStorage storage;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_models_merge_');
    storage = FileStorage(root: Directory(p.join(temp.path, '.athena')));
    // 前置状态:整数 id 迁移已完成(真实升级路径就是这样),provider 已经是
    // 一个一个文件
    await storage.root.create(recursive: true);
    await File(
      p.join(storage.root.path, '.storage_version'),
    ).writeAsString('{"version": 2, "legacy_model_ids": {}}');
  });
  tearDown(() => temp.delete(recursive: true));

  Future<void> writeProvider(String id, String name) async {
    File(p.join(storage.providersDir.path, '$id.yaml'))
      ..createSync(recursive: true)
      ..writeAsStringSync('id: "$id"\nname: "$name"\napiKey: "sk-$name"\n');
  }

  Future<void> writeModels(List<Map<String, dynamic>> models) async {
    await storage.modelsFile.writeAsString(jsonEncode(models));
  }

  Map<String, dynamic> model(
    String id,
    String providerId, {
    String modelId = 'm',
  }) => {
    'id': id,
    'name': 'Model $id',
    'model_id': modelId,
    'provider_id': providerId,
    'context_window': 1000,
    'output_limit': 100,
    'input_price': r'$1/M',
    'output_price': r'$2/M',
    'released_at': 'Released 2026-01-01',
    'reasoning': 1,
    'vision': 0,
    'is_preset': 1,
    'created_at': 1700000000000,
    'updated_at': 1700000000000,
  };

  Future<Map> providerFile(String id) async =>
      loadYaml(
            await File(
              p.join(storage.providersDir.path, '$id.yaml'),
            ).readAsString(),
          )
          as Map;

  test('模型按 provider_id 分发，provider 配置与 API key 不受影响', () async {
    await writeProvider('p1', 'One');
    await writeProvider('p2', 'Two');
    await writeModels([
      model('m1', 'p1'),
      model('m2', 'p1'),
      model('m3', 'p2'),
    ]);

    await storage.load();

    expect((await providerFile('p1'))['models'], hasLength(2));
    expect((await providerFile('p2'))['models'], hasLength(1));
    expect((await providerFile('p1'))['apiKey'], 'sk-One');
    expect((await providerFile('p2'))['apiKey'], 'sk-Two');

    final all = await storage.modelRepository.getAllModels();
    expect(all.map((m) => m.id).toSet(), {'m1', 'm2', 'm3'});
    expect(
      all.firstWhere((m) => m.id == 'm3').providerId,
      'p2',
      reason: 'providerId 取自文件名',
    );
    // 原文件退场留档，不再被读取
    expect(await storage.modelsFile.exists(), isFalse);
    expect(await File('${storage.modelsFile.path}.migrated').exists(), isTrue);
  });

  test('按 id 查模型跨 provider 找得到（每轮对话的热点路径）', () async {
    await writeProvider('p1', 'One');
    await writeProvider('p2', 'Two');
    await writeModels([model('m1', 'p1'), model('m2', 'p2')]);

    await storage.load();

    expect(
      (await storage.modelRepository.getModelById('m2'))!.name,
      'Model m2',
    );
    expect(
      (await storage.modelRepository.getModelByModelIdAndProviderId(
        'm',
        'p2',
      ))!.id,
      'm2',
    );
  });

  test('provider 不存在的模型不写进任何文件，保留在留档里', () async {
    await writeProvider('p1', 'One');
    await writeModels([model('m1', 'p1'), model('orphan', 'ghost')]);

    await storage.load();

    expect((await providerFile('p1'))['models'], hasLength(1));
    expect(await storage.providerRepository.getProviderById('ghost'), isNull);
    // 孤儿模型无法归位,但原始数据仍在留档里可查
    final archived =
        jsonDecode(
              await File('${storage.modelsFile.path}.migrated').readAsString(),
            )
            as List;
    expect(archived, hasLength(2));
  });

  test('重复执行幂等，且不会把已并入的模型重复写一遍', () async {
    await writeProvider('p1', 'One');
    await writeModels([model('m1', 'p1')]);

    await storage.load();
    await storage.load();
    await FileStorage(root: storage.root).load();

    expect((await providerFile('p1'))['models'], hasLength(1));
    expect(await storage.modelRepository.getAllModels(), hasLength(1));
  });

  test('models.json 损坏时中止并保留原文件', () async {
    await writeProvider('p1', 'One');
    await storage.modelsFile.writeAsString('[{"id": "m1"');

    await expectLater(storage.load(), throwsFormatException);

    expect(await storage.modelsFile.exists(), isTrue);
    expect((await providerFile('p1'))['models'], isNull);
  });

  test('没有 models.json（新装）直接落标记', () async {
    await writeProvider('p1', 'One');

    await storage.load();

    expect(await storage.modelRepository.getAllModels(), isEmpty);
    expect(
      await File(p.join(storage.providersDir.path, '.models-version')).exists(),
      isTrue,
    );
  });
}
