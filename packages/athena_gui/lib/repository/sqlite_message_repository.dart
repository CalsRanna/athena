import 'package:athena_gui/database/database.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/repository/message_repository.dart';

/// [MessageRepository] 的 SQLite 实现（GUI 侧）。
class SqliteMessageRepository
    implements MessageRepository, RecentMessageRepository {
  @override
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

  @override
  Future<List<MessageEntity>> loadRecentMessages(
    int chatId, {
    required int count,
    int? beforeId,
  }) async {
    if (count <= 0) return [];

    var query = Database.instance.laconic
        .table('messages')
        .where('chat_id', chatId);
    if (beforeId != null) {
      query = query.where('id', beforeId, comparator: '<');
    }
    final results = await query
        .orderBy('id', direction: 'desc')
        .limit(count)
        .get();
    return results.reversed
        .map((result) => MessageEntity.fromJson(result.toMap()))
        .toList();
  }

  @override
  Future<MessageEntity?> getMessageById(int id) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('messages').where('id', id).first();
      return MessageEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<int> storeMessage(MessageEntity message) async {
    var laconic = Database.instance.laconic;
    var json = message.toJson();
    json.remove('id');
    return await laconic.table('messages').insertGetId(json);
  }

  @override
  Future<void> updateMessage(MessageEntity message) async {
    if (message.id == null) return;
    var laconic = Database.instance.laconic;
    var json = message.toJson();
    json.remove('id');
    await laconic.table('messages').where('id', message.id).update(json);
  }

  @override
  Future<void> deleteMessage(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('messages').where('id', id).delete();
  }

  @override
  Future<void> deleteMessagesByChatId(int chatId) async {
    var laconic = Database.instance.laconic;
    await laconic.table('messages').where('chat_id', chatId).delete();
  }

  @override
  Future<int> getMessagesCount(int chatId) async {
    var laconic = Database.instance.laconic;
    return await laconic.table('messages').where('chat_id', chatId).count();
  }

  @override
  Future<void> markAsCompacted(Set<int> ids) async {
    if (ids.isEmpty) return;
    var laconic = Database.instance.laconic;
    final placeholders = ids.map((_) => '?').join(',');
    await laconic.statement(
      'UPDATE messages SET compacted = 1 WHERE id IN ($placeholders)',
      ids.toList(),
    );
  }

  @override
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
