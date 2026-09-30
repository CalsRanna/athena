import 'dart:io';

import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:athena_core/util/yaml_scalar.dart';
import 'package:yaml/yaml.dart';

/// 用户配置的持久化(`~/.athena/setting.yaml`)。GUI 与 TUI 共享此文件。
///
/// 这里只剩 TUI 的默认模型;provider 配置(含 API key)自 v3 起一个 provider
/// 一个文件,见 `ProviderStore`。仍然保留这个文件而不是并进别处:它是用户
/// 可以直接改的偏好,与 provider 那种「一条一个文件」的数据不是一类东西。
///
/// 文件格式:
/// ```yaml
/// # Athena 用户配置
/// model: "deepseek-v4-flash"   # 默认模型(modelId,可选)
/// ```
///
/// 写入采用原子替换(临时文件 + rename),避免写一半损坏文件。
///
/// 旧版本在这里还存过 `providers:` 段,由 `ProviderFilesMigration` 在启动时
/// 摊成独立文件并移除该段;本类不再读写它。
class UserSettingsStore {
  UserSettingsStore({required File file}) : _file = file;

  final File _file;

  /// 配置文件(供仓储层对其加跨进程锁)。
  File get file => _file;

  static const _modelKey = 'model';

  /// 读取持久化的默认模型(modelId 字符串,可能为 null)。
  Future<String?> loadModelId() async {
    final map = await _readMap();
    final value = map[_modelKey];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// 保存默认模型(modelId 字符串)。
  Future<void> saveModelId(String modelId) {
    return withFileLock(lockFileFor(_file), () async {
      final map = await _readMap(forWrite: true);
      map[_modelKey] = modelId;
      await _writeMap(map);
    });
  }

  // ---------------------------------------------------------------------------
  // 内部
  // ---------------------------------------------------------------------------

  /// [forWrite] 为 true 时(写锁内、随后要整文件重写)遇到损坏文件先备份:
  /// 这个文件标明可以手工编辑,一个 YAML 语法错误不能让下一次写入把用户
  /// 的偏好清空。
  Future<Map<String, dynamic>> _readMap({bool forWrite = false}) async {
    if (!await _file.exists()) return {};
    try {
      final content = await _file.readAsString();
      final value = loadYaml(content);
      // 空文件 / 只有注释时 loadYaml 返回 null,属正常的空配置
      if (value == null) return {};
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        // 只保留已知键:丢弃旧 GUI 遗留的 currentModel/models 等脏段,
        // 避免下次写回时把它们一并写出
        return {
          for (final key in [_modelKey])
            if (map.containsKey(key)) key: map[key],
        };
      }
      throw const FormatException('top level is not a map');
    } catch (e) {
      // 损坏的 yaml 读时按空配置处理;写入前先留备份
      if (forWrite) {
        final backup = await preserveCorruptFile(_file);
        LoggerUtil.w('${_file.path} is corrupt ($e), backed up to $backup');
      }
    }
    return {};
  }

  Future<void> _writeMap(Map<String, dynamic> map) async {
    final buf = StringBuffer()
      ..writeln('# Athena 用户配置:TUI 默认模型')
      ..writeln('# 修改后重启生效;运行中配置会同步回写')
      ..writeln();
    for (final entry in map.entries) {
      final value = entry.value;
      if (value is int || value is String) {
        buf.writeln('${entry.key}: ${YamlScalarCodec.encode(value)}');
      }
    }
    await atomicWriteString(_file, buf.toString());
  }
}
