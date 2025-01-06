import 'package:isar/isar.dart';

part 'chat.g.dart';

@collection
@Name('chats')
class Chat {
  Id id = Isar.autoIncrement;
  String model = '';
  @Name('sentinel_id')
  int sentinelId = 0;
  String title = '';
  @Name('created_at')
  DateTime createdAt = DateTime.now();
  @Name('updated_at')
  DateTime updatedAt = DateTime.now();

  Chat copyWith({
    int? id,
    String? model,
    String? title,
    int? sentinelId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Chat()
      ..id = id ?? this.id
      ..model = model ?? this.model
      ..sentinelId = sentinelId ?? this.sentinelId
      ..title = title ?? this.title
      ..createdAt = createdAt ?? this.createdAt
      ..updatedAt = updatedAt ?? this.updatedAt;
  }
}

@collection
@Name('messages')
class Message {
  Id id = Isar.autoIncrement;
  String content = '';
  String role = 'user';
  @Name('chat_id')
  int chatId = 0;

  Message();

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'role': role,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message()
      ..content = json['content']
      ..role = json['role'];
  }

  @override
  String toString() {
    return toJson().toString();
  }
}

@collection
@Name('sentinels')
class Sentinel {
  Id id = Isar.autoIncrement;
  String avatar = '';
  String name = '';
  String description = '';
  String prompt = '';
  List<String> tags = [];

  Sentinel();

  Sentinel copyWith({
    int? id,
    String? avatar,
    String? name,
    String? description,
    String? prompt,
    List<String>? tags,
  }) {
    return Sentinel()
      ..id = id ?? this.id
      ..avatar = avatar ?? this.avatar
      ..name = name ?? this.name
      ..description = description ?? this.description
      ..prompt = prompt ?? this.prompt
      ..tags = tags ?? this.tags;
  }
}
