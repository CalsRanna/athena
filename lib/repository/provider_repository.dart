import 'package:athena/database/database.dart';
import 'package:athena/entity/provider_entity.dart';

class ProviderRepository {
  Future<List<ProviderEntity>> getAllProviders() async {
    var laconic = Database.instance.laconic;
    var results = await laconic.table('providers').get();
    return results
        .map((result) => ProviderEntity.fromJson(result.toMap()))
        .toList();
  }

  Future<ProviderEntity?> getProviderById(int id) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('providers').where('id', id).first();
      return ProviderEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  Future<List<ProviderEntity>> getEnabledProviders() async {
    var laconic = Database.instance.laconic;
    var results = await laconic.table('providers').where('enabled', 1).get();
    return results.map((r) => ProviderEntity.fromJson(r.toMap())).toList();
  }

  Future<int> storeProvider(ProviderEntity provider) async {
    var laconic = Database.instance.laconic;
    var json = provider.toJson();
    json.remove('id');
    await laconic.table('providers').insert([json]);

    var result = await laconic.select('SELECT last_insert_rowid() as id');
    return result.first['id'] as int;
  }

  Future<void> updateProvider(ProviderEntity provider) async {
    if (provider.id == null) return;
    var laconic = Database.instance.laconic;
    var json = provider.toJson();
    json.remove('id');
    await laconic.table('providers').where('id', provider.id).update(json);
  }

  Future<void> deleteProvider(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('providers').where('id', id).delete();
  }

  Future<int> getProvidersCount() async {
    var laconic = Database.instance.laconic;
    return await laconic.table('providers').count();
  }

  Future<void> batchStoreProviders(List<ProviderEntity> providers) async {
    if (providers.isEmpty) return;
    var laconic = Database.instance.laconic;
    var jsonList = providers.map((p) {
      var json = p.toJson();
      json.remove('id');
      return json;
    }).toList();
    await laconic.table('providers').insert(jsonList);
  }

  Future<ProviderEntity?> getProviderByName(String name) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('providers').where('name', name).first();
      return ProviderEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteAllProviders() async {
    var laconic = Database.instance.laconic;
    await laconic.table('providers').delete();
  }

  /// 导入 providers：清空后插入，保留原始 ID
  Future<void> importProviders(List<ProviderEntity> providers) async {
    if (providers.isEmpty) return;
    var laconic = Database.instance.laconic;
    var jsonList = providers.map((p) => p.toJson()).toList();
    await laconic.table('providers').insert(jsonList);
  }
}
