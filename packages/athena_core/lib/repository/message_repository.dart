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

/// 可选的消息游标分页能力。
///
/// 返回 [beforeId] 之前、最接近游标的最近 [count] 条消息；未提供游标时
/// 返回会话最新的 [count] 条。结果始终按 id 升序排列。
abstract interface class RecentMessageRepository {
  Future<List<MessageEntity>> loadRecentMessages(
    int chatId, {
    required int count,
    int? beforeId,
  });
}
