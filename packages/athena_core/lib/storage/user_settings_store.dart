import 'dart:io';

import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:yaml/yaml.dart';

/// 用户配置的持久化(`~/.athena/setting.yaml`):provider 配置(含 API key)
/// 与 TUI 选择的默认模型。GUI 与 TUI 共享此文件。
///
/// yaml 是**provider 的权威存储**(jsonl 只存消息/数据流水):
/// - provider 的 name/baseUrl/apiKey 等直接读写 yaml,用户可手工编辑,
///   重启即生效
/// - 模型选择存 modelId 字符串(如 `deepseek-v4-flash`),稳定可读,
///   不依赖本地自增 id(仅 TUI 使用;GUI 的默认模型存 SharedPreferences)
///
/// 文件格式:
/// ```yaml
/// # Athena 用户配置
/// model: deepseek-v4-flash      # 默认模型(modelId,可选)
/// providers:
///   - id: 1                     # 与 models.json 的 providerId 对应
///     name: Deep Seek
///     baseUrl: https://api.deepseek.com/v1
///     apiKey: sk-xxx
///     apiFormat: chat_completions # 请求协议（LlmClient 按此分派）
///     apiFormatAuto: true         # false 时保留手动配置
///     enabled: false
///     isPreset: true
/// ```
///
/// 写入采用原子替换(临时文件 + rename),避免写一半损坏文件。
class UserSettingsStore {
  UserSettingsStore({required File file}) : _file = file;

  final File _file;

  /// 配置文件(供仓储层对其加跨进程锁)。
  File get file => _file;

  static const _modelKey = 'model';
  static const _providersKey = 'providers';

  /// 读取所有 provider 配置(按 yaml 顺序)。
  Future<List<ProviderEntity>> loadProviders() async {
    final map = await _readMap();
    final providers = map[_providersKey];
    if (providers is! List) return [];
    final result = <ProviderEntity>[];
    for (final entry in providers) {
      if (entry is! Map) continue;
      result.add(ProviderEntity(
        id: entry['id'] is int ? entry['id'] as int : null,
        // 防御:手工编辑/历史数据可能写入非字符串值(如裸数字被 YAML
        // 解析为 int),降级为空字符串而不是抛类型错误炸掉整个配置
        name: entry['name'] is String ? entry['name'] as String : '',
        baseUrl: entry['baseUrl'] is String ? entry['baseUrl'] as String : '',
        apiKey: entry['apiKey'] is String ? entry['apiKey'] as String : '',
        apiFormat: ApiFormat.tryParse(entry['apiFormat']),
        apiFormatAuto: entry['apiFormatAuto'] is bool
            ? entry['apiFormatAuto'] as bool
            : null,
        enabled: entry['enabled'] == true,
        isPreset: entry['isPreset'] == true,
        createdAt: entry['createdAt'] is String
            ? DateTime.tryParse(entry['createdAt'] as String) ??
                DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.fromMillisecondsSinceEpoch(0),
      ));
    }
    return result;
  }

  /// 保存全部 provider 配置(整段覆写)。调用方须持有 [file] 的写锁
  /// (`YamlProviderRepository` 的读-改-写都在锁内)。
  Future<void> saveProviders(List<ProviderEntity> providers) async {
    final map = await _readMap(forWrite: true);
    map[_providersKey] = [
      for (final provider in providers)
        {
          if (provider.id != null) 'id': provider.id,
          'name': provider.name,
          'baseUrl': provider.baseUrl,
          'apiKey': provider.apiKey,
          'apiFormat': provider.apiFormat.value,
          'apiFormatAuto': provider.apiFormatAuto,
          'enabled': provider.enabled,
          'isPreset': provider.isPreset,
          'createdAt': provider.createdAt.toIso8601String(),
        },
    ];
    await _writeMap(map);
  }

  /// 读取持久化的默认模型(modelId 字符串,可能为 null)。
  Future<String?> loadModelId() async {
    final map = await _readMap();
    final value = map[_modelKey];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// 保存默认模型(modelId 字符串)。
  ///
  /// 会把 providers 段整体读出再写回,必须在跨进程锁内:否则与 GUI 同时
  /// 保存 API key 时,这里手里的旧列表会把对方的修改盖掉。
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
  /// 这个文件标明可以手工编辑,一个 YAML 语法错误不能让下一次写入把全部
  /// provider 与 API key 清空。
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
          for (final key in [_modelKey, _providersKey])
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
      ..writeln('# Athena 用户配置:各 provider 的 API key 与 TUI 默认模型')
      ..writeln('# 修改后重启生效;运行中配置会同步回写')
      ..writeln();
    for (final entry in map.entries) {
      final value = entry.value;
      if (value is List) {
        buf.writeln('${entry.key}:');
        for (final item in value) {
          if (item is! Map) continue;
          if (item['id'] != null) {
            buf.writeln('  - id: ${_escapeScalar(item['id'])}');
          } else {
            buf.writeln('  - id: ""');
          }
          buf.writeln('    name: ${_escapeScalar(item['name'])}');
          buf.writeln('    baseUrl: ${_escapeScalar(item['baseUrl'])}');
          buf.writeln('    apiKey: ${_escapeScalar(item['apiKey'])}');
          // 保存默认模型时列表仍是原始 YAML，保留缺省字段的自动模式语义。
          if (item.containsKey('apiFormat')) {
            buf.writeln('    apiFormat: ${_escapeScalar(item['apiFormat'])}');
          }
          if (item['apiFormatAuto'] is bool) {
            buf.writeln('    apiFormatAuto: ${item['apiFormatAuto']}');
          }
          buf.writeln('    enabled: ${item['enabled'] == true}');
          buf.writeln('    isPreset: ${item['isPreset'] == true}');
          buf.writeln('    createdAt: ${_escapeScalar(item['createdAt'])}');
        }
      } else if (value is int || value is String) {
        buf.writeln('${entry.key}: ${_escapeScalar(value)}');
      }
    }
    await atomicWriteString(_file, buf.toString());
  }

  static String _escapeScalar(Object? value) {
    if (value == null) return '""';
    if (value is int) return value.toString();
    final s = value.toString();
    if (s.isEmpty) return '""';
    // 字符串总是双引号:不引号的标量会被 YAML 解析为 int/bool/null/日期,
    // 读回时类型不符导致配置整体丢失(如纯数字 API key、'true'、'null')。
    // id 是唯一的 int 字段,走上面的分支保持裸值。
    final buf = StringBuffer('"');
    for (final unit in s.codeUnits) {
      if (unit == 0x5C) {
        buf.write(r'\\');
      } else if (unit == 0x22) {
        buf.write(r'\"');
      } else if (unit == 0x0A) {
        buf.write(r'\n');
      } else if (unit == 0x09) {
        buf.write(r'\t');
      } else if (unit == 0x0D) {
        buf.write(r'\r');
      } else if (unit < 0x20) {
        buf.write('\\u${unit.toRadixString(16).padLeft(4, '0')}');
      } else {
        buf.writeCharCode(unit);
      }
    }
    buf.write('"');
    return buf.toString();
  }
}
