import 'package:isar/isar.dart';

part 'chat.g.dart';

@collection
@Name('chats')
class Chat {
  Id id = Isar.autoIncrement;
  String? title;
  List<Message> messages = [];
}

@embedded
class Message {
  String? role;
  String? content;
  @Name('created_at')
  int? createdAt;
}

extension ChatExtension on Chat {
  // 因为isar为了性能考虑，在返回数组时会返回FixedList，为了能够执行add等操作，需要通过
  // toList转换为GrowableList
  Chat withGrowableMessages() => this..messages = messages.toList();
}
