import 'package:athena/schema/model.dart';
import 'package:isar/isar.dart';

part 'chat.g.dart';

@collection
@Name('chats')
class Chat {
  Id id = Isar.autoIncrement;
  List<Message> messages = [];
  final model = IsarLink<Model>();
  String? title;
  @Name('updated_at')
  int? updatedAt;
}

@embedded
class Message {
  @Name('created_at')
  int? createdAt;
  String? content;
  String? role;
}

extension ChatExtension on Chat {
  // 因为isar为了性能考虑，在返回数组时会返回FixedList，为了能够执行add等操作，需要通过
  // toList转换为GrowableList
  Chat withGrowableMessages() => this..messages = messages.toList();
}
