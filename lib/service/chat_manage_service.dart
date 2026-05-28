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
import 'package:get_it/get_it.dart';

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
  })  : _chatRepository = chatRepository ?? GetIt.instance<ChatRepository>(),
        _messageRepository =
            messageRepository ?? GetIt.instance<MessageRepository>(),
        _modelRepository = modelRepository ?? GetIt.instance<ModelRepository>(),
        _providerRepository =
            providerRepository ?? GetIt.instance<ProviderRepository>(),
        _sentinelRepository =
            sentinelRepository ?? GetIt.instance<SentinelRepository>();

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

  Future<void> deleteMessagesFromIndex(
    List<MessageEntity> messages,
    int fromIndex,
  ) async {
    for (var i = fromIndex; i < messages.length; i++) {
      await _messageRepository.deleteMessage(messages[i].id!);
    }
  }

  Future<void> updateChatTimestamp(ChatEntity chat) async {
    final latest = await _chatRepository.getChatById(chat.id!);
    if (latest != null) {
      await _chatRepository.updateChat(latest.copyWith(updatedAt: DateTime.now()));
    }
  }

  /// 创建并落库一条空的 assistant 占位消息，返回带 id 的 entity
  Future<MessageEntity> appendAssistantPlaceholder(int chatId) async {
    final placeholder = MessageEntity(
      chatId: chatId,
      role: 'assistant',
      content: '',
    );
    final id = await _messageRepository.storeMessage(placeholder);
    return placeholder.copyWith(id: id);
  }

  /// 持久化 assistant 消息最终内容（含 toolCalls/toolResults/reasoning）
  Future<void> finalizeAssistantMessage(MessageEntity message) async {
    await _messageRepository.updateMessage(message);
  }

  /// 取消现场：保留所有累积内容，content 末尾追加 [Cancelled]
  Future<MessageEntity> recordCancelledOnMessage(MessageEntity message) async {
    final preservedContent = message.content.isEmpty
        ? '[Cancelled]'
        : '${message.content}\n\n[Cancelled]';
    final updated = message.copyWith(
      content: preservedContent,
      reasoning: false,
    );
    await _messageRepository.updateMessage(updated);
    return updated;
  }

  /// 错误现场：保留所有累积内容，content 末尾追加 [Error: ...]
  Future<MessageEntity> recordErrorOnMessage(
    MessageEntity message,
    Object error,
  ) async {
    final errorText = error.toString();
    final preservedContent = message.content.isEmpty
        ? 'Error: $errorText'
        : '${message.content}\n\n[Error: $errorText]';
    final updated = message.copyWith(
      content: preservedContent,
      reasoning: false,
    );
    await _messageRepository.updateMessage(updated);
    return updated;
  }
}
