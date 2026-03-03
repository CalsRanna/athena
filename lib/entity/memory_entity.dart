class MemoryEntity {
  final String content;
  final int lastChatId;
  final DateTime lastChatUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  MemoryEntity({
    this.content = '',
    this.lastChatId = 0,
    DateTime? lastChatUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : lastChatUpdatedAt = lastChatUpdatedAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory MemoryEntity.fromJson(Map<String, dynamic> json) {
    return MemoryEntity(
      content: json['content'] as String? ?? '',
      lastChatId: json['last_chat_id'] as int? ?? 0,
      lastChatUpdatedAt: json['last_chat_updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['last_chat_updated_at'] as int,
            )
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'last_chat_id': lastChatId,
      'last_chat_updated_at': lastChatUpdatedAt.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  MemoryEntity copyWith({
    String? content,
    int? lastChatId,
    DateTime? lastChatUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemoryEntity(
      content: content ?? this.content,
      lastChatId: lastChatId ?? this.lastChatId,
      lastChatUpdatedAt: lastChatUpdatedAt ?? this.lastChatUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
