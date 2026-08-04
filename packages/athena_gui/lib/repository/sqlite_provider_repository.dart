import 'package:athena_gui/database/database.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/provider_repository.dart';

/// [ProviderRepository] 的 SQLite 实现（GUI 侧）。
class SqliteProviderRepository implements ProviderRepository {
  @override
  Future<List<ProviderEntity>> getAllProviders() async {
    var laconic = Database.instance.laconic;
    var results = await laconic.table('providers').orderBy('name').get();
    return results
        .map((result) => ProviderEntity.fromJson(result.toMap()))
        .toList();
  }

  @override
  Future<ProviderEntity?> getProviderById(int id) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('providers').where('id', id).first();
      return ProviderEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<ProviderEntity>> getEnabledProviders() async {
    var laconic = Database.instance.laconic;
    var results = await laconic.table('providers').where('enabled', 1).orderBy('name').get();
    return results.map((r) => ProviderEntity.fromJson(r.toMap())).toList();
  }

  @override
  Future<int> storeProvider(ProviderEntity provider) async {
    var laconic = Database.instance.laconic;
    var json = provider.toJson();
    json.remove('id');
    return await laconic.table('providers').insertGetId(json);
  }

  @override
  Future<void> updateProvider(ProviderEntity provider) async {
    if (provider.id == null) return;
    var laconic = Database.instance.laconic;
    var json = provider.toJson();
    json.remove('id');
    await laconic.table('providers').where('id', provider.id).update(json);
  }

  @override
  Future<void> deleteProvider(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('providers').where('id', id).delete();
  }

  @override
  Future<int> getProvidersCount() async {
    var laconic = Database.instance.laconic;
    return await laconic.table('providers').count();
  }

  @override
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

  @override
  Future<ProviderEntity?> getProviderByName(String name) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('providers').where('name', name).first();
      return ProviderEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<ProviderEntity?> getPresetProviderByName(String name) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic
          .table('providers')
          .where('name', name)
          .where('is_preset', 1)
          .first();
      return ProviderEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> deleteAllProviders() async {
    var laconic = Database.instance.laconic;
    await laconic.table('providers').delete();
  }

  @override
  Future<void> importProviders(List<ProviderEntity> providers) async {
    if (providers.isEmpty) return;
    var laconic = Database.instance.laconic;
    var jsonList = providers.map((p) => p.toJson()).toList();
    await laconic.table('providers').insert(jsonList);
  }
}
