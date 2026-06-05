import 'package:athena/entity/provider_entity.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:signals/signals.dart';

class ProviderViewModel {
  late final ProviderRepository _repository;
  late final ModelViewModel _modelViewModel;

  ProviderViewModel({
    required ProviderRepository repository,
    required ModelViewModel modelViewModel,
  })  : _repository = repository,
        _modelViewModel = modelViewModel;

  // Signals 状态
  final providers = listSignal<ProviderEntity>([]);
  final isLoading = signal(false);
  final error = signal<String?>(null);

  // Computed signals
  late final enabledProviders = computed(() {
    return providers.value.where((p) => p.enabled).toList();
  });

  Future<void> initSignals() async {
    isLoading.value = true;
    error.value = null;
    try {
      providers.value = await _repository.getAllProviders();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<ProviderEntity?> getProviderById(int id) async {
    try {
      return await _repository.getProviderById(id);
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  Future<List<ProviderEntity>> getEnabledProviders() async {
    try {
      return await _repository.getEnabledProviders();
    } catch (e) {
      error.value = e.toString();
      return [];
    }
  }

  Future<void> storeProvider(ProviderEntity provider) async {
    isLoading.value = true;
    error.value = null;
    try {
      var id = await _repository.storeProvider(provider);
      var created = provider.copyWith(id: id);
      providers.value = [...providers.value, created];
    } catch (e) {
      AthenaDialog.error(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateProvider(ProviderEntity provider) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _repository.updateProvider(provider);
      var index = providers.value.indexWhere((p) => p.id == provider.id);
      if (index >= 0) {
        var updated = List<ProviderEntity>.from(providers.value);
        updated[index] = provider;
        providers.value = updated;
      }
      await _modelViewModel.loadEnabledModels();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteProvider(ProviderEntity provider) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _repository.deleteProvider(provider.id!);
      providers.value = providers.value
          .where((p) => p.id != provider.id)
          .toList();
      await _modelViewModel.loadEnabledModels();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleEnabled(ProviderEntity provider) async {
    error.value = null;
    try {
      var updated = provider.copyWith(enabled: !provider.enabled);
      await _repository.updateProvider(updated);
      var index = providers.value.indexWhere((p) => p.id == provider.id);
      if (index >= 0) {
        var updatedList = List<ProviderEntity>.from(providers.value);
        updatedList[index] = updated;
        providers.value = updatedList;
      }
      await _modelViewModel.loadEnabledModels();
    } catch (e) {
      error.value = e.toString();
    }
  }
}
