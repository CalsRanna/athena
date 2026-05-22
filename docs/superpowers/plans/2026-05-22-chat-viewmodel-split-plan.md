# ChatViewModel 拆分实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 ChatViewModel (1008 行) 拆分为 3 个 Service 类 + 瘦身后的 ChatViewModel，保持 UI 零改动。

**Architecture:** Service 层纯 Dart 无状态，只接收数据参数返回结果值/Stream；ChatViewModel 持有所有 signals，调用 Service 后根据返回值更新 signals。不改 `lib/di.dart`。

**Tech Stack:** Flutter/Dart, signals, GetIt

---

### Task 1: 创建 ChatManageService

**Files:**
- Create: `lib/service/chat_manage_service.dart`

- [ ] **Step 1: 编写完整文件**

```dart
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
```

- [ ] **Step 2: 验证编译**

```bash
flutter analyze lib/service/chat_manage_service.dart
```

Expected: No issues found.

---

### Task 2: 创建 MessageSendService

**Files:**
- Create: `lib/service/message_send_service.dart`

- [ ] **Step 1: 编写完整文件**

```dart
import 'dart:async';
import 'dart:convert';

import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';

sealed class SendEvent {}

class SendTextDelta extends SendEvent {
  final String delta;
  SendTextDelta(this.delta);
}

class SendReasoningDelta extends SendEvent {
  final String delta;
  SendReasoningDelta(this.delta);
}

class SendToolCall extends SendEvent {
  final String id;
  final String name;
  final String arguments;
  SendToolCall({required this.id, required this.name, required this.arguments});
}

class SendToolResult extends SendEvent {
  final String id;
  final String name;
  final String result;
  SendToolResult({required this.id, required this.name, required this.result});
}

class SendIterationEnd extends SendEvent {}

class SendDone extends SendEvent {
  final String content;
  SendDone(this.content);
}

class MessageSendService {
  final AgentService _agentService;

  MessageSendService({required AgentService agentService})
      : _agentService = agentService;

  Stream<SendEvent> sendMessage({
    required ChatEntity chat,
    required ProviderEntity provider,
    required ModelEntity model,
    required List<MessageEntity> baseMessages,
    required int maxIterations,
    required ModelEntity? auxiliaryModel,
    required ProviderEntity? auxiliaryModelProvider,
    required PermissionService permissionService,
    required Future<bool> Function(String toolName, String arguments) onPermission,
  }) async* {
    final agentStream = _agentService.run(
      chat: chat,
      provider: provider,
      model: model,
      baseMessages: baseMessages,
      maxIterations: maxIterations,
      auxiliaryModel: auxiliaryModel,
      auxiliaryModelProvider: auxiliaryModelProvider,
      permissionService: permissionService,
      onPermission: onPermission,
    );

    await for (final event in agentStream) {
      if (event is AgentReasoningEvent) {
        yield SendReasoningDelta(event.delta);
      } else if (event is AgentTextEvent) {
        yield SendTextDelta(event.delta);
      } else if (event is AgentToolCallEvent) {
        yield SendToolCall(
          id: event.id,
          name: event.name,
          arguments: event.arguments,
        );
      } else if (event is AgentToolResultEvent) {
        yield SendToolResult(
          id: event.id,
          name: event.name,
          result: event.result,
        );
      } else if (event is AgentDoneEvent) {
        yield SendDone(event.content);
      }
    }
  }

  String formatToolArgs(String toolName, String arguments) {
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
```

- [ ] **Step 2: 验证编译**

```bash
flutter analyze lib/service/message_send_service.dart
```

Expected: No issues found.

---

### Task 3: 创建 ChatSupportService

**Files:**
- Create: `lib/service/chat_support_service.dart`

- [ ] **Step 1: 编写完整文件**

```dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/provider_repository.dart';
import 'package:athena/service/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  })  : _chatRepository = chatRepository ?? ChatRepository(),
        _messageRepository = messageRepository ?? MessageRepository(),
        _providerRepository = providerRepository ?? ProviderRepository(),
        _chatService = chatService ?? ChatService();

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

  Future<Uint8List> exportImage(GlobalKey repaintBoundaryKey) async {
    final boundary = repaintBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Failed to get render boundary');

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to convert image to bytes');

    return byteData.buffer.asUint8List();
  }

  Future<String> saveImageFile(Uint8List bytes, int chatId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/chat_$chatId\_$timestamp.png';
      await File(path).writeAsBytes(bytes);
      return path;
    } else {
      final directory = await getDownloadsDirectory();
      if (directory == null) throw Exception('Failed to get downloads directory');
      final path = '${directory.path}/chat_$chatId\_$timestamp.png';
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

  Future<ChatEntity> updateTemperature(ChatEntity chat, double temperature) async {
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
```

- [ ] **Step 2: 验证编译**

```bash
flutter analyze lib/service/chat_support_service.dart
```

Expected: No issues found.

---

### Task 4: 重构 ChatViewModel — imports、字段、委托方法

**Files:**
- Modify: `lib/view_model/chat_view_model.dart`

这是最大的一步——替换 ChatViewModel 的所有方法体，使其委托给 3 个 Service。

- [ ] **Step 1: 替换文件头部（imports + 类字段）**

将 L1-L90 替换为：

```dart
import 'dart:async';
import 'dart:convert';

import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/chat_history_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/agent/permission/permission_dialog.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/service/chat_manage_service.dart';
import 'package:athena/service/chat_message_service.dart';
import 'package:athena/service/chat_support_service.dart';
import 'package:athena/service/message_send_service.dart';
import 'package:athena/view_model/delegate/chat_selection_delegate.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/router/router.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals.dart';

class ChatViewModel {
  static const int defaultDraftContext = 0;
  static const double defaultDraftTemperature = 1.0;

  final ChatManageService _manage;
  final MessageSendService _send;
  final ChatSupportService _support;
  final ChatMessageService _chatMessageService;
  final ChatSelectionDelegate _selection;

  ChatViewModel({
    ChatManageService? manageService,
    MessageSendService? sendService,
    ChatSupportService? supportService,
    ChatMessageService? chatMessageService,
    ChatSelectionDelegate? selection,
  })  : _manage = manageService ?? ChatManageService(),
        _send = sendService ?? MessageSendService(
          agentService: GetIt.instance<AgentService>(),
        ),
        _support = supportService ?? ChatSupportService(),
        _chatMessageService = chatMessageService ?? ChatMessageService(),
        _selection = selection ?? ChatSelectionDelegate();

  // ===== Signals（全部保留，不变）=====
  final chats = listSignal<ChatEntity>([]);
  final chatHistories = listSignal<ChatHistoryEntity>([]);
  final currentChat = signal<ChatEntity?>(null);
  final messages = listSignal<MessageEntity>([]);
  final isLoading = signal(false);
  final isStreaming = signal(false);
  final error = signal<String?>(null);
  final currentModel = signal<ModelEntity?>(null);
  final currentProvider = signal<ProviderEntity?>(null);
  final currentSentinel = signal<SentinelEntity?>(null);
  final currentContext = signal(defaultDraftContext);
  final currentTemperature = signal(defaultDraftTemperature);
  final pendingImages = listSignal<String>([]);

  // ===== Selection 委托（不变）=====
  ChatSelectionDelegate get selection => _selection;
  SetSignal<int> get selectedChatIds => _selection.selectedChatIds;
  Signal<int?> get lastSelectedIndex => _selection.lastSelectedIndex;
  SetSignal<int> get renamingChatIds => _selection.renamingChatIds;
  Signal<String> get renamingTitle => _selection.renamingTitle;
  late final isMultiSelect = _selection.isMultiSelect;

  late final recentChats = computed(() => chats.value.take(10).toList());
  late final recentChatHistories = computed(() => chatHistories.value.take(10).toList());
  late final pinnedChats = computed(() => chats.value.where((c) => c.pinned).toList());

  // ===== 内部辅助（不变）=====

  void _updateChatInLists(ChatEntity updated, {void Function()? onCurrentChatUpdated}) {
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

  // ===== 图片管理（简单逻辑，保留）=====

  void addPendingImage(String base64Image) {
    pendingImages.value = [...pendingImages.value, base64Image];
  }

  void clearPendingImages() {
    pendingImages.value = [];
  }

  void removePendingImage(int index) {
    var images = List<String>.from(pendingImages.value);
    if (index >= 0 && index < images.length) {
      images.removeAt(index);
      pendingImages.value = images;
    }
  }

  // ===== 选择委托方法（不变）=====

  void clearSelection() => _selection.clearSelection();
  void toggleChatSelection(int chatId, int index) => _selection.toggleChatSelection(chatId, index);
  void rangeSelectChats(int endIndex) => _selection.rangeSelectChats(endIndex, chats.value);
  void initLastSelectedIndex() => _selection.initLastSelectedIndex(currentChat.value, chats.value);
  void startRenaming(int chatId) => _selection.startRenaming(chatId);
  void stopRenaming(int chatId) => _selection.stopRenaming(chatId);
```

