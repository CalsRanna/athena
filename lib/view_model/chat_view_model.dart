import 'dart:io';
import 'dart:ui' as ui;

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
import 'package:athena/service/chat_service.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get_it/get_it.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signals/signals.dart';

/// ChatViewModel 负责聊天会话的业务逻辑
class ChatViewModel {
  // ViewModel 内部直接持有 Service/Repository
  final ChatRepository _chatRepository = ChatRepository();
  final MessageRepository _messageRepository = MessageRepository();
  final SentinelRepository _sentinelRepository = SentinelRepository();
  final ProviderRepository _providerRepository = ProviderRepository();
  final ModelRepository _modelRepository = ModelRepository();

  final ChatService _chatService = ChatService();

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
  final pendingImages = listSignal<String>([]);

  // 多选状态
  final selectedChatIds = setSignal<int>({});
  final lastSelectedIndex = signal<int?>(null);

  // AI 重命名状态
  final renamingChatIds = setSignal<int>({});

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

  late final isMultiSelect = computed(() {
    return selectedChatIds.value.length > 1;
  });

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
  void clearSelection() {
    selectedChatIds.value = {};
    lastSelectedIndex.value = null;
  }

  /// 切换单个对话的选中状态 (Cmd/Ctrl+Click)
  void toggleChatSelection(int chatId, int index) {
    var newSet = Set<int>.from(selectedChatIds.value);
    if (newSet.contains(chatId)) {
      newSet.remove(chatId);
      if (newSet.isEmpty) {
        lastSelectedIndex.value = null;
      }
    } else {
      newSet.add(chatId);
      lastSelectedIndex.value = index;
    }
    selectedChatIds.value = newSet;
  }

  /// 范围选择 (Shift+Click)
  void rangeSelectChats(int endIndex) {
    if (selectedChatIds.value.isEmpty && lastSelectedIndex.value == null) {
      return;
    }

    // Find the first selected index in the list
    int? firstSelectedIndex;
    if (selectedChatIds.value.isNotEmpty) {
      for (var i = 0; i < chats.value.length; i++) {
        if (selectedChatIds.value.contains(chats.value[i].id)) {
          firstSelectedIndex = i;
          break;
        }
      }
    }

    var startIndex = firstSelectedIndex ?? lastSelectedIndex.value;
    if (startIndex == null) return;

    var start = startIndex;
    var end = endIndex;
    if (start > end) {
      var temp = start;
      start = end;
      end = temp;
    }

    var newSet = Set<int>.from(selectedChatIds.value);
    for (var i = start; i <= end; i++) {
      if (i < chats.value.length) {
        var chatId = chats.value[i].id;
        if (chatId != null) {
          newSet.add(chatId);
        }
      }
    }
    selectedChatIds.value = newSet;
  }

  /// 初始化 lastSelectedIndex（用于首次打开时）
  void initLastSelectedIndex() {
    if (lastSelectedIndex.value == null && currentChat.value != null) {
      var index = chats.value.indexWhere((c) => c.id == currentChat.value!.id);
      if (index >= 0) {
        lastSelectedIndex.value = index;
      }
    }
  }

  /// 开始 AI 重命名
  void startRenaming(int chatId) {
    renamingChatIds.value = {...renamingChatIds.value, chatId};
  }

  /// 结束 AI 重命名
  void stopRenaming(int chatId) {
    var newSet = Set<int>.from(renamingChatIds.value);
    newSet.remove(chatId);
    renamingChatIds.value = newSet;
  }

