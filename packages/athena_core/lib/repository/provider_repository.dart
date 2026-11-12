import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';

/// Provider（模型服务商）存储接口。持久化策略由实现方决定。
abstract class ProviderRepository {
  Future<void> batchStoreProviders(List<ProviderEntity> providers);

  Future<void> deleteAllProviders();

  Future<void> deleteProvider(String id);

  Future<List<ProviderEntity>> getAllProviders();

  Future<List<ProviderEntity>> getEnabledProviders();

  /// 按名字查找预设 provider(is_preset = 1),供模型目录同步使用。
  Future<ProviderEntity?> getPresetProviderByName(String name);

  Future<ProviderEntity?> getProviderById(String id);

  Future<ProviderEntity?> getProviderByName(String name);

  Future<int> getProvidersCount();

  Future<String> storeProvider(ProviderEntity provider);

  /// 在同一次读改写中核对预设端点与自动模式，仅同步格式元数据。
  Future<void> syncApiFormat({
    required String id,
    required String baseUrl,
    required ApiFormat apiFormat,
  });

  Future<void> updateProvider(ProviderEntity provider);
}
