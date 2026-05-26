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
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

class ChatSupportService {
  final ChatRepository _chatRepository;
  final MessageRepository _messageRepository;
  final ProviderRepository _providerRepository;
  final ChatService _chatService;

  ChatSupportService({
    ChatRepository? chatRepository,
    MessageRepository? messageRepository,
    ProviderRepository? providerRepository,
    ChatService? chatService,
  })  : _chatRepository = chatRepository ?? GetIt.instance<ChatRepository>(),
        _messageRepository =
            messageRepository ?? GetIt.instance<MessageRepository>(),
        _providerRepository =
            providerRepository ?? GetIt.instance<ProviderRepository>(),
        _chatService = chatService ?? GetIt.instance<ChatService>();

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

  Future<ChatEntity> renameChatManually(ChatEntity chat, String title) async {
    final updated = chat.copyWith(title: title);
    await _chatRepository.updateChat(updated);
    return updated;
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

  Future<ChatEntity> updateModel(ChatEntity chat, int modelId) async {
    final updated = chat.copyWith(modelId: modelId);
    await _chatRepository.updateChat(updated);
    return updated;
  }

  Future<ChatEntity> updateSentinel(ChatEntity chat, int sentinelId) async {
    final updated = chat.copyWith(sentinelId: sentinelId);
    await _chatRepository.updateChat(updated);
    return updated;
  }

  Future<ChatEntity> updateContext(ChatEntity chat, int context) async {
    final updated = chat.copyWith(context: context);
    await _chatRepository.updateChat(updated);
    return updated;
  }

  Future<ChatEntity> updateTemperature(
      ChatEntity chat, double temperature) async {
    final updated = chat.copyWith(temperature: temperature);
    await _chatRepository.updateChat(updated);
    return updated;
  }

  Future<ProviderEntity?> getProviderForModel(int providerId) async {
    return _providerRepository.getProviderById(providerId);
  }

  Future<MessageEntity> updateExpanded(MessageEntity message) async {
    final updated = message.copyWith(expanded: !message.expanded);
    await _messageRepository.updateMessage(updated);
    return updated;
  }
}
