import 'package:athena/database/database.dart';
import 'package:athena/entity/trpg_game_entity.dart';

class TRPGGameRepository {
  Future<List<TRPGGameEntity>> getAllGames() async {
    var laconic = Database.instance.laconic;
    var results = await laconic
        .table('trpg_games')
        .orderBy('updated_at', direction: 'desc')
        .get();

    return results.map((r) => TRPGGameEntity.fromJson(r.toMap())).toList();
  }

  Future<TRPGGameEntity?> getGameById(int id) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('trpg_games').where('id', id).first();
      return TRPGGameEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  Future<int> createGame(TRPGGameEntity game) async {
    var laconic = Database.instance.laconic;
    var json = game.toJson();
    json.remove('id'); // 移除 id,让数据库自动生成
    await laconic.table('trpg_games').insert([json]);

    // 获取最后插入的 id
    var result = await laconic.select('SELECT last_insert_rowid() as id');
    return result.first['id'] as int;
  }

  Future<void> updateGame(TRPGGameEntity game) async {
    if (game.id == null) return;
    var laconic = Database.instance.laconic;
    var json = game.toJson();
    json.remove('id');
    await laconic.table('trpg_games').where('id', game.id).update(json);
  }

  Future<void> deleteGame(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('trpg_games').where('id', id).delete();
    // 需要手动删除关联的消息
    await laconic.table('trpg_messages').where('game_id', id).delete();
  }

  Future<int> getGamesCount() async {
    var laconic = Database.instance.laconic;
    return await laconic.table('trpg_games').count();
  }
}
