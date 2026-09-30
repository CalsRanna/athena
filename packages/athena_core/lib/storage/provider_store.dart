import 'dart:async';
import 'dart:io';

import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:athena_core/util/yaml_scalar.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// 每 provider 一个 YAML 文件的存储(`~/.athena/providers/{id}.yaml`)。
///
/// 取代旧的 `setting.yaml` 里那个 `providers:` 数组段:一个 provider 一个
/// 文件,新增/删除自定义 provider 不必再动含全部 API key 的大文件;单个文件
/// 损坏也只影响它自己(旧布局下一次 YAML 语法错误就让整个 provider 列表读成
/// 空,下次写入把所有人的 key 一起抹掉)。
///
/// **文件名就是身份**。`id` 取自文件名,文件里的 `id:` 字段只为可读性写出、
/// 读时忽略——于是手工复制一个文件就得到一个新身份的 provider,不必先想好
/// 新 UUID(副本里那行旧 id 会在它第一次被保存时改写)。
///
/// id 会拼进文件路径,因此限定为单个文件名段([_validId]);否则 `../x` 这样
/// 的 id 会写到目录外去(导入的 JSON 备份里带什么 id 由文件说了算)。
///
/// 锁粒度是**每个 provider 一把**([lockFileFor] 给出的 `{id}.yaml.lock`),
/// GUI 与 TUI 编辑不同 provider 时互不阻塞;列表级操作(清空后导入)另取
/// 目录锁(`providers.lock`)与列举互斥。两把锁按「目录锁 → 文件锁」的方向
/// 获取,不存在反向路径,因此不会死锁。
///
/// 锁文件不随数据文件删除:文件锁按 inode 记账,删掉一个正被别处持有的锁
/// 文件会让后来者在新 inode 上加锁,互斥就此失效。删除 provider 会留下空的
/// `{id}.yaml.lock`,这是刻意的。
class ProviderStore {
  ProviderStore({required Directory directory}) : _directory = directory;

  final Directory _directory;

  static const _extension = '.yaml';

  /// id 直接拼进文件名,必须限制为单个文件名段(与经验的 id 校验同口径)。
  static final _validId = RegExp(r'^[A-Za-z0-9_-]+$');

  /// id 是否存在且可作为文件名段。
  static bool isValidId(String id) => _validId.hasMatch(id);

  /// [id] 对应的数据文件。
  File fileFor(String id) => File(p.join(_directory.path, '$id$_extension'));

  /// 目录级锁:与 [lockFileFor] 对文件的关系一致,只是目标换成目录。
  /// 放在目录外侧(`providers.lock`),不与数据文件混在同一个目录里。
  File get _directoryLock => File('${_directory.path}.lock');

  /// 全部 provider(按文件名列举,顺序不定;排序由仓储层决定)。
  ///
  /// **不加锁**。旧实现(`JsonArrayStore.readAll`)同样不加锁,理由一致:写入
  /// 是「原子替换」(临时文件 + rename),读到的要么是旧文件要么是新文件,
  /// 不会看到写了一半的内容。这一点在本项目尤其重要——widget 测试跑在
  /// fake-async 里,`FileLock.blockingExclusive` 在那里永远不返回,加锁的读会
  /// 让整个界面初始化挂死。
  ///
  /// 代价是可能撞见 [replaceAll](导入)的中间态(清空后、逐个写回前)。导入
  /// 是用户显式触发的短操作,紧随其后的读取会看到最终状态,可以接受;要让
  /// 列举与导入互斥就得让所有读都排队,不划算。
  ///
  /// 单个文件损坏时跳过并告警,不影响其余 provider。
  Future<List<ProviderEntity>> list() async {
    if (!await _directory.exists()) return <ProviderEntity>[];
    final entities = <ProviderEntity>[];
    await for (final entry in _directory.list()) {
      if (entry is! File || !entry.path.endsWith(_extension)) continue;
      final entity = await _readFile(entry);
      if (entity != null) entities.add(entity);
    }
    return entities;
  }

  /// 读取单个 provider;不存在或损坏返回 null。不加锁,理由见 [list]。
  Future<ProviderEntity?> read(String id) async {
    if (!_validId.hasMatch(id)) return null;
    final file = fileFor(id);
    if (!await file.exists()) return null;
    return _readFile(file);
  }

