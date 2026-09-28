import 'package:athena_core/entity/sentinel_entity.dart';

/// Sentinel（角色）存储接口。持久化策略由实现方决定。
abstract class SentinelRepository {
  Future<List<SentinelEntity>> getAllSentinels();

  Future<SentinelEntity?> getSentinelById(String id);

  Future<String> createSentinel(SentinelEntity sentinel);

  Future<void> updateSentinel(SentinelEntity sentinel);

  Future<void> deleteSentinel(String id);

  Future<int> getSentinelsCount();

  Future<void> batchCreateSentinels(List<SentinelEntity> sentinels);

  Future<SentinelEntity?> getSentinelByName(String name);

  /// 导入 sentinels：同名更新，不同名插入
  Future<void> importSentinels(List<SentinelEntity> sentinels);
}
