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
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      description: json['description'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      tags: json['tags'] as String? ?? '',
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
