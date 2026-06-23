import 'package:athena/database/database.dart';
import 'package:athena/entity/message_entity.dart';

class MessageRepository {
  /// 获取聊天消息，[includeCompacted] 为 false 时排除已被 compact 压缩的消息。
  Future<List<MessageEntity>> getMessagesByChatId(
    int chatId, {
    bool includeCompacted = true,
  }) async {
    var laconic = Database.instance.laconic;
    var query = laconic.table('messages').where('chat_id', chatId);
    if (!includeCompacted) {
      query = query.where('compacted', 0);
    }
    var results = await query.orderBy('id').get();
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
    return await laconic.table('messages').insertGetId(json);
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

  /// 批量标记消息为已压缩。
  Future<void> markAsCompacted(Set<int> ids) async {
    if (ids.isEmpty) return;
    var laconic = Database.instance.laconic;
    final placeholders = ids.map((_) => '?').join(',');
    await laconic.statement(
      'UPDATE messages SET compacted = 1 WHERE id IN ($placeholders)',
      ids.toList(),
    );
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
