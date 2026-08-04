import 'dart:io';

import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_tui/storage/jsonl_store.dart';

/// ModelRepository 的 JSONL 实现(`~/.athena/tui/models.jsonl`)。
class JsonlModelRepository implements ModelRepository {
  JsonlModelRepository({required File file, required IdAllocator idAllocator})
    : _store = JsonlFileStore(file: file, idAllocator: idAllocator);

  final JsonlFileStore _store;

  @override
  Future<List<ModelEntity>> getAllModels() async {
    final rows = await _store.readAll();
    return rows.map(ModelEntity.fromJson).toList();
  }

  @override
  Future<ModelEntity?> getModelById(int id) async {
    final row = await _store.readById(id);
    return row == null ? null : ModelEntity.fromJson(row);
  }

  @override
  Future<List<ModelEntity>> getModelsByProviderId(int providerId) async {
    final models = await getAllModels();
    return models.where((m) => m.providerId == providerId).toList();
  }

  @override
  Future<int> createModel(ModelEntity model) => _store.insert(model.toJson());

  @override
  Future<void> updateModel(ModelEntity model) async {
    final id = model.id;
    if (id == null) return;
    await _store.replaceById(id, model.toJson());
  }

  @override
  Future<void> deleteModel(int id) => _store.deleteById(id);

  @override
  Future<void> deleteModelsByProviderId(int providerId) {
    return _store.deleteWhere((row) => row['provider_id'] == providerId);
  }

  @override
  Future<int> getModelsCount() => _store.count();

  @override
  Future<void> batchCreateModels(List<ModelEntity> models) async {
    for (final model in models) {
      await _store.insert(model.toJson());
    }
  }

  @override
  Future<ModelEntity?> getModelByNameAndProviderId(
    String name,
    int providerId,
  ) async {
    final models = await getAllModels();
    for (final m in models) {
      if (m.name == name && m.providerId == providerId) return m;
    }
    return null;
  }

  @override
  Future<ModelEntity?> getModelByModelIdAndProviderId(
    String modelId,
    int providerId,
  ) async {
    final models = await getAllModels();
    for (final m in models) {
      if (m.modelId == modelId && m.providerId == providerId) return m;
    }
    return null;
  }

  @override
  Future<void> deleteAllModels() => _store.deleteFile();

  @override
  Future<void> importModels(List<ModelEntity> models) async {
    await _store.deleteFile();
    for (final model in models) {
      await _store.insert(model.toJson());
    }
  }
}
