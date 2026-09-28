import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/storage/id_generator.dart';
import 'package:athena_core/storage/session_jsonl_store.dart';
import 'package:athena_core/util/logger_util.dart';

/// ChatRepository + MessageRepository 的会话文件实现
/// (`~/.athena/sessions/{chatId}.jsonl`,GUI 与 TUI 共用)。
///
/// 一个对话一个文件,首行是会话元数据,后续行是消息(见 [SessionJsonlStore])。
/// 一个类同时实现两个接口:对话与其消息同生命周期,`deleteChat` 即删文件,
/// 无需手动级联。
///
/// - `updateChat`(读-改首行)与 `recordUsage`(独立读写)共用会话文件的
///   锁,不会互相覆盖
///
/// 会话与消息使用 UUIDv7；消息 seq 在各自会话写锁内分配。
class JsonlSessionRepository
    implements ChatRepository, MessageRepository, RecentMessageRepository {
  JsonlSessionRepository({
    required Directory sessionsDir,
    IdGenerator idGenerator = const IdGenerator(),
  }) : _sessionsDir = sessionsDir,
       _idGenerator = idGenerator;

  final Directory _sessionsDir;
  final IdGenerator _idGenerator;

  /// 按 chatId 缓存共享的 store:SessionJsonlStore 的串行锁是实例字段,
  /// 若每次调用新建实例则锁不跨调用生效(「单写者锁」名存实亡),
  /// 同一文件的 update(读-改-整文件重写)与 append 之间可能交错丢行。
  final Map<String, SessionJsonlStore> _stores = {};

  SessionJsonlStore _storeFor(String chatId) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(chatId)) {
      throw ArgumentError.value(
        chatId,
        'chatId',
        'Expected one file name segment',
      );
    }
    return _stores.putIfAbsent(
      chatId,
      () => SessionJsonlStore(
        file: File(p.join(_sessionsDir.path, '$chatId.jsonl')),
        idGenerator: _idGenerator,
      ),
    );
  }

  /// 文件名即会话身份，扫描与按 ID 访问必须共用同一 store 和串行锁。
  SessionJsonlStore _storeForFile(File file) {
    return _storeFor(p.basenameWithoutExtension(file.path));
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
      final chat = await _readChatSafely(file);
      if (chat != null) chats.add(chat); // 损坏/不完整会话跳过
    }
    chats.sort((a, b) {
      final pinned = (b.pinned ? 1 : 0).compareTo(a.pinned ? 1 : 0);
      if (pinned != 0) return pinned;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return chats;
  }

  @override
  Future<ChatEntity?> getChatById(String id) async {
    final row = await _storeFor(id).readChatRow();
    return row == null ? null : ChatEntity.fromJson(row);
  }

  @override
  Future<String> createChat(ChatEntity chat) async {
    final id = _idGenerator.next();
    await _storeFor(
      id,
    ).writeChatRow(chat.toJson()..['id'] = id, createOnly: true);
    return id;
  }

  @override
  Future<void> updateChat(ChatEntity chat) async {
    final id = chat.id;
    if (id == null) return;
    // 接口契约:context_tokens / cached_tokens 两列由 recordUsage 独立
    // 路径管理,整行覆盖会回退快照。读当前行保留两列再写回。
    await _storeFor(id).updateChatRow((row) {
      final current = ChatEntity.fromJson(row);
      final merged = chat.copyWith(
        contextTokens: current.contextTokens,
        cachedTokens: current.cachedTokens,
      );
      return merged.toJson();
    });
  }

  @override
  Future<void> deleteChat(String id) async {
    _stores.remove(id);
    await _storeFor(id).deleteFile();
  }

  @override
  Future<List<ChatEntity>> getRecentChats({int limit = 10}) async {
    final chats = await getAllChats();
    return chats.take(limit).toList();
  }

  @override
  Future<void> recordUsage(
    String chatId,
    int contextTokens,
    int cachedTokens,
  ) async {
    // 单次锁内完成"读→改→写",与 updateChat 并发时不丢数据
    await _storeFor(chatId).updateChatRow((row) {
      final chat = ChatEntity.fromJson(row);
      return chat
          .copyWith(contextTokens: contextTokens, cachedTokens: cachedTokens)
          .toJson();
    });
  }

  @override
  Future<int> getChatsCount() async {
    var count = 0;
    for (final file in await _sessionFiles()) {
      if (await _readChatSafely(file) != null) count++;
    }
    return count;
  }

  /// 读单个会话的元数据;读不了(无权限、首行损坏等)返回 null 并记日志,
  /// 一个坏文件不能让整个会话列表都列不出来。
  Future<ChatEntity?> _readChatSafely(File file) async {
    try {
      final row = await _storeForFile(file).readChatRow();
      return row == null ? null : ChatEntity.fromJson(row);
    } catch (e) {
      LoggerUtil.w('session ${file.path} skipped: $e');
      return null;
    }
  }

  @override
  Future<int> getChatCountByModelId(String modelId) async {
    final chats = await getAllChats();
    return chats.where((c) => c.modelId == modelId).length;
  }

  @override
  Future<List<ChatEntity>> getChatsAfterId(
    String chatId, {
    int limit = 10,
  }) async {
    final chats = await getAllChats();
    final index = chats.indexWhere((chat) => chat.id == chatId);
    return index < 0 ? [] : chats.skip(index + 1).take(limit).toList();
  }

  @override
  Future<List<ChatHistoryEntity>> getAllChatsWithLastMessage() async {
    final histories = <ChatHistoryEntity>[];
    for (final file in await _sessionFiles()) {
      try {
        final history = await _historyFor(_storeForFile(file));
        if (history != null) histories.add(history);
      } catch (e) {
        LoggerUtil.w('session ${file.path} skipped: $e');
      }
    }
    // 与 SQLite 实现同序:置顶优先,再按更新时间倒序(目录遍历序不可靠)
    histories.sort((a, b) {
      final pinned = (b.chat.pinned ? 1 : 0).compareTo(a.chat.pinned ? 1 : 0);
      if (pinned != 0) return pinned;
      return b.chat.updatedAt.compareTo(a.chat.updatedAt);
    });
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
    int? beforeSeq;
    while (true) {
      final rows = await store.loadRecentRows(20, beforeSeq: beforeSeq);
      if (rows.isEmpty) break;
      for (final row in rows.reversed) {
        final content = row['content'];
        if (content is String && content.isNotEmpty) {
          lastContent = content;
          return ChatHistoryEntity(chat: chat, lastMessageContent: lastContent);
        }
      }
      if (rows.length < 20) break; // 已扫到文件头
      final firstId = rows.first['seq'];
      beforeSeq = firstId is int ? firstId : null;
    }
    return ChatHistoryEntity(chat: chat, lastMessageContent: lastContent);
  }

  // ─────────────────────────── MessageRepository ───────────────────────────

  @override
  Future<List<MessageEntity>> getMessagesByChatId(
    String chatId, {
    bool includeCompacted = true,
  }) async {
    final rows = await _storeFor(chatId).readMessageRows();
    final messages =
        rows
            .map(MessageEntity.fromJson)
            .where((m) => includeCompacted || !m.compacted)
            .toList()
          // 文件行序即插入序;防御性排序保证 seq 升序
          ..sort((a, b) => a.seq.compareTo(b.seq));
    return messages;
  }

  @override
  Future<MessageEntity?> getMessageById(String chatId, String id) async {
    final rows = await _storeFor(chatId).readMessageRows();
    for (final row in rows) {
      if (row['id'] == id) return MessageEntity.fromJson(row);
    }
    return null;
  }

  @override
  Future<MessageEntity> storeMessage(MessageEntity message) async {
    final row = await _storeFor(message.chatId).appendMessage(message.toJson());
    return MessageEntity.fromJson(row);
  }

  @override
  Future<void> updateMessage(MessageEntity message) async {
    final id = message.id;
    if (id == null) return;
    await _storeFor(message.chatId).replaceMessage(id, message.toJson());
  }

  /// 删除 [chatId] 会话内 id ∈ [ids] 的消息，**一次读-改-写**。
  ///
  /// 按会话定位文件，一次读改写删除整批消息，不扫描其他会话。
  @override
  Future<void> deleteMessages(String chatId, Set<String> ids) async {
    if (ids.isEmpty) return;
    await _storeFor(
      chatId,
    ).deleteMessageWhere((row) => ids.contains(row['id']));
  }

  @override
  Future<void> deleteMessagesByChatId(String chatId) async {
    _stores.remove(chatId);
    await _storeFor(chatId).deleteFile();
  }

  @override
  Future<int> getMessagesCount(String chatId) async {
    final rows = await _storeFor(chatId).readMessageRows();
    return rows.length;
  }

  /// 标记 [chatId] 会话内 id ∈ [ids] 的消息为已压缩（一次读-改-写）。
  ///
  /// 与删除同理按会话定位，一次更新所有命中消息。
  @override
  Future<void> markAsCompacted(String chatId, Set<String> ids) async {
    if (ids.isEmpty) return;
    await _storeFor(chatId).updateMessagesWhere(
      (row) => ids.contains(row['id']),
      (row) => {...row, 'compacted': 1},
    );
  }

  @override
  Future<MessageEntity?> getLatestMessageByChatId(String chatId) async {
    final rows = await _storeFor(chatId).loadRecentRows(1);
    if (rows.isEmpty) return null;
    return MessageEntity.fromJson(rows.first);
  }

  /// 整段会话里每一轮的起点(每条 user 消息)的 id,按文件顺序。
  ///
  /// 窗口化分页只加载尾部若干条,轮次指示器却要按"整段会话有多少轮"来画,
  /// 所以这里要整文件扫一遍(见 [SessionJsonlStore.loadUserMessageIds]);
  /// 结果由调用方(ChatViewModel)按 chatId 缓存,不要每次构建都调。
  @override
  Future<List<String>> getTurnStartIds(String chatId) {
    return _storeFor(chatId).loadUserMessageIds();
  }

  /// 小于该字节数的会话就一次读完整段，不再分页（见 [loadInitialMessages]）。
  ///
  /// 8MB 的依据（实测，见 `tool/bench_message_loading.dart`）：整读的峰值内存
  /// ≈ 文件大小 × 3.6~4.6（8MB → 约 +37MB），首屏耗时 ≈ 4~7ms/MB（8MB →
  /// 40ms 上下）。这是"小会话不分页"的唯一旋钮：调大它，更多会话不再分页、
  /// 换来更多内存占用。
  static const int wholeSessionMaxBytes = 8 * 1024 * 1024;

  /// 首屏窗口：文件够小就给整段（此后不再翻页），否则只给最新的 [pageSize] 条。
  ///
  /// 走哪条路只看文件大小——整读的开销（时间与内存）都由字节数决定；条数只
  /// 影响每帧重建的走查量（实测 2 万条 3.7ms，几千条 0.7ms，可忽略）。
  @override
  Future<MessageWindow> loadInitialMessages(
    String chatId, {
    required int pageSize,
  }) async {
    final store = _storeFor(chatId);
    if (await _fitsInOneRead(store.file)) {
      final messages = _toMessages(await store.readMessageRows())
        ..sort((a, b) => a.seq.compareTo(b.seq));
      return (messages: messages, hasOlder: false);
    }
    // 多要一条判断还有没有更早的
    final rows = await store.loadRecentRows(pageSize + 1);
    final hasOlder = rows.length > pageSize;
    final page = hasOlder ? rows.sublist(rows.length - pageSize) : rows;
    return (messages: _toMessages(page), hasOlder: hasOlder);
  }

  Future<bool> _fitsInOneRead(File file) async {
    if (!await file.exists()) return true;
    return await file.length() <= wholeSessionMaxBytes;
  }

  /// 从文件尾部向前扫描读取消息(不读整个文件),窗口化分页用。
  ///
  /// 长对话的 JSONL 可达几百 MB,`getMessagesByChatId` 全量读既慢又占
  /// 内存;窗口化(消息列表只持有最近 N 条,向上滚动加载更早)需要
  /// 「读最近 [count] 条」与「读 seq < [beforeSeq] 的最近 [count] 条」两个
  /// 原语,底层由 [SessionJsonlStore.loadRecentRows] 实现。
  @override
  Future<List<MessageEntity>> loadRecentMessages(
    String chatId, {
    required int count,
    int? beforeSeq,
  }) async {
    final rows = await _storeFor(
      chatId,
    ).loadRecentRows(count, beforeSeq: beforeSeq);
    return _toMessages(rows);
  }

  /// 行 → 实体，损坏行跳过（与 [getMessagesByChatId] 的容错一致）。
  List<MessageEntity> _toMessages(List<Map<String, dynamic>> rows) {
    final messages = <MessageEntity>[];
    for (final row in rows) {
      try {
        messages.add(MessageEntity.fromJson(row));
      } catch (_) {
        // 损坏行跳过
      }
    }
    return messages;
  }
}
