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
    await laconic.table('chats').insert([json]);

    // 获取最后插入的 id
    var result = await laconic.select('SELECT last_insert_rowid() as id');
    return result.first['id'] as int;
  }

  Future<void> updateChat(ChatEntity chat) async {
    if (chat.id == null) return;
    var laconic = Database.instance.laconic;
    var json = chat.toJson();
    json.remove('id');
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

  Future<int> getChatsCount() async {
    var laconic = Database.instance.laconic;
    return await laconic.table('chats').count();
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
