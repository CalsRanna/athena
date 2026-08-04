import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_tui/storage/jsonl_store.dart';

/// ChatRepository 的 JSONL 实现(`~/.athena/tui/chats.jsonl`)。
///
/// 与 SQLite 实现的差异:
/// - `updateChat` 整行覆盖天然与 `recordUsage`(独立读写)解耦 —— 两者共用
///   JsonlFileStore 的串行写锁,不会互相覆盖
/// - `deleteChat` 需手动级联删除 `messages/{chatId}.jsonl`
///   (SQLite 靠外键 ON DELETE CASCADE,GUI 无需手动处理)
class JsonlChatRepository implements ChatRepository {
  JsonlChatRepository({
    required File file,
    required Directory messagesDir,
    required IdAllocator idAllocator,
  })  : _store = JsonlFileStore(file: file, idAllocator: idAllocator),
        _messagesDir = messagesDir;

  final JsonlFileStore _store;
  final Directory _messagesDir;

  @override
  Future<List<ChatEntity>> getAllChats() async {
    final rows = await _store.readAll();
    final chats = rows.map(ChatEntity.fromJson).toList()
      ..sort((a, b) {
        final pinned = (b.pinned ? 1 : 0).compareTo(a.pinned ? 1 : 0);
        if (pinned != 0) return pinned;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return chats;
  }

  @override
  Future<ChatEntity?> getChatById(int id) async {
    final row = await _store.readById(id);
    return row == null ? null : ChatEntity.fromJson(row);
  }

  @override
  Future<int> createChat(ChatEntity chat) {
    return _store.insert(chat.toJson());
  }

  @override
  Future<void> updateChat(ChatEntity chat) async {
    final id = chat.id;
    if (id == null) return;
    // 接口契约:token_total / context_tokens / cached_tokens 三列由
    // recordUsage 独立路径管理,整行覆盖会回退累加值。JSONL 没有
    // SQLite 的"指定列 UPDATE",这里读当前行并保留三列再写回。
    await _store.inLock((view) async {
      final rows = await view.readRows();
      final index = rows.indexWhere((r) => r['id'] == id);
      if (index < 0) return;
      final current = ChatEntity.fromJson(rows[index]);
      final merged = chat.copyWith(
        tokenTotal: current.tokenTotal,
        contextTokens: current.contextTokens,
        cachedTokens: current.cachedTokens,
      );
      rows[index] = merged.toJson();
      await view.writeRows(rows);
    });
  }

  @override
  Future<void> deleteChat(int id) async {
    await _store.deleteById(id);
    // SQLite 版依赖外键级联;JSONL 需手动删除该聊天的消息文件
    final file = File('${_messagesDir.path}/$id.jsonl');
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<List<ChatEntity>> getRecentChats({int limit = 10}) async {
    final chats = await getAllChats();
    return chats.take(limit).toList();
  }

  @override
  Future<int> recordUsage(
    int chatId,
    int tokenDelta,
    int contextTokens,
    int cachedTokens,
  ) {
    // 单次锁内完成"读→累加→写",与 updateChat 并发时不丢数据
    return _store.inLock((view) async {
      final rows = await view.readRows();
      final index = rows.indexWhere((r) => r['id'] == chatId);
      if (index < 0) return 0;
      final chat = ChatEntity.fromJson(rows[index]);
      final updated = chat.copyWith(
        tokenTotal: chat.tokenTotal + tokenDelta,
        contextTokens: contextTokens,
        cachedTokens: cachedTokens,
      );
      rows[index] = updated.toJson();
      await view.writeRows(rows);
      return updated.tokenTotal;
    });
  }

  @override
  Future<int> getChatsCount() => _store.count();

  @override
  Future<int> getChatCountByModelId(int modelId) async {
    final chats = await getAllChats();
    return chats.where((c) => c.modelId == modelId).length;
  }

  @override
  Future<List<ChatEntity>> getChatsAfterId(int chatId, {int limit = 10}) async {
    final chats = await getAllChats();
    return chats.where((c) => (c.id ?? 0) > chatId).take(limit).toList();
  }

  @override
  Future<List<ChatHistoryEntity>> getAllChatsWithLastMessage() async {
    final chats = await getAllChats();
    final histories = <ChatHistoryEntity>[];
    for (final chat in chats) {
      final messageFile = File('${_messagesDir.path}/${chat.id}.jsonl');
      var lastContent = '';
      if (await messageFile.exists()) {
        final lines = await messageFile.readAsLines();
        for (final line in lines.reversed) {
          if (line.trim().isEmpty) continue;
          try {
            // 最后一条有 content 的消息(跳过空占位消息)
            final json = jsonDecode(line) as Map<String, dynamic>;
            final content = json['content'] as String? ?? '';
            if (content.isNotEmpty) {
              lastContent = content;
              break;
            }
          } catch (_) {
            continue;
          }
        }
      }
      histories.add(ChatHistoryEntity(
        chat: chat,
        lastMessageContent: lastContent,
      ));
    }
    return histories;
  }
}
