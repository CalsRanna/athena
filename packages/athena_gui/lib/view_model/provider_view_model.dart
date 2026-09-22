import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/extension/list_signal_extension.dart';
import 'package:signals/signals.dart';

class ProviderViewModel {
  final ProviderRepository _repository;
  final ModelViewModel _modelViewModel;

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

  /// 新建 provider;成功返回带 id 的实体(设置页据此直接打开它)。
  Future<ProviderEntity?> storeProvider(ProviderEntity provider) async {
    isLoading.value = true;
    error.value = null;
    try {
      var id = await _repository.storeProvider(provider);
      var created = provider.copyWith(id: id);
      providers.value = [...providers.value, created];
      return created;
    } catch (e) {
      AthenaDialog.error(e.toString());
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateProvider(ProviderEntity provider) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _repository.updateProvider(provider);
      providers.replaceWhere((p) => p.id == provider.id, provider);
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
      providers.replaceWhere((p) => p.id == provider.id, updated);
      await _modelViewModel.loadEnabledModels();
    } catch (e) {
      error.value = e.toString();
    }
  }
}
