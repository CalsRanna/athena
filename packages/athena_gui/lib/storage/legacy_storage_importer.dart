import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/storage/storage_merger.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:athena_gui/database/database.dart';
import 'package:laconic/laconic.dart';
import 'package:path/path.dart' as p;

/// 一次性把 GUI 旧的 SQLite 库(athena.db)与旧工具输出目录导入
/// [FileStorage] 文件布局。
///
/// 触发条件:`athena.db` 仍存在。整库读成 [StorageSnapshot] 后交给
/// [StorageMerger] 按合并语义写入(目标目录可能已有 TUI 数据),成功后
/// 把它改名为 `athena.db.migrated` 留作备份,下次启动不再触发。
/// 中途失败时不改名,下次启动重跑;合并器可重复执行不会写重。
class LegacyStorageImporter {
  LegacyStorageImporter({
    required FileStorage storage,
    required File dbFile,
    Directory? legacyToolOutputsDir,
  }) : _storage = storage,
       _dbFile = dbFile,
       _legacyToolOutputsDir = legacyToolOutputsDir;

  final FileStorage _storage;
  final File _dbFile;
  final Directory? _legacyToolOutputsDir;

  /// 需要导入时执行导入并返回 true;没有旧库时返回 false。
  Future<bool> importIfNeeded() async {
    if (!await _dbFile.exists()) return false;
    LoggerUtil.i('Importing legacy SQLite ${_dbFile.path}');
    // 先跑完历史 migration 把表结构升到最新,再整表读出
    await Database.instance.ensureInitialized(path: _dbFile.path);
    final laconic = Database.instance.laconic;
    final StorageSnapshot snapshot;
    try {
      snapshot = await readSnapshot(laconic);
    } finally {
      await laconic.close();
    }
    await StorageMerger(_storage).merge(snapshot);
    await _dbFile.rename('${_dbFile.path}.migrated');
    await _moveToolOutputs();
    LoggerUtil.i('Legacy SQLite imported, renamed to athena.db.migrated');
    return true;
  }

  /// 整库读出(id 为 SQLite 原 id)。
  Future<StorageSnapshot> readSnapshot(Laconic laconic) async {
    final sessions = <SessionSnapshot>[];
    for (final row in await laconic.select('SELECT * FROM chats ORDER BY id')) {
      final chat = ChatEntity.fromJson(row.toMap());
      final messageRows = await laconic.select(
        'SELECT * FROM messages WHERE chat_id = ? ORDER BY id',
        [chat.id],
      );
      sessions.add(
        SessionSnapshot(
          chat: chat,
          messages: [
            for (final m in messageRows) MessageEntity.fromJson(m.toMap()),
          ],
        ),
      );
    }
    return StorageSnapshot(
      providers: [
        for (final r in await laconic.select(
          'SELECT * FROM providers ORDER BY id',
        ))
          ProviderEntity.fromJson(r.toMap()),
      ],
      models: [
        for (final r in await laconic.select('SELECT * FROM models ORDER BY id'))
          ModelEntity.fromJson(r.toMap()),
      ],
      sentinels: [
        for (final r in await laconic.select(
          'SELECT * FROM sentinels ORDER BY id',
        ))
          SentinelEntity.fromJson(r.toMap()),
      ],
      sessions: sessions,
    );
  }

  /// 旧工具输出目录(桌面端曾在 Application Support 下)并入共享目录:
  /// 内容寻址文件名,同名即同内容,已存在的跳过。
  Future<void> _moveToolOutputs() async {
    final legacy = _legacyToolOutputsDir;
    if (legacy == null || !await legacy.exists()) return;
    final target = _storage.toolOutputsDir;
    if (legacy.path == target.path) return;
    await target.create(recursive: true);
    var moved = 0;
    await for (final entity in legacy.list()) {
      if (entity is! File) continue;
      final dest = File(p.join(target.path, p.basename(entity.path)));
      if (await dest.exists()) continue;
      await entity.rename(dest.path);
      moved++;
    }
    LoggerUtil.i('Moved $moved legacy tool outputs into ${target.path}');
  }
}
