import 'package:athena_core/entity/message_entity.dart';

/// 消息存储接口。文件实现见 `storage/jsonl_session_repository.dart`。
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

  /// 会话开头那一轮的 agent 回答正文,供侧栏悬浮预览使用。
  ///
  /// 取「首条用户消息之后紧跟的第一条有正文的 assistant 消息」——这次对话
  /// 问的第一句换来的答复,而不是最新消息(最新一条可能只是工具步骤或
  /// 尚未收尾的占位)。会话还没有这样的回答(首轮仍在跑、首条回答为空)
  /// 时返回空串。
  Future<String> getOpeningAnswerPreview(int chatId);
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
