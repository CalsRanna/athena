import 'package:athena_core/entity/provider_entity.dart';

/// Provider（模型服务商）存储接口。持久化策略由实现方决定。
abstract class ProviderRepository {
  Future<List<ProviderEntity>> getAllProviders();

  Future<ProviderEntity?> getProviderById(int id);

  Future<List<ProviderEntity>> getEnabledProviders();

  Future<int> storeProvider(ProviderEntity provider);

  Future<void> updateProvider(ProviderEntity provider);

  Future<void> deleteProvider(int id);

  Future<int> getProvidersCount();

  Future<void> batchStoreProviders(List<ProviderEntity> providers);

  Future<ProviderEntity?> getProviderByName(String name);

  /// 按名字查找预设 provider(is_preset = 1),供模型目录同步使用。
  Future<ProviderEntity?> getPresetProviderByName(String name);

  Future<void> deleteAllProviders();

  /// 导入 providers：清空后插入，保留原始 ID
  Future<void> importProviders(List<ProviderEntity> providers);
}
