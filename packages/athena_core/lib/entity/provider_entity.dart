import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/extension/json_map_extension.dart';

class ProviderEntity {
  final int? id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final ApiFormat apiFormat;

  /// 自动同步与手动选择分开记录，避免下一次目录同步覆盖用户配置。
  final bool apiFormatAuto;
  final bool enabled;
  final bool isPreset;
  final DateTime createdAt;

  ProviderEntity({
    this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    ApiFormat? apiFormat,
    bool? apiFormatAuto,
    this.enabled = false,
    this.isPreset = false,
    required this.createdAt,
  }) : apiFormat = apiFormat ?? ApiFormat.chatCompletions,
       apiFormatAuto = apiFormatAuto ?? (apiFormat == null);

  factory ProviderEntity.fromJson(Map<String, dynamic> json) {
    return ProviderEntity(
      id: json.getIntOrNull('id'),
      name: json.getString('name'),
      baseUrl: json.getString('base_url'),
      apiKey: json.getString('api_key'),
      apiFormat: ApiFormat.tryParse(json['api_format']),
      apiFormatAuto: json.containsKey('api_format_auto')
          ? json.getBool('api_format_auto')
          : null,
      enabled: json.getBool('enabled'),
      isPreset: json.getBool('is_preset'),
      createdAt: json.getDateTime('created_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'base_url': baseUrl,
      'api_key': apiKey,
      'api_format': apiFormat.value,
      'api_format_auto': apiFormatAuto,
      'enabled': enabled ? 1 : 0,
      'is_preset': isPreset ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  ProviderEntity copyWith({
    int? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    ApiFormat? apiFormat,
    bool? apiFormatAuto,
    bool? enabled,
    bool? isPreset,
    DateTime? createdAt,
  }) {
    return ProviderEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      apiFormat: apiFormat ?? this.apiFormat,
      apiFormatAuto: apiFormatAuto ??
          (apiFormat == null ? this.apiFormatAuto : false),
      enabled: enabled ?? this.enabled,
      isPreset: isPreset ?? this.isPreset,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
