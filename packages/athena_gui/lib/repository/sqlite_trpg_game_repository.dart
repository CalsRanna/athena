import 'package:athena_gui/database/database.dart';
import 'package:athena_gui/entity/trpg_game_entity.dart';
import 'package:athena_gui/repository/trpg_game_repository.dart';

/// [TRPGGameRepository] 的 SQLite 实现（GUI 侧）。
class SqliteTRPGGameRepository implements TRPGGameRepository {
  @override
  Future<List<TRPGGameEntity>> getAllGames() async {
    var laconic = Database.instance.laconic;
    var results = await laconic
        .table('trpg_games')
        .orderBy('updated_at', direction: 'desc')
        .get();

    return results.map((r) => TRPGGameEntity.fromJson(r.toMap())).toList();
  }

  @override
  Future<TRPGGameEntity?> getGameById(int id) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('trpg_games').where('id', id).first();
      return TRPGGameEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<int> createGame(TRPGGameEntity game) async {
    var laconic = Database.instance.laconic;
    var json = game.toJson();
    json.remove('id'); // 移除 id,让数据库自动生成
    return await laconic.table('trpg_games').insertGetId(json);
  }

  @override
  Future<void> updateGame(TRPGGameEntity game) async {
    if (game.id == null) return;
    var laconic = Database.instance.laconic;
    var json = game.toJson();
    json.remove('id');
    await laconic.table('trpg_games').where('id', game.id).update(json);
  }

  @override
  Future<void> deleteGame(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('trpg_games').where('id', id).delete();
    // 需要手动删除关联的消息
    await laconic.table('trpg_messages').where('game_id', id).delete();
  }

  @override
  Future<int> getGamesCount() async {
    var laconic = Database.instance.laconic;
    return await laconic.table('trpg_games').count();
  }

  @override
  Future<List<TRPGGameWithPreview>> getAllGamesWithPreview() async {
    var laconic = Database.instance.laconic;
    var sql = '''
      SELECT
        g.*,
        COALESCE(m.content, '') as preview_content
      FROM trpg_games g
      LEFT JOIN (
        SELECT game_id, content
        FROM trpg_messages m1
        WHERE role = 'dm' AND id = (
          SELECT MIN(id) FROM trpg_messages m2
          WHERE m2.game_id = m1.game_id AND m2.role = 'dm'
        )
      ) m ON g.id = m.game_id
      ORDER BY g.updated_at DESC
    ''';

    var results = await laconic.select(sql);
    return results.map((r) {
      var map = r.toMap();
      return TRPGGameWithPreview(
        game: TRPGGameEntity.fromJson(map),
        previewContent: (map['preview_content'] as String?) ?? '',
      );
    }).toList();
  }
}
