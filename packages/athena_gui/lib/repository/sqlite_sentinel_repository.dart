import 'package:athena_gui/database/database.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/sentinel_repository.dart';

/// [SentinelRepository] 的 SQLite 实现（GUI 侧）。
class SqliteSentinelRepository implements SentinelRepository {
  @override
  Future<List<SentinelEntity>> getAllSentinels() async {
    var laconic = Database.instance.laconic;
    var results = await laconic.table('sentinels').get();
    return results.map((r) => SentinelEntity.fromJson(r.toMap())).toList();
  }

  @override
  Future<SentinelEntity?> getSentinelById(int id) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('sentinels').where('id', id).first();
      return SentinelEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<int> createSentinel(SentinelEntity sentinel) async {
    var laconic = Database.instance.laconic;
    var json = sentinel.toJson();
    json.remove('id');
    return await laconic.table('sentinels').insertGetId(json);
  }

  @override
  Future<void> updateSentinel(SentinelEntity sentinel) async {
    if (sentinel.id == null) return;
    var laconic = Database.instance.laconic;
    var json = sentinel.toJson();
    json.remove('id');
    await laconic.table('sentinels').where('id', sentinel.id).update(json);
  }

  @override
  Future<void> deleteSentinel(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('sentinels').where('id', id).delete();
  }

  @override
  Future<int> getSentinelsCount() async {
    var laconic = Database.instance.laconic;
    return await laconic.table('sentinels').count();
  }

  @override
  Future<void> batchCreateSentinels(List<SentinelEntity> sentinels) async {
    if (sentinels.isEmpty) return;
    var laconic = Database.instance.laconic;
    var jsonList = sentinels.map((s) {
      var json = s.toJson();
      json.remove('id');
      return json;
    }).toList();
    await laconic.table('sentinels').insert(jsonList);
  }

  @override
  Future<SentinelEntity?> getSentinelByName(String name) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('sentinels').where('name', name).first();
      return SentinelEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> importSentinels(List<SentinelEntity> sentinels) async {
    if (sentinels.isEmpty) return;

    var toInsert = <SentinelEntity>[];

    for (var sentinel in sentinels) {
      var existing = await getSentinelByName(sentinel.name);
      if (existing != null) {
        // 同名存在，更新
        var updated = sentinel.copyWith(id: existing.id);
        await updateSentinel(updated);
      } else {
        // 不存在，加入批量插入列表
        toInsert.add(sentinel);
      }
    }

    // 批量插入新的
    if (toInsert.isNotEmpty) {
      await batchCreateSentinels(toInsert);
    }
  }
}