  /// 覆盖写入(不存在则创建)。[ProviderEntity.id] 必须非空。
  ///
  /// 目标已存在但读不出来时(手工编辑写出语法错误)先备份再覆盖:这里是盲写,
  /// 不像 [mutate] 那样本来就要读一次,若不额外检查,损坏文件里的 API key 会
  /// 被整文件覆盖直接抹掉。
  Future<void> write(ProviderEntity provider) {
    final id = provider.id;
    if (id == null || !_validId.hasMatch(id)) {
      throw ArgumentError('Invalid provider id: $id');
    }
    final file = fileFor(id);
    return withFileLock(lockFileFor(file), () async {
      if (await file.exists()) await _readFile(file, forWrite: true);
      await _writeFile(file, provider);
    });
  }

  /// 读-改-写单个 provider:全过程持该文件的跨进程锁。
  ///
  /// [transform] 拿到锁内读到的最新实体,返回新实体写回;返回 null 表示本次
  /// 不改写(调用方的守卫条件不满足)。文件不存在或损坏时不做任何事并返回
  /// false——「更新一个已被删除的 provider」不应把它复活。
  ///
  /// 与旧实现(读整个文件、改、再写回整个文件)的差别正在这里:同步进程只
  /// 需要关心它要改的那一个 provider,外层的凭据编辑不会被旧快照盖回去。
  Future<bool> mutate(
    String id,
    ProviderEntity? Function(ProviderEntity current) transform,
  ) {
    if (!_validId.hasMatch(id)) return Future.value(false);
    final file = fileFor(id);
    return withFileLock(lockFileFor(file), () async {
      if (!await file.exists()) return false;
      final current = await _readFile(file, forWrite: true);
      if (current == null) return false;
      final updated = transform(current);
      if (updated == null) return false;
      await _writeFile(file, updated);
      return true;
    });
  }

  /// 删除单个 provider(不存在视为成功)。
  Future<void> delete(String id) {
    if (!_validId.hasMatch(id)) return Future.value();
    final file = fileFor(id);
    return withFileLock(lockFileFor(file), () async {
      if (await file.exists()) await file.delete();
    });
  }

  /// 整目录替换为 [providers](导入用):先清空再写入,持目录锁。
  ///
  /// 每个实体的 id 必须非空(导入的数据带着原 id 进来);缺 id 的调用方应先
  /// 补齐,否则无从决定文件名。逐个写入时各自取该文件的锁,与并发的单条
  /// 编辑按「谁后写谁赢」排队。
  Future<void> replaceAll(List<ProviderEntity> providers) {
    return withFileLock(_directoryLock, () async {
      for (final provider in providers) {
        final id = provider.id;
        if (id == null || !_validId.hasMatch(id)) {
          throw ArgumentError('Invalid provider id: $id');
        }
      }
      if (await _directory.exists()) {
        await for (final entry in _directory.list()) {
          if (entry is! File || !entry.path.endsWith(_extension)) continue;
          await entry.delete();
        }
      }
      for (final provider in providers) {
        final file = fileFor(provider.id!);
        await withFileLock(lockFileFor(file), () => _writeFile(file, provider));
      }
    });
  }

  /// 清空全部 provider;不触碰锁文件(见类注释)。
  Future<void> deleteAll() => replaceAll(const []);

  /// provider 文件数。只数文件、不解析内容;id 不合法的文件(如手工放进去的
  /// 备注文件)不计入。不加锁,理由见 [list]。
  ///
  /// 注意与 [list] 的口径不同:损坏的文件这里照样计入。仓储层的
  /// `getProvidersCount` 走的是 [list].length(损坏即视为不存在),这里留给
  /// 需要「磁盘上有几个文件」的场景。
  Future<int> count() async {
    if (!await _directory.exists()) return 0;
    var total = 0;
    await for (final entry in _directory.list()) {
      if (entry is! File || !entry.path.endsWith(_extension)) continue;
      if (_validId.hasMatch(p.basenameWithoutExtension(entry.path))) total++;
    }
    return total;
  }

  // ---------------------------------------------------------------------------
  // 解析与编码
  // ---------------------------------------------------------------------------

