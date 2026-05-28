import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:athena/agent/cancel_token.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/widget/permission_dialog.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/chat_history_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/router/router.dart';
import 'package:athena/service/chat_manage_service.dart';
import 'package:athena/service/chat_message_service.dart';
import 'package:athena/service/chat_support_service.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/agent/agent_service.dart';
import 'package:athena/view_model/delegate/chat_selection_delegate.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:get_it/get_it.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:signals/signals.dart';

/// ChatViewModel 负责聊天会话的业务逻辑
class ChatViewModel {
  static const int defaultDraftContext = 0;
  static const double defaultDraftTemperature = 1.0;

  final ChatManageService _manage;
  final ChatSupportService _support;
  final ChatMessageService _chatMessageService;
  final ChatSelectionDelegate _selection;
  final AgentService _agentService;
  final MessageRepository _messageRepository;
  final ModelRepository _modelRepository;
  final SentinelRepository _sentinelRepository;

  CancelToken? _activeCancelToken;

  ChatViewModel({
    ChatManageService? manageService,
    ChatSupportService? supportService,
    ChatMessageService? chatMessageService,
    ChatSelectionDelegate? selection,
    AgentService? agentService,
    MessageRepository? messageRepository,
    ModelRepository? modelRepository,
    SentinelRepository? sentinelRepository,
  })  : _manage = manageService ?? GetIt.instance<ChatManageService>(),
        _support = supportService ?? GetIt.instance<ChatSupportService>(),
        _chatMessageService =
            chatMessageService ?? GetIt.instance<ChatMessageService>(),
        _selection = selection ?? ChatSelectionDelegate(),
        _agentService = agentService ?? GetIt.instance<AgentService>(),
        _messageRepository =
            messageRepository ?? GetIt.instance<MessageRepository>(),
        _modelRepository = modelRepository ?? GetIt.instance<ModelRepository>(),
        _sentinelRepository =
            sentinelRepository ?? GetIt.instance<SentinelRepository>();

  // Signals 状态
  final chats = listSignal<ChatEntity>([]);
  final chatHistories = listSignal<ChatHistoryEntity>([]);
  final currentChat = signal<ChatEntity?>(null);
  final messages = listSignal<MessageEntity>([]);
  final isLoading = signal(false);
  final isStreaming = signal(false);
  final error = signal<String?>(null);

  // 当前聊天的关联状态
  final currentModel = signal<ModelEntity?>(null);
  final currentProvider = signal<ProviderEntity?>(null);
  final currentSentinel = signal<SentinelEntity?>(null);
  final currentContext = signal(defaultDraftContext);
  final currentTemperature = signal(defaultDraftTemperature);
  final pendingImages = listSignal<String>([]);

  // 多选与重命名 UI 交互状态委托
  ChatSelectionDelegate get selection => _selection;

  // Computed signals
  late final recentChats = computed(() {
    return chats.value.take(10).toList();
  });

  late final recentChatHistories = computed(() {
    return chatHistories.value.take(10).toList();
  });

  late final pinnedChats = computed(() {
    return chats.value.where((c) => c.pinned).toList();
  });

  /// 更新 chats、chatHistories、currentChat 三个列表中的 chat 数据
  void _updateChatInLists(
    ChatEntity updated, {
    void Function()? onCurrentChatUpdated,
  }) {
    final idx = chats.value.indexWhere((c) => c.id == updated.id);
    if (idx >= 0) {
      final copy = List<ChatEntity>.from(chats.value);
      copy[idx] = updated;
      chats.value = copy;
    }

    final hIdx = chatHistories.value.indexWhere((h) => h.chat.id == updated.id);
    if (hIdx >= 0) {
      final copy = List<ChatHistoryEntity>.from(chatHistories.value);
      copy[hIdx] = ChatHistoryEntity(
        chat: updated,
        lastMessageContent: chatHistories.value[hIdx].lastMessageContent,
      );
      chatHistories.value = copy;
    }

    if (currentChat.value?.id == updated.id) {
      currentChat.value = updated;
      onCurrentChatUpdated?.call();
    }
  }

