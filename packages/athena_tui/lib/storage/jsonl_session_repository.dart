import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_tui/storage/id_allocator.dart';
import 'package:athena_tui/storage/session_jsonl_store.dart';

/// ChatRepository + MessageRepository 的会话文件实现
/// (`~/.athena/tui/sessions/{chatId}.jsonl`)。
///
/// 一个对话一个文件,首行是会话元数据,后续行是消息(见 [SessionJsonlStore])。
/// 一个类同时实现两个接口:对话与其消息同生命周期,`deleteChat` 即删文件,
/// 无需像旧的 chats.jsonl + messages/ 双存储那样手动级联。
///
/// 与 SQLite 实现的差异:
/// - `updateChat`(读-改首行)与 `recordUsage`(独立读写)共用会话文件的
///   串行锁,不会互相覆盖
/// - `deleteChat` 直接删除会话文件(SQLite 靠外键级联)
///
/// id 分配(与旧版行为一致,meta.json 计数 key 对应迁移):
/// - chat id:会话目录路径为 key,所有会话共享递增计数
/// - message id:会话文件路径为 key,每个会话独立递增计数
class JsonlSessionRepository implements ChatRepository, MessageRepository {
  JsonlSessionRepository({
    required Directory sessionsDir,
    required IdAllocator idAllocator,
  })  : _sessionsDir = sessionsDir,
        _idAllocator = idAllocator;

  final Directory _sessionsDir;
  final IdAllocator _idAllocator;

  /// 按 chatId 缓存共享的 store:SessionJsonlStore 的串行锁是实例字段,
  /// 若每次调用新建实例则锁不跨调用生效(「单写者锁」名存实亡),
  /// 同一文件的 update(读-改-整文件重写)与 append 之间可能交错丢行。
  final Map<int, SessionJsonlStore> _stores = {};

  SessionJsonlStore _storeFor(int chatId) {
    return _stores.putIfAbsent(
      chatId,
      () => SessionJsonlStore(
        file: File('${_sessionsDir.path}/$chatId.jsonl'),
        idAllocator: _idAllocator,
      ),
    );
  }

  /// 按文件获取共享 store:文件名即 {chatId}.jsonl,解析后复用 [_storeFor]
  /// 的缓存实例——同一文件的锁必须共享,文件扫描操作(读-改-整文件重写)
  /// 与流式 append/update 才能真正串行。文件名解析失败(非标准命名)时
  /// 退回独立实例,仅影响该文件自身的并发。
  SessionJsonlStore _storeForFile(File file) {
    final name = file.uri.pathSegments.last;
    final chatId = int.tryParse(name.endsWith('.jsonl')
        ? name.substring(0, name.length - '.jsonl'.length)
        : name);
    return chatId == null
        ? SessionJsonlStore(file: file, idAllocator: _idAllocator)
        : _storeFor(chatId);
  }

  /// sessions/ 目录下所有会话文件。
  Future<List<File>> _sessionFiles() async {
    if (!await _sessionsDir.exists()) return const [];
    final files = <File>[];
    await for (final entity in _sessionsDir.list()) {
      if (entity is File && entity.path.endsWith('.jsonl')) {
        files.add(entity);
      }
    }
    return files;
  }

  // ─────────────────────────── ChatRepository ───────────────────────────

