import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/storage/file_storage.dart';
import 'package:athena_core/storage/storage_merger.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:path/path.dart' as p;

/// 一次性把旧的 TUI 专属数据目录(`root/tui/`)并入共享根目录。
///
/// GUI 与 TUI 改为共享 `~/.athena/` 后,TUI 早先写在 `~/.athena/tui/`
/// 的会话/模型/角色需要并入根目录。旧目录可能是两种布局之一,都支持:
/// - 更早:`chats.jsonl` + `messages/{chatId}.jsonl`、`models.jsonl`、
///   `sentinels.jsonl`、`providers.jsonl`
/// - 较新:`sessions/{chatId}.jsonl`(首行会话 + 消息行)、`models.json`、
///   `sentinels.json`
///
/// 读出后经 [StorageMerger] 按合并语义写入(根目录已有 GUI 数据时按
/// 名字/模型匹配、冲突 id 重分配),成功后把旧目录改名为 `tui.migrated`
/// 留作备份,下次启动不再触发。provider 早已共享 `setting.yaml`,只有
/// 更早布局的 `providers.jsonl` 需要并入。
class LegacyTuiDirImporter {
  LegacyTuiDirImporter({required FileStorage storage, Directory? legacyDir})
    : _storage = storage,
      _legacyDir = legacyDir ?? Directory(p.join(storage.root.path, 'tui'));

  final FileStorage _storage;
  final Directory _legacyDir;

  /// 需要导入时执行并返回 true;没有旧目录时返回 false。
  Future<bool> importIfNeeded() async {
    if (!await _legacyDir.exists()) return false;
    LoggerUtil.i('Importing legacy TUI dir ${_legacyDir.path}');
    final snapshot = await readSnapshot();
    if (!snapshot.isEmpty) {
      await StorageMerger(_storage).merge(snapshot);
    }
    await _legacyDir.rename('${_legacyDir.path}.migrated');
    LoggerUtil.i('Legacy TUI dir imported, renamed to tui.migrated');
    return true;
  }

  /// 读出旧目录的全部数据(两种布局都认)。
  Future<StorageSnapshot> readSnapshot() async {
    return StorageSnapshot(
      providers: [
        for (final row in await _readJsonl(_file('providers.jsonl')))
          ProviderEntity.fromJson(row),
      ],
      models: [
        for (final row in await _readList('models')) ModelEntity.fromJson(row),
      ],
      sentinels: [
        for (final row in await _readList('sentinels'))
          SentinelEntity.fromJson(row),
      ],
      sessions: [...await _readSessions(), ...await _readLegacyChats()],
    );
  }

  File _file(String name) => File(p.join(_legacyDir.path, name));

  /// `{name}.json`(数组)与 `{name}.jsonl` 都读,两者并存时合并。
  Future<List<Map<String, dynamic>>> _readList(String name) async {
    final rows = <Map<String, dynamic>>[];
    final json = _file('$name.json');
    if (await json.exists()) {
      try {
        final value = jsonDecode(await json.readAsString());
        if (value is List) {
          rows.addAll([
            for (final item in value)
              if (item is Map) Map<String, dynamic>.from(item),
          ]);
        }
      } catch (_) {
        // 损坏文件跳过
      }
    }
    rows.addAll(await _readJsonl(_file('$name.jsonl')));
    return rows;
  }

  Future<List<Map<String, dynamic>>> _readJsonl(File file) async {
    if (!await file.exists()) return const [];
    final rows = <Map<String, dynamic>>[];
    for (final line in await file.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        final value = jsonDecode(line);
        if (value is Map) rows.add(Map<String, dynamic>.from(value));
      } catch (_) {
        // 损坏行跳过
      }
    }
    return rows;
  }

  /// 较新布局:sessions/{chatId}.jsonl,首行 type=chat,其余 type=message。
  Future<List<SessionSnapshot>> _readSessions() async {
    final dir = Directory(p.join(_legacyDir.path, 'sessions'));
    if (!await dir.exists()) return const [];
    final sessions = <SessionSnapshot>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.jsonl')) continue;
      ChatEntity? chat;
      final messages = <MessageEntity>[];
      for (final row in await _readJsonl(entity)) {
        try {
          if (row['type'] == 'chat') {
            chat ??= ChatEntity.fromJson(row);
          } else if (row['type'] == 'message') {
            messages.add(MessageEntity.fromJson(row));
          }
        } catch (_) {
          // 损坏行跳过
        }
      }
      if (chat != null) {
        sessions.add(SessionSnapshot(chat: chat, messages: messages));
      }
    }
    return sessions;
  }

  /// 更早布局:chats.jsonl + messages/{chatId}.jsonl。
  Future<List<SessionSnapshot>> _readLegacyChats() async {
    final chats = await _readJsonl(_file('chats.jsonl'));
    if (chats.isEmpty) return const [];
    final sessions = <SessionSnapshot>[];
    for (final row in chats) {
      try {
        final chat = ChatEntity.fromJson(row);
        final id = chat.id;
        if (id == null) continue;
        final messages = <MessageEntity>[];
        final file = File(p.join(_legacyDir.path, 'messages', '$id.jsonl'));
        for (final m in await _readJsonl(file)) {
          try {
            messages.add(MessageEntity.fromJson(m));
          } catch (_) {
            // 损坏行跳过
          }
        }
        sessions.add(SessionSnapshot(chat: chat, messages: messages));
      } catch (_) {
        // 损坏的 chat 行跳过
      }
    }
    return sessions;
  }
}
