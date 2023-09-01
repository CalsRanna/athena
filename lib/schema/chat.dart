import 'package:isar/isar.dart';

part 'chat.g.dart';

@collection
@Name('chats')
class Chat {
  Id id = Isar.autoIncrement;
  List<Message> messages = [];
  String model = '';
  String? title;
  @Name('updated_at')
  int? updatedAt;
}

@embedded
class Message {
  String? content;
  String? role;

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

extension ChatExtension on Chat {
  // 因为isar为了性能考虑，在返回数组时会返回FixedList，为了能够执行add等操作，需要通过
  // toList转换为GrowableList
  Chat withGrowableMessages() => this..messages = messages.toList();
}
