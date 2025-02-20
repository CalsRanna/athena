import 'package:isar/isar.dart';

part 'chat.g.dart';

@collection
@Name('chats')
class Chat {
  Id id = Isar.autoIncrement;
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
    String? title,
    int? modelId,
    int? sentinelId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Chat()
      ..id = id ?? this.id
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
  @Name('reasoning_content')
  String reasoningContent = '';
  String role = 'user';
  @Name('chat_id')
  int chatId = 0;

  Message();

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'reasoning_content': reasoningContent,
      'role': role,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message()
      ..content = json['content']
      ..reasoningContent = json['reasoning_content'] ?? ''
      ..role = json['role'];
  }

  @override
  String toString() {
    return toJson().toString();
  }
}
