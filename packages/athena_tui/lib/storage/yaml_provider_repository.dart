import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_tui/storage/serial_lock.dart';
import 'package:athena_tui/storage/user_settings_store.dart';

/// ProviderRepository 的 YAML 实现(`~/.athena/setting.yaml`)。
///
/// 设计:yaml **不自动生成 providers 列表**——只有用户配置了某个
/// provider 的 api key(或清空 key 后移除)时才修改 yaml。
///
/// - **内存 `_all` 是运行时权威**:启动时由 [load](读 yaml 用户配置)+
///   PresetSeed / ModelCatalogService(模板 provider)填充
/// - **yaml 只存用户配置的子集**:apiKey 非空的 provider;
///   种子/同步创建的 provider(空 key)不落 yaml
/// - 所有操作经 [serialLock] 串行化(防并发写覆盖)
///
/// id 分配:复用已有 provider 的 id,新 provider 取 max(id)+1——
/// 与 models.jsonl 的 providerId 引用保持一致。
class YamlProviderRepository implements ProviderRepository {
  YamlProviderRepository({required UserSettingsStore store}) : _store = store;

  final UserSettingsStore _store;
  Future<void>? _lock;

  /// 运行时权威的完整 provider 列表(内存)。
  final List<ProviderEntity> _all = [];

  /// 启动时加载:读取 yaml 中用户配置的 provider(配过 key 的)。
  Future<void> load() {
    return _serialized(() async {
      _all
        ..clear()
        ..addAll(await _store.loadProviders());
    });
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    return serialLock(_lock, action, (f) => _lock = f);
  }

  /// 把"配了 key 的 provider"同步到 yaml(整段覆写 yaml 的用户配置段)。
  ///
  /// 不加锁:所有调用方(updateProvider/deleteProvider/importProviders/
  /// deleteAllProviders)已持有 [serialLock],嵌套加锁会死锁。
  Future<void> _syncYaml() {
    return _store.saveProviders(
      [for (final p in _all) if (p.apiKey.isNotEmpty) p],
    );
  }

  @override
  Future<List<ProviderEntity>> getAllProviders() async {
    return List.of(_all);
  }

  @override
  Future<ProviderEntity?> getProviderById(int id) async {
    for (final provider in _all) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  @override
  Future<List<ProviderEntity>> getEnabledProviders() async {
    return [for (final p in _all) if (p.enabled) p];
  }

  @override
  Future<int> storeProvider(ProviderEntity provider) {
    return _serialized(() async {
      if (provider.id != null) {
        // 已带 id(如 importProviders 保留原始 id):更新或追加
        final index = _all.indexWhere((p) => p.id == provider.id);
        if (index >= 0) {
          _all[index] = provider;
        } else {
          _all.add(provider);
        }
        return provider.id!;
      }
      // 分配新 id:max(id)+1,保证与 models.jsonl 引用一致且跨重启稳定
      var maxId = 0;
      for (final p in _all) {
        if ((p.id ?? 0) > maxId) maxId = p.id!;
      }
      final newId = maxId + 1;
      _all.add(provider.copyWith(id: newId));
      return newId;
    });
  }

  @override
  Future<void> updateProvider(ProviderEntity provider) {
    return _serialized(() async {
      final id = provider.id;
      final index = id == null ? -1 : _all.indexWhere((p) => p.id == id);
      if (index < 0) return;
      _all[index] = provider;
      // 只有配置了 key 的 provider 才写 yaml;清空 key 则从 yaml 移除
      await _syncYaml();
    });
  }

  @override
  Future<void> deleteProvider(int id) {
    return _serialized(() async {
      _all.removeWhere((p) => p.id == id);
      await _syncYaml();
    });
  }

  @override
  Future<int> getProvidersCount() async => _all.length;

  @override
  Future<void> batchStoreProviders(List<ProviderEntity> providers) {
    return _serialized(() async {
      for (final provider in providers) {
        final index = provider.id == null
            ? -1
            : _all.indexWhere((p) => p.id == provider.id);
        if (index >= 0) {
          _all[index] = provider;
        } else {
          _all.add(provider);
        }
      }
    });
  }

  @override
  Future<ProviderEntity?> getProviderByName(String name) async {
    for (final provider in _all) {
      if (provider.name == name) return provider;
    }
    return null;
  }

  @override
  Future<ProviderEntity?> getPresetProviderByName(String name) async {
    for (final provider in _all) {
      if (provider.name == name && provider.isPreset) return provider;
    }
    return null;
  }

  @override
  Future<void> deleteAllProviders() {
    return _serialized(() async {
      _all.clear();
      await _store.saveProviders(const []);
    });
  }

  @override
  Future<void> importProviders(List<ProviderEntity> providers) {
    return _serialized(() async {
      _all
        ..clear()
        ..addAll(providers);
      // 只把配了 key 的写 yaml(迁移场景:用户历史 key 进 yaml,
      // 空 key 的模板 provider 不落盘)
      await _syncYaml();
    });
  }
}
