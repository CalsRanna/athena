import 'package:athena_gui/database/database.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';

/// [ChatRepository] 的 SQLite 实现（GUI 侧）。
class SqliteChatRepository implements ChatRepository {
  @override
  Future<List<ChatEntity>> getAllChats() async {
    var laconic = Database.instance.laconic;
    var results = await laconic
        .table('chats')
        .orderBy('pinned', direction: 'desc')
        .orderBy('updated_at', direction: 'desc')
        .get();

    return results.map((r) => ChatEntity.fromJson(r.toMap())).toList();
  }

  @override
  Future<ChatEntity?> getChatById(int id) async {
    var laconic = Database.instance.laconic;
    try {
      var result = await laconic.table('chats').where('id', id).first();
      return ChatEntity.fromJson(result.toMap());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<int> createChat(ChatEntity chat) async {
    var laconic = Database.instance.laconic;
    var json = chat.toJson();
    json.remove('id'); // 移除 id,让数据库自动生成
    return await laconic.table('chats').insertGetId(json);
  }

  @override
  Future<void> updateChat(ChatEntity chat) async {
    if (chat.id == null) return;
    var laconic = Database.instance.laconic;
    var json = chat.toJson();
    json.remove('id');
    // 以下三列由独立写入路径（recordUsage）
    // 管理，整行覆盖写回会回退已累加/已覆盖值；
    // 此处显式排除，与增量路径解耦。
    json.remove('token_total');
    json.remove('context_tokens');
    json.remove('cached_tokens');
    await laconic.table('chats').where('id', chat.id).update(json);
  }

  @override
  Future<void> deleteChat(int id) async {
    var laconic = Database.instance.laconic;
    await laconic.table('chats').where('id', id).delete();
    // messages 会通过外键级联删除
  }

  @override
  Future<List<ChatEntity>> getRecentChats({int limit = 10}) async {
    var allChats = await getAllChats();
    return allChats.take(limit).toList();
  }

  @override
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

  @override
  Future<int> getChatsCount() async {
    var laconic = Database.instance.laconic;
    return await laconic.table('chats').count();
  }

  @override
  Future<int> getChatCountByModelId(int modelId) async {
    var laconic = Database.instance.laconic;
    return await laconic.table('chats').where('model_id', modelId).count();
  }

  @override
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

  @override
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
      ORDER BY c.pinned DESC, c.updated_at DESC
    ''';

    var results = await laconic.select(sql);
    return results
        .map((r) => ChatHistoryEntity.fromJson(r.toMap()))
        .toList();
  }
}
