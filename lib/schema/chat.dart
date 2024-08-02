import 'package:isar/isar.dart';

part 'chat.g.dart';

@collection
@Name('chats')
class Chat {
  Id id = Isar.autoIncrement;
  String model = '';
  @Name('sentinel_id')
  int sentinelId = 0;
  String? title;
  @Name('created_at')
  DateTime createdAt = DateTime.now();
  @Name('updated_at')
  DateTime updatedAt = DateTime.now();

  Chat copyWith({String? model, String? title, DateTime? updatedAt}) {
    return Chat()
      ..id = id
      ..model = model ?? this.model
      ..sentinelId = sentinelId
      ..title = title ?? this.title
      ..createdAt = createdAt
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
  String name = '';
  String description = '';
  String prompt = '';
}
