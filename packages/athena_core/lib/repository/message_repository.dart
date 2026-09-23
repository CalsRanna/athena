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

  /// 删除 [chatId] 会话内 [ids] 命中的消息（一次读-改-写）。
  ///
  /// **必须带 [chatId]**：消息 id 只在会话内唯一（`IdAllocator` 以会话文件
  /// 路径为计数 key，每个会话都从 1 开始），只按 id 跨会话查找会命中别的
  /// 会话——目标会话那条删不掉，另一个对话却少一条。
  Future<void> deleteMessages(int chatId, Set<int> ids);

  Future<void> deleteMessagesByChatId(int chatId);

  Future<int> getMessagesCount(int chatId);

  /// 批量标记 [chatId] 会话内的消息为已压缩（同样必须带 chatId，理由见
  /// [deleteMessages]）。
  Future<void> markAsCompacted(int chatId, Set<int> ids);

  Future<MessageEntity?> getLatestMessageByChatId(int chatId);

  /// 整段会话里每一轮的起点(每条 user 消息)的 id,按文件顺序。
  ///
  /// 消息列表是窗口化分页的(只持有最近若干条),而轮次指示器要按整段会话
  /// 的轮数来画,所以只能从文件里补这一段。这是一次**整文件**扫描,调用方
  /// 必须按 chatId 缓存(见 `ChatViewModel.turnStartIds`),不要每次构建都调。
  Future<List<int>> getTurnStartIds(int chatId);
}

/// 一次读进来的消息窗口：[messages] 按 id 升序，[hasOlder] 表示还有更早的消息。
typedef MessageWindow = ({List<MessageEntity> messages, bool hasOlder});

/// 可选的消息游标分页能力。
///
/// 返回 [beforeId] 之前、最接近游标的最近 [count] 条消息；未提供游标时
/// 返回会话最新的 [count] 条。结果始终按 id 升序排列。
abstract interface class RecentMessageRepository {
  /// 首屏窗口：会话小到能一次读进来时**直接给整段**（[MessageWindow.hasOlder]
  /// 为 false，此后不再翻页），超过阈值才只给最新的 [pageSize] 条。
  ///
  /// 小会话不分页的依据（实测见 `athena_core/tool/bench_message_loading.dart`）：
  /// 分页首屏只要几毫秒到几十毫秒（真实会话实测 5~93ms），但窗口之外没有内容
  /// 可预览（轮次条 hover 不出卡）、点窗口外的一轮要连翻数页（每页十几毫秒到
  /// 数百 ms，最多 8 页）、列表高度逐页长出来会让滚动条跳；整读的代价是峰值
  /// 内存 ≈ 文件大小 × 3.6~4.6、首屏 ≈ 4~7ms/MB，在几 MB 这个量级上远比上面
  /// 那些体验代价便宜。阈值由实现方定。
  Future<MessageWindow> loadInitialMessages(
    int chatId, {
    required int pageSize,
  });

  Future<List<MessageEntity>> loadRecentMessages(
    int chatId, {
    required int count,
    int? beforeId,
  });
}
