import 'dart:io';

import 'package:athena_core/entity/provider_entity.dart';
import 'package:yaml/yaml.dart';

/// 用户配置的持久化(`~/.athena/setting.yaml`):provider 配置(含 API key)
/// 与用户选择的默认模型。
///
/// yaml 是**用户配置的权威存储**(jsonl 只存消息/数据流水):
/// - provider 的 name/baseUrl/apiKey 等直接读写 yaml,用户可手工编辑,
///   重启即生效
/// - 模型选择存 modelId 字符串(如 `deepseek-v4-flash`),稳定可读,
///   不依赖本地自增 id
///
/// 文件格式:
/// ```yaml
/// # Athena TUI 用户配置
/// model: deepseek-v4-flash      # 默认模型(modelId,可选)
/// providers:
///   - id: 1                     # 与 models.jsonl 的 providerId 对应
///     name: Deep Seek
///     baseUrl: https://api.deepseek.com/v1
///     apiKey: sk-xxx
///     enabled: false
///     isPreset: true
/// ```
///
/// 写入采用原子替换(临时文件 + rename),避免写一半损坏文件。
class UserSettingsStore {
  UserSettingsStore({required File file}) : _file = file;

  final File _file;

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
        name: entry['name'] as String? ?? '',
        baseUrl: entry['baseUrl'] as String? ?? '',
        apiKey: entry['apiKey'] as String? ?? '',
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

  /// 保存全部 provider 配置(整段覆写)。
  Future<void> saveProviders(List<ProviderEntity> providers) async {
    final map = await _readMap();
    map[_providersKey] = [
      for (final provider in providers)
        {
          if (provider.id != null) 'id': provider.id,
          'name': provider.name,
          'baseUrl': provider.baseUrl,
          'apiKey': provider.apiKey,
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
  Future<void> saveModelId(String modelId) async {
    final map = await _readMap();
    map[_modelKey] = modelId;
    await _writeMap(map);
  }

  // ---------------------------------------------------------------------------
  // 内部
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _readMap() async {
    if (!await _file.exists()) return {};
    try {
      final content = await _file.readAsString();
      final value = loadYaml(content);
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        // 只保留已知键:丢弃旧 GUI 遗留的 currentModel/models 等脏段,
        // 避免下次写回时把它们一并写出
        return {
          for (final key in [_modelKey, _providersKey])
            if (map.containsKey(key)) key: map[key],
        };
      }
    } catch (_) {
      // 损坏的 yaml 按空配置处理(不覆盖,等下次写入重建)
    }
    return {};
  }

  Future<void> _writeMap(Map<String, dynamic> map) async {
    await _file.parent.create(recursive: true);
    final tmp = File('${_file.path}.tmp');
    final buf = StringBuffer()
      ..writeln('# Athena TUI 用户配置:默认模型与各 provider 的 API key')
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
          buf.writeln('    enabled: ${item['enabled'] == true}');
          buf.writeln('    isPreset: ${item['isPreset'] == true}');
          buf.writeln('    createdAt: ${_escapeScalar(item['createdAt'])}');
        }
      } else if (value is int || value is String) {
        buf.writeln('${entry.key}: ${_escapeScalar(value)}');
      }
    }
    await tmp.writeAsString(buf.toString());
    // rename 目标目录必须已存在:单独确保一次
    await _file.parent.create(recursive: true);
    await tmp.rename(_file.path);
  }

  static String _escapeScalar(Object? value) {
    if (value == null) return '""';
    final s = value.toString();
    if (s.isEmpty) return '""';
    // 需要引号:含特殊字符或可能被解析为其他类型
    if (RegExp(r'^[A-Za-z0-9_./:+-]+$').hasMatch(s)) return s;
    return '"${s.replaceAll('"', '\\"')}"';
  }
}
