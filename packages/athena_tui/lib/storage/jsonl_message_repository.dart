import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_tui/storage/jsonl_store.dart';

/// MessageRepository 的 JSONL 实现。
///
/// 每个聊天一个文件:`~/.athena/tui/messages/{chatId}.jsonl`,
/// 按行序即消息序(id 升序)。
class JsonlMessageRepository implements MessageRepository {
  JsonlMessageRepository({
    required Directory messagesDir,
    required IdAllocator idAllocator,
  })  : _messagesDir = messagesDir,
        _idAllocator = idAllocator;

  final Directory _messagesDir;
  final IdAllocator _idAllocator;

  /// 按 chatId 缓存共享的 store：JsonlFileStore 的串行锁是实例字段，
  /// 若每次调用新建实例则锁不跨调用生效（「单写者」注释名存实亡），
  /// 同一文件的 update（读-改-整文件重写）与 append 之间可能交错丢行。
  final Map<int, JsonlFileStore> _stores = {};

  JsonlFileStore _storeFor(int chatId) {
    return _stores.putIfAbsent(
      chatId,
      () => JsonlFileStore(
        file: File('${_messagesDir.path}/$chatId.jsonl'),
        idAllocator: _idAllocator,
      ),
    );
  }

  /// 按文件获取共享 store:文件名即 {chatId}.jsonl,解析后复用
  /// [_storeFor] 的缓存实例——同一文件的锁必须共享,文件扫描操作
  /// (读-改-整文件重写)与流式 append/update 才能真正串行。文件名
  /// 解析失败(非标准命名)时退回独立实例,仅影响该文件自身的并发。
  JsonlFileStore _storeForFile(File file) {
    final name = file.uri.pathSegments.last;
    final chatId = int.tryParse(name.endsWith('.jsonl')
        ? name.substring(0, name.length - '.jsonl'.length)
        : name);
    return chatId == null
        ? JsonlFileStore(file: file, idAllocator: _idAllocator)
        : _storeFor(chatId);
  }

  @override
  Future<List<MessageEntity>> getMessagesByChatId(
    int chatId, {
    bool includeCompacted = true,
  }) async {
    final rows = await _storeFor(chatId).readAll();
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
    // id 全局唯一;遍历所有消息文件查找
    if (!await _messagesDir.exists()) return null;
    await for (final entry in _messagesDir.list()) {
      if (entry is! File || !entry.path.endsWith('.jsonl')) continue;
      final row = await _storeForFile(entry).readById(id);
      if (row != null) return MessageEntity.fromJson(row);
    }
    return null;
  }

  @override
  Future<int> storeMessage(MessageEntity message) {
    return _storeFor(message.chatId).insert(message.toJson());
  }

  @override
  Future<void> updateMessage(MessageEntity message) async {
    final id = message.id;
    if (id == null) return;
    await _storeFor(message.chatId).replaceById(id, message.toJson());
  }

  @override
  Future<void> deleteMessage(int id) async {
    if (!await _messagesDir.exists()) return;
    await for (final entry in _messagesDir.list()) {
      if (entry is! File || !entry.path.endsWith('.jsonl')) continue;
      final store = _storeForFile(entry);
      final row = await store.readById(id);
      if (row != null) {
        await store.deleteById(id);
        return;
      }
    }
  }

  @override
  Future<void> deleteMessagesByChatId(int chatId) {
    _stores.remove(chatId);
    return _storeFor(chatId).deleteFile();
  }

  @override
  Future<int> getMessagesCount(int chatId) => _storeFor(chatId).count();

  @override
  Future<void> markAsCompacted(Set<int> ids) async {
    if (ids.isEmpty) return;
    if (!await _messagesDir.exists()) return;
    await for (final entry in _messagesDir.list()) {
      if (entry is! File || !entry.path.endsWith('.jsonl')) continue;
      await _storeForFile(entry).updateWhere(
        (row) => ids.contains(row['id']),
        (row) => {...row, 'compacted': 1},
      );
    }
  }

