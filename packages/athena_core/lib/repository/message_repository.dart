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
