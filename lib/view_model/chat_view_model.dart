import 'dart:async';
import 'dart:convert';

import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/permission/permission_dialog.dart';
import 'package:athena/agent/permission/permission_service.dart';
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
import 'package:athena/service/message_send_service.dart';
import 'package:athena/view_model/delegate/chat_selection_delegate.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals.dart';

/// ChatViewModel 负责聊天会话的业务逻辑
class ChatViewModel {
  static const int defaultDraftContext = 0;
  static const double defaultDraftTemperature = 1.0;

  final ChatManageService _manage;
  final ChatSupportService _support;
  final ChatMessageService _chatMessageService;
  final ChatSelectionDelegate _selection;

  MessageSendService? _sendService;

  ChatViewModel({
    ChatManageService? manageService,
    MessageSendService? sendService,
    ChatSupportService? supportService,
    ChatMessageService? chatMessageService,
    ChatSelectionDelegate? selection,
  })  : _manage = manageService ?? ChatManageService(),
        _sendService = sendService,
        _support = supportService ?? ChatSupportService(),
        _chatMessageService = chatMessageService ?? ChatMessageService(),
        _selection = selection ?? ChatSelectionDelegate();

  /// Lazily initialised getter for MessageSendService.
  /// Uses GetIt to resolve AgentService, which may not be available
  /// in lightweight contexts (e.g. tests that only inspect signals).
  MessageSendService get _send {
    _sendService ??= MessageSendService(
      agentService: GetIt.instance<AgentService>(),
    );
    return _sendService!;
  }

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

