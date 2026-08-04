import 'package:athena_core/entity/trpg_message_entity.dart';

/// TRPG 消息存储接口。持久化策略由实现方决定。
abstract class TRPGMessageRepository {
  Future<List<TRPGMessageEntity>> getMessagesByGameId(int gameId);

  Future<int> createMessage(TRPGMessageEntity message);

  Future<void> deleteMessagesByGameId(int gameId);

  Future<void> deleteMessage(int messageId);

  Future<int> getMessagesCountByGameId(int gameId);
}
