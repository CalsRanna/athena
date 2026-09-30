import 'dart:convert';
import 'dart:io';

import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/id_generator.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// 旧整数身份只在迁移边界出现；同类引用共用映射，消息另按会话隔离。
class LegacyIdMap {
  final Map<String, Map<String, String>> values = {};
  final IdGenerator generator;

  LegacyIdMap({this.generator = const IdGenerator()});

  String id(String kind, Object? old) {
    if (old is String && old.isNotEmpty) return old;
    if (old == null) return generator.next();
    if (old is! int) throw FormatException('Invalid $kind ID: $old');
    return values
        .putIfAbsent(kind, () => {})
        .putIfAbsent('$old', generator.next);
  }

  String? sentinel(Object? old) =>
      old == null || old == 0 ? null : id('sentinel', old);

  /// JSON 备份导入与磁盘升级共用身份转换，不能把旧数字直接转成字符串。
  Map<String, dynamic> convertCatalog(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    for (final entry in {
      'providers': 'provider',
      'models': 'model',
      'sentinels': 'sentinel',
    }.entries) {
      final rows = data[entry.key];
      if (rows is! List) continue;
      result[entry.key] = [
        for (final value in rows)
          if (value is Map)
            {
              ...Map<String, dynamic>.from(value),
              'id': id(entry.value, value['id']),
              if (entry.key == 'models')
                'provider_id': id('provider', value['provider_id']),
            },
      ];
    }
    return result;
  }
}

/// 启动时的一次性格式升级。首次升级前须关闭所有旧版 GUI/TUI。
///
/// 先备份、再生成全部目标文件、最后写 ready 清单；ready 后的提交可重复
/// 执行。格式版本最后落盘，因此中断后不会把半迁移目录当作可用仓储。
/// 两个新版进程同时启动时由同一把跨进程迁移锁串行。
class StorageIdMigration {
  StorageIdMigration({
    required this.root,
    required this.settingFile,
    required LockRegistry locks,
  }) : _locks = locks;

  static const version = 2;
  final Directory root;
  final File settingFile;

  /// 锁放哪由它决定,见 [LockRegistry]。
  final LockRegistry _locks;
  final _ids = LegacyIdMap();

  File get versionFile => File(p.join(root.path, 'storage_version.json'));
  Directory get _work => Directory(p.join(root.path, '.id-migration-v2'));
  Directory get _backup => Directory(p.join(root.path, 'backups', 'ids-v1'));
  File get _journal => File(p.join(_work.path, 'ready.json'));

  Future<Map<String, String>>
  run() => withFileLock(_locks.named('storage-migration'), () async {
    if (await versionFile.exists()) {
      final state = jsonDecode(await versionFile.readAsString()) as Map;
      if (state['version'] != version) {
        throw StateError('Unsupported storage version: ${state['version']}');
      }
      return Map<String, String>.from(state['legacy_model_ids'] as Map? ?? {});
    }
    if (!await _journal.exists()) await _prepare();
    final journal = jsonDecode(await _journal.readAsString()) as Map;
    final entries = (journal['files'] as List).cast<Map>();
    // 所有新文件先落盘，再清理旧文件名；断电后可用同一清单重放。
    for (final entry in entries) {
      final target = entry['target'] as String?;
      if (target == null) continue;
      final staged = File(p.join(_work.path, entry['staged'] as String));
      await atomicWriteString(_file(target), await staged.readAsString());
    }
    for (final entry in entries) {
      if (entry['source'] == entry['target']) continue;
      final source = _file(entry['source'] as String);
      if (await source.exists()) await source.delete();
    }
    final models = Map<String, String>.from(journal['legacy_model_ids'] as Map);
    await atomicWriteString(
      versionFile,
      jsonEncode({'version': version, 'legacy_model_ids': models}),
    );
    await _work.delete(recursive: true);
    return models;
  });

