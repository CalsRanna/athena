class MessageEntity {
  final int? id;
  final int chatId;
  final String role;
  final String content;
  final String reasoningContent;
  final bool reasoning;
  final bool expanded;
  final String imageUrls;
  final String reference;
  final bool searching;
  final DateTime reasoningStartedAt;
  final DateTime reasoningUpdatedAt;

  MessageEntity({
    this.id,
    required this.chatId,
    required this.role,
    this.content = '',
    this.reasoningContent = '',
    this.reasoning = false,
    this.expanded = true,
    this.imageUrls = '',
    this.reference = '',
    this.searching = false,
    DateTime? reasoningStartedAt,
    DateTime? reasoningUpdatedAt,
  }) : reasoningStartedAt = reasoningStartedAt ?? DateTime.now(),
       reasoningUpdatedAt = reasoningUpdatedAt ?? DateTime.now();

  factory MessageEntity.fromJson(Map<String, dynamic> json) {
    return MessageEntity(
      id: json['id'] as int?,
      chatId: json['chat_id'] as int? ?? 0,
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      reasoningContent: json['reasoning_content'] as String? ?? '',
      reasoning: (json['reasoning'] as int?) == 1,
      expanded: (json['expanded'] as int?) == 1,
      imageUrls: json['image_urls'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      searching: (json['searching'] as int?) == 1,
      reasoningStartedAt: json['reasoning_started_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['reasoning_started_at'] as int,
            )
          : DateTime.now(),
      reasoningUpdatedAt: json['reasoning_updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['reasoning_updated_at'] as int,
            )
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'chat_id': chatId,
      'role': role,
      'content': content,
      'reasoning_content': reasoningContent,
      'reasoning': reasoning ? 1 : 0,
      'expanded': expanded ? 1 : 0,
      'image_urls': imageUrls,
      'reference': reference,
      'searching': searching ? 1 : 0,
      'reasoning_started_at': reasoningStartedAt.millisecondsSinceEpoch,
      'reasoning_updated_at': reasoningUpdatedAt.millisecondsSinceEpoch,
    };
  }

  MessageEntity copyWith({
    int? id,
    int? chatId,
    String? role,
    String? content,
    String? reasoningContent,
    bool? reasoning,
    bool? expanded,
    String? imageUrls,
    String? reference,
    bool? searching,
    DateTime? reasoningStartedAt,
    DateTime? reasoningUpdatedAt,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      role: role ?? this.role,
      content: content ?? this.content,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      reasoning: reasoning ?? this.reasoning,
      expanded: expanded ?? this.expanded,
      imageUrls: imageUrls ?? this.imageUrls,
      reference: reference ?? this.reference,
      searching: searching ?? this.searching,
      reasoningStartedAt: reasoningStartedAt ?? this.reasoningStartedAt,
      reasoningUpdatedAt: reasoningUpdatedAt ?? this.reasoningUpdatedAt,
    );
  }
}
