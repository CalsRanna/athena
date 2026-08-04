import 'package:athena_gui/database/database.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/repository/model_repository.dart';

/// [ModelRepository] 的 SQLite 实现（GUI 侧）。
class SqliteModelRepository implements ModelRepository {
  @override
  Future<List<ModelEntity>> getAllModels() async {
    var laconic = Database.instance.laconic;
    var results = await laconic.table('models').orderBy('name').get();
    return results.map((r) => ModelEntity.fromJson(r.toMap())).toList();
  }

  @override
  Future<ModelEntity?> getModelById(int id) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('models').where('id', id).first();
      return ModelEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<ModelEntity>> getModelsByProviderId(int providerId) async {
    var laconic = Database.instance.laconic;
    var results = await laconic
        .table('models')
        .where('provider_id', providerId)
        .orderBy('name')
        .get();
    return results.map((r) => ModelEntity.fromJson(r.toMap())).toList();
  }

  @override
  Future<int> createModel(ModelEntity model) async {
    var laconic = Database.instance.laconic;
    var json = model.toJson();
    json.remove('id');
    return await laconic.table('models').insertGetId(json);
  }

  @override
  Future<void> updateModel(ModelEntity model) async {
    if (model.id == null) return;
    var laconic = Database.instance.laconic;
    var json = model.toJson();
    json.remove('id');
    await laconic.table('models').where('id', model.id).update(json);
  }

  @override
  Future<void> deleteModel(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('models').where('id', id).delete();
  }

  @override
  Future<void> deleteModelsByProviderId(int providerId) async {
    var laconic = Database.instance.laconic;
    await laconic.table('models').where('provider_id', providerId).delete();
  }

  @override
  Future<int> getModelsCount() async {
    var laconic = Database.instance.laconic;
    return await laconic.table('models').count();
  }

  @override
  Future<void> batchCreateModels(List<ModelEntity> models) async {
    if (models.isEmpty) return;
    var laconic = Database.instance.laconic;
    var jsonList = models.map((m) {
      var json = m.toJson();
      json.remove('id');
      return json;
    }).toList();
    await laconic.table('models').insert(jsonList);
  }

  @override
  Future<ModelEntity?> getModelByNameAndProviderId(
    String name,
    int providerId,
  ) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic
          .table('models')
          .where('name', name)
          .where('provider_id', providerId)
          .first();
      return ModelEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<ModelEntity?> getModelByModelIdAndProviderId(
    String modelId,
    int providerId,
  ) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic
          .table('models')
          .where('model_id', modelId)
          .where('provider_id', providerId)
          .first();
      return ModelEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> deleteAllModels() async {
    var laconic = Database.instance.laconic;
    await laconic.table('models').delete();
  }

  @override
  Future<void> importModels(List<ModelEntity> models) async {
    if (models.isEmpty) return;
    var laconic = Database.instance.laconic;
    var jsonList = models.map((m) => m.toJson()).toList();
    await laconic.table('models').insert(jsonList);
  }
}
