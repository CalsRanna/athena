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
      id: json['id'] as int?,
      name: json['name'] as String,
      baseUrl: json['base_url'] as String,
      apiKey: json['api_key'] as String,
      enabled: json['enabled'] as bool,
      isPreset: json['is_preset'] as bool,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'base_url': baseUrl,
      'api_key': apiKey,
      'enabled': enabled,
      'is_preset': isPreset,
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
