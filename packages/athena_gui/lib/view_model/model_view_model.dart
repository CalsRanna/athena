import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_gui/extension/list_signal_extension.dart';
import 'package:signals/signals.dart';

class ConnectionCheckResult {
  final bool isSuccess;
  final String message;
  final String? detail;

  const ConnectionCheckResult({
    required this.isSuccess,
    required this.message,
    this.detail,
  });
}

class ModelViewModel {
  final ModelRepository _repository;
  final ProviderRepository _providerRepository;
  final ChatCompletionsService _chatService;

  ModelViewModel({
    required ModelRepository repository,
    required ProviderRepository providerRepository,
    required ChatCompletionsService chatService,
  }) : _repository = repository,
       _providerRepository = providerRepository,
       _chatService = chatService;

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
      final Map<String, List<ModelEntity>> grouped = {};

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

  Future<ModelEntity?> getModelById(String id) async {
    try {
      return await _repository.getModelById(id);
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  Future<List<ModelEntity>> getModelsByProviderId(String providerId) async {
    try {
      final providerModels = await _repository.getModelsByProviderId(
        providerId,
      );
      providerModels.sort((a, b) => a.name.compareTo(b.name));
      return providerModels;
    } catch (e) {
      error.value = e.toString();
      return [];
    }
  }

  Future<List<ModelEntity>> getEnabledModelsByProviderId(
    String providerId,
  ) async {
    try {
      // 只需检查 provider 是否 enabled，所有该 provider 下的 models 都视为 enabled
      final provider = await _providerRepository.getProviderById(providerId);
      if (provider == null || !provider.enabled) {
        return [];
      }
      final providerModels = await _repository.getModelsByProviderId(
        providerId,
      );
      providerModels.sort((a, b) => a.name.compareTo(b.name));
      return providerModels;
    } catch (e) {
      error.value = e.toString();
      return [];
    }
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
      final id = await _repository.createModel(model);
      final created = model.copyWith(id: id);
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
      models.replaceWhere((m) => m.id == model.id, model);
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

  /// Removes models from local state after their provider has been deleted.
  void removeModelsOfProvider(String providerId) {
    // 持久化模型已随 provider 文件删除，这里只同步前端状态。
    models.value = models.value
        .where((m) => m.providerId != providerId)
        .toList();
  }

  Future<ConnectionCheckResult> checkConnection(ModelEntity model) async {
    try {
      final provider = await _providerRepository.getProviderById(
        model.providerId,
      );
      if (provider == null) {
        return const ConnectionCheckResult(
          isSuccess: false,
          message: 'Connection failed',
          detail: 'Provider not found.',
        );
      }
      final response = await _chatService.connect(
        model: model,
        provider: provider,
      );
      return ConnectionCheckResult(
        isSuccess: true,
        message: 'Connected to ${model.name}',
        detail: response.isEmpty ? null : response,
      );
    } catch (e) {
      return ConnectionCheckResult(
        isSuccess: false,
        message: 'Connection failed',
        detail: e.toString(),
      );
    }
  }
}
