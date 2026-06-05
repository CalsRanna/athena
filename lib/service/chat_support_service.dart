import 'dart:io';
import 'dart:typed_data';

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
  })  : _chatRepository = chatRepository,
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
    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/chat_${chatId}_$timestamp.png';
      await File(path).writeAsBytes(bytes);
      return path;
    } else {
      final directory = await getDownloadsDirectory();
      if (directory == null) throw Exception('Failed to get downloads directory');
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
