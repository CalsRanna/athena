import 'package:athena/database/database.dart';
import 'package:athena/entity/trpg_message_entity.dart';

class TRPGMessageRepository {
  Future<List<TRPGMessageEntity>> getMessagesByGameId(int gameId) async {
    var laconic = Database.instance.laconic;
    var results = await laconic
        .table('trpg_messages')
        .where('game_id', gameId)
        .orderBy('created_at', direction: 'asc')
        .get();

    return results.map((r) => TRPGMessageEntity.fromJson(r.toMap())).toList();
  }

  Future<int> createMessage(TRPGMessageEntity message) async {
    var laconic = Database.instance.laconic;
    var json = message.toJson();
    json.remove('id'); // 移除 id,让数据库自动生成
    await laconic.table('trpg_messages').insert([json]);

    // 获取最后插入的 id
    var result = await laconic.select('SELECT last_insert_rowid() as id');
    return result.first['id'] as int;
  }

  Future<void> deleteMessagesByGameId(int gameId) async {
    var laconic = Database.instance.laconic;
    await laconic.table('trpg_messages').where('game_id', gameId).delete();
  }

  Future<void> deleteMessage(int messageId) async {
    var laconic = Database.instance.laconic;
    await laconic.table('trpg_messages').where('id', messageId).delete();
  }

  Future<int> getMessagesCountByGameId(int gameId) async {
    var laconic = Database.instance.laconic;
    return await laconic.table('trpg_messages').where('game_id', gameId).count();
  }
}
