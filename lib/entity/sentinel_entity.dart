import 'package:athena/extension/json_map_extension.dart';

class SentinelEntity {
  final int? id;
  final String name;
  final String avatar;
  final String description;
  final String prompt;
  final String tags;

  SentinelEntity({
    this.id,
    required this.name,
    this.avatar = '',
    this.description = '',
    this.prompt = '',
    this.tags = '',
  });

  factory SentinelEntity.fromJson(Map<String, dynamic> json) {
    return SentinelEntity(
      id: json.getIntOrNull('id'),
      name: json.getString('name'),
      avatar: json.getString('avatar'),
      description: json.getString('description'),
      prompt: json.getString('prompt'),
      tags: json.getString('tags'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'avatar': avatar,
      'description': description,
      'prompt': prompt,
      'tags': tags,
    };
  }

  /// 将 tags 字符串转换为列表，用于页面渲染
  List<String> get tagList {
    if (tags.isEmpty) return [];
    return tags.split(',').map((e) => e.trim()).toList();
  }

  SentinelEntity copyWith({
    int? id,
    String? name,
    String? avatar,
    String? description,
    String? prompt,
    String? tags,
  }) {
    return SentinelEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      description: description ?? this.description,
      prompt: prompt ?? this.prompt,
      tags: tags ?? this.tags,
    );
  }
}
