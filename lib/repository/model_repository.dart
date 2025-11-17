import 'package:athena/database/database.dart';
import 'package:athena/entity/model_entity.dart';

class ModelRepository {
  Future<List<ModelEntity>> getAllModels() async {
    var laconic = Database.instance.laconic;
    var results = await laconic.table('models').get();
    return results.map((r) => ModelEntity.fromJson(r.toMap())).toList();
  }

  Future<ModelEntity?> getModelById(int id) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('models').where('id', id).first();
      return ModelEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  Future<List<ModelEntity>> getModelsByProviderId(int providerId) async {
    var laconic = Database.instance.laconic;
    var results = await laconic
        .table('models')
        .where('provider_id', providerId)
        .get();
    return results.map((r) => ModelEntity.fromJson(r.toMap())).toList();
  }

  Future<int> createModel(ModelEntity model) async {
    var laconic = Database.instance.laconic;
    var json = model.toJson();
    json.remove('id');
    await laconic.table('models').insert([json]);

    var result = await laconic.select('SELECT last_insert_rowid() as id');
    return result.first['id'] as int;
  }

  Future<void> updateModel(ModelEntity model) async {
    if (model.id == null) return;
    var laconic = Database.instance.laconic;
    var json = model.toJson();
    json.remove('id');
    await laconic.table('models').where('id', model.id).update(json);
  }

  Future<void> deleteModel(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('models').where('id', id).delete();
  }

  Future<void> deleteModelsByProviderId(int providerId) async {
    var laconic = Database.instance.laconic;
    await laconic.table('models').where('provider_id', providerId).delete();
  }

  Future<int> getModelsCount() async {
    var laconic = Database.instance.laconic;
    return await laconic.table('models').count();
  }
}
