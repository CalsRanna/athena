class ChatEntity {
  final int? id;
  final String title;
  final int modelId;
  final int sentinelId;
  final double temperature;
  final int context;
  final bool enableSearch;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatEntity({
    this.id,
    required this.title,
    required this.modelId,
    required this.sentinelId,
    this.temperature = 1.0,
    this.context = 0,
    this.enableSearch = false,
    this.pinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatEntity.fromJson(Map<String, dynamic> json) {
    return ChatEntity(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      modelId: json['model_id'] as int? ?? 0,
      sentinelId: json['sentinel_id'] as int? ?? 0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 1.0,
      context: json['context'] as int? ?? 0,
      enableSearch: (json['enable_search'] as int?) == 1,
      pinned: (json['pinned'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        json['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'model_id': modelId,
      'sentinel_id': sentinelId,
      'temperature': temperature,
      'context': context,
      'enable_search': enableSearch ? 1 : 0,
      'pinned': pinned ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  ChatEntity copyWith({
    int? id,
    String? title,
    int? modelId,
    int? sentinelId,
    double? temperature,
    int? context,
    bool? enableSearch,
    bool? pinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      modelId: modelId ?? this.modelId,
      sentinelId: sentinelId ?? this.sentinelId,
      temperature: temperature ?? this.temperature,
      context: context ?? this.context,
      enableSearch: enableSearch ?? this.enableSearch,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

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
  })  : reasoningStartedAt = reasoningStartedAt ?? DateTime.now(),
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
          ? DateTime.fromMillisecondsSinceEpoch(json['reasoning_started_at'] as int)
          : DateTime.now(),
      reasoningUpdatedAt: json['reasoning_updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['reasoning_updated_at'] as int)
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
