import 'dart:async';

import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/service/model_catalog_service.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals.dart';

void main() {
  late _Providers providers;
  late _Models models;
  late _Catalog catalog;
  late ProviderViewModel subject;

  setUp(() {
    providers = _Providers();
    models = _Models();
    catalog = _Catalog();
    subject = ProviderViewModel(
      repository: providers,
      modelViewModel: models,
      catalogService: catalog,
    );
  });

  test('同步统一刷新两种状态，并采用目录缓存时间', () async {
    const result = CatalogSyncResult(createdProviders: 1, createdModels: 2);
    catalog.pending.complete(result);
    expect(await subject.syncCatalog(), same(result));
    expect(subject.providers.value, providers.items);
    expect(models.reloads, 1);
    expect(subject.lastSyncedAt.value, catalog.syncedAt);
    expect(catalog.forces, [true]);
    expect(subject.isSyncing.value, isFalse);
    expect(subject.error.value, isNull);
  });

  test('重复同步共用一次请求，结束后可以重新发起', () async {
    final first = subject.syncCatalog();
    final second = subject.syncCatalog();
    expect(first, same(second));
    expect(subject.isSyncing.value, isTrue);
    expect(catalog.forces, [true]);
    catalog.pending.complete(const CatalogSyncResult());
    await first;
    await subject.syncCatalog();
    expect(catalog.forces, [true, true]);
    expect(models.reloads, 2);
  });

  test('同步异常进入错误状态并复位，下一次操作可以恢复', () async {
    final syncing = subject.syncCatalog();
    catalog.pending.completeError(StateError('catalog failed'));
    expect(await syncing, isNull);
    expect(subject.error.value, contains('catalog failed'));
    expect(subject.isSyncing.value, isFalse);
    expect(models.reloads, 0);
    catalog.pending = Completer<CatalogSyncResult>()
      ..complete(const CatalogSyncResult());
    expect(await subject.syncCatalog(), isNotNull);
    expect(subject.error.value, isNull);
  });

  test('Provider 刷新失败不会返回成功统计', () async {
    providers.fail = true;
    catalog.pending.complete(const CatalogSyncResult());
    expect(await subject.syncCatalog(), isNull);
    expect(subject.error.value, contains('providers failed'));
    expect(models.reloads, 0);
    expect(subject.isSyncing.value, isFalse);
  });

  test('Model 刷新只写 error signal 时同样视为失败', () async {
    models.fail = true;
    catalog.pending.complete(const CatalogSyncResult());
    expect(await subject.syncCatalog(), isNull);
    expect(subject.error.value, 'models failed');
    expect(subject.isSyncing.value, isFalse);
  });

  test('缓存回退保留旧抓取时间，不假造刚刚联网同步的时间', () async {
    catalog.syncedAt = DateTime(2020);
    catalog.pending.complete(const CatalogSyncResult(updatedModels: 2));
    expect((await subject.syncCatalog())?.updatedModels, 2);
    expect(subject.lastSyncedAt.value, DateTime(2020));
  });

  test('没有可用缓存的空结果不能报成功', () async {
    catalog.syncedAt = null;
    catalog.pending.complete(const CatalogSyncResult());
    expect(await subject.syncCatalog(), isNull);
    expect(subject.error.value, contains('No model catalog'));
    expect(subject.isSyncing.value, isFalse);
  });

  test('删除 Provider 只删除一次持久化数据，再清理本地模型', () async {
    final provider = providers.items.single;
    await subject.deleteProvider(provider);
    expect(providers.deleted, [provider.id]);
    expect(models.removed, [provider.id]);
    expect(models.enabledReloads, 1);
    expect(subject.error.value, isNull);
  });
}

class _Providers extends Fake implements ProviderRepository {
  final items = [
    ProviderEntity(
      id: 'provider',
      name: 'Test',
      baseUrl: 'https://example.com/v1',
      apiKey: '',
      createdAt: DateTime(2026),
    ),
  ];
  final deleted = <String>[];
  bool fail = false;

  @override
  Future<List<ProviderEntity>> getAllProviders() async {
    if (fail) throw StateError('providers failed');
    return items;
  }

  @override
  Future<void> deleteProvider(String id) async => deleted.add(id);
}

class _Models extends Fake implements ModelViewModel {
  @override
  final error = signal<String?>(null);
  bool fail = false;
  int reloads = 0;
  int enabledReloads = 0;
  final removed = <String>[];

  @override
  Future<void> initSignals() async {
    reloads++;
    error.value = fail ? 'models failed' : null;
  }

  @override
  void removeModelsOfProvider(String providerId) => removed.add(providerId);

  @override
  Future<void> loadEnabledModels() async => enabledReloads++;
}

class _Catalog extends Fake implements ModelCatalogService {
  Completer<CatalogSyncResult> pending = Completer<CatalogSyncResult>();
  DateTime? syncedAt = DateTime(2026, 1, 1);
  final forces = <bool>[];

  @override
  Future<CatalogSyncResult> syncIfNeeded({bool force = false}) {
    forces.add(force);
    return pending.future;
  }

  @override
  Future<DateTime?> lastSyncedAt() async => syncedAt;
}
