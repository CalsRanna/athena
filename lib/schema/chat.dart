import 'package:isar/isar.dart';

part 'chat.g.dart';

@collection
@Name('chats')
class Chat {
  Id id = Isar.autoIncrement;
  int context = 0;
  bool enableSearch = false;
  double temperature = 1.0;
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
    int? context,
    bool? enableSearch,
    double? temperature,
    String? title,
    int? modelId,
    int? sentinelId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Chat()
      ..id = id ?? this.id
      ..context = context ?? this.context
      ..enableSearch = enableSearch ?? this.enableSearch
      ..temperature = temperature ?? this.temperature
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
  bool expanded = true;
  String imageUrls = '';
  bool reasoning = false;
  @Name('reasoning_content')
  String reasoningContent = '';
  @Name('reasoning_started_at')
  DateTime reasoningStartedAt = DateTime.now();
  @Name('reasoning_updated_at')
  DateTime reasoningUpdatedAt = DateTime.now();
  String reference = '';
  String role = 'user';
  bool searching = false;
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
    bool? expanded,
    bool? reasoning,
    String? reasoningContent,
    DateTime? reasoningStartedAt,
    DateTime? reasoningUpdatedAt,
    String? role,
    bool? searching,
    String? reference,
    int? chatId,
  }) {
    return Message()
      ..id = id ?? this.id
      ..content = content ?? this.content
      ..expanded = expanded ?? this.expanded
      ..reasoning = reasoning ?? this.reasoning
      ..reasoningContent = reasoningContent ?? this.reasoningContent
      ..reasoningStartedAt = reasoningStartedAt ?? this.reasoningStartedAt
      ..reasoningUpdatedAt = reasoningUpdatedAt ?? this.reasoningUpdatedAt
      ..role = role ?? this.role
      ..searching = searching ?? this.searching
      ..reference = reference ?? this.reference
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
