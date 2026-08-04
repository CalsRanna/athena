import 'dart:io';

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

  JsonlFileStore _storeFor(int chatId) {
    return JsonlFileStore(
      file: File('${_messagesDir.path}/$chatId.jsonl'),
      idAllocator: _idAllocator,
    );
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
      final store = JsonlFileStore(
        file: entry,
        idAllocator: _idAllocator,
      );
      final row = await store.readById(id);
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
      final store = JsonlFileStore(
        file: entry,
        idAllocator: _idAllocator,
      );
      final row = await store.readById(id);
      if (row != null) {
        await store.deleteById(id);
        return;
      }
    }
  }

  @override
  Future<void> deleteMessagesByChatId(int chatId) {
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
      final store = JsonlFileStore(
        file: entry,
        idAllocator: _idAllocator,
      );
      await store.updateWhere(
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
}
