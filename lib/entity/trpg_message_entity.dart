class TRPGMessageEntity {
  final int? id;
  final int gameId;
  final String role;
  final String content;
  final DateTime createdAt;

  TRPGMessageEntity({
    this.id,
    required this.gameId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory TRPGMessageEntity.fromJson(Map<String, dynamic> json) {
    return TRPGMessageEntity(
      id: json['id'] as int?,
      gameId: json['game_id'] as int? ?? 0,
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'game_id': gameId,
      'role': role,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  TRPGMessageEntity copyWith({
    int? id,
    int? gameId,
    String? role,
    String? content,
    DateTime? createdAt,
  }) {
    return TRPGMessageEntity(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
