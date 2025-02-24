import 'package:isar/isar.dart';

part 'chat.g.dart';

@collection
@Name('chats')
class Chat {
  Id id = Isar.autoIncrement;
  bool enableSearch = false;
  String title = '';
  int modelId = 0;
  @Name('sentinel_id')
  int sentinelId = 0;
  @Name('created_at')
  DateTime createdAt = DateTime.now();
  @Name('updated_at')
  DateTime updatedAt = DateTime.now();

  Chat copyWith({
    int? id,
    bool? enableSearch,
    String? title,
    int? modelId,
    int? sentinelId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Chat()
      ..id = id ?? this.id
      ..enableSearch = enableSearch ?? this.enableSearch
      ..title = title ?? this.title
      ..modelId = modelId ?? this.modelId
      ..sentinelId = sentinelId ?? this.sentinelId
      ..createdAt = createdAt ?? this.createdAt
      ..updatedAt = updatedAt ?? this.updatedAt;
  }
}

@collection
@Name('messages')
class Message {
  Id id = Isar.autoIncrement;
  String content = '';
  bool reasoning = false;
  @Name('reasoning_content')
  String reasoningContent = '';
  String role = 'user';
  @Name('reasoning_started_at')
  DateTime reasoningStartedAt = DateTime.now();
  @Name('reasoning_updated_at')
  DateTime reasoningUpdatedAt = DateTime.now();
  @Name('chat_id')
  int chatId = 0;

  Message();

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message()
      ..content = json['content']
      ..reasoningContent = json['reasoning_content'] ?? ''
      ..role = json['role'];
  }

  Message copyWith({
    int? id,
    String? content,
    bool? reasoning,
    String? reasoningContent,
    String? role,
    DateTime? reasoningStartedAt,
    DateTime? reasoningUpdatedAt,
    int? chatId,
  }) {
    return Message()
      ..id = id ?? this.id
      ..content = content ?? this.content
      ..reasoning = reasoning ?? this.reasoning
      ..reasoningContent = reasoningContent ?? this.reasoningContent
      ..role = role ?? this.role
      ..reasoningStartedAt = reasoningStartedAt ?? this.reasoningStartedAt
      ..reasoningUpdatedAt = reasoningUpdatedAt ?? this.reasoningUpdatedAt
      ..chatId = chatId ?? this.chatId;
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'reasoning_content': reasoningContent,
      'role': role,
    };
  }

  @override
  String toString() {
    return toJson().toString();
  }
}
