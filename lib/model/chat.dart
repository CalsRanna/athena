import 'package:isar/isar.dart';

part 'chat.g.dart';

@collection
@Name('chats')
class Chat {
  Id id = Isar.autoIncrement;
  String? title;
  List<Message>? messages;
}

@embedded
class Message {
  String? role;
  String? content;
  @Name('created_at')
  int? createdAt;
}