- [ ] **Step 2: 替换 CRUD 方法**

```dart
  Future<void> getChats() async {
    isLoading.value = true;
    error.value = null;
    try {
      final (chatsList, histories) = await _manage.getChats();
      chats.value = chatsList;
      chatHistories.value = histories;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<ChatEntity?> createChat() async {
    isLoading.value = true;
    error.value = null;
    try {
      ModelEntity? model;
      final settingViewModel = GetIt.instance<SettingViewModel>();
      model = settingViewModel.chatModel.value;
      if (model == null || model.id == null || model.id! <= 0) {
        final modelViewModel = GetIt.instance<ModelViewModel>();
        await modelViewModel.loadEnabledModels();
        if (modelViewModel.enabledModels.value.isEmpty) {
          error.value = 'No enabled models found';
          return null;
        }
        model = modelViewModel.enabledModels.value.first;
      }

      final provider = await _support.getProviderForModel(model.providerId);
      if (provider == null) {
        error.value = 'No provider found';
        return null;
      }

      final sentinelViewModel = GetIt.instance<SentinelViewModel>();
      if (sentinelViewModel.sentinels.value.isEmpty) {
        await sentinelViewModel.getSentinels();
      }
      final selectedSentinel = sentinelViewModel.defaultSentinel.value;
      if (selectedSentinel == null) {
        error.value = 'No sentinels found';
        return null;
      }

      final chat = await _manage.createChat(
        model: model,
        sentinel: selectedSentinel,
        context: defaultDraftContext,
        temperature: defaultDraftTemperature,
      );

      final pinnedChats = chats.value.where((c) => c.pinned).toList();
      final unpinnedChats = chats.value.where((c) => !c.pinned).toList();
      chats.value = [...pinnedChats, chat, ...unpinnedChats];
      currentChat.value = chat;
      currentModel.value = model;
      currentProvider.value = provider;
      currentSentinel.value = selectedSentinel;
      currentContext.value = defaultDraftContext;
      currentTemperature.value = defaultDraftTemperature;
      pendingImages.value = [];
      messages.value = [];

      clearSelection();
      lastSelectedIndex.value = pinnedChats.length;

      return chat;
    } catch (e) {
      error.value = e.toString();
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteChat(ChatEntity chat) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _manage.deleteChat(chat.id!);
      chats.value = chats.value.where((c) => c.id != chat.id).toList();
      chatHistories.value = chatHistories.value.where((h) => h.chat.id != chat.id).toList();
      if (currentChat.value?.id == chat.id) {
        await _selectFirstChatOrClear();
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteChats(List<ChatEntity> chatsToDelete) async {
    isLoading.value = true;
    error.value = null;
    try {
      final idsToDelete = chatsToDelete.map((c) => c.id!).toSet();
      await _manage.deleteChats(idsToDelete);
      chats.value = chats.value.where((c) => !idsToDelete.contains(c.id)).toList();
      chatHistories.value = chatHistories.value.where((h) => !idsToDelete.contains(h.chat.id)).toList();
      if (currentChat.value != null && idsToDelete.contains(currentChat.value!.id)) {
        await _selectFirstChatOrClear();
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _selectFirstChatOrClear() async {
    if (chats.value.isNotEmpty) {
      final firstChat = chats.value.first;
      currentChat.value = firstChat;
      final result = await _manage.selectChat(firstChat);
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
```

