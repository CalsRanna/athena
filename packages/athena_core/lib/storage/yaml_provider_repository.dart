import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/storage/id_generator.dart';
import 'package:athena_core/storage/provider_store.dart';

/// ProviderRepository 的文件实现:一个 provider 一个 YAML 文件
/// (`~/.athena/providers/{id}.yaml`,布局与读写语义见 `ProviderStore`)。
///
/// - **文件是唯一真相**:每次读都重新列举目录(GUI 与 TUI 共享此目录且可能
///   同时运行,内存副本会把对方刚写入的 provider 覆盖掉)
/// - **全部 provider 都落盘**(含尚未配 key 的模板 provider):GUI 的设置页
///   需要在重启后仍列出它们供用户填 key;目录同步在 TTL 内会跳过,不能依赖
///   同步重建
/// - 修改在「进程内串行 + 跨进程文件锁」内完成读-改-写,且锁只覆盖被改的
///   那一个 provider
///
/// 列表顺序由**名字**决定(见 [_byName]):一个文件一个 provider 之后,列举
/// 顺序来自目录、不稳定,必须有确定的排序键。按名字排还有一个好处:用户新增
/// provider 时不必考虑它排在哪儿,叫什么都决定了位置。
class YamlProviderRepository implements ProviderRepository {
  YamlProviderRepository({
    required ProviderStore store,
    IdGenerator idGenerator = const IdGenerator(),
  }) : _store = store,
       _idGenerator = idGenerator;

  final ProviderStore _store;
  final IdGenerator _idGenerator;

  /// 兼容旧调用:不再有内存副本,无需预加载。保留以便装配层统一调用。
  Future<void> load() async {}

  /// 用户可见列表按名字排,大小写不敏感(避免 `deepseek` 与 `Deep Seek`
  /// 被拆到列表两端);同名时按 id 兜底,保证顺序稳定且与文件系统无关。
  static int _byName(ProviderEntity a, ProviderEntity b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (byName != 0) return byName;
    return (a.id ?? '').compareTo(b.id ?? '');
  }

  Future<List<ProviderEntity>> _sorted() async {
    final all = await _store.list();
    all.sort(_byName);
    return all;
  }

  @override
  Future<List<ProviderEntity>> getAllProviders() => _sorted();

  @override
  Future<ProviderEntity?> getProviderById(String id) => _store.read(id);

  @override
  Future<List<ProviderEntity>> getEnabledProviders() async {
    return [
      for (final p in await _sorted())
        if (p.enabled) p,
    ];
  }

  @override
  Future<String> storeProvider(ProviderEntity provider) async {
    final id = provider.id ?? _idGenerator.next();
    // 已带 id(更新、批量写入)时覆盖同名文件;否则写入刚生成的新 id。
    await _store.write(provider.copyWith(id: id));
    return id;
  }

  @override
  Future<void> updateProvider(ProviderEntity provider) async {
    final id = provider.id;
    if (id == null) return;
    await _store.write(provider);
  }

  @override
  Future<void> syncApiFormat({
    required String id,
    required String baseUrl,
    required ApiFormat apiFormat,
  }) {
    // 同步只改格式元数据。守卫条件全部在锁内、基于锁内读到的最新实体判定:
    // 审批与同步可能与 GUI/TUI 的编辑并发,不能把编辑开始时的旧快照(旧的
    // API key、启用状态、手动选择)写回去。
    return _store.mutate(id, (ProviderEntity provider) {
      final trailingSlashes = RegExp(r'/+$');
      if (!provider.isPreset ||
          !provider.apiFormatAuto ||
          provider.baseUrl.replaceFirst(trailingSlashes, '') !=
              baseUrl.replaceFirst(trailingSlashes, '') ||
          provider.apiFormat == apiFormat) {
        return null;
      }
      return provider.copyWith(apiFormat: apiFormat, apiFormatAuto: true);
    });
  }

  @override
  Future<void> deleteProvider(String id) => _store.delete(id);

  @override
  Future<int> getProvidersCount() async => (await _sorted()).length;

  @override
  Future<void> batchStoreProviders(List<ProviderEntity> providers) async {
    for (final provider in providers) {
      final id = provider.id ?? _idGenerator.next();
      await _store.write(provider.copyWith(id: id));
    }
  }

  @override
  Future<ProviderEntity?> getProviderByName(String name) async {
    for (final provider in await getAllProviders()) {
      if (provider.name == name) return provider;
    }
    return null;
  }

  @override
  Future<ProviderEntity?> getPresetProviderByName(String name) async {
    for (final provider in await getAllProviders()) {
      if (provider.name == name && provider.isPreset) return provider;
    }
    return null;
  }

  @override
  /// 清空全部 provider。**模型随 provider 文件消失**,不再单独清理。
  Future<void> deleteAllProviders() async {
    for (final id in await _store.providerIds()) {
      await _store.delete(id);
    }
  }
}
