import 'package:athena_core/entity/sentinel_entity.dart';

/// Sentinel（角色）存储接口。持久化策略由实现方决定。
abstract class SentinelRepository {
  Future<void> batchCreateSentinels(List<SentinelEntity> sentinels);

  Future<String> createSentinel(SentinelEntity sentinel);

  Future<void> deleteSentinel(String id);

  Future<List<SentinelEntity>> getAllSentinels();

  Future<SentinelEntity?> getSentinelById(String id);

  Future<SentinelEntity?> getSentinelByName(String name);

  Future<int> getSentinelsCount();

  Future<void> updateSentinel(SentinelEntity sentinel);
}
