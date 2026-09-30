import 'dart:io';

import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:athena_core/util/yaml_scalar.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// 一个目录、一个实体一个 YAML 文件的文件机制(provider / sentinel 共用)。
///
/// **文件名(去掉扩展名)就是实体的身份**。于是手工复制一个文件就得到一个新
/// 实体,不必先编造一个 UUID;实体文件里的 `id:` 只为可读性写出,读时以文件名
/// 为准。
///
/// id 会拼进文件路径,因此必须限定为单个文件名段([isValidId]);否则 `../x`
/// 这样的 id 会把文件写到目录外去——导入的 JSON 备份里带什么 id,由文件说了算。
///
/// 读写语义:
/// - **列举与单读不加锁**。写入是原子替换(临时文件 + rename),读到的要么是旧
///   文件要么是新文件,不会看到写了一半的内容。这不只是省一次加锁:widget
///   测试跑在 fake-async 里,`FileLock.blockingExclusive` 在那里永不返回,任何
///   加锁的读都会让界面初始化整个挂死。
/// - 写、删、读-改-写持**该文件**的跨进程锁;清空后重建持目录锁。
/// - 内容损坏时读按「不存在」处理;写入前先备份成 `.corrupt-{时间戳}`,
///   这个目录标明可以手工编辑,一个语法错误不该让下一次写入把内容抹掉。
///
/// 锁文件不在数据目录里:它们由 [LockRegistry] 统一放在数据根的 `.locks/` 下,
/// 并镜像数据文件的相对路径(`sentinels/{id}.yaml` 的锁在
/// `.locks/sentinels/{id}.yaml.lock`)。所以遍历这个目录时只会看到数据文件与
/// `.version` 标记,不必再考虑锁文件。
///
/// 本类只搬运 `Map`,实体层的解析与编码由各自的 Store 负责。
class YamlEntityDirectory {
  YamlEntityDirectory({
    required Directory directory,
    required LockRegistry locks,
  }) : _directory = directory,
       _locks = locks;

  final Directory _directory;

  /// 锁放哪由它决定,见 [LockRegistry]。
  final LockRegistry _locks;

  static const extension = '.yaml';

  /// 实体 id 直接拼进文件名,必须限制为单个文件名段(与经验的 id 校验同口径)。
  static final _validId = RegExp(r'^[A-Za-z0-9_-]+$');

  static bool isValidId(String id) => _validId.hasMatch(id);

  Directory get directory => _directory;

  File fileFor(String id) => File(p.join(_directory.path, '$id$extension'));

  /// 目录级锁:`replaceAllRaw` 的「清空 + 重建」与并发的单条写互斥。
  File get _directoryLock => _locks.forDirectory(_directory);

  /// 目录下全部合法 id;实体文件之外的任何东西(id 不合法的文件、标记文件、
  /// 子目录)一律跳过。不加锁,理由见类注释。
  Future<List<String>> listIds() async {
    if (!await _directory.exists()) return const [];
    final ids = <String>[];
    await for (final entry in _directory.list()) {
      if (entry is! File || !entry.path.endsWith(extension)) continue;
      final id = p.basenameWithoutExtension(entry.path);
      if (_validId.hasMatch(id)) ids.add(id);
    }
    return ids;
  }

  /// 该 id 的原始映射;不存在或损坏返回 null。不加锁。
  Future<Map<String, dynamic>?> readRaw(
    String id, {
    bool forWrite = false,
  }) async {
    if (!_validId.hasMatch(id)) return null;
    final file = fileFor(id);
    if (!await file.exists()) return null;
    return _readFile(file, forWrite: forWrite);
  }

  /// 覆盖写入(不存在则创建)。持该文件的锁。
  ///
  /// 目标已存在但读不出来时(手工编辑写出语法错误)先备份再覆盖:这里是盲写,
  /// 不像 [mutateRaw] 那样本来就要读一次,不额外检查的话,损坏文件里的内容会被
  /// 整文件覆盖直接抹掉。
  Future<void> writeRaw(String id, Map<String, dynamic> raw) {
    _requireValidId(id);
    final file = fileFor(id);
    return withFileLock(_locks.forTarget(file), () async {
      if (await file.exists()) await _readFile(file, forWrite: true);
      await _writeFile(file, raw);
    });
  }

  /// 读-改-写:全过程持该文件的跨进程锁。
  ///
  /// [transform] 拿到锁内读到的最新内容,返回新内容写回;返回 null 表示本次不
  /// 改写(调用方的守卫条件不满足)。文件不存在或损坏时不做任何事并返回 false
  /// ——「更新一个已被删除的实体」不应把它复活。
  Future<bool> mutateRaw(
    String id,
    Map<String, dynamic>? Function(Map<String, dynamic> current) transform,
  ) {
    if (!_validId.hasMatch(id)) return Future.value(false);
    final file = fileFor(id);
    return withFileLock(_locks.forTarget(file), () async {
      if (!await file.exists()) return false;
      final current = await _readFile(file, forWrite: true);
      if (current == null) return false;
      final updated = transform(current);
      if (updated == null) return false;
      await _writeFile(file, updated);
      return true;
    });
  }

