import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/tool_set.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/storage/key_value_store.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:test/test.dart';

class _FakeKeyValueStore implements KeyValueStore {
  @override
  Future<String?> getString(String key) async => null;
  @override
  Future<void> setString(String key, String value) async {}
  @override
  Future<int?> getInt(String key) async => null;
  @override
  Future<void> setInt(String key, int value) async {}
  @override
  Future<void> remove(String key) async {}
  @override
  Future<Set<String>> getKeys() async => {};
}

class _FakeSentinelRepository extends SentinelRepository {
  @override
  Future<SentinelEntity?> getSentinelById(int id) async => null;
  @override
  Future<int> createSentinel(SentinelEntity sentinel) async => 0;
  @override
  Future<void> updateSentinel(SentinelEntity sentinel) async {}
  @override
  Future<void> deleteSentinel(int id) async {}
  @override
  Future<int> getSentinelsCount() async => 0;
  @override
  Future<void> batchCreateSentinels(List<SentinelEntity> sentinels) async {}
  @override
  Future<SentinelEntity?> getSentinelByName(String name) async => null;
  @override
  Future<void> importSentinels(List<SentinelEntity> sentinels) async {}
  @override
  Future<List<SentinelEntity>> getAllSentinels() async => [];
}

/// 工具清单是引擎的事实，两个前端（GUI / TUI）共用同一份装配。
/// 这里锁住「注册了哪些工具」，任何一端漏改都不再可能。
void main() {
  List<String> toolNames({bool? mobile, String? workdir}) {
    final registry = buildToolRegistry(
      skillRegistry: SkillRegistry(),
      experienceRepository: ExperienceRepository(),
      sentinelRepository: _FakeSentinelRepository(),
      store: _FakeKeyValueStore(),
      defaultWorkdir: workdir,
      mobile: mobile,
    );
    return registry.all.map((t) => t.name).toList();
  }

  test('桌面端注册 11 个工具，shell 按操作系统二选一', () {
    final names = toolNames(mobile: false);

    // bash 与 powershell 互斥：运行时只存在其中一个
    final shell = PlatformUtil.isWindows ? 'powershell' : 'bash';
    final absentShell = PlatformUtil.isWindows ? 'bash' : 'powershell';

    expect(names, hasLength(11));
    expect(names, containsAll(<String>[
      'file_read',
      'file_write',
      'file_update',
      shell,
      'web_fetch',
      'web_search',
      'skill',
      'skill_evolve',
      'experience_learn',
      'experience_recall',
      'sentinel_evolve',
    ]));
    expect(names, isNot(contains(absentShell)));
  });

  test('移动端只注册无本地文件/进程依赖的 3 个工具', () {
    final names = toolNames(mobile: true);

    expect(names, hasLength(3));
    expect(names, containsAll(<String>['web_fetch', 'web_search', 'skill']));
    // 文件与 shell 工具在移动端不可用
    for (final absent in const [
      'file_read',
      'file_write',
      'file_update',
      'bash',
      'powershell',
      'sentinel_evolve',
    ]) {
      expect(names, isNot(contains(absent)), reason: '$absent 不应出现在移动端');
    }
  });

  test('工具名唯一（注册表按名索引，重名会静默覆盖）', () {
    final names = toolNames(mobile: false);
    expect(names.toSet(), hasLength(names.length));
  });
}
