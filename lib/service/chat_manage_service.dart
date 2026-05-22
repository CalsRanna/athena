import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/chat_history_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';

class ChatManageService {
  final ChatRepository _chatRepository;
  final MessageRepository _messageRepository;
  final ModelRepository _modelRepository;
  final ProviderRepository _providerRepository;
  final SentinelRepository _sentinelRepository;

  ChatManageService({
    ChatRepository? chatRepository,
    MessageRepository? messageRepository,
    ModelRepository? modelRepository,
    ProviderRepository? providerRepository,
    SentinelRepository? sentinelRepository,
  })  : _chatRepository = chatRepository ?? ChatRepository(),
        _messageRepository = messageRepository ?? MessageRepository(),
        _modelRepository = modelRepository ?? ModelRepository(),
        _providerRepository = providerRepository ?? ProviderRepository(),
        _sentinelRepository = sentinelRepository ?? SentinelRepository();

  Future<(List<ChatEntity>, List<ChatHistoryEntity>)> getChats() async {
    final chats = await _chatRepository.getAllChats();
    final histories = await _chatRepository.getAllChatsWithLastMessage();
    return (chats, histories);
  }

  Future<ChatEntity> createChat({
    required ModelEntity model,
    required SentinelEntity sentinel,
    int context = 0,
    double temperature = 1.0,
  }) async {
    final now = DateTime.now();
    var chat = ChatEntity(
      title: 'New Chat',
      modelId: model.id!,
      sentinelId: sentinel.id!,
      temperature: temperature,
      context: context,
      createdAt: now,
      updatedAt: now,
    );
    final id = await _chatRepository.createChat(chat);
    return chat.copyWith(id: id);
  }

  Future<void> deleteChat(int chatId) async {
    await _chatRepository.deleteChat(chatId);
    await _messageRepository.deleteMessagesByChatId(chatId);
  }

  Future<void> deleteChats(Set<int> ids) async {
    for (final id in ids) {
      await _chatRepository.deleteChat(id);
      await _messageRepository.deleteMessagesByChatId(id);
    }
  }

  Future<({
    List<MessageEntity> messages,
    ModelEntity? model,
    ProviderEntity? provider,
    SentinelEntity? sentinel,
  })> selectChat(ChatEntity chat) async {
    final messages = await _messageRepository.getMessagesByChatId(chat.id!);
    final model = await _modelRepository.getModelById(chat.modelId);
    final provider = model != null
        ? await _providerRepository.getProviderById(model.providerId)
        : null;
    final sentinel = await _sentinelRepository.getSentinelById(chat.sentinelId);
    return (messages: messages, model: model, provider: provider, sentinel: sentinel);
  }

  Future<void> togglePin(ChatEntity chat) async {
    await _chatRepository.updateChat(chat.copyWith(pinned: !chat.pinned));
  }

  Future<List<MessageEntity>> refreshMessages(int chatId) async {
    return _messageRepository.getMessagesByChatId(chatId);
  }

  Future<void> deleteMessagesFromIndex(
    List<MessageEntity> messages,
    int fromIndex,
  ) async {
    for (var i = fromIndex; i < messages.length; i++) {
      await _messageRepository.deleteMessage(messages[i].id!);
    }
  }

  Future<ModelEntity?> getModel(int modelId) async {
    return _modelRepository.getModelById(modelId);
  }

  Future<SentinelEntity?> getSentinel(int sentinelId) async {
    return _sentinelRepository.getSentinelById(sentinelId);
  }

  Future<void> updateChatTimestamp(ChatEntity chat) async {
    final latest = await _chatRepository.getChatById(chat.id!);
    if (latest != null) {
      await _chatRepository.updateChat(latest.copyWith(updatedAt: DateTime.now()));
    }
  }

  Future<int> storeMessage(MessageEntity message) async {
    return _messageRepository.storeMessage(message);
  }

  Future<void> updateMessage(MessageEntity message) async {
    await _messageRepository.updateMessage(message);
  }
}
