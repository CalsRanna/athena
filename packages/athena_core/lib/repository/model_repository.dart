import 'package:athena_core/entity/model_entity.dart';

/// 模型目录存储接口。持久化策略由实现方决定（GUI=SQLite，TUI=JSONL 等）。
abstract class ModelRepository {
  Future<List<ModelEntity>> getAllModels();

  Future<ModelEntity?> getModelById(int id);

  Future<List<ModelEntity>> getModelsByProviderId(int providerId);

  Future<int> createModel(ModelEntity model);

  Future<void> updateModel(ModelEntity model);

  Future<void> deleteModel(int id);

  Future<void> deleteModelsByProviderId(int providerId);

  Future<int> getModelsCount();

  Future<void> batchCreateModels(List<ModelEntity> models);

  Future<ModelEntity?> getModelByNameAndProviderId(
    String name,
    int providerId,
  );

  /// 按 API 模型 id 查找模型,供模型目录同步使用。
  Future<ModelEntity?> getModelByModelIdAndProviderId(
    String modelId,
    int providerId,
  );

  Future<void> deleteAllModels();

  /// 导入 models：清空后插入，保留原始 ID
  Future<void> importModels(List<ModelEntity> models);
}