  /// 创建新的聊天会话
  Future<ChatEntity?> createChat({SentinelEntity? sentinel}) async {
    isLoading.value = true;
    error.value = null;
    try {
      // 优先使用当前选择的模型，否则使用设置中的默认模型
      ModelEntity? model = currentModel.value;
      if (model == null) {
        var settingViewModel = GetIt.instance<SettingViewModel>();
        var modelId = settingViewModel.chatModelId.value;
        if (modelId > 0) {
          model = await _modelRepository.getModelById(modelId);
        }
      }
      if (model == null) {
        var modelViewModel = GetIt.instance<ModelViewModel>();
        await modelViewModel.loadEnabledModels();
        if (modelViewModel.enabledModels.value.isEmpty) {
          error.value = 'No enabled models found';
          return null;
        }
        model = modelViewModel.enabledModels.value.first;
      }

      var provider = await _providerRepository.getProviderById(
        model.providerId,
      );
      if (provider == null) {
        error.value = 'No provider found';
        return null;
      }
      currentProvider.value = provider;

      // 优先使用传入的 sentinel，其次使用当前选择的 sentinel，最后使用第一个 sentinel
      var selectedSentinel = sentinel ?? currentSentinel.value;
      if (selectedSentinel == null) {
        var sentinels = await _sentinelRepository.getAllSentinels();
        selectedSentinel = sentinels.firstOrNull;
      }
      if (selectedSentinel == null) {
        error.value = 'No sentinels found';
        return null;
      }

      var now = DateTime.now();
      var chat = ChatEntity(
        title: 'New Chat',
        modelId: model.id!,
        sentinelId: selectedSentinel.id!,
        createdAt: now,
        updatedAt: now,
      );

      var id = await _chatRepository.createChat(chat);
      chat = chat.copyWith(id: id);

      var pinnedChats = chats.value.where((c) => c.pinned).toList();
      var unpinnedChats = chats.value.where((c) => !c.pinned).toList();
      chats.value = [...pinnedChats, chat, ...unpinnedChats];
      currentChat.value = chat;
      currentModel.value = model;
      currentSentinel.value = selectedSentinel;
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
      await _chatRepository.deleteChat(chat.id!);
      await _messageRepository.deleteMessagesByChatId(chat.id!);

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

      for (var chat in chatsToDelete) {
        await _chatRepository.deleteChat(chat.id!);
        await _messageRepository.deleteMessagesByChatId(chat.id!);
      }

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
      currentChat.value = firstChat;
      messages.value = await _messageRepository.getMessagesByChatId(
        firstChat.id!,
      );
      currentModel.value = await _modelRepository.getModelById(
        firstChat.modelId,
      );
      if (currentModel.value != null) {
        currentProvider.value = await _providerRepository.getProviderById(
          currentModel.value!.providerId,
        );
      }
      currentSentinel.value = await _sentinelRepository.getSentinelById(
        firstChat.sentinelId,
      );
      lastSelectedIndex.value = 0;
    } else {
      currentChat.value = null;
      currentModel.value = null;
      currentProvider.value = null;
      currentSentinel.value = null;
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
        // 删除从该消息开始的所有后续消息
        for (var i = index; i < messages.length; i++) {
          await _messageRepository.deleteMessage(messages[i].id!);
        }
        // 重新加载消息
        messages.value = await _messageRepository.getMessagesByChatId(
          message.chatId,
        );
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
      // 获取RenderRepaintBoundary
      final boundary =
          repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        error.value = 'Failed to get render boundary';
        return;
      }

      // 渲染为图片
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        error.value = 'Failed to convert image to bytes';
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      // 保存图片
      if (Platform.isAndroid || Platform.isIOS) {
        // 移动端保存到Documents文件夹
        final directory = await getApplicationDocumentsDirectory();
        final filePath =
            '${directory.path}/chat_${chat.id}_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(pngBytes);
      } else {
        // 桌面端保存到Downloads���件夹
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          error.value = 'Failed to get downloads directory';
          return;
        }
        final filePath =
            '${directory.path}/chat_${chat.id}_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(pngBytes);
      }
    } catch (e) {
      error.value = e.toString();
    }
  }

  /// 加载所有聊天会话
  Future<void> getChats() async {
    isLoading.value = true;
    error.value = null;
    try {
      chats.value = await _chatRepository.getAllChats();
      chatHistories.value = await _chatRepository.getAllChatsWithLastMessage();
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
    chats.value = await _chatRepository.getAllChats();
    chatHistories.value = await _chatRepository.getAllChatsWithLastMessage();
    currentChat.value = chats.value.firstOrNull;

    if (currentChat.value != null) {
      // 有对话时，加载对话的消息和关联信息
      messages.value = await _messageRepository.getMessagesByChatId(
        currentChat.value!.id!,
      );
      currentModel.value = await _modelRepository.getModelById(
        currentChat.value!.modelId,
      );
      if (currentModel.value != null) {
        currentProvider.value = await _providerRepository.getProviderById(
          currentModel.value!.providerId,
        );
      }
      currentSentinel.value = await _sentinelRepository.getSentinelById(
        currentChat.value!.sentinelId,
      );
    } else {
      // 没有对话时，使用设置中的默认模型和默认哨兵
      var settingViewModel = GetIt.instance<SettingViewModel>();
      currentModel.value = settingViewModel.chatModel.value;
      currentProvider.value = settingViewModel.chatModelProvider.value;

      // 使用默认哨兵
      var sentinels = await _sentinelRepository.getAllSentinels();
      currentSentinel.value = sentinels.firstOrNull;
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
    startRenaming(chat.id!);
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
      var provider = await _providerRepository.getProviderById(
        model.providerId,
      );
      if (provider == null) return null;

      // 获取标题流
      var titleBuffer = StringBuffer();
      var stream = _chatService.getTitle(
        firstUserMessage.content,
        provider: provider,
        model: model,
      );

      await for (final chunk in stream) {
        titleBuffer.write(chunk);
      }

      var title = titleBuffer.toString().trim();
      if (title.isEmpty) return null;

      // 更新chat标题
      var updated = chat.copyWith(title: title);
      await _chatRepository.updateChat(updated);

      // 更新 chats 状态
      var index = chats.value.indexWhere((c) => c.id == chat.id);
      if (index >= 0) {
        var updatedChats = List<ChatEntity>.from(chats.value);
        updatedChats[index] = updated;
        chats.value = updatedChats;
      }

      // 更新 chatHistories 状态
      var historyIndex = chatHistories.value.indexWhere(
        (h) => h.chat.id == chat.id,
      );
      if (historyIndex >= 0) {
        var updatedHistories = List<ChatHistoryEntity>.from(
          chatHistories.value,
        );
        updatedHistories[historyIndex] = ChatHistoryEntity(
          chat: updated,
          lastMessageContent:
              chatHistories.value[historyIndex].lastMessageContent,
        );
        chatHistories.value = updatedHistories;
      }

      // 如果是当前选中的对话，也更新 currentChat
      if (currentChat.value?.id == chat.id) {
        currentChat.value = updated;
      }

      return updated;
    } catch (e) {
      error.value = e.toString();
      return null;
    } finally {
      stopRenaming(chat.id!);
    }
  }

  /// 手动重命名聊天
  Future<void> renameChatManually(ChatEntity chat, String title) async {
    if (title.isEmpty) return;
    isLoading.value = true;
    error.value = null;
    try {
      var updated = chat.copyWith(title: title);
      await _chatRepository.updateChat(updated);

      // 更新 chats 状态
      var index = chats.value.indexWhere((c) => c.id == chat.id);
      if (index >= 0) {
        var updatedChats = List<ChatEntity>.from(chats.value);
        updatedChats[index] = updated;
        chats.value = updatedChats;
      }

      // 更新 chatHistories 状态
      var historyIndex = chatHistories.value.indexWhere(
        (h) => h.chat.id == chat.id,
      );
      if (historyIndex >= 0) {
        var updatedHistories = List<ChatHistoryEntity>.from(
          chatHistories.value,
        );
        updatedHistories[historyIndex] = ChatHistoryEntity(
          chat: updated,
          lastMessageContent:
              chatHistories.value[historyIndex].lastMessageContent,
        );
        chatHistories.value = updatedHistories;
      }

      if (currentChat.value?.id == chat.id) {
        currentChat.value = updated;
      }
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

    // 加载消息
    messages.value = await _messageRepository.getMessagesByChatId(chat.id!);

    // 加载关联的 model
    var model = await _modelRepository.getModelById(chat.modelId);
    currentModel.value = model;

    // 加载关联的 provider
    var provider = await _providerRepository.getProviderById(model!.providerId);
    currentProvider.value = provider;

    // 加载关联的 sentinel
    var sentinel = await _sentinelRepository.getSentinelById(chat.sentinelId);
    currentSentinel.value = sentinel;

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
  /// - 搜索集成 (需要 SearchService)
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

    try {
      // 1. 保存用户消息
      var id = await _messageRepository.storeMessage(message);
      var userMessage = message.copyWith(id: id);
      messages.value = [...messages.value, userMessage];

      // 2. 获取model和provider
      var model = await _modelRepository.getModelById(chat.modelId);
      if (model == null) {
        error.value = 'Model not found';
        return;
      }
      var provider = await _providerRepository.getProviderById(
        model.providerId,
      );
      if (provider == null) {
        error.value = 'Provider not found';
        return;
      }

      // 3. 获取sentinel
      var sentinel = await _sentinelRepository.getSentinelById(chat.sentinelId);

      // 4. 构建历史消息上下文
      var chatMessages = await _messageRepository.getMessagesByChatId(chat.id!);
      var contextLimit = chat.context * 2; // 每轮对话包含user和assistant两条消息
      var contextMessages =
          chatMessages.length > contextLimit && chat.context > 0
          ? chatMessages.sublist(chatMessages.length - contextLimit)
          : chatMessages;

      // 5. 转换为OpenAI格式并添加system message
      var wrappedMessages = <ChatCompletionMessage>[];
      if (sentinel != null && sentinel.prompt.isNotEmpty) {
        wrappedMessages.add(
          ChatCompletionMessage.system(content: sentinel.prompt),
        );
      }

      for (var contextMessage in contextMessages) {
        if (contextMessage.role == 'system') {
          wrappedMessages.add(
            ChatCompletionMessage.system(content: contextMessage.content),
          );
        } else if (contextMessage.role == 'assistant') {
          wrappedMessages.add(
            ChatCompletionMessage.assistant(content: contextMessage.content),
          );
        } else {
          // Handle images
          if (contextMessage.imageUrls.isNotEmpty) {
            var imageList = contextMessage.imageUrls.split(',');
            var contentParts = <ChatCompletionMessageContentPart>[
              ChatCompletionMessageContentPart.text(
                text: contextMessage.content,
              ),
            ];
            for (var imageUrl in imageList) {
              contentParts.add(
                ChatCompletionMessageContentPart.image(
                  imageUrl: ChatCompletionMessageImageUrl(
                    url: 'data:image/jpeg;base64,$imageUrl',
                  ),
                ),
              );
            }
            wrappedMessages.add(
              ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.parts(contentParts),
              ),
            );
          } else {
            wrappedMessages.add(
              ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.string(
                  contextMessage.content,
                ),
              ),
            );
          }
        }
      }

      // 6. 创建assistant消息用于流式更新
      var assistantMessage = MessageEntity(
        chatId: chat.id!,
        role: 'assistant',
        content: '',
      );
      assistantId = await _messageRepository.storeMessage(assistantMessage);
      assistantMessage = assistantMessage.copyWith(id: assistantId);
      messages.value = [...messages.value, assistantMessage];

      // 7. 获取流式响应
      var contentBuffer = StringBuffer();
      var reasoningBuffer = StringBuffer();
      var stream = _chatService.getCompletion(
        chat: chat,
        messages: wrappedMessages,
        provider: provider,
        model: model,
      );

      await for (final chunk in stream) {
        if (!isStreaming.value) break; // Allow termination

        if (chunk.choices.isEmpty) continue;
        var choice = chunk.choices.first;

        // Handle reasoning content from delta
        var reasoningContent = choice.delta.reasoningContent;
        if (reasoningContent != null && reasoningContent.isNotEmpty) {
          reasoningBuffer.write(reasoningContent);
          assistantMessage = assistantMessage.copyWith(
            reasoningContent: reasoningBuffer.toString(),
            reasoning: true,
            reasoningUpdatedAt: DateTime.now(),
          );
        }

        // Handle regular content from delta
        var content = choice.delta.content;
        if (content != null && content.isNotEmpty) {
          contentBuffer.write(content);
          assistantMessage = assistantMessage.copyWith(
            content: contentBuffer.toString(),
          );
        }

        // Update UI
        var index = messages.value.indexWhere((m) => m.id == assistantId);
        if (index >= 0) {
          var updated = List<MessageEntity>.from(messages.value);
          updated[index] = assistantMessage;
          messages.value = updated;
        }
      }

      // 8. 流结束后，标记推理完成
      if (reasoningBuffer.isNotEmpty) {
        assistantMessage = assistantMessage.copyWith(reasoning: false);
        var index = messages.value.indexWhere((m) => m.id == assistantId);
        if (index >= 0) {
          var updated = List<MessageEntity>.from(messages.value);
          updated[index] = assistantMessage;
          messages.value = updated;
        }
      }

      // 9. 保存最终消息
      await _messageRepository.updateMessage(assistantMessage);

      // 10. 更新chat的updatedAt
      var updatedChat = chat.copyWith(updatedAt: DateTime.now());
      await _chatRepository.updateChat(updatedChat);
      await getChats();
    } catch (e) {
      error.value = e.toString();
      // 如果已创建 assistant 消息，将错误信息写入消息内容
      if (assistantId != null) {
        var errorMessage = MessageEntity(
          id: assistantId,
          chatId: chat.id!,
          role: 'assistant',
          content: 'Error: ${e.toString()}',
        );
        await _messageRepository.updateMessage(errorMessage);
        var index = messages.value.indexWhere((m) => m.id == assistantId);
        if (index >= 0) {
          var updated = List<MessageEntity>.from(messages.value);
          updated[index] = errorMessage;
          messages.value = updated;
        }
      }
    } finally {
      isStreaming.value = false;
    }
  }

  /// 切换聊天的置顶状态
  Future<void> togglePin(ChatEntity chat) async {
    error.value = null;
    try {
      var updated = chat.copyWith(pinned: !chat.pinned);
      await _chatRepository.updateChat(updated);

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
      var updated = chat.copyWith(context: context);
      await _chatRepository.updateChat(updated);

      // 更新状态
      var index = chats.value.indexWhere((c) => c.id == chat.id);
      if (index >= 0) {
        var updatedChats = List<ChatEntity>.from(chats.value);
        updatedChats[index] = updated;
        chats.value = updatedChats;
      }

      if (currentChat.value?.id == chat.id) {
        currentChat.value = updated;
      }

      return updated;
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  /// 更新是否启用搜索
  Future<ChatEntity?> updateEnableSearch(
    bool enabled, {
    required ChatEntity chat,
  }) async {
    error.value = null;
    try {
      var updated = chat.copyWith(enableSearch: enabled);
      await _chatRepository.updateChat(updated);

      // 更新状态
      var index = chats.value.indexWhere((c) => c.id == chat.id);
      if (index >= 0) {
        var updatedChats = List<ChatEntity>.from(chats.value);
        updatedChats[index] = updated;
        chats.value = updatedChats;
      }

      if (currentChat.value?.id == chat.id) {
        currentChat.value = updated;
      }

      return updated;
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  /// 更新消息的expanded状态
  Future<void> updateExpanded(MessageEntity message) async {
    try {
      var updated = message.copyWith(expanded: !message.expanded);
      await _messageRepository.updateMessage(updated);

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
      var updated = chat.copyWith(modelId: model.id);
      await _chatRepository.updateChat(updated);

      // 更新状态
      var index = chats.value.indexWhere((c) => c.id == chat.id);
      if (index >= 0) {
        var updatedChats = List<ChatEntity>.from(chats.value);
        updatedChats[index] = updated;
        chats.value = updatedChats;
      }

      if (currentChat.value?.id == chat.id) {
        currentChat.value = updated;
        currentModel.value = model;
      }

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
      var updated = chat.copyWith(sentinelId: sentinel.id);
      await _chatRepository.updateChat(updated);

      // 更新状态
      var index = chats.value.indexWhere((c) => c.id == chat.id);
      if (index >= 0) {
        var updatedChats = List<ChatEntity>.from(chats.value);
        updatedChats[index] = updated;
        chats.value = updatedChats;
      }

      if (currentChat.value?.id == chat.id) {
        currentChat.value = updated;
        currentSentinel.value = sentinel;
      }

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
      var updated = chat.copyWith(temperature: temperature);
      await _chatRepository.updateChat(updated);

      // 更新状态
      var index = chats.value.indexWhere((c) => c.id == chat.id);
      if (index >= 0) {
        var updatedChats = List<ChatEntity>.from(chats.value);
        updatedChats[index] = updated;
        chats.value = updatedChats;
      }

      if (currentChat.value?.id == chat.id) {
        currentChat.value = updated;
      }

      return updated;
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  /// 更新当前模型（没有选中对话时使用）
  Future<void> updateCurrentModel(ModelEntity model) async {
    currentModel.value = model;
    currentProvider.value = await _providerRepository.getProviderById(
      model.providerId,
    );
  }

  /// 更新当前哨兵（没有选中对话时使用）
  void updateCurrentSentinel(SentinelEntity sentinel) {
    currentSentinel.value = sentinel;
  }
}
