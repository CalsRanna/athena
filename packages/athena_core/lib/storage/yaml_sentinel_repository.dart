import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/storage/id_generator.dart';
import 'package:athena_core/storage/sentinel_store.dart';

/// SentinelRepository 的文件实现:一个角色一个 YAML 文件
/// (`~/.athena/sentinels/{id}.yaml`,读写语义见 [SentinelStore])。
///
/// 列表顺序按**名字**排:一个文件一个角色之后,目录列举顺序不稳定,必须有确定
/// 的排序键。这与 provider 一致;与旧的「JSON 数组插入顺序」不同,但角色列表
/// 本来就按名字认人(种子只建一个 Athena)。
class YamlSentinelRepository implements SentinelRepository {
  YamlSentinelRepository({
    required SentinelStore store,
    IdGenerator idGenerator = const IdGenerator(),
  }) : _store = store,
       _idGenerator = idGenerator;

  final SentinelStore _store;
  final IdGenerator _idGenerator;

  static int _byName(SentinelEntity a, SentinelEntity b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (byName != 0) return byName;
    return (a.id ?? '').compareTo(b.id ?? '');
  }

  Future<List<SentinelEntity>> _sorted() async {
    final all = await _store.list();
    all.sort(_byName);
    return all;
  }

  @override
  Future<List<SentinelEntity>> getAllSentinels() => _sorted();

  @override
  Future<SentinelEntity?> getSentinelById(String id) => _store.read(id);

  @override
  Future<SentinelEntity?> getSentinelByName(String name) async {
    for (final sentinel in await _sorted()) {
      if (sentinel.name == name) return sentinel;
    }
    return null;
  }

  @override
  Future<String> createSentinel(SentinelEntity sentinel) async {
    final id = sentinel.id ?? _idGenerator.next();
    await _store.write(sentinel.copyWith(id: id));
    return id;
  }

  @override
  Future<void> updateSentinel(SentinelEntity sentinel) async {
    final id = sentinel.id;
    if (id == null) return;
    await _store.write(sentinel);
  }

  @override
  Future<void> deleteSentinel(String id) => _store.delete(id);

  @override
  Future<int> getSentinelsCount() => _store.count();

  @override
  Future<void> batchCreateSentinels(List<SentinelEntity> sentinels) async {
    for (final sentinel in sentinels) {
      final id = sentinel.id ?? _idGenerator.next();
      await _store.write(sentinel.copyWith(id: id));
    }
  }

  @override
  Future<void> importSentinels(List<SentinelEntity> sentinels) async {
    // 旧语义:同名更新、不同名插入(导出文件里的 chat.sentinelId 引用原 id,
    // 所以带 id 的复用原 id 而不是重新分配)
    for (final sentinel in sentinels) {
      final existing = await getSentinelByName(sentinel.name);
      if (existing != null) {
        await _store.write(sentinel.copyWith(id: existing.id));
      } else if (sentinel.id != null) {
        await _store.write(sentinel);
      } else {
        await _store.write(sentinel.copyWith(id: _idGenerator.next()));
      }
    }
  }
}
