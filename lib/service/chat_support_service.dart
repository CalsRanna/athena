import 'dart:io';
import 'dart:typed_data';

import 'package:athena/util/platform_util.dart';

import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/service/chat_service.dart';
import 'package:path_provider/path_provider.dart';

/// 会话的 UI 辅助操作。
///
/// 职责：重命名（AI 流 + 手动）、模型/哨兵/上下文/温度等字段更新、
/// 图片保存、消息折叠。是 ViewModel 与 Repository/网络层之间的薄胶水。
class ChatSupportService {
  final ChatRepository _chatRepository;
  final MessageRepository _messageRepository;
  final ProviderRepository _providerRepository;
  final ChatService _chatService;

  ChatSupportService({
    required ChatRepository chatRepository,
    required MessageRepository messageRepository,
    required ProviderRepository providerRepository,
    required ChatService chatService,
  }) : _chatRepository = chatRepository,
       _messageRepository = messageRepository,
       _providerRepository = providerRepository,
       _chatService = chatService;

  Stream<String> renameChat(
    String firstUserMessage, {
    required ProviderEntity provider,
    required ModelEntity model,
  }) async* {
    final stream = _chatService.getTitle(
      firstUserMessage,
      provider: provider,
      model: model,
    );
    yield* stream;
  }

  Future<ChatEntity> renameChatManually(ChatEntity chat, String title) {
    return _touchChat(chat.copyWith(title: title));
  }

  Future<String> saveImageFile(Uint8List bytes, int chatId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (PlatformUtil.isMobile) {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/chat_${chatId}_$timestamp.png';
      await File(path).writeAsBytes(bytes);
      return path;
    } else {
      final directory = await getDownloadsDirectory();
      if (directory == null)
        throw Exception('Failed to get downloads directory');
      final path = '${directory.path}/chat_${chatId}_$timestamp.png';
      await File(path).writeAsBytes(bytes);
      return path;
    }
  }

  Future<ChatEntity> updateModel(ChatEntity chat, int modelId) {
    return _touchChat(chat.copyWith(modelId: modelId));
  }

  Future<ChatEntity> updateSentinel(ChatEntity chat, int sentinelId) {
    return _touchChat(chat.copyWith(sentinelId: sentinelId));
  }

  Future<ChatEntity> updateContext(ChatEntity chat, int context) {
    return _touchChat(chat.copyWith(context: context));
  }

  Future<ChatEntity> updateTemperature(ChatEntity chat, double temperature) {
    return _touchChat(chat.copyWith(temperature: temperature));
  }

  /// 原子累加 token_total [tokenDelta] 并覆盖写 context_tokens/cached_tokens
  /// 快照列。不触碰 updatedAt。返回 DB 最新行（跨并发写者一致）。
  Future<ChatEntity?> recordUsage(
    ChatEntity chat, {
    required int tokenDelta,
    required int contextTokens,
    required int cachedTokens,
  }) async {
    if (chat.id == null) return chat;
    await _chatRepository.recordUsage(
      chat.id!,
      tokenDelta,
      contextTokens,
      cachedTokens,
    );
    return _chatRepository.getChatById(chat.id!);
  }

  /// 累加 [chat] 的 token_total [delta] 个 token 并落库。
  /// 不触碰 updatedAt。返回 DB 最近一行。
  /// 新代码优先使用 [recordUsage]。
  Future<ChatEntity?> incrementTokenTotal(ChatEntity chat, int delta) async {
    if (chat.id == null) return chat;
    await _chatRepository.incrementTokenTotal(chat.id!, delta);
    return _chatRepository.getChatById(chat.id!);
  }

  Future<ProviderEntity?> getProviderForModel(int providerId) async {
    return _providerRepository.getProviderById(providerId);
  }

  Future<MessageEntity> updateExpanded(MessageEntity message) async {
    final updated = message.copyWith(expanded: !message.expanded);
    await _messageRepository.updateMessage(updated);
    return updated;
  }

  Future<ChatEntity> _touchChat(ChatEntity updated) async {
    final touched = updated.copyWith(updatedAt: DateTime.now());
    await _chatRepository.updateChat(touched);
    return touched;
  }
}
