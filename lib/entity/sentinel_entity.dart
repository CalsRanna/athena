import 'dart:convert';

class SentinelEntity {
  final int? id;
  final String name;
  final String avatar;
  final String description;
  final String prompt;
  final List<String> tags;

  SentinelEntity({
    this.id,
    required this.name,
    this.avatar = '',
    this.description = '',
    this.prompt = '',
    this.tags = const [],
  });

  factory SentinelEntity.fromJson(Map<String, dynamic> json) {
    List<String> tagsList = [];
    if (json['tags'] != null) {
      if (json['tags'] is String) {
        // 如果是JSON字符串,解析它
        try {
          tagsList = List<String>.from(jsonDecode(json['tags'] as String));
        } catch (e) {
          // 如果解析失败,尝试按逗号分割
          tagsList = (json['tags'] as String).split(',').map((e) => e.trim()).toList();
        }
      } else if (json['tags'] is List) {
        tagsList = List<String>.from(json['tags']);
      }
    }

    return SentinelEntity(
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      description: json['description'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      tags: tagsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'avatar': avatar,
      'description': description,
      'prompt': prompt,
      'tags': jsonEncode(tags), // 存储为JSON字符串
    };
  }

  SentinelEntity copyWith({
    int? id,
    String? name,
    String? avatar,
    String? description,
    String? prompt,
    List<String>? tags,
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
