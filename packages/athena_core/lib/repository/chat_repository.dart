import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/chat_history_entity.dart';

/// 聊天（会话）存储接口。
///
/// 持久化策略由实现方决定：GUI 用 SQLite（[SqliteChatRepository]），
/// TUI 可用 JSONL 文件实现。
abstract class ChatRepository {
  Future<List<ChatEntity>> getAllChats();

  Future<ChatEntity?> getChatById(int id);

  Future<int> createChat(ChatEntity chat);

  /// 更新聊天。实现方注意：token_total / context_tokens / cached_tokens 三列
  /// 由独立写入路径（[recordUsage]）管理，整行覆盖写回会回退已累加/已覆盖值，
  /// 更新时应显式排除这三列，与增量路径解耦。
  Future<void> updateChat(ChatEntity chat);

  Future<void> deleteChat(int id);

  Future<List<ChatEntity>> getRecentChats({int limit = 10});

  /// 原子地累加 [chatId] 的 token_total 列 [delta]，
  /// 同时覆盖写 context_tokens 与 cached_tokens 快照列，不触碰 updatedAt。
  /// 返回累加后的最新行。
  Future<int> recordUsage(
    int chatId,
    int tokenDelta,
    int contextTokens,
    int cachedTokens,
  );

  Future<int> getChatsCount();

  /// 统计引用指定模型的 chat 数量,供模型目录清理下架模型时保护引用。
  Future<int> getChatCountByModelId(int modelId);

  Future<List<ChatEntity>> getChatsAfterId(int chatId, {int limit = 10});

  /// 获取所有聊天及其最后一条消息内容
  Future<List<ChatHistoryEntity>> getAllChatsWithLastMessage();
}
