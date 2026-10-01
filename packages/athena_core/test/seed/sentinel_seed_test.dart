import 'dart:io';

import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/seed/daedalus_preset_prompt.dart';
import 'package:athena_core/seed/sentinel_seed.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// 内置角色的种子规则：只补缺、不覆盖，且两者都开箱可用。
void main() {
  late Directory temp;
  late FileStorage storage;
  const seed = SentinelSeed();

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('athena_sentinel_seed_');
    storage = FileStorage(root: Directory(p.join(temp.path, '.athena')));
    await storage.load();
  });
  tearDown(() => temp.delete(recursive: true));

  test('全新安装创建全部内置角色，且都可见', () async {
    await seed.applyIfNeeded(sentinelRepo: storage.sentinelRepository);

    final all = await storage.sentinelRepository.getAllSentinels();
    expect(all.map((s) => s.name).toSet(), {
      SentinelEntity.athenaName,
      SentinelEntity.daedalusName,
    });
    // 开箱即用 = 每个内置角色都进得了选择器
    expect(all.every((s) => s.isListVisible), isTrue);
    expect(all.every((s) => s.isPreset), isTrue);
  });

  test('内置角色不可改名，但内容可改进', () async {
    await seed.applyIfNeeded(sentinelRepo: storage.sentinelRepository);

    final daedalus = (await storage.sentinelRepository.getSentinelByName(
      SentinelEntity.daedalusName,
    ))!;
    expect(daedalus.isNameLocked, isTrue);
    expect(daedalus.prompt, daedalusPresetPrompt);
  });

  test('已存在 Athena 的老用户会补上 Daedalus', () async {
    // 只有 Athena 的既有库（升级前的状态）
    await storage.sentinelRepository.createSentinel(
      const SentinelEntity(
        name: SentinelEntity.athenaName,
        description: 'old',
        prompt: 'old prompt',
        tags: 'old',
        isPreset: true,
      ),
    );

    await seed.applyIfNeeded(sentinelRepo: storage.sentinelRepository);

    final all = await storage.sentinelRepository.getAllSentinels();
    expect(all.map((s) => s.name).toSet(), {
      SentinelEntity.athenaName,
      SentinelEntity.daedalusName,
    });
    // 既有角色不被覆盖：用户可能已经改过它
    final athena = (await storage.sentinelRepository.getSentinelByName(
      SentinelEntity.athenaName,
    ))!;
    expect(athena.prompt, 'old prompt');
  });

  test('被删除的内置角色会在下次启动重建', () async {
    await seed.applyIfNeeded(sentinelRepo: storage.sentinelRepository);
    final daedalus = (await storage.sentinelRepository.getSentinelByName(
      SentinelEntity.daedalusName,
    ))!;
    await storage.sentinelRepository.deleteSentinel(daedalus.id!);

    await seed.applyIfNeeded(sentinelRepo: storage.sentinelRepository);

    // 判定依据是名字，删掉就等于「缺一个」。这是有意的：内置角色是开箱即用
    // 的基线，缺失时补齐比让它永久消失更符合预期。
    final rebuilt = await storage.sentinelRepository.getSentinelByName(
      SentinelEntity.daedalusName,
    );
    expect(rebuilt, isNotNull);
    expect(rebuilt!.prompt, daedalusPresetPrompt);
  });

  test('重复执行幂等，不会重复建角色', () async {
    await seed.applyIfNeeded(sentinelRepo: storage.sentinelRepository);
    await seed.applyIfNeeded(sentinelRepo: storage.sentinelRepository);

    final all = await storage.sentinelRepository.getAllSentinels();
    expect(all.length, SentinelSeed.builtins.length);
  });

  test('种子清单与可见性白名单保持一致', () async {
    await seed.applyIfNeeded(sentinelRepo: storage.sentinelRepository);
    final all = await storage.sentinelRepository.getAllSentinels();

    // 清单里的每个名字都应可见；反过来，可见的预设角色都应在清单里。
    // 两边漏登记一处，就会得到「建了但选不到」或「选得到但没提示词」。
    final seeded = SentinelSeed.builtins.map((b) => b.$1).toSet();
    expect(
      all.where((s) => s.isListVisible).map((s) => s.name).toSet(),
      seeded,
    );
    // 而清单里的提示词必须非空 —— 空提示词的预设等于一个空壳角色
    expect(SentinelSeed.builtins.every((b) => b.$3.trim().isNotEmpty), isTrue);
  });
}
