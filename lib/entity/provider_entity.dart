import 'package:athena/extension/json_map_extension.dart';

class ProviderEntity {
  final int? id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final bool enabled;
  final bool isPreset;
  final DateTime createdAt;

  ProviderEntity({
    this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    this.enabled = false,
    this.isPreset = false,
    required this.createdAt,
  });

  factory ProviderEntity.fromJson(Map<String, dynamic> json) {
    return ProviderEntity(
      id: json.getIntOrNull('id'),
      name: json.getString('name'),
      baseUrl: json.getString('base_url'),
      apiKey: json.getString('api_key'),
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
    bool? enabled,
    bool? isPreset,
    DateTime? createdAt,
  }) {
    return ProviderEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      enabled: enabled ?? this.enabled,
      isPreset: isPreset ?? this.isPreset,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
