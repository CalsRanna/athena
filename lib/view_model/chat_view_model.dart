import 'dart:io';
import 'dart:ui' as ui;

import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/service/chat_service.dart';
import 'package:athena/view_model/model_view_model.dart';
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
  final currentChat = signal<ChatEntity?>(null);
  final messages = listSignal<MessageEntity>([]);
  final isLoading = signal(false);
  final isStreaming = signal(false);
  final error = signal<String?>(null);

  // 当前聊天的关联状态
  final currentModel = signal<ModelEntity?>(null);
  final currentSentinel = signal<SentinelEntity?>(null);
  final pendingImages = listSignal<String>([]);

  // Computed signals
  late final recentChats = computed(() {
    return chats.value.take(10).toList();
  });

  late final pinnedChats = computed(() {
    return chats.value.where((c) => c.pinned).toList();
  });

  // 业务方法

  /// 加载所有聊天会话
  Future<void> getChats() async {
    isLoading.value = true;
    error.value = null;
    try {
      chats.value = await _chatRepository.getAllChats();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 加载指定聊天的消息
  Future<void> loadMessages(int chatId) async {
    isLoading.value = true;
    error.value = null;
    try {
      messages.value = await _messageRepository.getMessagesByChatId(chatId);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 创建新的聊天会话
  Future<ChatEntity?> createChat({SentinelEntity? sentinel}) async {
    isLoading.value = true;
    error.value = null;
    try {
      // 获取第一个启用的模型 - 通过 ModelViewModel
      var modelViewModel = GetIt.instance<ModelViewModel>();
      await modelViewModel.loadEnabledModels();
      if (modelViewModel.enabledModels.value.isEmpty) {
        error.value = 'No enabled models found';
        return null;
      }
      var model = modelViewModel.enabledModels.value.first;

      // 获取第一个哨兵
      var sentinels = await _sentinelRepository.getAllSentinels();
      var firstSentinel = sentinel ?? sentinels.firstOrNull;
      if (firstSentinel == null) {
        error.value = 'No sentinels found';
        return null;
      }

      var now = DateTime.now();
      var chat = ChatEntity(
        title: 'New Chat',
        modelId: model.id!,
        sentinelId: firstSentinel.id!,
        createdAt: now,
        updatedAt: now,
      );

      var id = await _chatRepository.createChat(chat);
      chat = chat.copyWith(id: id);

      // 更新状态
      chats.value = [...chats.value, chat];
      currentChat.value = chat;
      currentModel.value = model;
      currentSentinel.value = firstSentinel;
      pendingImages.value = [];

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

      // 更新状态
      chats.value = chats.value.where((c) => c.id != chat.id).toList();

      // 如果删除的是当前聊天,清空当前聊天
      if (currentChat.value?.id == chat.id) {
        currentChat.value = null;
        messages.value = [];
      }

      // 如果是桌面端且没有聊天了,创建新聊天
      var isDesktop =
          Platform.isMacOS || Platform.isLinux || Platform.isWindows;
      if (isDesktop && chats.value.isEmpty) {
        await createChat();
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
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

  /// 初始化聊天(如果没有聊天则创建一个)
  Future<void> initChats() async {
    var chatCount = chats.value.length;
    if (chatCount == 0) {
      await getChats();
      chatCount = chats.value.length;
    }
    if (chatCount == 0) {
      await createChat();
    }
  }

  /// 切换当前聊天
  Future<void> selectChat(ChatEntity chat) async {
    if (isStreaming.value) return;

    currentChat.value = chat;

    // 加载消息
    await loadMessages(chat.id!);

    // 加载关联的 model
    var model = await _modelRepository.getModelById(chat.modelId);
    currentModel.value = model;

    // 加载关联的 sentinel
    var sentinel = await _sentinelRepository.getSentinelById(chat.sentinelId);
    currentSentinel.value = sentinel;

    // 清空待发送图片
    pendingImages.value = [];
  }

  /// 添加待发送图片
  void addPendingImage(String base64Image) {
    pendingImages.value = [...pendingImages.value, base64Image];
  }

  /// 移除待发送图片
  void removePendingImage(int index) {
    var images = List<String>.from(pendingImages.value);
    if (index >= 0 && index < images.length) {
      images.removeAt(index);
      pendingImages.value = images;
    }
  }

  /// 清空待发送图片
  void clearPendingImages() {
    pendingImages.value = [];
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

  /// 手动重命名聊天
  Future<void> renameChatManually(ChatEntity chat, String title) async {
    if (title.isEmpty) return;
    isLoading.value = true;
    error.value = null;
    try {
      var updated = chat.copyWith(title: title);
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
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
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
      var assistantId = await _messageRepository.storeMessage(assistantMessage);
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

        if (chunk.response.choices.isEmpty) continue;
        var choice = chunk.response.choices.first;

        // Handle reasoning content from rawJson
        var reasoningContent =
            chunk.rawJson['choices']?[0]?['delta']?['reasoning_content'];
        if (reasoningContent != null) {
          reasoningBuffer.write(reasoningContent);
          assistantMessage = assistantMessage.copyWith(
            reasoningContent: reasoningBuffer.toString(),
            reasoning: true,
          );
        }

        // Handle regular content
        if (choice.delta.content != null) {
          contentBuffer.write(choice.delta.content);
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

      // 8. 保存最终消息
      await _messageRepository.updateMessage(assistantMessage);

      // 9. 更新chat的updatedAt
      var updatedChat = chat.copyWith(updatedAt: DateTime.now());
      await _chatRepository.updateChat(updatedChat);
      await getChats();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isStreaming.value = false;
    }
  }

  /// 自动重命名聊天
  Future<ChatEntity?> renameChat(ChatEntity chat) async {
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

      // 更新状态
      var index = chats.value.indexWhere((c) => c.id == chat.id);
      if (index >= 0) {
        var updatedChats = List<ChatEntity>.from(chats.value);
        updatedChats[index] = updated;
        chats.value = updatedChats;
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
}
