import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/rewind_result.dart';
import 'package:athena_core/repository/session_rewind_repository.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/run_statistics.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';

/// 会话与消息的持久化编排。
///
/// 职责：会话 CRUD、消息删除/占位/最终化、取消/错误标记。
/// 所有写操作直接落库；不涉及 AI 网络调用（→ [ChatCompletionsService]）。
class ChatStore {
  final ChatRepository _chatRepository;
  final MessageRepository _messageRepository;
  final ModelRepository _modelRepository;
  final ProviderRepository _providerRepository;
  final SentinelRepository _sentinelRepository;

  ChatStore({
    required ChatRepository chatRepository,
    required MessageRepository messageRepository,
    required ModelRepository modelRepository,
    required ProviderRepository providerRepository,
    required SentinelRepository sentinelRepository,
  }) : _chatRepository = chatRepository,
       _messageRepository = messageRepository,
       _modelRepository = modelRepository,
       _providerRepository = providerRepository,
       _sentinelRepository = sentinelRepository;

  Future<(List<ChatEntity>, List<ChatHistoryEntity>)> getChats() async {
    final chats = await _chatRepository.getAllChats();
    final histories = await _chatRepository.getAllChatsWithLastMessage();
    return (chats, histories);
  }

  /// 落库一个新会话。[reasoningEffort] / [workspacePath] / [approvalMode]
  /// 与其余参数一样，由调用方从草稿态带过来；不传即为新会话默认值。
  Future<ChatEntity> createChat({
    required ModelEntity model,
    required SentinelEntity sentinel,
    int retention = -1,
    double temperature = 1.0,
    String reasoningEffort = ChatEntity.defaultReasoningEffort,
    String? workspacePath,
    ApprovalMode approvalMode = ApprovalMode.defaultMode,
  }) async {
    final now = DateTime.now();
    final chat = ChatEntity(
      title: 'New Chat',
      modelId: model.id!,
      sentinelId: sentinel.id,
      temperature: temperature,
      reasoningEffort: reasoningEffort,
      retention: retention,
      workspacePath: workspacePath,
      approvalMode: approvalMode,
      createdAt: now,
      updatedAt: now,
    );
    final id = await _chatRepository.createChat(chat);
    return chat.copyWith(id: id);
  }

  Future<void> deleteChat(String chatId) async {
    // 会话与消息共用一个 JSONL 文件，删除会话即删除全部消息。
    await _chatRepository.deleteChat(chatId);
  }

  Future<void> deleteChats(Set<String> ids) async {
    for (final id in ids) {
      await _chatRepository.deleteChat(id);
    }
  }

  Future<
    ({
      List<MessageEntity> messages,
      ModelEntity? model,
      ProviderEntity? provider,
      SentinelEntity? sentinel,
    })
  >
  selectChat(ChatEntity chat, {List<MessageEntity>? preloadedMessages}) async {
    final messages =
        preloadedMessages ??
        await _messageRepository.getMessagesByChatId(chat.id!);
    final model = await _modelRepository.getModelById(chat.modelId);
    final provider = model != null
        ? await _providerRepository.getProviderById(model.providerId)
        : null;
    final sentinel = chat.sentinelId == null
        ? null
        : await _sentinelRepository.getSentinelById(chat.sentinelId!);
    return (
      messages: messages,
      model: model,
      provider: provider,
      sentinel: sentinel,
    );
  }

  /// 切换置顶，返回更新后的会话；会话已被删除时返回 null。
  ///
  /// 返回实体是为了让调用方能**就地**更新列表：置顶只改一条会话，调用方若为此
  /// 重读整个 `sessions/` 目录，代价会随会话数线性增长。
  Future<ChatEntity?> togglePin(ChatEntity chat) async {
    // 先读最新行再改 pinned，避免整行覆盖写回旧快照
    final latest = await _chatRepository.getChatById(chat.id!);
    if (latest == null) return null;
    final updated = latest.copyWith(
      pinned: !latest.pinned,
      updatedAt: DateTime.now(),
    );
    await _chatRepository.updateChat(updated);
    return updated;
  }

  /// 从 [fromIndex] 起删掉 [messages] 里的全部消息。
  ///
  /// 一次性收集 id 交给仓储按会话删除：一次读-改-写，而不是逐条删
  /// （逐条 = 每条都要把整会话文件读+写一遍）。
  Future<void> deleteMessagesFromIndex(
    String chatId,
    List<MessageEntity> messages,
    int fromIndex,
  ) async {
    final ids = <String>{
      for (var i = fromIndex; i < messages.length; i++) messages[i].id!,
    };
    if (ids.isEmpty) return;
    await _messageRepository.deleteMessages(chatId, ids);
  }

  Future<RewindResult> rewindToUserMessage(String chatId, String messageId) {
    final repository = _messageRepository;
    if (repository is! SessionRewindRepository) {
      throw UnsupportedError('Session repository does not support rewind.');
    }
    return (repository as SessionRewindRepository).rewindToUserMessage(
      chatId,
      messageId,
    );
  }

  Future<void> updateChatTimestamp(ChatEntity chat) async {
    final latest = await _chatRepository.getChatById(chat.id!);
    if (latest != null) {
      await _chatRepository.updateChat(
        latest.copyWith(updatedAt: DateTime.now()),
      );
    }
  }

  /// 创建并落库一条空的 assistant 占位消息，返回带 id 与 seq 的 entity
  Future<MessageEntity> appendAssistantPlaceholder(
    String chatId, {
    RunStatistics? runStatistics,
  }) async {
    final placeholder = MessageEntity(
      chatId: chatId,
      role: 'assistant',
      content: '',
      runStatistics: runStatistics,
    );
    return _messageRepository.storeMessage(placeholder);
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
