import 'package:athena/extension/json_map_extension.dart';

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
      id: json.getIntOrNull('id'),
      name: json.getString('name'),
      key: json.getString('key'),
      description: json.getString('description'),
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