  @override
  Future<List<ChatEntity>> getAllChats() async {
    final chats = <ChatEntity>[];
    for (final file in await _sessionFiles()) {
      final row = await _storeForFile(file).readChatRow();
      if (row == null) continue; // 损坏/不完整会话跳过
      chats.add(ChatEntity.fromJson(row));
    }
    chats.sort((a, b) {
      final pinned = (b.pinned ? 1 : 0).compareTo(a.pinned ? 1 : 0);
      if (pinned != 0) return pinned;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return chats;
  }

  @override
  Future<ChatEntity?> getChatById(int id) async {
    final row = await _storeFor(id).readChatRow();
    return row == null ? null : ChatEntity.fromJson(row);
  }

  @override
  Future<int> createChat(ChatEntity chat) async {
    final id = await _idAllocator.next(_sessionsDir.path);
    await _storeFor(id).writeChatRow(chat.toJson()..['id'] = id);
    return id;
  }

  @override
  Future<void> updateChat(ChatEntity chat) async {
    final id = chat.id;
    if (id == null) return;
    // 接口契约:token_total / context_tokens / cached_tokens 三列由
    // recordUsage 独立路径管理,整行覆盖会回退累加值。读当前行保留
    // 三列再写回(与旧 chats.jsonl 实现一致)。
    await _storeFor(id).updateChatRow((row) {
      final current = ChatEntity.fromJson(row);
      final merged = chat.copyWith(
        tokenTotal: current.tokenTotal,
        contextTokens: current.contextTokens,
        cachedTokens: current.cachedTokens,
      );
      return merged.toJson();
    });
  }

  @override
  Future<void> deleteChat(int id) async {
    _stores.remove(id);
    await _storeFor(id).deleteFile();
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
  ) async {
    // 单次锁内完成"读→累加→写",与 updateChat 并发时不丢数据
    final updated = await _storeFor(chatId).updateChatRow((row) {
      final chat = ChatEntity.fromJson(row);
      return chat
          .copyWith(
            tokenTotal: chat.tokenTotal + tokenDelta,
            contextTokens: contextTokens,
            cachedTokens: cachedTokens,
          )
          .toJson();
    });
    return updated == null ? 0 : ChatEntity.fromJson(updated).tokenTotal;
  }

  @override
  Future<int> getChatsCount() async {
    var count = 0;
    for (final file in await _sessionFiles()) {
      if (await _storeForFile(file).readChatRow() != null) count++;
    }
    return count;
  }

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
    final histories = <ChatHistoryEntity>[];
    for (final file in await _sessionFiles()) {
      final history = await _historyFor(_storeForFile(file));
      if (history != null) histories.add(history);
    }
    return histories;
  }

  /// 单个会话的历史:首行会话元数据 + 尾部最近的**非空**消息内容。
  ///
  /// 尾部反向读块不读整个文件;全空消息(占位)时向前继续扫,直到找到
  /// 非空内容或文件头。损坏/不完整会话返回 null(调用方跳过)。
  Future<ChatHistoryEntity?> _historyFor(SessionJsonlStore store) async {
    final chatRow = await store.readChatRow();
    if (chatRow == null) return null;
    final chat = ChatEntity.fromJson(chatRow);
    var lastContent = '';
    int? beforeId;
    while (true) {
      final rows = await store.loadRecentRows(20, beforeId: beforeId);
      if (rows.isEmpty) break;
      for (final row in rows.reversed) {
        final content = row['content'];
        if (content is String && content.isNotEmpty) {
          lastContent = content;
          return ChatHistoryEntity(
            chat: chat,
            lastMessageContent: lastContent,
          );
        }
      }
      if (rows.length < 20) break; // 已扫到文件头
      final firstId = rows.first['id'];
      beforeId = firstId is int ? firstId : null;
    }
    return ChatHistoryEntity(chat: chat, lastMessageContent: lastContent);
  }

  // ─────────────────────────── MessageRepository ───────────────────────────

  @override
  Future<List<MessageEntity>> getMessagesByChatId(
    int chatId, {
    bool includeCompacted = true,
  }) async {
    final rows = await _storeFor(chatId).readMessageRows();
    final messages = rows
        .map(MessageEntity.fromJson)
        .where((m) => includeCompacted || !m.compacted)
        .toList()
      // 文件行序即插入序;防御性排序保证 id 升序
      ..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    return messages;
  }

  @override
  Future<MessageEntity?> getMessageById(int id) async {
    // id 会话内唯一;遍历所有会话文件查找
    for (final file in await _sessionFiles()) {
      final rows = await _storeForFile(file).readMessageRows();
      for (final row in rows) {
        if (row['id'] == id) return MessageEntity.fromJson(row);
      }
    }
    return null;
  }

  @override
  Future<int> storeMessage(MessageEntity message) {
    return _storeFor(message.chatId).appendMessage(message.toJson());
  }

  @override
  Future<void> updateMessage(MessageEntity message) async {
    final id = message.id;
    if (id == null) return;
    await _storeFor(message.chatId).replaceMessage(id, message.toJson());
  }

  @override
  Future<void> deleteMessage(int id) async {
    for (final file in await _sessionFiles()) {
      final deleted = await _storeForFile(file).deleteMessageWhere(
        (row) => row['id'] == id,
      );
      if (deleted > 0) return;
    }
  }

  @override
  Future<void> deleteMessagesByChatId(int chatId) async {
    _stores.remove(chatId);
    await _storeFor(chatId).deleteFile();
  }

  @override
  Future<int> getMessagesCount(int chatId) async {
    final rows = await _storeFor(chatId).readMessageRows();
    return rows.length;
  }

  @override
  Future<void> markAsCompacted(Set<int> ids) async {
    if (ids.isEmpty) return;
    for (final file in await _sessionFiles()) {
      await _storeForFile(file).updateMessagesWhere(
        (row) => ids.contains(row['id']),
        (row) => {...row, 'compacted': 1},
      );
    }
  }

  @override
  Future<MessageEntity?> getLatestMessageByChatId(int chatId) async {
    final rows = await _storeFor(chatId).loadRecentRows(1);
    if (rows.isEmpty) return null;
    return MessageEntity.fromJson(rows.first);
  }

  /// 从文件尾部向前扫描读取消息(不读整个文件),窗口化分页用。
  ///
  /// 长对话的 JSONL 可达几百 MB,`getMessagesByChatId` 全量读既慢又占
  /// 内存;窗口化(消息列表只持有最近 N 条,向上滚动加载更早)需要
  /// 「读最近 [count] 条」与「读 id < [beforeId] 的最近 [count] 条」两个
  /// 原语,底层由 [SessionJsonlStore.loadRecentRows] 实现。
  Future<List<MessageEntity>> loadRecentMessages(
    int chatId, {
    required int count,
    int? beforeId,
  }) async {
    final rows = await _storeFor(chatId).loadRecentRows(count, beforeId: beforeId);
    final messages = <MessageEntity>[];
    for (final row in rows) {
      try {
        messages.add(MessageEntity.fromJson(row));
      } catch (_) {
        // 损坏行跳过,与 readMessageRows 的容错一致
      }
    }
    return messages;
  }
}