  /// 把单个 provider 文件的 YAML 映射解析成实体。
  ///
  /// 字段缺失或类型不符一律降级(空串 / false / 纪元时间)而不是抛错:这个
  /// 目录标明可以手工编辑,一处笔误不该让整个 provider 消失。旧布局
  /// (`setting.yaml` 的 `providers:` 段)的解析口径与此完全相同,迁移
  /// 过来的文件读出来是同一个实体。
  static ProviderEntity parseYaml(String id, Map raw) {
    return ProviderEntity(
      id: id,
      // 防御:手工编辑可能写入非字符串值(如裸数字被 YAML 解析为 int),
      // 降级为空串而不是抛类型错误
      name: raw['name'] is String ? raw['name'] as String : '',
      baseUrl: raw['baseUrl'] is String ? raw['baseUrl'] as String : '',
      apiKey: raw['apiKey'] is String ? raw['apiKey'] as String : '',
      apiFormat: ApiFormat.tryParse(raw['apiFormat']),
      apiFormatAuto: raw['apiFormatAuto'] is bool
          ? raw['apiFormatAuto'] as bool
          : null,
      enabled: raw['enabled'] == true,
      isPreset: raw['isPreset'] == true,
      createdAt: raw['createdAt'] is String
          ? DateTime.tryParse(raw['createdAt'] as String) ??
                DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// 实体的 YAML 文本。键名保持旧 `setting.yaml` 的 camelCase 拼写,迁移前后
  /// 的文件长相一致,手工编辑的经验可以直接沿用。
  static String encode(ProviderEntity provider) {
    final buf = StringBuffer()
      ..writeln('# Athena provider 配置:可手工编辑,重启生效')
      ..writeln('# 文件名(去掉 .yaml)就是它的 id,不要与别的文件重名')
      ..writeln();
    buf.writeln('id: ${YamlScalarCodec.encode(provider.id)}');
    buf.writeln('name: ${YamlScalarCodec.encode(provider.name)}');
    buf.writeln('baseUrl: ${YamlScalarCodec.encode(provider.baseUrl)}');
    buf.writeln('apiKey: ${YamlScalarCodec.encode(provider.apiKey)}');
    buf.writeln(
      'apiFormat: ${YamlScalarCodec.encode(provider.apiFormat.value)}',
    );
    buf.writeln('apiFormatAuto: ${provider.apiFormatAuto}');
    buf.writeln('enabled: ${provider.enabled}');
    buf.writeln('isPreset: ${provider.isPreset}');
    buf.writeln(
      'createdAt: ${YamlScalarCodec.encode(provider.createdAt.toIso8601String())}',
    );
    return buf.toString();
  }

  /// [forWrite] 为 true 时(写锁内、随后要覆盖这个文件)遇到损坏内容先备份成
  /// `.corrupt-{时间戳}`:这个目录可以手工编辑,一个语法错误不该让下一次写入
  /// 把 API key 永久抹掉。
  Future<ProviderEntity?> _readFile(File file, {bool forWrite = false}) async {
    final id = p.basenameWithoutExtension(file.path);
    if (!_validId.hasMatch(id)) {
      LoggerUtil.w('Provider file ${file.path} has an invalid id, skipped');
      return null;
    }
    try {
      final raw = loadYaml(await file.readAsString());
      // 空文件 / 只有注释时 loadYaml 返回 null,按缺失处理
      if (raw == null) return null;
      if (raw is! Map) {
        throw const FormatException('provider file is not a map');
      }
      return parseYaml(id, raw);
    } catch (e) {
      if (forWrite) {
        final backup = await preserveCorruptFile(file);
        LoggerUtil.w('${file.path} is corrupt ($e), backed up to $backup');
      } else {
        LoggerUtil.w('Provider file ${file.path} is unreadable ($e), skipped');
      }
      return null;
    }
  }

  /// 写入 [file] 对应的实体。id 以**文件名**为准写回,避免手工改名后文件里
  /// 那行旧 id 与文件名长期不一致。调用方须已持有该文件的锁。
  Future<void> _writeFile(File file, ProviderEntity provider) async {
    final id = p.basenameWithoutExtension(file.path);
    await atomicWriteString(file, encode(provider.copyWith(id: id)));
  }
}