  // 保持向后兼容的信号访问器
  SetSignal<int> get selectedChatIds => _selection.selectedChatIds;
  Signal<int?> get lastSelectedIndex => _selection.lastSelectedIndex;
  SetSignal<int> get renamingChatIds => _selection.renamingChatIds;
  Signal<String> get renamingTitle => _selection.renamingTitle;
  late final isMultiSelect = _selection.isMultiSelect;

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
      lastSelectedIndex.value = pinnedChats.length; // 新对话在 pinnedChats 之后

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
      lastSelectedIndex.value = 0;
    } else {
      await prepareNewChatDraft();
      messages.value = [];
      lastSelectedIndex.value = null;
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
        messages.value = await _manage.refreshMessages(message.chatId);
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 导出聊天为图片
  Future<void> exportImage({
    required ChatEntity chat,
    required GlobalKey repaintBoundaryKey,
  }) async {
    try {
      final bytes = await _support.exportImage(repaintBoundaryKey);
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
    messages.value = await _manage.refreshMessages(chatId);
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
    if (renamingChatIds.value.contains(chat.id)) return null;

    startRenaming(chat.id!);
    renamingTitle.value = '';
    try {
      // 获取第一条用户消息
      var chatMessages = await _manage.refreshMessages(chat.id!);
      var firstUserMessage = chatMessages
          .where((m) => m.role == 'user')
          .firstOrNull;
      if (firstUserMessage == null) return null;

      // 获取model和provider
      var model = await _manage.getModel(chat.modelId);
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
        renamingTitle.value = titleBuffer.toString();
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
      renamingTitle.value = '';
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

    isStreaming.value = true;
    error.value = null;
    int? assistantId;
    MessageEntity? assistantMessage;

    try {
      // 1. 保存用户消息
      var id = await _manage.storeMessage(message);
      var userMessage = message.copyWith(id: id);
      messages.value = [...messages.value, userMessage];

      // 首条用户消息入库后立即异步触发自动命名
      var isDefaultTitle = chat.title.isEmpty || chat.title == 'New Chat';
      if (isDefaultTitle) {
        if (await _chatMessageService.isFirstUserMessage(chat.id!)) {
          unawaited(renameChat(chat));
        }
      }

      // 2. 获取model、provider、sentinel
      var model = await _manage.getModel(chat.modelId);
      if (model == null) {
        error.value = 'Model not found';
        return;
      }
      var provider = await _support.getProviderForModel(
        model.providerId,
      );
      if (provider == null) {
        error.value = 'Provider not found';
        return;
      }
      var sentinel = await _manage.getSentinel(chat.sentinelId);

      // 3. 构建消息上下文（委托给 ChatMessageService）
      var wrappedMessages = await _chatMessageService.buildMessages(
        chat: chat,
        sentinel: sentinel,
      );

      // 4. 创建 assistant 消息占位
      assistantMessage = MessageEntity(
        chatId: chat.id!,
        role: 'assistant',
        content: '',
      );
      assistantId = await _manage.storeMessage(assistantMessage);
      assistantMessage = assistantMessage.copyWith(id: assistantId);
      messages.value = [...messages.value, assistantMessage];

      // 5. AgentService 编排
      var toolCallsJson = <Map<String, dynamic>>[];
      var toolResultsJson = <Map<String, dynamic>>[];

      final settingVM = GetIt.instance<SettingViewModel>();
      final permissionService = GetIt.instance<PermissionService>();

      var agentStream = _send.sendMessage(
        chat: chat,
        provider: provider,
        model: model,
        baseMessages: wrappedMessages,
        maxIterations: settingVM.maxAgentIterations.value,
        auxiliaryModel: settingVM.auxiliaryModel.value,
        auxiliaryModelProvider: settingVM.auxiliaryModelProvider.value,
        permissionService: permissionService,
        onPermission: (toolName, arguments) async {
          final context = router.navigatorKey.currentContext;
          if (context == null) return false;
          Map<String, dynamic> args;
          try {
            args = jsonDecode(arguments) as Map<String, dynamic>;
          } catch (_) {
            args = {};
          }
          final description = _send.formatToolArgs(toolName, arguments);
          final ruleDesc = permissionService.generateRuleDescription(
            toolName,
            args,
          );
          final isDangerous = permissionService.isDangerous(toolName, args);
          final isFileRule = const {
            'file_read',
            'file_write',
            'file_update',
            'file_delete',
          }.contains(toolName);
          final result = await showPermissionDialog(
            toolName: toolName,
            description: description,
            ruleDescription: ruleDesc,
            allowPersist: !isDangerous,
            isFileRule: isFileRule,
          );
          if (result.approved && result.persist) {
            final rule = permissionService.generateRule(
              toolName,
              args,
              recursive: result.recursive,
            );
            await permissionService.persistRule(rule);
          }
          return result.approved;
        },
      );

      var contentBuffer = StringBuffer();
      var reasoningBuffer = StringBuffer();
      var hasCompletedIteration = false;

      await for (final event in agentStream) {
        if (!isStreaming.value) break;

        if (event is SendReasoningDelta) {
          if (hasCompletedIteration) {
            await _manage.updateMessage(assistantMessage!);
            assistantMessage = MessageEntity(
              chatId: chat.id!,
              role: 'assistant',
              content: '',
            );
            assistantId = await _manage.storeMessage(
              assistantMessage,
            );
            assistantMessage = assistantMessage.copyWith(id: assistantId);
            messages.value = [...messages.value, assistantMessage];
            contentBuffer = StringBuffer();
            reasoningBuffer = StringBuffer();
            toolCallsJson = [];
            toolResultsJson = [];
            hasCompletedIteration = false;
          }
          reasoningBuffer.write(event.delta);
          assistantMessage = assistantMessage!.copyWith(
            reasoningContent: reasoningBuffer.toString(),
            reasoning: true,
            reasoningUpdatedAt: DateTime.now(),
          );
          _updateMessageInList(assistantId, assistantMessage);
        } else if (event is SendTextDelta) {
          if (hasCompletedIteration) {
            await _manage.updateMessage(assistantMessage!);
            assistantMessage = MessageEntity(
              chatId: chat.id!,
              role: 'assistant',
              content: '',
            );
            assistantId = await _manage.storeMessage(
              assistantMessage,
            );
            assistantMessage = assistantMessage.copyWith(id: assistantId);
            messages.value = [...messages.value, assistantMessage];
            contentBuffer = StringBuffer();
            reasoningBuffer = StringBuffer();
            toolCallsJson = [];
            toolResultsJson = [];
            hasCompletedIteration = false;
          }
          contentBuffer.write(event.delta);
          assistantMessage = assistantMessage!.copyWith(
            content: contentBuffer.toString(),
          );
          _updateMessageInList(assistantId, assistantMessage);
        } else if (event is SendToolCall) {
          toolCallsJson.add({
            'id': event.id,
            'name': event.name,
            'arguments': event.arguments,
          });
          assistantMessage = assistantMessage!.copyWith(
            toolCalls: jsonEncode(toolCallsJson),
          );
          _updateMessageInList(assistantId, assistantMessage);
        } else if (event is SendToolResult) {
          toolResultsJson.add({
            'id': event.id,
            'name': event.name,
            'result': event.result,
          });
          assistantMessage = assistantMessage!.copyWith(
            toolResults: jsonEncode(toolResultsJson),
          );
          _updateMessageInList(assistantId, assistantMessage);
          hasCompletedIteration = true;
        } else if (event is SendDone) {
          assistantMessage = assistantMessage!.copyWith(content: event.content);
          _updateMessageInList(assistantId, assistantMessage);
        }
      }

      // 标记推理完成
      if (reasoningBuffer.isNotEmpty) {
        assistantMessage = assistantMessage!.copyWith(reasoning: false);
        _updateMessageInList(assistantId, assistantMessage);
      }

      // 6. 保存最终消息并更新时间戳
      await _manage.updateMessage(assistantMessage!);
      await _manage.updateChatTimestamp(chat);
      await getChats();
    } catch (e) {
      error.value = e.toString();
      if (assistantId != null && assistantMessage != null) {
        var preservedContent = assistantMessage.content.isEmpty
            ? 'Error: ${e.toString()}'
            : '${assistantMessage.content}\n\n[Error: ${e.toString()}]';
        var preserved = assistantMessage.copyWith(
          content: preservedContent,
          reasoning: false,
        );
        await _manage.updateMessage(preserved);
        _updateMessageInList(assistantId, preserved);
      }
    } finally {
      isStreaming.value = false;
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
}
