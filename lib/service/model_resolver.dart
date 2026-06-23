import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';

/// 统一的模型 / Provider 解析器。
///
/// 提供"优先用指定模型 → 回退到第一个可用 Provider 的第一个模型"的
/// 标准 fallback 逻辑，供 Summary / Translation / TRPG 等 ViewModel 使用。
class ModelResolver {
  final ModelRepository _modelRepo;
  final ProviderRepository _providerRepo;

  ModelResolver({
    required ModelRepository modelRepo,
    required ProviderRepository providerRepo,
  })  : _modelRepo = modelRepo,
        _providerRepo = providerRepo;

  /// 解析模型和 Provider。若 [preferredModelId] 有效，优先使用；
  /// 否则回退到第一个启用 Provider 的第一个模型。返回 null 表示无可用。
  Future<({ModelEntity model, ProviderEntity provider})?> resolve({
    int? preferredModelId,
  }) async {
    if (preferredModelId != null && preferredModelId > 0) {
      final model = await _modelRepo.getModelById(preferredModelId);
      if (model != null) {
        final provider = await _providerRepo.getProviderById(model.providerId);
        if (provider != null) {
          return (model: model, provider: provider);
        }
      }
    }

    final providers = await _providerRepo.getEnabledProviders();
    if (providers.isEmpty) return null;

    final provider = providers.first;
    final models = await _modelRepo.getModelsByProviderId(provider.id!);
    if (models.isEmpty) return null;

    return (model: models.first, provider: provider);
  }

  /// 仅解析模型。若 [preferredModelId] 有效，优先使用；
  /// 否则回退到数据库中第一个模型。返回 null 表示无可用。
  Future<ModelEntity?> resolveModel({int? preferredModelId}) async {
    if (preferredModelId != null && preferredModelId > 0) {
      final model = await _modelRepo.getModelById(preferredModelId);
      if (model != null) return model;
    }

    final models = await _modelRepo.getAllModels();
    return models.isNotEmpty ? models.first : null;
  }
}
