class SummaryEntity {
  final int id;
  final String link;
  final String title;
  final String content;
  final String icon;
  final DateTime createdAt;

  SummaryEntity({
    required this.id,
    required this.link,
    required this.title,
    required this.content,
    required this.icon,
    required this.createdAt,
  });

  factory SummaryEntity.fromJson(Map<String, dynamic> json) {
    return SummaryEntity(
      id: json['id'] as int,
      link: json['link'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != 0) 'id': id,
      'link': link,
      'title': title,
      'content': content,
      'icon': icon,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  SummaryEntity copyWith({
    int? id,
    String? link,
    String? title,
    String? content,
    String? icon,
    DateTime? createdAt,
  }) {
    return SummaryEntity(
      id: id ?? this.id,
      link: link ?? this.link,
      title: title ?? this.title,
      content: content ?? this.content,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
