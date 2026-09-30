import 'dart:io';

import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/provider_store.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:athena_core/util/yaml_scalar.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// 一次性升级:`setting.yaml` 里的 `providers:` 数组段 → 每 provider 一个
/// 文件(`providers/{id}.yaml`),并从 setting.yaml 移除该段。
///
/// 与 `StorageIdMigration` 同一时点执行、同一前置条件(首次升级前关闭所有
/// 旧版 GUI/TUI),但两者互不依赖:本迁移只搬运已经不缺 id 的 provider,
/// 整数 id 早已由前者转换完毕。
///
/// 顺序上先备份、再写文件、最后才改 setting.yaml:任何一步中断都停在「旧
/// setting.yaml 仍在、新文件已写出一部分」的状态,重跑时 [list]/[read] 会跳过
/// 已写出的那些而只补剩下的。反过来(先清空 setting.yaml 再写文件)一旦中途
/// 失败就永久丢掉全部 API key。
///
/// 完成后在 `providers/` 下留一个 `.version` 标记:没有它时,一个空目录与
/// 「尚未迁移」无法区分——用户删光全部 provider 是合法状态,不能因为目录
/// 空了就在下次启动把已清空的段又搬回来(那时它已被移除,搬不回来,但会把
/// 「已完成」误判成「待迁移」)。
class ProviderFilesMigration {
  ProviderFilesMigration({
    required Directory root,
    required File settingFile,
    required Directory providersDir,
  }) : _root = root,
       _settingFile = settingFile,
       _providersDir = providersDir;

  static const version = 1;

  final Directory _root;
  final File _settingFile;
  final Directory _providersDir;

  static const _providersKey = 'providers';

  File get _marker => File(p.join(_providersDir.path, '.version'));
  File get _lockFile =>
      File(p.join(_root.path, '.provider-files-migration.lock'));

  Future<void> run() {
    return withFileLock(_lockFile, () async {
      if (await _marker.exists()) return;
      if (!await _settingFile.exists()) {
        await _writeMarker();
        return;
      }
      final map = await _readSetting();
      final providers = map[_providersKey];
      if (providers is! List) {
        // 没有 providers 段:新装或已迁移过的旧版本,直接落标记
        await _writeMarker();
        return;
      }

      final backup = await _backupSetting();
      await _writeProviderFiles(providers);
      map.remove(_providersKey);
      await _writeSetting(map);
      await _writeMarker();
      LoggerUtil.i(
        'Provider files: migrated ${providers.length} providers '
        'to ${_providersDir.path} (setting.yaml backed up to $backup)',
      );
    });
  }

  /// 把旧数组段写成独立文件。
  ///
  /// 先整体校验再落盘:一个 id 不合法就整批中止并保留原 setting.yaml,而不是
  /// 写出一半再失败——半迁移的目录加上已被移除的段才是真正的数据丢失。
  /// id 会拼进文件名,必须是单个文件名段。
  ///
  /// 单个条目损坏(不是映射)跳过而不是中止:整个数组里只有一条有语法毛病时,
  /// 让其余 provider 正常迁移比全都不动更有用,原 setting.yaml 也还在备份里。
  Future<void> _writeProviderFiles(List<dynamic> providers) async {
    final entries = <(String, Map)>[];
    for (final value in providers) {
      if (value is! Map) {
        LoggerUtil.w('Provider files: skipping a non-map provider entry');
        continue;
      }
      final id = value['id'];
      if (id is! String || !ProviderStore.isValidId(id)) {
        throw FormatException(
          'Provider with invalid id cannot be migrated: $id',
        );
      }
      entries.add((id, value));
    }
    for (final (id, value) in entries) {
      final file = File(p.join(_providersDir.path, '$id.yaml'));
      await atomicWriteString(file, _encodeEntry(id, value));
    }
  }

  /// 单个旧条目 → 新文件文本。键名与 [ProviderStore.encode] 一致,只是这里
  /// 从原始 YAML 映射出发:迁移不做字段级解释,把用户手写的额外键也一起带
  /// 过去(本迁移只管搬家,不管内容对错)。
  static String _encodeEntry(String id, Map value) {
    final buf = StringBuffer()
      ..writeln('# Athena provider 配置:可手工编辑,重启生效')
      ..writeln('# 文件名(去掉 .yaml)就是它的 id,不要与别的文件重名')
      ..writeln();
    buf.writeln('id: ${YamlScalarCodec.encode(id)}');
    for (final entry in value.entries) {
      final key = entry.key;
      if (key == 'id') continue;
      if (key is! String) continue;
      buf.writeln('$key: ${YamlScalarCodec.encode(entry.value)}');
    }
    return buf.toString();
  }

  Future<Map<String, dynamic>> _readSetting() async {
    try {
      final raw = loadYaml(await _settingFile.readAsString());
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (e) {
      LoggerUtil.w('${_settingFile.path} is unreadable ($e), skipped');
    }
    return {};
  }

  /// 把整个 setting.yaml 复制成 `.pre-provider-files-{时间戳}` 的独立备份。
  ///
  /// 用 [preserveCorruptFile] 那套 `.corrupt-` 命名会让读者以为文件损坏;
  /// 这里显式给一个说明迁移的标记。备份是整文件复制(不是解析后重建),
  /// 坏行与未知字段原样保留。
  Future<File> _backupSetting() async {
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backup = File('${_settingFile.path}.pre-provider-files-$stamp');
    await _settingFile.copy(backup.path);
    return backup;
  }

  /// 写回移除 providers 段后的 setting.yaml,保留其余键与标量类型。
  ///
  /// 接受全部标量类型(bool / num / String),不只是 int 与 String:这个文件
  /// 现在由两个前端共用,存着主题、字号、窗口尺寸这类 bool 与 double 偏好。
  /// 按旧口径只写 int/String 的话,一条 providers 段的迁移会把它们静默抹掉。
  Future<void> _writeSetting(Map<String, dynamic> map) async {
    final buf = StringBuffer()
      ..writeln('# Athena 用户配置:GUI 与 TUI 共用,可手工编辑')
      ..writeln('# 修改后重启生效;运行中配置会同步回写')
      ..writeln();
    for (final entry in map.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is bool || value is num || value is String) {
        buf.writeln('${entry.key}: ${YamlScalarCodec.encode(value)}');
      }
    }
    await atomicWriteString(_settingFile, buf.toString());
  }

  Future<void> _writeMarker() async {
    await atomicWriteString(_marker, 'version: $version\n');
  }
}
