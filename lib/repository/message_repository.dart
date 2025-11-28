import 'package:athena/database/database.dart';
import 'package:athena/entity/message_entity.dart';

class MessageRepository {
  Future<List<MessageEntity>> getMessagesByChatId(int chatId) async {
    var laconic = Database.instance.laconic;
    var results = await laconic
        .table('messages')
        .where('chat_id', chatId)
        .orderBy('id')
        .get();
    return results.map((r) => MessageEntity.fromJson(r.toMap())).toList();
  }

  Future<MessageEntity?> getMessageById(int id) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('messages').where('id', id).first();
      return MessageEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  Future<int> storeMessage(MessageEntity message) async {
    var laconic = Database.instance.laconic;
    var json = message.toJson();
    json.remove('id');
    await laconic.table('messages').insert([json]);

    var result = await laconic.select('SELECT last_insert_rowid() as id');
    return result.first['id'] as int;
  }

  Future<void> updateMessage(MessageEntity message) async {
    if (message.id == null) return;
    var laconic = Database.instance.laconic;
    var json = message.toJson();
    json.remove('id');
    await laconic.table('messages').where('id', message.id).update(json);
  }

  Future<void> deleteMessage(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('messages').where('id', id).delete();
  }

  Future<void> deleteMessagesByChatId(int chatId) async {
    var laconic = Database.instance.laconic;
    await laconic.table('messages').where('chat_id', chatId).delete();
  }

  Future<int> getMessagesCount(int chatId) async {
    var laconic = Database.instance.laconic;
    return await laconic.table('messages').where('chat_id', chatId).count();
  }

  Future<MessageEntity?> getLatestMessageByChatId(int chatId) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic
          .table('messages')
          .where('chat_id', chatId)
          .orderBy('id', direction: 'desc')
          .limit(1)
          .first();
      return MessageEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }
}
