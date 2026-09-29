import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/repository/message_repository.dart';

/// 可控的消息仓储：消息是 seq 0..total-1 的 user 消息（顺带当轮次起点）。
///
/// [olderDelay] 让**只有向前翻页**慢下来，用例借此制造「翻页还没回来」的窗口，
/// 用来验证重入守卫与「切了对话」的守卫。
///
/// 刻意只延迟向前翻页：切对话那类用例要在翻页未返回时照常完成新会话的首屏。
/// 用的是真实延迟而不是手动完成的 Completer——后者要跨 `runAsync` 的 zone 推进，
/// 容易写出自己等自己的死锁。
class FakeMessageRepo implements MessageRepository, RecentMessageRepository {
  int total = 0;

  Duration olderDelay = Duration.zero;

  List<MessageEntity> _all(String chatId) => [
    for (var i = 0; i < total; i++)
      MessageEntity(
        id: 'm$i',
        chatId: chatId,
        role: 'user',
        content: 'c$i',
        seq: i,
      ),
  ];

  @override
  Future<MessageWindow> loadInitialMessages(
    String chatId, {
    required int pageSize,
  }) async {
    final all = _all(chatId);
    if (all.length <= pageSize) return (messages: all, hasOlder: false);
    return (messages: all.sublist(all.length - pageSize), hasOlder: true);
  }

  @override
  Future<List<MessageEntity>> loadRecentMessages(
    String chatId, {
    required int count,
    int? beforeSeq,
  }) async {
    await Future<void>.delayed(olderDelay);
    final all = _all(chatId);
    final eligible = beforeSeq == null
        ? all
        : all.where((message) => message.seq < beforeSeq).toList();
    if (eligible.length <= count) return eligible;
    return eligible.sublist(eligible.length - count);
  }

  @override
  Future<List<String>> getTurnStartIds(String chatId) async => [
    for (final message in _all(chatId)) message.id!,
  ];

  // 下面这些不在分页路径上。显式抛错而不是返回假数据：将来若有人把它们接进
  // 分页路径，测试会立刻炸，而不是悄悄拿到空结果。
  @override
  Future<List<MessageEntity>> getMessagesByChatId(
    String chatId, {
    bool includeCompacted = true,
  }) async => _all(chatId);

  @override
  Future<MessageEntity?> getMessageById(String chatId, String id) =>
      throw UnimplementedError();

  @override
  Future<MessageEntity> storeMessage(MessageEntity message) =>
      throw UnimplementedError();

  @override
  Future<void> updateMessage(MessageEntity message) =>
      throw UnimplementedError();

  @override
  Future<void> deleteMessages(String chatId, Set<String> ids) =>
      throw UnimplementedError();

  @override
  Future<void> deleteMessagesByChatId(String chatId) =>
      throw UnimplementedError();

  @override
  Future<int> getMessagesCount(String chatId) async => total;

  @override
  Future<void> markAsCompacted(String chatId, Set<String> ids) =>
      throw UnimplementedError();

  @override
  Future<MessageEntity?> getLatestMessageByChatId(String chatId) =>
      throw UnimplementedError();
}
