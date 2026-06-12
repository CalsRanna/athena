import 'package:athena/database/database.dart';
import 'package:athena/util/logger_util.dart';

/// 修复从旧版本升级时内置 provider/sentinel 重复的问题。
///
/// 旧版本用计数去重（providers.count > 0 则跳过），
/// 新版本用 migrations 表中的 marker 去重（preset_providers_v1/preset_sentinels_v1）。
/// 旧用户升级到新版本时 marker 不存在 → _preset() 重新插入全部预设数据 → 产生重复。
///
/// 本迁移：
/// 1. 按 name 去重 providers（保留 id 最小的，先迁移关联的 models 再删重复的）
/// 2. 按 name 去重 sentinels（保留 id 最小的，先迁移关联的 chats 再删重复的）
/// 3. 为已有数据的表补写 marker，防止后续启动再次插入预设
class Migration202606110001DedupPresets {
  static const name = 'migration_202606110001_dedup_presets';
  static const presetProvidersMarker = 'preset_providers_v1';
  static const presetSentinelsMarker = 'preset_sentinels_v1';

  Future<void> migrate() async {
    var laconic = Database.instance.laconic;

    var count = await laconic.table('migrations').where('name', name).count();
    if (count > 0) return;

    await laconic.transaction(() async {
      await _dedupProviders();
      await _dedupSentinels();
      await _backfillMarkers();

      await laconic.table('migrations').insert([
        {'name': name},
      ]);
    });
  }

  Future<void> _dedupProviders() async {
    var laconic = Database.instance.laconic;

    // 查找有重复的 provider name
    var dupRows = await laconic.select('''
      SELECT name, MIN(id) as keep_id
      FROM providers
      GROUP BY name
      HAVING COUNT(*) > 1
    ''');

    for (var row in dupRows) {
      var map = row.toMap();
      var name = map['name'] as String;
      var keepId = map['keep_id'] as int;

      LoggerUtil.i('Dedup providers: keeping $name (id=$keepId)');

      // 1. 删除重复 provider 下与保留 provider 中 model_id 相同的 models
      await laconic.statement('''
        DELETE FROM models
        WHERE provider_id IN (
          SELECT id FROM providers WHERE name = ? AND id != ?
        )
        AND model_id IN (
          SELECT model_id FROM models WHERE provider_id = ?
        )
      ''', [name, keepId, keepId]);

      // 2. 将剩余 models 迁移到保留的 provider
      await laconic.statement('''
        UPDATE models SET provider_id = ?
        WHERE provider_id IN (
          SELECT id FROM providers WHERE name = ? AND id != ?
        )
      ''', [keepId, name, keepId]);

      // 3. 删除重复的 providers
      await laconic.statement('''
        DELETE FROM providers WHERE name = ? AND id != ?
      ''', [name, keepId]);
    }
  }

  Future<void> _dedupSentinels() async {
    var laconic = Database.instance.laconic;

    var dupRows = await laconic.select('''
      SELECT name, MIN(id) as keep_id
      FROM sentinels
      GROUP BY name
      HAVING COUNT(*) > 1
    ''');

    for (var row in dupRows) {
      var map = row.toMap();
      var name = map['name'] as String;
      var keepId = map['keep_id'] as int;

      LoggerUtil.i('Dedup sentinels: keeping $name (id=$keepId)');

      // 1. 将引用重复 sentinel 的 chats 指向保留的 sentinel
      await laconic.statement('''
        UPDATE chats SET sentinel_id = ?
        WHERE sentinel_id IN (
          SELECT id FROM sentinels WHERE name = ? AND id != ?
        )
      ''', [keepId, name, keepId]);

      // 2. 删除重复的 sentinels
      await laconic.statement('''
        DELETE FROM sentinels WHERE name = ? AND id != ?
      ''', [name, keepId]);
    }
  }

  /// 对已有数据的表补写 marker，避免 _preset() 再次插入
  Future<void> _backfillMarkers() async {
    var laconic = Database.instance.laconic;

    // providers marker
    var providerCount = await laconic.table('providers').count();
    if (providerCount > 0) {
      var markerExists = await laconic
          .table('migrations')
          .where('name', presetProvidersMarker)
          .count();
      if (markerExists == 0) {
        await laconic.table('migrations').insert([
          {'name': presetProvidersMarker},
        ]);
        LoggerUtil.i('Backfilled marker: $presetProvidersMarker');
      }
    }

    // sentinels marker
    var sentinelCount = await laconic.table('sentinels').count();
    if (sentinelCount > 0) {
      var markerExists = await laconic
          .table('migrations')
          .where('name', presetSentinelsMarker)
          .count();
      if (markerExists == 0) {
        await laconic.table('migrations').insert([
          {'name': presetSentinelsMarker},
        ]);
        LoggerUtil.i('Backfilled marker: $presetSentinelsMarker');
      }
    }
  }
}