  File _file(String key) {
    if (key == '@settings') return settingFile;
    final target = p.normalize(p.join(root.path, key));
    if (!p.isWithin(p.normalize(root.path), target)) {
      throw FormatException('Invalid migration path: $key');
    }
    return File(target);
  }

  Future<void> _prepare() async {
    if (await _work.exists()) await _work.delete(recursive: true);
    await _work.create(recursive: true);
    final inputs = <String, File>{};
    for (final name in [
      'models.json',
      'sentinels.json',
      'meta.json',
      'kv.json',
    ]) {
      final file = _file(name);
      if (await file.exists()) inputs[name] = file;
    }
    if (await settingFile.exists()) inputs['@settings'] = settingFile;
    for (final name in [
      'sessions',
      'experiences',
      'sentinels',
      'background_tasks',
    ]) {
      final dir = Directory(p.join(root.path, name));
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File &&
            ['.json', '.jsonl'].contains(p.extension(entity.path))) {
          inputs[p.relative(entity.path, from: root.path)] = entity;
        }
      }
    }
    // 备份保留原始字节（包括坏行），不能用已解析的行重建备份。
    for (final entry in inputs.entries) {
      final backup = File(
        p.join(
          _backup.path,
          entry.key == '@settings' ? 'setting.yaml' : entry.key,
        ),
      );
      if (!await backup.exists()) {
        await backup.parent.create(recursive: true);
        final temporary = File('${backup.path}.tmp');
        await entry.value.copy(temporary.path);
        await temporary.rename(backup.path);
      }
    }
    final files = <Map<String, dynamic>>[];
    final targets = <String>{};
    for (final entry in inputs.entries) {
      final source = entry.key;
      if (source == 'meta.json') {
        files.add({'source': source, 'target': null});
        continue;
      }
      var target = source;
      final text = await entry.value.readAsString(
        encoding: const Utf8Codec(allowMalformed: true),
      );
      String output;
      if (source == '@settings') {
        final raw = _decode(text, yaml: true);
        final settings = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        if (settings['providers'] is List) {
          settings['providers'] = (_ids.convertCatalog({
            'providers': settings['providers'],
          }))['providers'];
          _checkUnique((settings['providers'] as List).cast<Map>(), source);
        }
        // JSON 是 YAML 的子集，保留未知设置字段与标量的原始类型。
        output = const JsonEncoder.withIndent('  ').convert(settings);
      } else if (source == 'models.json' || source == 'sentinels.json') {
        final raw = _decode(text);
        final key = source == 'models.json' ? 'models' : 'sentinels';
        final rows = _ids.convertCatalog({
          key: raw is List ? raw : <Object?>[],
        })[key];
        _checkUnique((rows as List).cast<Map>(), source);
        output = jsonEncode(rows);
      } else if (p.split(source).first == 'sessions') {
        final rows = <Map<String, dynamic>>[];
        for (final line in const LineSplitter().convert(text)) {
          if (line.trim().isEmpty) continue;
          final value = _decode(line);
          if (value is Map) rows.add(Map<String, dynamic>.from(value));
        }
        final chats = rows.where((row) => row['type'] == 'chat').toList();
        if (chats.length != 1) {
          // 缺失头部的会话不参与迁移，原文件仍在完整备份中。
          LoggerUtil.w('ID migration skipped invalid session: $source');
          files.add({'source': source, 'target': null});
          continue;
        }
        final chat = chats.single;
        final oldChat = chat['id'];
        final chatId = _ids.id('chat', oldChat);
        final messageKind = 'message:$oldChat';
        chat['id'] = chatId;
        chat['model_id'] = _ids.id('model', chat['model_id']);
        chat['sentinel_id'] = _ids.sentinel(chat['sentinel_id']);
        var seq = 0;
        for (final row in rows.where((row) => row['type'] == 'message')) {
          final oldId = row['id'];
          // 原整数 ID 即原有顺序，保留空洞使摘要 throughMessageId 无损转换。
          final next = oldId is int ? oldId : row['seq'] as int? ?? seq + 1;
          if (next <= seq) {
            throw FormatException('Non-increasing message order: $source');
          }
          row['seq'] = seq = next;
          row['id'] = _ids.id(messageKind, oldId);
          row['chat_id'] = chatId;
          if ((row['role'] == 'summary' || row['role'] == 'compaction') &&
              row['reference'] is String &&
              (row['reference'] as String).isNotEmpty) {
            final data =
                jsonDecode(row['reference'] as String) as Map<String, dynamic>;
            if (data['coveredMessageIds'] is List) {
              data['coveredMessageIds'] = [
                for (final id in data['coveredMessageIds'] as List)
                  _ids.id(messageKind, id),
              ];
            }
            if (data.containsKey('throughMessageId')) {
              data['throughSeq'] = data.remove('throughMessageId');
            }
            if (data.containsKey('compactionId')) {
              data['compactionId'] = '$chatId:${row['id']}';
            }
            row['reference'] = jsonEncode(data);
          }
          for (final key in [
            'responses_state',
            'messages_state',
            'chat_completions_state',
          ]) {
            final state = row[key];
            if (state is! String || state.isEmpty) continue;
            final data = _decode(state);
            if (data is Map && data['provider_id'] != null) {
              data['provider_id'] = _ids.id('provider', data['provider_id']);
              row[key] = jsonEncode(data);
            }
          }
        }
        _checkUnique(rows.where((row) => row['type'] == 'message'), source);
        target = p.join('sessions', '$chatId.jsonl');
        output = '${rows.map(jsonEncode).join('\n')}\n';
      } else {
        final raw = _decode(text);
        final parts = p.split(source);
        if (raw is Map && parts.first == 'experiences') {
          final old = raw['sentinel_id'];
          if (old != null && old != 'shared' && old != 'direct') {
            final mapped = _ids.id('sentinel', int.tryParse('$old') ?? old);
            raw['sentinel_id'] = mapped;
            target = p.join('experiences', mapped, p.basename(source));
          }
        } else if (raw is Map &&
            parts.first == 'sentinels' &&
            raw['sentinel'] is Map) {
          final sentinel = raw['sentinel'] as Map;
          final mapped = _ids.id('sentinel', sentinel['id']);
          sentinel['id'] = mapped;
          target = p.join(
            'sentinels',
            'by-id',
            mapped,
            'history',
            p.basename(source),
          );
        } else if (raw is List && parts.first == 'background_tasks') {
          for (final task in raw.whereType<Map>()) {
            if (task['chat_id'] != null) {
              task['chat_id'] = _ids.id('chat', task['chat_id']);
            }
          }
        }
        output = raw == null ? text : jsonEncode(raw);
      }
      if (!targets.add(target)) {
        throw FormatException('Duplicate migration target: $target');
      }
      // 路径也须在 ready 前验证，避免提交到一半才发现非法目标。
      _file(target);
      final staged = '${files.length}.new';
      await atomicWriteString(File(p.join(_work.path, staged)), output);
      files.add({'source': source, 'target': target, 'staged': staged});
    }
    await atomicWriteString(
      _journal,
      jsonEncode({
        'files': files,
        'legacy_model_ids': _ids.values['model'] ?? <String, String>{},
      }),
    );
  }

  Object? _decode(String text, {bool yaml = false}) {
    try {
      // yaml 的 Map/List 只读；经 JSON 往返得到可修改的普通集合。
      return yaml ? jsonDecode(jsonEncode(loadYaml(text))) : jsonDecode(text);
    } catch (error) {
      LoggerUtil.w('ID migration preserved corrupt data in backup');
      return null;
    }
  }

  void _checkUnique(Iterable<Map> rows, String source) {
    final ids = <Object?>{};
    for (final row in rows) {
      if (!ids.add(row['id'])) throw FormatException('Duplicate ID in $source');
    }
  }
}
