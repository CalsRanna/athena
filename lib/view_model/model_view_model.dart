import 'package:athena/entity/model_entity.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/service/chat_service.dart';
import 'package:signals/signals.dart';

class ModelViewModel {
  // ViewModel 内部直接持有 Service/Repository
  final ModelRepository _repository = ModelRepository();
  final ProviderRepository _providerRepository = ProviderRepository();
  final ChatService _chatService = ChatService();

  // Signals 状态
  final models = listSignal<ModelEntity>([]);
  final isLoading = signal(false);
  final error = signal<String?>(null);

  // "enabled models" = models from enabled providers
  // 不能在 computed 中使用 async，所以使用普通 signal
  final enabledModels = listSignal<ModelEntity>([]);
  final groupedEnabledModels = signal<Map<String, List<ModelEntity>>>({});

  // 业务方法
  Future<void> loadEnabledModels() async {
    try {
      final enabledProviders = await _providerRepository.getEnabledProviders();
      final List<ModelEntity> result = [];
      Map<String, List<ModelEntity>> grouped = {};

      for (var provider in enabledProviders) {
        final providerModels = await _repository.getModelsByProviderId(
          provider.id!,
        );
        if (providerModels.isNotEmpty) {
          result.addAll(providerModels);
          providerModels.sort((a, b) => a.name.compareTo(b.name));
          grouped[provider.name] = providerModels;
        }
      }

      result.sort((a, b) => a.name.compareTo(b.name));
      enabledModels.value = result;
      groupedEnabledModels.value = grouped;
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> initSignals() async {
    isLoading.value = true;
    error.value = null;
    try {
      models.value = await _repository.getAllModels();
      await loadEnabledModels();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<ModelEntity?> getModelById(int id) async {
    try {
      return await _repository.getModelById(id);
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  Future<List<ModelEntity>> getModelsByProviderId(int providerId) async {
    try {
      var providerModels = await _repository.getModelsByProviderId(providerId);
      providerModels.sort((a, b) => a.name.compareTo(b.name));
      return providerModels;
    } catch (e) {
      error.value = e.toString();
      return [];
    }
  }

  Future<List<ModelEntity>> getEnabledModelsByProviderId(int providerId) async {
    try {
      // 只需检查 provider 是否 enabled，所有该 provider 下的 models 都视为 enabled
      var provider = await _providerRepository.getProviderById(providerId);
      if (provider == null || !provider.enabled) {
        return [];
      }
      var providerModels = await _repository.getModelsByProviderId(providerId);
      providerModels.sort((a, b) => a.name.compareTo(b.name));
      return providerModels;
    } catch (e) {
      error.value = e.toString();
      return [];
    }
  }

  Future<ModelEntity?> getFirstEnabledModel() async {
    if (enabledModels.value.isEmpty) {
      await loadEnabledModels();
    }
    return enabledModels.value.firstOrNull;
  }

  Future<bool> hasModel() async {
    if (enabledModels.value.isEmpty) {
      await loadEnabledModels();
    }
    return groupedEnabledModels.value.isNotEmpty;
  }

  Future<void> createModel(ModelEntity model) async {
    isLoading.value = true;
    error.value = null;
    try {
      var id = await _repository.createModel(model);
      var created = model.copyWith(id: id);
      models.value = [...models.value, created];
      await loadEnabledModels();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateModel(ModelEntity model) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _repository.updateModel(model);
      var index = models.value.indexWhere((m) => m.id == model.id);
      if (index >= 0) {
        var updated = List<ModelEntity>.from(models.value);
        updated[index] = model;
        models.value = updated;
      }
      await loadEnabledModels();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteModel(ModelEntity model) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _repository.deleteModel(model.id!);
      models.value = models.value.where((m) => m.id != model.id).toList();
      await loadEnabledModels();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<String> checkConnection(ModelEntity model) async {
    try {
      var provider = await _providerRepository.getProviderById(
        model.providerId,
      );
      if (provider == null) return 'Connection failed: provider not found';
      var response = await _chatService.connect(
        model: model,
        provider: provider,
      );
      if (response.isEmpty) {
        return 'Connection succeed, but response is empty'; // Success
      }
      return 'Connection succeed, and response is: $response'; // Success
    } catch (e) {
      return 'Connection failed: ${e.toString()}';
    }
  }
}