  void _updateMessageInList(int? messageId, MessageEntity updated) {
    var index = messages.value.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      var copy = List<MessageEntity>.from(messages.value);
      copy[index] = updated;
      messages.value = copy;
    }
  }

  // 业务方法

  /// 添加待发送图片
  void addPendingImage(String base64Image) {
    pendingImages.value = [...pendingImages.value, base64Image];
  }

  /// 清空待发送图片
  void clearPendingImages() {
    pendingImages.value = [];
  }

  /// 清空多选状态
  void clearSelection() => _selection.clearSelection();

  /// 切换单个对话的选中状态 (Cmd/Ctrl+Click)
  void toggleChatSelection(int chatId, int index) =>
      _selection.toggleChatSelection(chatId, index);

  /// 范围选择 (Shift+Click)
  void rangeSelectChats(int endIndex) =>
      _selection.rangeSelectChats(endIndex, chats.value);

  /// 初始化 lastSelectedIndex（用于首次打开时）
  void initLastSelectedIndex() =>
      _selection.initLastSelectedIndex(currentChat.value, chats.value);

  /// 开始 AI 重命名
  void startRenaming(int chatId) => _selection.startRenaming(chatId);

  /// 结束 AI 重命名
  void stopRenaming(int chatId) => _selection.stopRenaming(chatId);

  /// 创建新的聊天会话
  Future<ChatEntity?> createChat() async {
    isLoading.value = true;
    error.value = null;
    try {
      // 优先使用用户设置的默认模型，未设置则回退到第一个可用模型
      ModelEntity? model;
      var settingViewModel = GetIt.instance<SettingViewModel>();
      model = settingViewModel.chatModel.value;
      if (model == null || model.id == null || model.id! <= 0) {
        var modelViewModel = GetIt.instance<ModelViewModel>();
        await modelViewModel.loadEnabledModels();
        if (modelViewModel.enabledModels.value.isEmpty) {
          error.value = 'No enabled models found';
          return null;
        }
        model = modelViewModel.enabledModels.value.first;
      }

      var provider = await _support.getProviderForModel(
        model.providerId,
      );
      if (provider == null) {
        error.value = 'No provider found';
        return null;
      }
      currentProvider.value = provider;

      // 新建对话始终从默认值开始，避免沿用上一个会话的状态
      var selectedSentinel = await _getDefaultSentinel();
      if (selectedSentinel == null) {
        error.value = 'No sentinels found';
        return null;
      }

      var chat = await _manage.createChat(
        model: model,
        sentinel: selectedSentinel,
        context: defaultDraftContext,
        temperature: defaultDraftTemperature,
      );

      var pinnedChats = chats.value.where((c) => c.pinned).toList();
      var unpinnedChats = chats.value.where((c) => !c.pinned).toList();
      chats.value = [...pinnedChats, chat, ...unpinnedChats];
      currentChat.value = chat;
      currentModel.value = model;
      currentSentinel.value = selectedSentinel;
      currentContext.value = chat.context;
      currentTemperature.value = chat.temperature;
      pendingImages.value = [];
      messages.value = [];

      // 清除多选状态，更新选中索引为新建的对话
      clearSelection();
      _selection.lastSelectedIndex.value = pinnedChats.length; // 新对话在 pinnedChats 之后

      return chat;
    } catch (e) {
      error.value = e.toString();
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// 删除聊天会话
  Future<void> deleteChat(ChatEntity chat) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _manage.deleteChat(chat.id!);

      // 更新 chats 状态
      chats.value = chats.value.where((c) => c.id != chat.id).toList();

      // 更新 chatHistories 状态
      chatHistories.value = chatHistories.value
          .where((h) => h.chat.id != chat.id)
          .toList();

      // 如果删除的是当前聊天，选中第一个剩余对话
      if (currentChat.value?.id == chat.id) {
        await _selectFirstChatOrClear();
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 批量删除聊天会话
  Future<void> deleteChats(List<ChatEntity> chatsToDelete) async {
    isLoading.value = true;
    error.value = null;
    try {
      var idsToDelete = chatsToDelete.map((c) => c.id!).toSet();

      await _manage.deleteChats(idsToDelete);

      // 更新 chats 状态
      chats.value = chats.value
          .where((c) => !idsToDelete.contains(c.id))
          .toList();

      // 更新 chatHistories 状态
      chatHistories.value = chatHistories.value
          .where((h) => !idsToDelete.contains(h.chat.id))
          .toList();

      // 如果删除的包含当前聊天，选中第一个剩余对话
      if (currentChat.value != null &&
          idsToDelete.contains(currentChat.value!.id)) {
        await _selectFirstChatOrClear();
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 选中第一个对话，如果没有对话则清空状态
  Future<void> _selectFirstChatOrClear() async {
    if (chats.value.isNotEmpty) {
      var firstChat = chats.value.first;
      final result = await _manage.selectChat(firstChat);
      currentChat.value = firstChat;
      messages.value = result.messages;
      currentModel.value = result.model;
      currentProvider.value = result.provider;
      currentSentinel.value = result.sentinel;
      currentContext.value = firstChat.context;
      currentTemperature.value = firstChat.temperature;
      _selection.lastSelectedIndex.value = 0;
    } else {
      await prepareNewChatDraft();
      messages.value = [];
      _selection.lastSelectedIndex.value = null;
    }
  }

  /// 删除消息(从该消息开始的所有后续消息)
  Future<void> deleteMessage(MessageEntity message) async {
    isLoading.value = true;
    error.value = null;
    try {
      var index = messages.value.indexWhere((item) => item.id == message.id);
      if (index >= 0) {
        await _manage.deleteMessagesFromIndex(messages.value, index);
        messages.value = await _messageRepository.getMessagesByChatId(message.chatId);
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 导出聊天为图片（接收已渲染的 PNG 字节）
  Future<void> exportImage({
    required ChatEntity chat,
    required Uint8List bytes,
  }) async {
    try {
      await _support.saveImageFile(bytes, chat.id!);
    } catch (e) {
      error.value = e.toString();
    }
  }

  /// 加载所有聊天会话
  Future<void> getChats() async {
    isLoading.value = true;
    error.value = null;
    try {
      final (rawChats, histories) = await _manage.getChats();
      chats.value = rawChats;
      chatHistories.value = histories;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 获取第一个聊天
  Future<ChatEntity?> getFirstChat() async {
    if (chats.value.isEmpty) {
      await getChats();
    }
    if (chats.value.isEmpty) {
      return await createChat();
    }
    return chats.value.first;
  }

  Future<void> initSignals() async {
    final (rawChats, histories) = await _manage.getChats();
    chats.value = rawChats;
    chatHistories.value = histories;
    currentChat.value = chats.value.firstOrNull;

    if (currentChat.value != null) {
      final result = await _manage.selectChat(currentChat.value!);
      messages.value = result.messages;
      currentModel.value = result.model;
      currentProvider.value = result.provider;
      currentSentinel.value = result.sentinel;
      currentContext.value = currentChat.value!.context;
      currentTemperature.value = currentChat.value!.temperature;
    } else {
      await prepareNewChatDraft();
    }
  }

  Future<void> refreshMessages(int chatId) async {
    messages.value = await _messageRepository.getMessagesByChatId(chatId);
  }

  /// 移除待发送图片
  void removePendingImage(int index) {
    var images = List<String>.from(pendingImages.value);
    if (index >= 0 && index < images.length) {
      images.removeAt(index);
      pendingImages.value = images;
    }
  }

  /// 自动重命名聊天
  Future<ChatEntity?> renameChat(ChatEntity chat) async {
    if (chat.id == null) return null;
    if (_selection.renamingChatIds.value.contains(chat.id)) return null;

    startRenaming(chat.id!);
    _selection.renamingTitle.value = '';
    try {
      // 获取第一条用户消息
      var chatMessages = await _messageRepository.getMessagesByChatId(chat.id!);
      var firstUserMessage = chatMessages
          .where((m) => m.role == 'user')
          .firstOrNull;
      if (firstUserMessage == null) return null;

      // 获取model和provider
      var model = await _modelRepository.getModelById(chat.modelId);
      if (model == null) return null;
      var provider = await _support.getProviderForModel(
        model.providerId,
      );
      if (provider == null) return null;

      // 获取标题流
      var titleBuffer = StringBuffer();
      var stream = _support.renameChat(
        firstUserMessage.content,
        provider: provider,
        model: model,
      );

      await for (final chunk in stream) {
        titleBuffer.write(chunk);
        _selection.renamingTitle.value = titleBuffer.toString();
      }

      var title = titleBuffer.toString().trim();
      if (title.isEmpty) return null;

      var updated = await _support.renameChatManually(chat, title);
      _updateChatInLists(updated);

      return updated;
    } catch (e) {
      error.value = e.toString();
      return null;
    } finally {
      _selection.renamingTitle.value = '';
      stopRenaming(chat.id!);
    }
  }

  /// 手动重命名聊天
  Future<void> renameChatManually(ChatEntity chat, String title) async {
    if (title.isEmpty) return;
    isLoading.value = true;
    error.value = null;
    try {
      final updated = await _support.renameChatManually(chat, title);
      _updateChatInLists(updated);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 切换当前聊天
  Future<void> selectChat(ChatEntity chat) async {
    if (isStreaming.value) return;

    currentChat.value = chat;

    final result = await _manage.selectChat(chat);
    messages.value = result.messages;
    currentModel.value = result.model;
    currentProvider.value = result.provider;
    currentSentinel.value = result.sentinel;
    currentContext.value = chat.context;
    currentTemperature.value = chat.temperature;

    // 清空待发送图片
    pendingImages.value = [];
  }

  /// 发送消息(基础流式实现)
  ///
  /// 这是一个简化版本,实现了核心的流式聊天功能:
  /// 1. 保存用户消息
  /// 2. 获取历史上下文
  /// 3. 调用 AI 获取流式响应
  /// 4. 实时更新消息内容
  ///
  /// 待实现功能:
  /// - MCP 工具调用 (需要 MCP 架构完善)
  /// - 错误重试机制
  Future<void> sendMessage(
    MessageEntity message, {
    required ChatEntity chat,
  }) async {
    if (isStreaming.value) return;

    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;
    isStreaming.value = true;
    error.value = null;
    MessageEntity? assistantMessage;

    try {
      final ctx = await _prepareSendContext(message, chat);
      if (ctx == null) return;

      assistantMessage = await _manage.appendAssistantPlaceholder(chat.id!);
      messages.value = [...messages.value, assistantMessage];

      final settingVM = GetIt.instance<SettingViewModel>();
      final permissionService = GetIt.instance<PermissionService>();

      final agentStream = _agentService.run(
        chat: chat,
        provider: ctx.provider,
        model: ctx.model,
        baseMessages: ctx.wrappedMessages,
        maxIterations: settingVM.maxAgentIterations.value,
        auxiliaryModel: settingVM.auxiliaryModel.value,
        auxiliaryModelProvider: settingVM.auxiliaryModelProvider.value,
        permissionService: permissionService,
        cancelToken: cancelToken,
        onPermission: (toolName, arguments) =>
            _askPermission(toolName, arguments, permissionService, cancelToken),
      );

      assistantMessage = await _consumeAgentStream(
        chat: chat,
        assistantMessage: assistantMessage,
        cancelToken: cancelToken,
        agentStream: agentStream,
      );

      await _manage.finalizeAssistantMessage(assistantMessage);
      await _manage.updateChatTimestamp(chat);
      await getChats();
    } on CancelledException {
      if (assistantMessage != null) {
        final cancelled =
            await _manage.recordCancelledOnMessage(assistantMessage);
        _updateMessageInList(cancelled.id, cancelled);
      }
    } catch (e) {
      error.value = e.toString();
      if (assistantMessage != null) {
        final errored = await _manage.recordErrorOnMessage(assistantMessage, e);
        _updateMessageInList(errored.id, errored);
      }
    } finally {
      isStreaming.value = false;
      _activeCancelToken = null;
    }
  }

  /// 切换聊天的置顶状态
  Future<void> togglePin(ChatEntity chat) async {
    error.value = null;
    try {
      await _manage.togglePin(chat);

      // 重新加载聊天列表以应用排序
      await getChats();
    } catch (e) {
      error.value = e.toString();
    }
  }

  /// 更新上下文轮数
  Future<ChatEntity?> updateContext(
    int context, {
    required ChatEntity chat,
  }) async {
    error.value = null;
    try {
      final updated = await _support.updateContext(chat, context);
      _updateChatInLists(
        updated,
        onCurrentChatUpdated: () {
          currentContext.value = updated.context;
        },
      );
      return updated;
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  /// 更新消息的expanded状态
  Future<void> updateExpanded(MessageEntity message) async {
    try {
      var updated = await _support.updateExpanded(message);

      // 更新signals中的消息
      var index = messages.value.indexWhere((m) => m.id == message.id);
      if (index >= 0) {
        var updatedMessages = List<MessageEntity>.from(messages.value);
        updatedMessages[index] = updated;
        messages.value = updatedMessages;
      }
    } catch (e) {
      error.value = e.toString();
    }
  }

  /// 更新聊天的模型
  Future<ChatEntity?> updateModel(
    ModelEntity model, {
    required ChatEntity chat,
  }) async {
    error.value = null;
    try {
      final updated = await _support.updateModel(chat, model.id!);
      _updateChatInLists(
        updated,
        onCurrentChatUpdated: () async {
          currentModel.value = model;
          currentProvider.value = await _support.getProviderForModel(
            model.providerId,
          );
        },
      );
      return updated;
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  /// 更新聊天的哨兵
  Future<ChatEntity?> updateSentinel(
    SentinelEntity sentinel, {
    required ChatEntity chat,
  }) async {
    error.value = null;
    try {
      final updated = await _support.updateSentinel(chat, sentinel.id!);
      _updateChatInLists(
        updated,
        onCurrentChatUpdated: () {
          currentSentinel.value = sentinel;
        },
      );
      return updated;
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  /// 更新温度参数
  Future<ChatEntity?> updateTemperature(
    double temperature, {
    required ChatEntity chat,
  }) async {
    error.value = null;
    try {
      final updated = await _support.updateTemperature(chat, temperature);
      _updateChatInLists(
        updated,
        onCurrentChatUpdated: () {
          currentTemperature.value = updated.temperature;
        },
      );
      return updated;
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  /// 更新当前模型（没有选中对话时使用）
  Future<void> updateCurrentModel(ModelEntity model) async {
    currentModel.value = model;
    currentProvider.value = await _support.getProviderForModel(
      model.providerId,
    );
  }

  /// 更新当前哨兵（没有选中对话时使用）
  void updateCurrentSentinel(SentinelEntity sentinel) {
    currentSentinel.value = sentinel;
  }

  void updateCurrentContext(int context) {
    currentContext.value = context;
  }

  void updateCurrentTemperature(double temperature) {
    currentTemperature.value = temperature;
  }

  Future<void> prepareNewChatDraft() async {
    currentChat.value = null;
    messages.value = [];
    pendingImages.value = [];
    await _syncDraftDefaults();
  }

  /// 停止当前流式生成
  void stopGenerating() {
    _activeCancelToken?.cancel();
  }

  Future<SentinelEntity?> _getDefaultSentinel() async {
    final sentinelViewModel = GetIt.instance<SentinelViewModel>();
    if (sentinelViewModel.sentinels.value.isEmpty) {
      await sentinelViewModel.getSentinels();
    }
    return sentinelViewModel.defaultSentinel.value;
  }

  Future<void> _syncDraftDefaults() async {
    final settingViewModel = GetIt.instance<SettingViewModel>();
    currentModel.value = settingViewModel.chatModel.value;
    currentProvider.value = settingViewModel.chatModelProvider.value;

    if (currentModel.value == null) {
      final modelViewModel = GetIt.instance<ModelViewModel>();
      await modelViewModel.loadEnabledModels();
      currentModel.value = modelViewModel.enabledModels.value.firstOrNull;
      if (currentModel.value != null) {
        currentProvider.value = await _support.getProviderForModel(
          currentModel.value!.providerId,
        );
      }
    }

    currentSentinel.value = await _getDefaultSentinel();
    currentContext.value = defaultDraftContext;
    currentTemperature.value = defaultDraftTemperature;
  }

  Future<MessageEntity> _consumeAgentStream({
    required ChatEntity chat,
    required MessageEntity assistantMessage,
    required CancelToken cancelToken,
    required Stream<AgentEvent> agentStream,
  }) async {
    var current = assistantMessage;
    var contentBuffer = StringBuffer();
    var reasoningBuffer = StringBuffer();
    var toolCallsJson = <Map<String, dynamic>>[];
    var toolResultsJson = <Map<String, dynamic>>[];
    var hasCompletedIteration = false;

    await for (final event in agentStream) {
      cancelToken.throwIfCancelled();

      if (event is AgentReasoningEvent) {
        if (hasCompletedIteration) {
          current = await _advanceIteration(chat, current);
          contentBuffer = StringBuffer();
          reasoningBuffer = StringBuffer();
          toolCallsJson = [];
          toolResultsJson = [];
          hasCompletedIteration = false;
        }
        reasoningBuffer.write(event.delta);
        current = current.copyWith(
          reasoningContent: reasoningBuffer.toString(),
          reasoning: true,
          reasoningUpdatedAt: DateTime.now(),
        );
        _updateMessageInList(current.id, current);
      } else if (event is AgentTextEvent) {
        if (hasCompletedIteration) {
          current = await _advanceIteration(chat, current);
          contentBuffer = StringBuffer();
          reasoningBuffer = StringBuffer();
          toolCallsJson = [];
          toolResultsJson = [];
          hasCompletedIteration = false;
        }
        contentBuffer.write(event.delta);
        current = current.copyWith(content: contentBuffer.toString());
        _updateMessageInList(current.id, current);
      } else if (event is AgentToolCallEvent) {
        toolCallsJson.add({
          'id': event.id,
          'name': event.name,
          'arguments': event.arguments,
        });
        current = current.copyWith(toolCalls: jsonEncode(toolCallsJson));
        _updateMessageInList(current.id, current);
      } else if (event is AgentToolResultEvent) {
        toolResultsJson.add({
          'id': event.id,
          'name': event.name,
          'result': event.result,
        });
        current = current.copyWith(toolResults: jsonEncode(toolResultsJson));
        _updateMessageInList(current.id, current);
        hasCompletedIteration = true;
      } else if (event is AgentDoneEvent) {
        current = current.copyWith(content: event.content);
        _updateMessageInList(current.id, current);
      }
    }

    if (reasoningBuffer.isNotEmpty) {
      current = current.copyWith(reasoning: false);
      _updateMessageInList(current.id, current);
    }

    return current;
  }

  /// 推进到下一轮 iteration：finalize 上一条 assistant，append 新占位
  Future<MessageEntity> _advanceIteration(
    ChatEntity chat,
    MessageEntity current,
  ) async {
    await _manage.finalizeAssistantMessage(current);
    final next = await _manage.appendAssistantPlaceholder(chat.id!);
    messages.value = [...messages.value, next];
    return next;
  }

  Future<_SendContext?> _prepareSendContext(
    MessageEntity message,
    ChatEntity chat,
  ) async {
    // 1. 保存用户消息
    final id = await _messageRepository.storeMessage(message);
    final userMessage = message.copyWith(id: id);
    messages.value = [...messages.value, userMessage];

    // 首条用户消息入库后立即异步触发自动命名
    final isDefaultTitle = chat.title.isEmpty || chat.title == 'New Chat';
    if (isDefaultTitle) {
      if (await _chatMessageService.isFirstUserMessage(chat.id!)) {
        unawaited(renameChat(chat));
      }
    }

    // 2. 获取 model / provider / sentinel
    final model = await _modelRepository.getModelById(chat.modelId);
    if (model == null) {
      error.value = 'Model not found';
      return null;
    }
    final provider = await _support.getProviderForModel(model.providerId);
    if (provider == null) {
      error.value = 'Provider not found';
      return null;
    }
    final sentinel = await _sentinelRepository.getSentinelById(chat.sentinelId);

    // 3. 构建消息上下文
    final wrappedMessages = await _chatMessageService.buildMessages(
      chat: chat,
      sentinel: sentinel,
    );

    return _SendContext(
      model: model,
      provider: provider,
      sentinel: sentinel,
      wrappedMessages: wrappedMessages,
    );
  }

  Future<bool> _askPermission(
    String toolName,
    String arguments,
    PermissionService permissionService,
    CancelToken cancelToken,
  ) async {
    if (cancelToken.isCancelled) return false;
    Map<String, dynamic> args;
    try {
      args = jsonDecode(arguments) as Map<String, dynamic>;
    } catch (_) {
      args = {};
    }
    final description = _formatToolArgs(toolName, arguments);
    final ruleDesc = permissionService.generateRuleDescription(toolName, args);
    final isDangerous = permissionService.isDangerous(toolName, args);
    final isFileRule = const {
      'file_read',
      'file_write',
      'file_update',
      'file_delete',
    }.contains(toolName);

    final dialogFuture = showPermissionDialog(
      toolName: toolName,
      description: description,
      ruleDescription: ruleDesc,
      allowPersist: !isDangerous,
      isFileRule: isFileRule,
    );

    final result = await Future.any<PermissionDialogResult>([
      dialogFuture,
      cancelToken.whenCancelled.then((_) {
        final nav = router.navigatorKey.currentState;
        if (nav?.canPop() ?? false) nav!.pop();
        return const PermissionDialogResult(approved: false, persist: false);
      }),
    ]);

    if (result.approved && result.persist) {
      final rule = permissionService.generateRule(
        toolName,
        args,
        recursive: result.recursive,
      );
      await permissionService.persistRule(rule);
    }
    return result.approved;
  }

  String _formatToolArgs(String toolName, String arguments) {
    final buffer = StringBuffer();
    buffer.writeln('Agent wants to use: $toolName');
    try {
      final args = jsonDecode(arguments) as Map<String, dynamic>;
      for (final entry in args.entries) {
        var value = entry.value.toString();
        if (value.length > 120) {
          value = '${value.substring(0, 120)}...';
        }
        buffer.writeln('  ${entry.key}: $value');
      }
    } catch (_) {
      if (arguments.length > 200) {
        buffer.writeln('  ${arguments.substring(0, 200)}...');
      } else {
        buffer.writeln('  $arguments');
      }
    }
    return buffer.toString();
  }
}

class _SendContext {
  final ModelEntity model;
  final ProviderEntity provider;
  final SentinelEntity? sentinel;
  final List<ChatMessage> wrappedMessages;

  _SendContext({
    required this.model,
    required this.provider,
    required this.sentinel,
    required this.wrappedMessages,
  });
}
