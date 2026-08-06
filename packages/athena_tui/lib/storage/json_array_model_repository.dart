import 'dart:io';

import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_tui/storage/id_allocator.dart';
import 'package:athena_tui/storage/json_array_store.dart';

/// ModelRepository 的 JSON 数组实现(`~/.athena/tui/models.json`)。
///
/// 模型列表是整读整写的列表数据,JSON 数组文件比 JSONL 更合适
/// (与 GUI 的 models.json 对齐)。
class JsonArrayModelRepository implements ModelRepository {
  JsonArrayModelRepository({
    required File file,
    required IdAllocator idAllocator,
  }) : _store = JsonArrayStore(file: file, idAllocator: idAllocator);

  final JsonArrayStore _store;

  @override
  Future<List<ModelEntity>> getAllModels() async {
    final rows = await _store.readAll();
    return rows.map(ModelEntity.fromJson).toList();
  }

  @override
  Future<ModelEntity?> getModelById(int id) async {
    final rows = await _store.readAll();
    for (final row in rows) {
      if (row['id'] == id) return ModelEntity.fromJson(row);
    }
    return null;
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
