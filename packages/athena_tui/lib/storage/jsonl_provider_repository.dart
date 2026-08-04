import 'dart:io';

import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_tui/storage/jsonl_store.dart';

/// ProviderRepository 的 JSONL 实现(`~/.athena/tui/providers.jsonl`)。
class JsonlProviderRepository implements ProviderRepository {
  JsonlProviderRepository({required File file, required IdAllocator idAllocator})
    : _store = JsonlFileStore(file: file, idAllocator: idAllocator);

  final JsonlFileStore _store;

  @override
  Future<List<ProviderEntity>> getAllProviders() async {
    final rows = await _store.readAll();
    return rows.map(ProviderEntity.fromJson).toList();
  }

  @override
  Future<ProviderEntity?> getProviderById(int id) async {
    final row = await _store.readById(id);
    return row == null ? null : ProviderEntity.fromJson(row);
  }

  @override
  Future<List<ProviderEntity>> getEnabledProviders() async {
    final providers = await getAllProviders();
    return providers.where((p) => p.enabled).toList();
  }

  @override
  Future<int> storeProvider(ProviderEntity provider) async {
    if (provider.id != null) {
      await _store.replaceById(provider.id!, provider.toJson());
      return provider.id!;
    }
    return _store.insert(provider.toJson());
  }

  @override
  Future<void> updateProvider(ProviderEntity provider) async {
    final id = provider.id;
    if (id == null) return;
    await _store.replaceById(id, provider.toJson());
  }

  @override
  Future<void> deleteProvider(int id) => _store.deleteById(id);

  @override
  Future<int> getProvidersCount() => _store.count();

  @override
  Future<void> batchStoreProviders(List<ProviderEntity> providers) async {
    for (final provider in providers) {
      await storeProvider(provider);
    }
  }

  @override
  Future<ProviderEntity?> getProviderByName(String name) async {
    final providers = await getAllProviders();
    for (final p in providers) {
      if (p.name == name) return p;
    }
    return null;
  }

  @override
  Future<ProviderEntity?> getPresetProviderByName(String name) async {
    final providers = await getAllProviders();
    for (final p in providers) {
      if (p.name == name && p.isPreset) return p;
    }
    return null;
  }

  @override
  Future<void> deleteAllProviders() => _store.deleteFile();

  @override
  Future<void> importProviders(List<ProviderEntity> providers) async {
    await _store.deleteFile();
    for (final provider in providers) {
      // 保留原始 ID:导入时按已有 id 重建行
      final json = provider.toJson();
      if (provider.id != null) {
        await _store.replaceById(provider.id!, json);
      } else {
        await _store.insert(json);
      }
    }
  }
}