  @override
  Future<MessageEntity?> getLatestMessageByChatId(int chatId) async {
    final rows = await _storeFor(chatId).readAll();
    if (rows.isEmpty) return null;
    return MessageEntity.fromJson(rows.last);
  }

  /// 从文件**尾部向前**扫描读取消息,不读整个文件。
  ///
  /// 长对话的 JSONL 可达几百 MB,`readAll` 全量读 + 逐行 jsonDecode 既慢
  /// 又占内存;窗口化(消息列表只持有最近 N 条,向上滚动加载更早)需要
  /// 「读最近 [count] 条」与「读 id < [beforeId] 的最近 [count] 条」两个
  /// 原语,这里用 RandomAccessFile 从末尾向前读块实现,读取量 ≈ 需要
  /// 的字节数,与文件总大小无关。
  ///
  /// 文件行序即消息序(id 升序,IdAllocator 全局递增),从尾部向前遍历
  /// 即按 id 降序。块边界可能切断 UTF-8 多字节字符——只切「以 \n 结尾
  /// 的完整行段」解码,块首到第一个 \n 之间的悬浮半行留在缓冲里等更早
  /// 的块拼全,保证解码的行字节总是完整的。文件末尾无换行的最后一行
  /// 按完整行处理。损坏行(空行/非法 JSON/非法 UTF-8)跳过,与 readRows
  /// 的容错一致。
  ///
  /// 全程走该文件的串行锁:与 append/整文件重写(update)互斥,避免
  /// 重写窗口内读到中间状态。
  Future<List<MessageEntity>> loadRecentMessages(
    int chatId, {
    required int count,
    int? beforeId,
  }) {
    final store = _storeFor(chatId);
    final file = store.file;
    return store.inLock((_) async {
      if (count <= 0 || !await file.exists()) return const [];
      final raf = await file.open();
      try {
        final length = await raf.length();
        final result = <MessageEntity>[];
        // 已读未切出完整行的字节:开头方向 = 更早,末尾方向 = 更晚
        var buffer = <int>[];
        var pos = length;
        while (pos > 0 && result.length < count) {
          final blockSize = math.min(65536, pos);
          final start = pos - blockSize;
          await raf.setPosition(start);
          final block = await raf.read(blockSize);
          pos = start;
          final combined = [...block, ...buffer];
          // 从末尾向前切完整行,直到块内没有可切的(悬浮行首留到下一轮)。
          // 索引指针 [end) 单调前移,整块一次线性扫描(不反复 lastIndexOf
          // + sublist 复制,避免 O(n²)——每行只复制行字节本身)
          var end = combined.length;
          while (end > 0 && result.length < count) {
            final nl = combined.lastIndexOf(0x0A, end - 1);
            if (nl < 0) break;
            final lineBytes = combined.sublist(nl + 1, end);
            end = nl;
            if (lineBytes.isNotEmpty) {
              final entity = _decodeLine(lineBytes);
              if (entity != null &&
                  (beforeId == null || entity.id! < beforeId)) {
                result.add(entity);
              }
            }
          }
          buffer = combined.sublist(0, end);
        }
        // 所有块读完:缓冲里剩的是文件第一行(文件头即行首,无 \n 前缀)
        if (pos == 0 && buffer.isNotEmpty && result.length < count) {
          final entity = _decodeLine(buffer);
          if (entity != null && (beforeId == null || entity.id! < beforeId)) {
            result.add(entity);
          }
        }
        // 逆序收集(最新在前),翻转为升序
        return result.reversed.toList();
      } finally {
        await raf.close();
      }
    });
  }

  /// 解码单行字节为 [MessageEntity];损坏行返回 null(与 readRows 一致)。
  MessageEntity? _decodeLine(List<int> lineBytes) {
    try {
      final line = utf8.decode(lineBytes);
      if (line.trim().isEmpty) return null;
      return MessageEntity.fromJson(jsonDecode(line) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
