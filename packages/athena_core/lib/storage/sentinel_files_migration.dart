import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/sentinel_store.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:path/path.dart' as p;

/// 一次性升级:`sentinels.json` 数组 → 每角色一个文件
/// (`sentinels/{id}.yaml`),然后让 `sentinels.json` 退场(改名留档)。
///
/// 与 [ModelsIntoProvidersMigration] 同一模式,但更简单:角色自带完整 id,不
/// 需要按别的东西分组。
///
/// 顺序:先备份、再逐文件写入、最后才让原文件退场。中断后重跑幂等(整目录覆盖
/// 式写入,重复执行结果相同)。
class SentinelFilesMigration {
  SentinelFilesMigration({
    required File sentinelsFile,
    required SentinelStore sentinelStore,
    required LockRegistry locks,
  }) : _sentinelsFile = sentinelsFile,
       _store = sentinelStore,
       _locks = locks;

  static const version = 1;

  final File _sentinelsFile;
  final SentinelStore _store;

  /// 锁放哪由它决定,见 [LockRegistry]。
  final LockRegistry _locks;

  File get _marker => File(p.join(_store.directory.path, '.version'));
  File get _lockFile => _locks.named('sentinel-files-migration');

  Future<void> run() {
    return withFileLock(_lockFile, () async {
      if (await _marker.exists()) return;
      if (!await _sentinelsFile.exists()) {
        await _writeMarker();
        return;
      }

      final sentinels = await _readSentinels();
      // id 不合法的角色无法决定文件名,先整体校验再落盘:写出一半再失败,
      // 加上原文件已退场,才是真的丢数据
      for (final sentinel in sentinels) {
        final id = sentinel.id;
        if (id == null || !SentinelStore.isValidId(id)) {
          throw FormatException('Sentinel with invalid id: $id');
        }
      }
      await _store.replaceAll(sentinels);
      await _sentinelsFile.rename('${_sentinelsFile.path}.migrated');
      await _writeMarker();
      LoggerUtil.i(
        'Sentinel files: migrated ${sentinels.length} sentinels '
        'to ${_store.directory.path}',
      );
    });
  }

  /// `sentinels.json` 的 JSON 数组 → 实体。
  ///
  /// 文件损坏时抛错中止并保留原文件:整表读不出来还继续跑,会写出一个空目录
  /// 再把唯一的数据源改名退场,那就是真的丢数据了。
  Future<List<SentinelEntity>> _readSentinels() async {
    final raw = jsonDecode(await _sentinelsFile.readAsString());
    if (raw is! List) {
      throw const FormatException('sentinels.json is not a JSON array');
    }
    return [
      for (final item in raw)
        if (item is Map)
          SentinelEntity.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<void> _writeMarker() async {
    await atomicWriteString(_marker, 'version: $version\n');
  }
}