- [ ] **Step 3: 替换 deleteMessage、initSignals、selectChat、refreshMessages、getFirstChat**

```dart
  Future<void> deleteMessage(MessageEntity message) async {
    isLoading.value = true;
    error.value = null;
    try {
      final index = messages.value.indexWhere((item) => item.id == message.id);
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

  Future<void> initSignals() async {
    final (chatsList, histories) = await _manage.getChats();
    chats.value = chatsList;
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
    pendingImages.value = [];
  }

  Future<void> refreshMessages(int chatId) async {
    messages.value = await _manage.refreshMessages(chatId);
  }

  Future<ChatEntity?> getFirstChat() async {
    if (chats.value.isEmpty) {
      await getChats();
    }
    if (chats.value.isEmpty) {
      return await createChat();
    }
    return chats.value.first;
  }
```

- [ ] **Step 4: 替换属性更新方法**

```dart
  Future<void> togglePin(ChatEntity chat) async {
    error.value = null;
    try {
      await _manage.togglePin(chat);
      await getChats();
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<ChatEntity?> updateContext(int context, {required ChatEntity chat}) async {
    error.value = null;
    try {
      final updated = await _support.updateContext(chat, context);
      _updateChatInLists(updated, onCurrentChatUpdated: () {
        currentContext.value = updated.context;
      });
      return updated;
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  Future<ChatEntity?> updateModel(ModelEntity model, {required ChatEntity chat}) async {
    error.value = null;
    try {
      final updated = await _support.updateModel(chat, model.id);
      _updateChatInLists(updated, onCurrentChatUpdated: () async {
        currentModel.value = model;
        currentProvider.value = await _support.getProviderForModel(model.providerId);
      });
      return updated;
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  Future<ChatEntity?> updateSentinel(SentinelEntity sentinel, {required ChatEntity chat}) async {
    error.value = null;
    try {
      final updated = await _support.updateSentinel(chat, sentinel.id);
      _updateChatInLists(updated, onCurrentChatUpdated: () {
        currentSentinel.value = sentinel;
      });
      return updated;
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  Future<ChatEntity?> updateTemperature(double temperature, {required ChatEntity chat}) async {
    error.value = null;
    try {
      final updated = await _support.updateTemperature(chat, temperature);
      _updateChatInLists(updated, onCurrentChatUpdated: () {
        currentTemperature.value = updated.temperature;
      });
      return updated;
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  Future<void> updateExpanded(MessageEntity message) async {
    try {
      final updated = await _support.updateExpanded(message);
      final index = messages.value.indexWhere((m) => m.id == message.id);
      if (index >= 0) {
        final updatedMessages = List<MessageEntity>.from(messages.value);
        updatedMessages[index] = updated;
        messages.value = updatedMessages;
      }
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> updateCurrentModel(ModelEntity model) async {
    currentModel.value = model;
    currentProvider.value = await _support.getProviderForModel(model.providerId);
  }

  void updateCurrentSentinel(SentinelEntity sentinel) {
    currentSentinel.value = sentinel;
  }

  void updateCurrentContext(int context) {
    currentContext.value = context;
  }

  void updateCurrentTemperature(double temperature) {
    currentTemperature.value = temperature;
  }
```

- [ ] **Step 5: 替换重命名方法**

```dart
  Future<ChatEntity?> renameChat(ChatEntity chat) async {
    if (chat.id == null) return null;
    if (renamingChatIds.value.contains(chat.id)) return null;

    startRenaming(chat.id!);
    renamingTitle.value = '';
    try {
      final chatMessages = await _manage.refreshMessages(chat.id!);
      final firstUserMessage = chatMessages.where((m) => m.role == 'user').firstOrNull;
      if (firstUserMessage == null) return null;

      final model = await _manage.getModel(chat.modelId);
      if (model == null) return null;
      final provider = await _support.getProviderForModel(model.providerId);
      if (provider == null) return null;

      final titleBuffer = StringBuffer();
      final stream = _support.renameChat(
        firstUserMessage.content,
        provider: provider,
        model: model,
      );

      await for (final chunk in stream) {
        titleBuffer.write(chunk);
        renamingTitle.value = titleBuffer.toString();
      }

      final title = titleBuffer.toString().trim();
      if (title.isEmpty) return null;

      final updated = await _support.renameChatManually(chat, title);
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
```

