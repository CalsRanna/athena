import 'dart:io';

import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_tui/storage/jsonl_store.dart';

/// SentinelRepository 的 JSONL 实现(`~/.athena/tui/sentinels.jsonl`)。
class JsonlSentinelRepository implements SentinelRepository {
  JsonlSentinelRepository({
    required File file,
    required IdAllocator idAllocator,
  }) : _store = JsonlFileStore(file: file, idAllocator: idAllocator);

  final JsonlFileStore _store;

  @override
  Future<List<SentinelEntity>> getAllSentinels() async {
    final rows = await _store.readAll();
    return rows.map(SentinelEntity.fromJson).toList();
  }

  @override
  Future<SentinelEntity?> getSentinelById(int id) async {
    final row = await _store.readById(id);
    return row == null ? null : SentinelEntity.fromJson(row);
  }

  @override
  Future<int> createSentinel(SentinelEntity sentinel) {
    return _store.insert(sentinel.toJson());
  }

  @override
  Future<void> updateSentinel(SentinelEntity sentinel) async {
    final id = sentinel.id;
    if (id == null) return;
    await _store.replaceById(id, sentinel.toJson());
  }

  @override
  Future<void> deleteSentinel(int id) => _store.deleteById(id);

  @override
  Future<int> getSentinelsCount() => _store.count();

  @override
  Future<void> batchCreateSentinels(List<SentinelEntity> sentinels) async {
    for (final sentinel in sentinels) {
      await _store.insert(sentinel.toJson());
    }
  }

  @override
  Future<SentinelEntity?> getSentinelByName(String name) async {
    final sentinels = await getAllSentinels();
    for (final s in sentinels) {
      if (s.name == name) return s;
    }
    return null;
  }

  @override
  Future<void> importSentinels(List<SentinelEntity> sentinels) async {
    for (final sentinel in sentinels) {
      final existing = await getSentinelByName(sentinel.name);
      if (existing != null) {
        await _store.replaceById(existing.id!, sentinel.toJson());
      } else {
        await _store.insert(sentinel.toJson());
      }
    }
  }
}
