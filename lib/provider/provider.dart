import 'package:athena/schema/isar.dart';
import 'package:athena/schema/provider.dart' as schema;
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'provider.g.dart';

@riverpod
class EnabledProvidersNotifier extends _$EnabledProvidersNotifier {
  @override
  Future<List<schema.Provider>> build() async {
    var providers = await ref.watch(providersNotifierProvider.future);
    return providers.where((provider) => provider.enabled).toList();
  }
}

@riverpod
class ProvidersNotifier extends _$ProvidersNotifier {
  @override
  Future<List<schema.Provider>> build() async {
    return await isar.providers.where().findAll();
  }

  Future<void> destroy(schema.Provider provider) async {
    await isar.writeTxn(() async {
      await isar.providers.delete(provider.id);
    });
    ref.invalidateSelf();
  }

  Future<void> store(schema.Provider provider) async {
    await isar.writeTxn(() async {
      await isar.providers.put(provider);
    });
    ref.invalidateSelf();
  }

  Future<void> updateProvider(schema.Provider provider) async {
    await isar.writeTxn(() async {
      await isar.providers.put(provider);
    });
    ref.invalidateSelf();
  }
}

@riverpod
class ProviderNotifier extends _$ProviderNotifier {
  @override
  Future<schema.Provider> build(int id) async {
    var provider = await isar.providers.where().idEqualTo(id).findFirst();
    return provider ?? schema.Provider();
  }
}
