import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/sentinel_repository.dart';

/// 内存版 sentinel 仓库：记录 updateSentinel 调用，供断言回滚/进化落库。
///
/// 供 sentinel_revert_tool_test 与 sentinel_evolve_tool_test 共享
///（Dart 库私有成员 `_` 前缀无法跨库 import，故独立成文件）。
class InMemorySentinelRepository extends SentinelRepository {
  final List<SentinelEntity> sentinels = [];
  final List<SentinelEntity> updates = [];

  @override
  Future<List<SentinelEntity>> getAllSentinels() async => List.of(sentinels);
  @override
  Future<SentinelEntity?> getSentinelById(int id) async =>
      sentinels.where((s) => s.id == id).firstOrNull;
  @override
  Future<int> createSentinel(SentinelEntity sentinel) async {
    sentinels.add(sentinel);
    return sentinel.id ?? sentinels.length;
  }

  @override
  Future<void> updateSentinel(SentinelEntity sentinel) async {
    updates.add(sentinel);
    final i = sentinels.indexWhere((s) => s.id == sentinel.id);
    if (i >= 0) {
      sentinels[i] = sentinel;
    } else {
      sentinels.add(sentinel);
    }
  }

  @override
  Future<void> deleteSentinel(int id) async =>
      sentinels.removeWhere((s) => s.id == id);
  @override
  Future<int> getSentinelsCount() async => sentinels.length;
  @override
  Future<void> batchCreateSentinels(List<SentinelEntity> sentinels) async =>
      this.sentinels.addAll(sentinels);
  @override
  Future<SentinelEntity?> getSentinelByName(String name) async =>
      sentinels.where((s) => s.name == name).firstOrNull;
  @override
  Future<void> importSentinels(List<SentinelEntity> sentinels) async =>
      this.sentinels.addAll(sentinels);
}
