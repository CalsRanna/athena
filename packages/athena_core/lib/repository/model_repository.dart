import 'package:athena_core/entity/model_entity.dart';

/// 模型目录存储接口。文件实现见 `storage/provider_model_repository.dart`。
abstract class ModelRepository {
  Future<void> batchCreateModels(List<ModelEntity> models);

  Future<String> createModel(ModelEntity model);

  Future<void> deleteModel(String id);

  Future<void> deleteModelsByProviderId(String providerId);

  Future<List<ModelEntity>> getAllModels();

  Future<ModelEntity?> getModelById(String id);

  /// 按 API 模型 id 查找模型,供模型目录同步使用。
  Future<ModelEntity?> getModelByModelIdAndProviderId(
    String modelId,
    String providerId,
  );

  Future<ModelEntity?> getModelByNameAndProviderId(
    String name,
    String providerId,
  );

  Future<List<ModelEntity>> getModelsByProviderId(String providerId);

  Future<int> getModelsCount();

  Future<void> updateModel(ModelEntity model);
}
