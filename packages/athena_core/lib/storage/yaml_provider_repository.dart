import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/serial_lock.dart';
import 'package:athena_core/storage/user_settings_store.dart';

/// ProviderRepository 的 YAML 实现(`~/.athena/setting.yaml`)。
///
/// - **yaml 是唯一真相**:每次读都重新解析文件(几 KB,可忽略),不在
///   内存里另存一份权威副本——GUI 与 TUI 共享此文件且可能同时运行,
///   内存副本会把对方刚写入的 provider 覆盖掉
/// - **yaml 持久化全部 provider**(含尚未配 key 的模板 provider):
///   GUI 的 provider 设置页需要在重启后仍列出它们供用户填 key;
///   目录同步在 TTL 内会跳过,不能依赖同步重建
/// - 修改在"进程内串行 + 跨进程文件锁"内完成读-改-写
///
/// id 分配:新 provider 取 max(id)+1——与 models.json 的 providerId
/// 引用保持一致。
class YamlProviderRepository implements ProviderRepository {
  YamlProviderRepository({required UserSettingsStore store}) : _store = store;

  final UserSettingsStore _store;
  Future<void>? _lock;

  /// 兼容旧调用:不再有内存副本,无需预加载。保留以便装配层统一调用。
  Future<void> load() async {}

  Future<T> _mutate<T>(
    Future<T> Function(List<ProviderEntity> all) action,
  ) {
    return serialLock(
      _lock,
      () => withFileLock(lockFileFor(_store.file), () async {
        final all = await _store.loadProviders();
        final result = await action(all);
        await _store.saveProviders(all);
        return result;
      }),
      (f) => _lock = f,
    );
  }

  @override
  Future<List<ProviderEntity>> getAllProviders() => _store.loadProviders();

  @override
  Future<ProviderEntity?> getProviderById(int id) async {
    for (final provider in await getAllProviders()) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  @override
  Future<List<ProviderEntity>> getEnabledProviders() async {
    return [for (final p in await getAllProviders()) if (p.enabled) p];
  }

  @override
  Future<int> storeProvider(ProviderEntity provider) {
    return _mutate((all) async {
      if (provider.id != null) {
        // 已带 id(如导入保留原始 id):更新或追加
        final index = all.indexWhere((p) => p.id == provider.id);
        if (index >= 0) {
          all[index] = provider;
        } else {
          all.add(provider);
        }
        return provider.id!;
      }
      var maxId = 0;
      for (final p in all) {
        if ((p.id ?? 0) > maxId) maxId = p.id!;
      }
      final newId = maxId + 1;
      all.add(provider.copyWith(id: newId));
      return newId;
    });
  }

  @override
  Future<void> updateProvider(ProviderEntity provider) {
    return _mutate((all) async {
      final id = provider.id;
      final index = id == null ? -1 : all.indexWhere((p) => p.id == id);
      if (index >= 0) all[index] = provider;
    });
  }

  @override
  Future<void> deleteProvider(int id) {
    return _mutate((all) async {
      all.removeWhere((p) => p.id == id);
    });
  }

  @override
  Future<int> getProvidersCount() async => (await getAllProviders()).length;

  @override
  Future<void> batchStoreProviders(List<ProviderEntity> providers) {
    return _mutate((all) async {
      for (final provider in providers) {
        final index = provider.id == null
            ? -1
            : all.indexWhere((p) => p.id == provider.id);
        if (index >= 0) {
          all[index] = provider;
        } else {
          all.add(provider);
        }
      }
    });
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
  Future<void> deleteAllProviders() {
    return _mutate((all) async => all.clear());
  }

  @override
  Future<void> importProviders(List<ProviderEntity> providers) {
    return _mutate((all) async {
      all
        ..clear()
        ..addAll(providers);
    });
  }
}
