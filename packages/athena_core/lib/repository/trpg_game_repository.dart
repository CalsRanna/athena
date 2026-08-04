import 'package:athena_core/entity/trpg_game_entity.dart';

/// 用于存档列表展示的数据类
class TRPGGameWithPreview {
  final TRPGGameEntity game;
  final String previewContent;

  TRPGGameWithPreview({required this.game, this.previewContent = ''});
}

/// TRPG 游戏存档存储接口。持久化策略由实现方决定。
abstract class TRPGGameRepository {
  Future<List<TRPGGameEntity>> getAllGames();

  Future<TRPGGameEntity?> getGameById(int id);

  Future<int> createGame(TRPGGameEntity game);

  Future<void> updateGame(TRPGGameEntity game);

  /// 删除游戏及其关联消息。
  Future<void> deleteGame(int id);

  Future<int> getGamesCount();

  /// 获取所有游戏及其第一条DM消息预览
  Future<List<TRPGGameWithPreview>> getAllGamesWithPreview();
}
