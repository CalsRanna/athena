import 'package:athena_gui/database/database.dart';
import 'package:athena_core/entity/trpg_message_entity.dart';
import 'package:athena_core/repository/trpg_message_repository.dart';

/// [TRPGMessageRepository] 的 SQLite 实现（GUI 侧）。
class SqliteTRPGMessageRepository implements TRPGMessageRepository {
  @override
  Future<List<TRPGMessageEntity>> getMessagesByGameId(int gameId) async {
    var laconic = Database.instance.laconic;
    var results = await laconic
        .table('trpg_messages')
        .where('game_id', gameId)
        .orderBy('created_at', direction: 'asc')
        .orderBy('id', direction: 'asc')
        .get();

    return results.map((r) => TRPGMessageEntity.fromJson(r.toMap())).toList();
  }

  @override
  Future<int> createMessage(TRPGMessageEntity message) async {
    var laconic = Database.instance.laconic;
    var json = message.toJson();
    json.remove('id'); // 移除 id,让数据库自动生成
    return await laconic.table('trpg_messages').insertGetId(json);
  }

  @override
  Future<void> deleteMessagesByGameId(int gameId) async {
    var laconic = Database.instance.laconic;
    await laconic.table('trpg_messages').where('game_id', gameId).delete();
  }

  @override
  Future<void> deleteMessage(int messageId) async {
    var laconic = Database.instance.laconic;
    await laconic.table('trpg_messages').where('id', messageId).delete();
  }

  @override
  Future<int> getMessagesCountByGameId(int gameId) async {
    var laconic = Database.instance.laconic;
    return await laconic
        .table('trpg_messages')
        .where('game_id', gameId)
        .count();
  }
}
