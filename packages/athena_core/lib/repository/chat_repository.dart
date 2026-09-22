import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/chat_history_entity.dart';

/// 聊天（会话）存储接口。
///
/// 文件实现见 `storage/jsonl_session_repository.dart`（GUI 与 TUI 共用）。
abstract class ChatRepository {
  Future<List<ChatEntity>> getAllChats();

  Future<ChatEntity?> getChatById(int id);

  Future<int> createChat(ChatEntity chat);

  /// 更新聊天。实现方注意：context_tokens / cached_tokens 两列由独立写入
  /// 路径（[recordUsage]）管理，整行覆盖写回会回退已覆盖的快照，
  /// 更新时应显式排除这两列，与快照路径解耦。
  Future<void> updateChat(ChatEntity chat);

  Future<void> deleteChat(int id);

  Future<List<ChatEntity>> getRecentChats({int limit = 10});

  /// 覆盖写 [chatId] 的 context_tokens / cached_tokens 快照列（最近一次推理
  /// 的 prompt token 数与其中的缓存命中数），不触碰 updatedAt。
  ///
  /// 只记上下文，不累计会话总用量：指示器只关心上下文窗口占用。
  Future<void> recordUsage(int chatId, int contextTokens, int cachedTokens);

  Future<int> getChatsCount();

  /// 统计引用指定模型的 chat 数量,供模型目录清理下架模型时保护引用。
  Future<int> getChatCountByModelId(int modelId);

  Future<List<ChatEntity>> getChatsAfterId(int chatId, {int limit = 10});

  /// 获取所有聊天及其最后一条消息内容
  Future<List<ChatHistoryEntity>> getAllChatsWithLastMessage();
}
