import 'package:athena/database/database.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/chat_history_entity.dart';

class ChatRepository {
  Future<List<ChatEntity>> getAllChats() async {
    var laconic = Database.instance.laconic;
    var results = await laconic
        .table('chats')
        .orderBy('updated_at', direction: 'desc')
        .get();

    var chats = results.map((r) => ChatEntity.fromJson(r.toMap())).toList();

    // 先按置顶排序,再按更新时间
    chats.sort((a, b) {
      if (a.pinned == b.pinned) {
        return b.updatedAt.compareTo(a.updatedAt);
      }
      return a.pinned ? -1 : 1;
    });

    return chats;
  }

  Future<ChatEntity?> getChatById(int id) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('chats').where('id', id).first();
      return ChatEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  Future<int> createChat(ChatEntity chat) async {
    var laconic = Database.instance.laconic;
    var json = chat.toJson();
    json.remove('id'); // 移除 id,让数据库自动生成
    return await laconic.table('chats').insertGetId(json);
  }

  Future<void> updateChat(ChatEntity chat) async {
    if (chat.id == null) return;
    var laconic = Database.instance.laconic;
    var json = chat.toJson();
    json.remove('id');
    // 以下三列由独立写入路径（incrementTokenTotal / recordTokenSnapshot）
    // 管理，整行覆盖写回会回退已累加/已覆盖值；
    // 此处显式排除，与增量路径解耦。
    json.remove('token_total');
    json.remove('context_tokens');
    json.remove('cached_tokens');
    await laconic.table('chats').where('id', chat.id).update(json);
  }

  Future<void> deleteChat(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('chats').where('id', id).delete();
    // messages 会通过外键级联删除
  }

  Future<List<ChatEntity>> getRecentChats({int limit = 10}) async {
    var allChats = await getAllChats();
    return allChats.take(limit).toList();
  }

  /// 原子地累加 [chatId] 的 token_total 列 [delta]，
  /// 同时覆盖写 context_tokens 与 cached_tokens 快照列，不触碰 updatedAt。
  /// 返回累加后的最新行。
  Future<int> recordUsage(
    int chatId,
    int tokenDelta,
    int contextTokens,
    int cachedTokens,
  ) async {
    var laconic = Database.instance.laconic;
    await laconic.statement(
      'UPDATE chats SET token_total = token_total + ?, '
          'context_tokens = ?, cached_tokens = ? WHERE id = ?',
      [tokenDelta, contextTokens, cachedTokens, chatId],
    );
    final chat = await getChatById(chatId);
    return chat?.tokenTotal ?? 0;
  }

  /// 原子地累加 [chatId] 的 token_total 列 [delta] 且不触碰 updatedAt。
  /// 返回累加后的 token_total 值。
  /// 新代码优先使用 [recordUsage]（同时写快照列）。
  Future<int> incrementTokenTotal(int chatId, int delta) async {
    if (delta == 0) {
      final chat = await getChatById(chatId);
      return chat?.tokenTotal ?? 0;
    }
    var laconic = Database.instance.laconic;
    await laconic.statement(
      'UPDATE chats SET token_total = token_total + ? WHERE id = ?',
      [delta, chatId],
    );
    final chat = await getChatById(chatId);
    return chat?.tokenTotal ?? 0;
  }

  Future<int> getChatsCount() async {
    var laconic = Database.instance.laconic;
    return await laconic.table('chats').count();
  }

  Future<List<ChatEntity>> getChatsAfterId(int chatId, {int limit = 10}) async {
    var laconic = Database.instance.laconic;
    var results = await laconic
        .table('chats')
        .where('id', chatId, comparator: '>')
        .orderBy('id', direction: 'asc')
        .limit(limit)
        .get();
    return results.map((r) => ChatEntity.fromJson(r.toMap())).toList();
  }

  /// 获取所有聊天及其最后一条消息内容
  Future<List<ChatHistoryEntity>> getAllChatsWithLastMessage() async {
    var laconic = Database.instance.laconic;
    var sql = '''
      SELECT
        c.*,
        COALESCE(m.content, '') as last_message_content
      FROM chats c
      LEFT JOIN (
        SELECT chat_id, content
        FROM messages m1
        WHERE id = (
          SELECT MAX(id) FROM messages m2 WHERE m2.chat_id = m1.chat_id
        )
      ) m ON c.id = m.chat_id
      ORDER BY c.updated_at DESC
    ''';

    var results = await laconic.select(sql);
    var histories = results
        .map((r) => ChatHistoryEntity.fromJson(r.toMap()))
        .toList();

    // 按置顶和更新时间排序
    histories.sort((a, b) {
      if (a.chat.pinned == b.chat.pinned) {
        return b.chat.updatedAt.compareTo(a.chat.updatedAt);
      }
      return a.chat.pinned ? -1 : 1;
    });

    return histories;
  }
}
