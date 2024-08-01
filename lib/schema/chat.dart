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

  Chat copyWith({String? model, String? title}) {
    return Chat()
      ..model = model ?? this.model
      ..title = title ?? this.title
      ..updatedAt = DateTime.now();
  }
}

@collection
@Name('messages')
class Message {
  Id id = Isar.autoIncrement;
  String? content;
  String? role;
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
