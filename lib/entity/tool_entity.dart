class ToolEntity {
  final int? id;
  final String name;
  final String key;
  final String description;

  ToolEntity({
    this.id,
    required this.name,
    required this.key,
    this.description = '',
  });

  factory ToolEntity.fromJson(Map<String, dynamic> json) {
    return ToolEntity(
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      key: json['key'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'key': key,
      'description': description,
    };
  }

  ToolEntity copyWith({
    int? id,
    String? name,
    String? key,
    String? description,
  }) {
    return ToolEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      key: key ?? this.key,
      description: description ?? this.description,
    );
  }
}
