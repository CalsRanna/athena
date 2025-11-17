import 'package:athena/entity/ai_provider_entity.dart';
import 'package:athena/repository/ai_provider_repository.dart';
import 'package:signals/signals.dart';

class AIProviderViewModel {
  // ViewModel 内部直接持有 Repository
  final AIProviderRepository _providerRepository = AIProviderRepository();

  // Signals 状态
  final providers = listSignal<AIProviderEntity>([]);
  final isLoading = signal(false);
  final error = signal<String?>(null);

  // Computed signals
  late final enabledProviders = computed(() {
    return providers.value.where((p) => p.enabled).toList();
  });

  // 业务方法
  Future<void> loadProviders() async {
    isLoading.value = true;
    error.value = null;
    try {
      providers.value = await _providerRepository.getAllProviders();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<AIProviderEntity?> getProviderById(int id) async {
    try {
      return await _providerRepository.getProviderById(id);
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  Future<List<AIProviderEntity>> getEnabledProviders() async {
    try {
      return await _providerRepository.getEnabledProviders();
    } catch (e) {
      error.value = e.toString();
      return [];
    }
  }

  Future<void> createProvider(AIProviderEntity provider) async {
    isLoading.value = true;
    error.value = null;
    try {
      var id = await _providerRepository.createProvider(provider);
      var created = provider.copyWith(id: id);
      providers.value = [...providers.value, created];
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateProvider(AIProviderEntity provider) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _providerRepository.updateProvider(provider);
      var index = providers.value.indexWhere((p) => p.id == provider.id);
      if (index >= 0) {
        var updated = List<AIProviderEntity>.from(providers.value);
        updated[index] = provider;
        providers.value = updated;
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteProvider(AIProviderEntity provider) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _providerRepository.deleteProvider(provider.id!);
      providers.value =
          providers.value.where((p) => p.id != provider.id).toList();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleEnabled(AIProviderEntity provider) async {
    error.value = null;
    try {
      var updated = provider.copyWith(enabled: !provider.enabled);
      await _providerRepository.updateProvider(updated);
      var index = providers.value.indexWhere((p) => p.id == provider.id);
      if (index >= 0) {
        var updatedList = List<AIProviderEntity>.from(providers.value);
        updatedList[index] = updated;
        providers.value = updatedList;
      }
    } catch (e) {
      error.value = e.toString();
    }
  }

  void dispose() {
    providers.dispose();
    isLoading.dispose();
    error.dispose();
    enabledProviders.dispose();
  }
}
