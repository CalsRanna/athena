import 'package:athena_core/entity/message_entity.dart';

/// 消息存储接口。持久化策略由实现方决定（GUI=SQLite，TUI=JSONL 等）。
abstract class MessageRepository {
  /// 获取聊天消息，[includeCompacted] 为 false 时排除已被 compact 压缩的消息。
  Future<List<MessageEntity>> getMessagesByChatId(
    int chatId, {
    bool includeCompacted = true,
  });

  Future<MessageEntity?> getMessageById(int id);

  Future<int> storeMessage(MessageEntity message);

  Future<void> updateMessage(MessageEntity message);

  Future<void> deleteMessage(int id);

  Future<void> deleteMessagesByChatId(int chatId);

  Future<int> getMessagesCount(int chatId);

  /// 批量标记消息为已压缩。
  Future<void> markAsCompacted(Set<int> ids);

  Future<MessageEntity?> getLatestMessageByChatId(int chatId);
}
