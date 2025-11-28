import 'package:athena/database/database.dart';
import 'package:athena/entity/sentinel_entity.dart';

class SentinelRepository {
  Future<List<SentinelEntity>> getAllSentinels() async {
    var laconic = Database.instance.laconic;
    var results = await laconic.table('sentinels').get();
    return results.map((r) => SentinelEntity.fromJson(r.toMap())).toList();
  }

  Future<SentinelEntity?> getSentinelById(int id) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('sentinels').where('id', id).first();
      return SentinelEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  Future<int> createSentinel(SentinelEntity sentinel) async {
    var laconic = Database.instance.laconic;
    var json = sentinel.toJson();
    json.remove('id');
    await laconic.table('sentinels').insert([json]);

    var result = await laconic.select('SELECT last_insert_rowid() as id');
    return result.first['id'] as int;
  }

  Future<void> updateSentinel(SentinelEntity sentinel) async {
    if (sentinel.id == null) return;
    var laconic = Database.instance.laconic;
    var json = sentinel.toJson();
    json.remove('id');
    await laconic.table('sentinels').where('id', sentinel.id).update(json);
  }

  Future<void> deleteSentinel(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('sentinels').where('id', id).delete();
  }

  Future<int> getSentinelsCount() async {
    var laconic = Database.instance.laconic;
    return await laconic.table('sentinels').count();
  }

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
}
