import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/extension/list_signal_extension.dart';
import 'package:signals/signals.dart';

class ProviderViewModel {
  final ProviderRepository _repository;
  final ModelViewModel _modelViewModel;
  final ModelCatalogService _catalogService;
  Future<CatalogSyncResult?>? _syncOperation;

  ProviderViewModel({
    required ProviderRepository repository,
    required ModelViewModel modelViewModel,
    required ModelCatalogService catalogService,
  }) : _repository = repository,
       _modelViewModel = modelViewModel,
       _catalogService = catalogService;

  // Signals 状态
  final providers = listSignal<ProviderEntity>([]);
  final isLoading = signal(false);
  final isSyncing = signal(false);
  final lastSyncedAt = signal<DateTime?>(null);
  final error = signal<String?>(null);

  // Computed signals
  late final enabledProviders = computed(() {
    return providers.value.where((p) => p.enabled).toList();
  });

  late final disabledProviders = computed(() {
    return providers.value.where((p) => !p.enabled).toList();
  });

  Future<void> initSignals() async {
    isLoading.value = true;
    error.value = null;
    try {
      providers.value = await _repository.getAllProviders();
      lastSyncedAt.value = await _catalogService.lastSyncedAt();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// Synchronizes the catalog and refreshes both provider and model state.
  Future<CatalogSyncResult?> syncCatalog() => _syncOperation ??= _syncCatalog()
      .whenComplete(() => _syncOperation = null);

  Future<CatalogSyncResult?> _syncCatalog() async {
    isSyncing.value = true;
    error.value = null;
    try {
      final result = await _catalogService.syncIfNeeded(force: true);
      await initSignals();
      if (error.value != null) return null;
      await _modelViewModel.initSignals();
      // 两个 initSignals 都将异常写入 signal，不抛出；不能据此误报同步成功。
      if (_modelViewModel.error.value != null) {
        error.value = _modelViewModel.error.value;
        return null;
      }
      // 离线时沿用目录服务的缓存回退，显示缓存真实时间；没有缓存则不是成功。
      if (lastSyncedAt.value == null) {
        error.value = 'No model catalog is available. Please try again.';
        return null;
      }
      return result;
    } catch (e) {
      error.value = e.toString();
      return null;
    } finally {
      isSyncing.value = false;
    }
  }

  Future<ProviderEntity?> getProviderById(String id) async {
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
      final id = await _repository.storeProvider(provider);
      final created = provider.copyWith(id: id);
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
      // Provider 文件包含它的模型，持久化删除已完成；这里只移除本地列表项。
      _modelViewModel.removeModelsOfProvider(provider.id!);
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
      final updated = provider.copyWith(enabled: !provider.enabled);
      await _repository.updateProvider(updated);
      providers.replaceWhere((p) => p.id == provider.id, updated);
      await _modelViewModel.loadEnabledModels();
    } catch (e) {
      error.value = e.toString();
    }
  }
}