  /// 读-改-写,文件不存在时以空映射为基础创建。
  ///
  /// 与 [mutateRaw] 的差别只在「不存在怎么办」:那条路径刻意不复活已删除的
  /// 实体,这条是 upsert,用于「新建一个实体」。(损坏的文件仍按空映射处理并
  /// 备份,随后被新内容覆盖——那是 upsert 的应有语义。)
  Future<void> upsertRaw(
    String id,
    Map<String, dynamic> Function(Map<String, dynamic> current) transform,
  ) {
    _requireValidId(id);
    final file = fileFor(id);
    return withFileLock(_locks.forTarget(file), () async {
      final current = await file.exists()
          ? await _readFile(file, forWrite: true)
          : null;
      await _writeFile(file, transform(current ?? <String, dynamic>{}));
    });
  }

  /// 删除单个实体(不存在视为成功)。持该文件的锁。
  Future<void> deleteRaw(String id) {
    if (!_validId.hasMatch(id)) return Future.value();
    final file = fileFor(id);
    return withFileLock(_locks.forTarget(file), () async {
      if (await file.exists()) await file.delete();
    });
  }

  /// 整目录替换为 [rows](导入用):先清空再逐个写入,持目录锁。
  ///
  /// 逐个写入时各自取该文件的锁,与并发的单条编辑按「谁后写谁赢」排队。
  Future<void> replaceAllRaw(List<(String id, Map<String, dynamic> raw)> rows) {
    return withFileLock(_directoryLock, () async {
      for (final (id, _) in rows) {
        _requireValidId(id);
      }
      if (await _directory.exists()) {
        await for (final entry in _directory.list()) {
          if (entry is! File || !entry.path.endsWith(extension)) continue;
          if (!_validId.hasMatch(p.basenameWithoutExtension(entry.path))) {
            continue;
          }
          await entry.delete();
        }
      }
      for (final (id, raw) in rows) {
        final file = fileFor(id);
        await withFileLock(_locks.forTarget(file), () => _writeFile(file, raw));
      }
    });
  }

  /// 实体文件数。只数文件、不解析内容;id 不合法的文件不计入。不加锁。
  Future<int> count() async {
    if (!await _directory.exists()) return 0;
    var total = 0;
    await for (final entry in _directory.list()) {
      if (entry is! File || !entry.path.endsWith(extension)) continue;
      if (_validId.hasMatch(p.basenameWithoutExtension(entry.path))) total++;
    }
    return total;
  }

  void _requireValidId(String id) {
    if (!_validId.hasMatch(id)) {
      throw ArgumentError('Invalid entity id: $id');
    }
  }

  /// [forWrite] 为 true 时(写锁内、随后要覆盖这个文件)遇到损坏内容先备份成
  /// `.corrupt-{时间戳}`。
  Future<Map<String, dynamic>?> _readFile(
    File file, {
    bool forWrite = false,
  }) async {
    try {
      final raw = loadYaml(await file.readAsString());
      // 空文件 / 只有注释时 loadYaml 返回 null,按缺失处理
      if (raw == null) return null;
      if (raw is! Map) {
        throw const FormatException('file is not a YAML mapping');
      }
      return Map<String, dynamic>.from(raw);
    } catch (e) {
      if (forWrite) {
        final backup = await preserveCorruptFile(file);
        LoggerUtil.w('${file.path} is corrupt ($e), backed up to $backup');
      } else {
        LoggerUtil.w('${file.path} is unreadable ($e), skipped');
      }
      return null;
    }
  }

  Future<void> _writeFile(File file, Map<String, dynamic> raw) =>
      atomicWriteString(file, encodeYamlMap(raw));
}

/// 把一个映射写成 YAML 文本:键顺序即写入顺序,标量统一走 [YamlScalarCodec]。
///
/// 放在这里而不是各 Store 里,是因为 provider 与 sentinel 的顶层结构相同
/// (都是「标量键 + 一个可选的实体列表」);列表元素的具体字段由各自的 Store
/// 决定如何展开成 [YamlScalarCodec.encode] 可接受的标量。
String encodeYamlMap(Map<String, dynamic> raw) {
  final buf = StringBuffer();
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is List) {
      // 空列表也要写出(`models: []`):读回时「没有这个键」与「一个模型都没有」
      // 在语义上等同,但显式写出来,用户编辑时能看出这里可以加条目。
      buf.writeln('${entry.key}:${value.isEmpty ? ' []' : ''}');
      for (final item in value) {
        if (item is! Map) continue;
        buf.writeln('  - ${_encodeListEntry(item)}');
      }
    } else {
      buf.writeln('${entry.key}: ${YamlScalarCodec.encode(value)}');
    }
  }
  return buf.toString();
}

/// 列表元素:首行内联,其余键按两个空格缩进续写。
String _encodeListEntry(Map item) {
  final buf = StringBuffer();
  var first = true;
  for (final entry in item.entries) {
    final line = '${entry.key}: ${YamlScalarCodec.encode(entry.value)}';
    if (first) {
      buf.write(line);
      first = false;
    } else {
      buf.write('\n    $line');
    }
  }
  return buf.toString();
}