- [ ] **Step 6: 替换 exportImage**

```dart
  Future<void> exportImage({
    required ChatEntity chat,
    required GlobalKey repaintBoundaryKey,
  }) async {
    try {
      final pngBytes = await _support.exportImage(repaintBoundaryKey);
      await _support.saveImageFile(pngBytes, chat.id!);
    } catch (e) {
      error.value = e.toString();
    }
  }
```

- [ ] **Step 7: 替换 prepareNewChatDraft 和 _syncDraftDefaults**

```dart
  Future<void> prepareNewChatDraft() async {
    currentChat.value = null;
    messages.value = [];
    pendingImages.value = [];
    await _syncDraftDefaults();
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

    final sentinelViewModel = GetIt.instance<SentinelViewModel>();
    if (sentinelViewModel.sentinels.value.isEmpty) {
      await sentinelViewModel.getSentinels();
    }
    currentSentinel.value = sentinelViewModel.defaultSentinel.value;
    currentContext.value = defaultDraftContext;
    currentTemperature.value = defaultDraftTemperature;
  }
```

- [ ] **Step 8: 替换 sendMessage（最复杂的部分）**

```dart
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
      final id = await _manage.storeMessage(message);
      final userMessage = message.copyWith(id: id);
      messages.value = [...messages.value, userMessage];

      // 首条用户消息触发自动命名
      final isDefaultTitle = chat.title.isEmpty || chat.title == 'New Chat';
      if (isDefaultTitle) {
        if (await _chatMessageService.isFirstUserMessage(chat.id!)) {
          unawaited(renameChat(chat));
        }
      }

      // 2. 获取 model、provider、sentinel
      final model = await _manage.getModel(chat.modelId);
      if (model == null) {
        error.value = 'Model not found';
        return;
      }
      final provider = await _support.getProviderForModel(model.providerId);
      if (provider == null) {
        error.value = 'Provider not found';
        return;
      }
      final sentinel = await _manage.getSentinel(chat.sentinelId);

      // 3. 构建消息上下文
      final wrappedMessages = await _chatMessageService.buildMessages(
        chat: chat,
        sentinel: sentinel,
      );

      // 4. 创建 assistant 消息占位
      var assistantMessage = MessageEntity(
        chatId: chat.id!,
        role: 'assistant',
        content: '',
      );
      assistantId = await _manage.storeMessage(assistantMessage);
      assistantMessage = assistantMessage.copyWith(id: assistantId);
      messages.value = [...messages.value, assistantMessage];

      // 5. 准备权限回调（保留在 ChatViewModel，需要 context 和 dialog）
      final settingVM = GetIt.instance<SettingViewModel>();
      final permissionService = GetIt.instance<PermissionService>();

      Future<bool> onPermission(String toolName, String arguments) async {
        final context = router.navigatorKey.currentContext;
        if (context == null) return false;
        Map<String, dynamic> args;
        try {
          args = jsonDecode(arguments) as Map<String, dynamic>;
        } catch (_) {
          args = {};
        }
        final description = _send.formatToolArgs(toolName, arguments);
        final ruleDesc = permissionService.generateRuleDescription(toolName, args);
        final isDangerous = permissionService.isDangerous(toolName, args);
        final result = await showPermissionDialog(
          toolName: toolName,
          description: description,
          ruleDescription: ruleDesc,
          allowPersist: !isDangerous,
        );
        if (result.approved && result.persist) {
          final rule = permissionService.generateRule(toolName, args);
          await permissionService.persistRule(rule);
        }
        return result.approved;
      }

      // 6. Agent 编排
      final eventStream = _send.sendMessage(
        chat: chat,
        provider: provider,
        model: model,
        baseMessages: wrappedMessages,
        maxIterations: settingVM.maxAgentIterations.value,
        auxiliaryModel: settingVM.auxiliaryModel.value,
        auxiliaryModelProvider: settingVM.auxiliaryModelProvider.value,
        permissionService: permissionService,
        onPermission: onPermission,
      );

      var contentBuffer = StringBuffer();
      var reasoningBuffer = StringBuffer();
      var toolCallsJson = <Map<String, dynamic>>[];
      var toolResultsJson = <Map<String, dynamic>>[];
      var hasCompletedIteration = false;

      await for (final event in eventStream) {
        if (!isStreaming.value) break;

        if (event is SendReasoningDelta) {
          if (hasCompletedIteration) {
            await _manage.updateMessage(assistantMessage);
            assistantMessage = MessageEntity(
              chatId: chat.id!,
              role: 'assistant',
              content: '',
            );
            assistantId = await _manage.storeMessage(assistantMessage);
            assistantMessage = assistantMessage.copyWith(id: assistantId);
            messages.value = [...messages.value, assistantMessage];
            contentBuffer = StringBuffer();
            reasoningBuffer = StringBuffer();
            toolCallsJson = [];
            toolResultsJson = [];
            hasCompletedIteration = false;
          }
          reasoningBuffer.write(event.delta);
          assistantMessage = assistantMessage.copyWith(
            reasoningContent: reasoningBuffer.toString(),
            reasoning: true,
            reasoningUpdatedAt: DateTime.now(),
          );
          _updateMessageInList(assistantId, assistantMessage);
        } else if (event is SendTextDelta) {
          if (hasCompletedIteration) {
            await _manage.updateMessage(assistantMessage);
            assistantMessage = MessageEntity(
              chatId: chat.id!,
              role: 'assistant',
              content: '',
            );
            assistantId = await _manage.storeMessage(assistantMessage);
            assistantMessage = assistantMessage.copyWith(id: assistantId);
            messages.value = [...messages.value, assistantMessage];
            contentBuffer = StringBuffer();
            reasoningBuffer = StringBuffer();
            toolCallsJson = [];
            toolResultsJson = [];
            hasCompletedIteration = false;
          }
          contentBuffer.write(event.delta);
          assistantMessage = assistantMessage.copyWith(
            content: contentBuffer.toString(),
          );
          _updateMessageInList(assistantId, assistantMessage);
        } else if (event is SendToolCall) {
          toolCallsJson.add({
            'id': event.id,
            'name': event.name,
            'arguments': event.arguments,
          });
          assistantMessage = assistantMessage.copyWith(
            toolCalls: jsonEncode(toolCallsJson),
          );
          _updateMessageInList(assistantId, assistantMessage);
        } else if (event is SendToolResult) {
          toolResultsJson.add({
            'id': event.id,
            'name': event.name,
            'result': event.result,
          });
          assistantMessage = assistantMessage.copyWith(
            toolResults: jsonEncode(toolResultsJson),
          );
          _updateMessageInList(assistantId, assistantMessage);
          hasCompletedIteration = true;
        } else if (event is SendDone) {
          assistantMessage = assistantMessage.copyWith(content: event.content);
          _updateMessageInList(assistantId, assistantMessage);
        }
      }

      // 标记推理完成
      if (reasoningBuffer.isNotEmpty) {
        assistantMessage = assistantMessage.copyWith(reasoning: false);
        _updateMessageInList(assistantId, assistantMessage);
      }

      // 7. 持久化并刷新列表
      await _manage.updateMessage(assistantMessage);
      await _manage.updateChatTimestamp(chat);
      await getChats();
    } catch (e) {
      error.value = e.toString();
      if (assistantId != null) {
        final errorMessage = MessageEntity(
          id: assistantId,
          chatId: chat.id!,
          role: 'assistant',
          content: 'Error: ${e.toString()}',
        );
        await _manage.updateMessage(errorMessage);
        _updateMessageInList(assistantId, errorMessage);
      }
    } finally {
      isStreaming.value = false;
    }
  }
}
```

---

### Task 5: 全量验证

- [ ] **Step 1: 分析检查**

```bash
flutter analyze
```

Expected: No issues found.

- [ ] **Step 2: 运行测试**

```bash
flutter test
```

Expected: All tests pass.

- [ ] **Step 3: 确认行数**

```bash
wc -l lib/view_model/chat_view_model.dart lib/service/chat_manage_service.dart lib/service/message_send_service.dart lib/service/chat_support_service.dart
```

Expected: ChatViewModel ~400 行，每个 Service < 250 行。
