import 'dart:async';
import 'dart:typed_data';

import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/chat_history_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/model/token_usage.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/service/chat_manage_service.dart';
import 'package:athena/service/chat_support_service.dart';
import 'package:athena/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena/view_model/delegate/chat_rename_delegate.dart';
import 'package:athena/view_model/delegate/chat_selection_delegate.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:signals/signals.dart';

/// ChatViewModel 负责聊天会话的业务逻辑。
///
/// 持有全部 UI 状态（Signal），直接调用 Service/Repository 完成简单操作，
/// 将复杂的流式 Agent 交互委托给 [AgentStreamDelegate]（通过 Stream 事件通信）。
class ChatViewModel {
  static const int defaultDraftRetention = -1;
  static const double defaultDraftTemperature = 1.0;

  final ChatManageService _manageService;
  final AgentStreamDelegate _stream;
  final ChatRenameDelegate _rename;
  final ChatSelectionDelegate _selection;
  final ChatSupportService _supportService;
  final MessageRepository _messageRepo;
  final SettingViewModel _settingViewModel;
  final ModelViewModel _modelViewModel;
  final SentinelViewModel _sentinelViewModel;

  // ─── Signals ───

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
  final currentRetention = signal(defaultDraftRetention);
  final currentTemperature = signal(defaultDraftTemperature);
  final currentIteration = signal(0);
  final currentToolName = signal<String?>(null);
  final currentTokenUsage = signal<TokenUsage?>(null);
  final cumulativeTokenTotal = signal(0);
  final pendingImages = listSignal<String>([]);

  // ─── Computed ───

  late final recentChats = computed(() {
    return chats.value.take(10).toList();
  });

  late final recentChatHistories = computed(() {
    return chatHistories.value.take(10).toList();
  });

  late final pinnedChats = computed(() {
    return chats.value.where((c) => c.pinned).toList();
  });

  // ─── 多选代理 ───

  ChatSelectionDelegate get selection => _selection;

  // ─── 内部辅助 ───

  void _updateChatInLists(ChatEntity updated) {
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
    }
  }

  void _updateMessageInList(MessageEntity updated) {
    final index = messages.value.indexWhere((m) => m.id == updated.id);
    if (index >= 0) {
      final copy = List<MessageEntity>.from(messages.value);
      copy[index] = updated;
      messages.value = copy;
    }
  }

  ChatViewModel({
    required ChatManageService manageService,
    required AgentStreamDelegate streamDelegate,
    required ChatRenameDelegate renameDelegate,
    ChatSelectionDelegate? selectionDelegate,
    required ChatSupportService supportService,
    required MessageRepository messageRepo,
    required SettingViewModel settingViewModel,
    required ModelViewModel modelViewModel,
    required SentinelViewModel sentinelViewModel,
  })  : _manageService = manageService,
        _stream = streamDelegate,
        _rename = renameDelegate,
        _selection = selectionDelegate ?? ChatSelectionDelegate(),
        _supportService = supportService,
        _messageRepo = messageRepo,
        _settingViewModel = settingViewModel,
        _modelViewModel = modelViewModel,
        _sentinelViewModel = sentinelViewModel;

  // ═══════════════════════════════════════════════════════════════
  // 会话列表操作
  // ═══════════════════════════════════════════════════════════════

  Future<void> getChats() async {
    isLoading.value = true;
    try {
      final (chatsList, histories) = await _manageService.getChats();
      chats.value = chatsList;
      chatHistories.value = histories;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<ChatEntity?> getFirstChat() async {
    if (chats.value.isEmpty) await getChats();
    if (chats.value.isEmpty) return await createChat();
    return chats.value.first;
  }

  Future<void> initSignals() async {
    final (chatsList, histories) = await _manageService.getChats();
    chats.value = chatsList;
    chatHistories.value = histories;
    currentChat.value = chats.value.firstOrNull;

    if (currentChat.value != null) {
      final selected = await _manageService.selectChat(currentChat.value!);
      messages.value = selected.messages;
      currentModel.value = selected.model;
      currentProvider.value = selected.provider;
      currentSentinel.value = selected.sentinel;
      currentRetention.value = currentChat.value!.retention;
      currentTemperature.value = currentChat.value!.temperature;
      cumulativeTokenTotal.value = currentChat.value!.tokenTotal;
    } else {
      await prepareNewChatDraft();
    }
  }

  Future<ChatEntity?> createChat() async {
    isLoading.value = true;
    error.value = null;
    try {
      final model = await _modelViewModel.resolveDefaultModel(
        _settingViewModel.chatModelId.value,
      );
      if (model == null) {
        error.value = 'Failed to create chat';
        return null;
      }

      final provider = await _supportService.getProviderForModel(model.providerId);
      if (provider == null) {
        error.value = 'Failed to create chat';
        return null;
      }

      if (_sentinelViewModel.sentinels.value.isEmpty) {
        await _sentinelViewModel.getSentinels();
      }
      final sentinel = _sentinelViewModel.defaultSentinel.value;

      final chat = await _manageService.createChat(
        model: model,
        sentinel: sentinel,
        retention: defaultDraftRetention,
        temperature: defaultDraftTemperature,
      );

      currentTokenUsage.value = null;
      cumulativeTokenTotal.value = 0;

      final pinned = chats.value.where((c) => c.pinned).toList();
      final unpinned = chats.value.where((c) => !c.pinned).toList();
      chats.value = [...pinned, chat, ...unpinned];

      currentChat.value = chat;
      currentModel.value = model;
      currentProvider.value = provider;
      currentSentinel.value = sentinel;
      currentRetention.value = chat.retention;
      currentTemperature.value = chat.temperature;
      pendingImages.value = [];
      messages.value = [];

      clearSelection();
      _selection.lastSelectedIndex.value = pinned.length;

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
      if (isStreaming.value && _stream.streamingChatId == chat.id) {
        final done = _stream.settled;
        _stream.stop();
        if (done != null) await done;
      }
      _rename.cancel(chat.id!);

      await _manageService.deleteChat(chat.id!);

      chats.value = chats.value.where((c) => c.id != chat.id).toList();
      chatHistories.value =
          chatHistories.value.where((h) => h.chat.id != chat.id).toList();

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
      final ids = chatsToDelete.map((c) => c.id!).toSet();

      if (isStreaming.value &&
          _stream.streamingChatId != null &&
          ids.contains(_stream.streamingChatId)) {
        final done = _stream.settled;
        _stream.stop();
        if (done != null) await done;
      }
      for (final id in ids) {
        _rename.cancel(id);
      }

      await _manageService.deleteChats(ids);

      chats.value = chats.value.where((c) => !ids.contains(c.id)).toList();
      chatHistories.value =
          chatHistories.value.where((h) => !ids.contains(h.chat.id)).toList();

      if (currentChat.value != null && ids.contains(currentChat.value!.id)) {
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
      final first = chats.value.first;
      final result = await _manageService.selectChat(first);
      currentChat.value = first;
      messages.value = result.messages;
      currentModel.value = result.model;
      currentProvider.value = result.provider;
      currentSentinel.value = result.sentinel;
      currentRetention.value = first.retention;
      currentTemperature.value = first.temperature;
      cumulativeTokenTotal.value = first.tokenTotal;
      _selection.lastSelectedIndex.value = 0;
    } else {
      await prepareNewChatDraft();
      messages.value = [];
      currentTokenUsage.value = null;
      cumulativeTokenTotal.value = 0;
      _selection.lastSelectedIndex.value = null;
    }
  }

  Future<void> selectChat(ChatEntity chat) async {
    if (isStreaming.value) return;

    currentChat.value = chat;

    final result = await _manageService.selectChat(chat);
    messages.value = result.messages;
    currentModel.value = result.model;
    currentProvider.value = result.provider;
    currentSentinel.value = result.sentinel;
    currentRetention.value = chat.retention;
    currentTemperature.value = chat.temperature;
    pendingImages.value = [];
    currentTokenUsage.value = null;
    cumulativeTokenTotal.value = chat.tokenTotal;
  }

  Future<void> togglePin(ChatEntity chat) async {
    error.value = null;
    try {
      await _manageService.togglePin(chat);
      await getChats();
    } catch (e) {
      error.value = e.toString();
    }
  }

  void clearSelection() => _selection.clearSelection();
  void toggleChatSelection(int chatId, int index) =>
      _selection.toggleChatSelection(chatId, index);
  void rangeSelectChats(int endIndex) =>
      _selection.rangeSelectChats(endIndex, chats.value);
  void initLastSelectedIndex() =>
      _selection.initLastSelectedIndex(currentChat.value, chats.value);

  // ═══════════════════════════════════════════════════════════════
  // 会话参数操作
  // ═══════════════════════════════════════════════════════════════

  Future<void> updateModel(ModelEntity model, {required ChatEntity chat}) async {
    error.value = null;
    try {
      final updated =
          await _supportService.updateModel(chat, model.id!);
      _updateChatInLists(updated);
      currentModel.value = model;
      currentProvider.value =
          await _supportService.getProviderForModel(model.providerId);
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> updateSentinel(
      SentinelEntity sentinel, {required ChatEntity chat}) async {
    error.value = null;
    try {
      final updated =
          await _supportService.updateSentinel(chat, sentinel.id!);
      _updateChatInLists(updated);
      currentSentinel.value = sentinel;
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> updateRetention(int retention, {required ChatEntity chat}) async {
    error.value = null;
    try {
      final updated =
          await _supportService.updateRetention(chat, retention);
      _updateChatInLists(updated);
      currentRetention.value = updated.retention;
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> updateTemperature(
      double temperature, {required ChatEntity chat}) async {
    error.value = null;
    try {
      final updated =
          await _supportService.updateTemperature(chat, temperature);
      _updateChatInLists(updated);
      currentTemperature.value = updated.temperature;
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> updateExpanded(MessageEntity message) async {
    try {
      final updated = await _supportService.updateExpanded(message);
      _updateMessageInList(updated);
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> updateCurrentModel(ModelEntity model) async {
    currentModel.value = model;
    currentProvider.value =
        await _supportService.getProviderForModel(model.providerId);
  }

  void updateCurrentSentinel(SentinelEntity sentinel) {
    currentSentinel.value = sentinel;
  }

  void updateCurrentRetention(int retention) {
    currentRetention.value = retention;
  }

  void updateCurrentTemperature(double temperature) {
    currentTemperature.value = temperature;
  }

  // ═══════════════════════════════════════════════════════════════
  // Agent 流式交互
  // ═══════════════════════════════════════════════════════════════

  Future<void> sendMessage(
    MessageEntity message, {
    required ChatEntity chat,
  }) async {
    if (isStreaming.value) return;

    isStreaming.value = true;
    currentTokenUsage.value = null;

    try {
      final eventStream = _stream.send(message: message, chat: chat);
      await for (final event in eventStream) {
        switch (event) {
          case StreamMessageStored(:final message):
            messages.value = [...messages.value, message];
          case StreamAssistantAppended(:final message):
            messages.value = [...messages.value, message];
          case StreamMessageUpdated(:final message):
            _updateMessageInList(message);
          case StreamIterationChanged(:final iteration):
            currentIteration.value = iteration;
          case StreamToolNameChanged(:final toolName):
            currentToolName.value = toolName;
          case StreamUsageChanged(:final usage, :final chat):
            if (chat.id == currentChat.value?.id) {
              currentTokenUsage.value = usage;
              cumulativeTokenTotal.value = chat.tokenTotal;
              _updateChatInLists(chat);
            }
          case StreamAutoRename():
            unawaited(renameChat(chat));
          case StreamListReload():
            unawaited(getChats());
          case StreamError(:final message):
            print("[DEBUG] sendMessage StreamError: $message");
            error.value = message;
        }
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isStreaming.value = false;
      currentIteration.value = 0;
      currentToolName.value = null;
    }
  }

  void stopGenerating() {
    _stream.stop();
  }

  Future<void> deleteMessage(MessageEntity message) async {
    isLoading.value = true;
    error.value = null;
    try {
      final index =
          messages.value.indexWhere((item) => item.id == message.id);
      if (index >= 0) {
        await _manageService.deleteMessagesFromIndex(messages.value, index);
        messages.value = await _messageRepo.getMessagesByChatId(message.chatId);
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshMessages(int chatId) async {
    messages.value = await _messageRepo.getMessagesByChatId(chatId);
  }

  // ═══════════════════════════════════════════════════════════════
  // 重命名
  // ═══════════════════════════════════════════════════════════════

  void startRenaming(int chatId) => _selection.startRenaming(chatId);
  void stopRenaming(int chatId) => _selection.stopRenaming(chatId);

  Future<ChatEntity?> renameChat(ChatEntity chat) async {
    if (chat.id == null) return null;
    if (_selection.renamingChatIds.value.contains(chat.id)) return null;

    startRenaming(chat.id!);
    _selection.renamingTitle.value = '';

    try {
      final updated = await _rename.rename(
        chat: chat,
        onTitle: (t) => _selection.renamingTitle.value = t,
      );
      if (updated != null) {
        _updateChatInLists(updated);
      }
      return updated;
    } catch (e) {
      error.value = e.toString();
      return null;
    } finally {
      _selection.renamingTitle.value = '';
      stopRenaming(chat.id!);
    }
  }

  Future<void> renameChatManually(ChatEntity chat, String title) async {
    if (title.isEmpty) return;
    isLoading.value = true;
    error.value = null;
    try {
      final updated = await _supportService.renameChatManually(chat, title);
      _updateChatInLists(updated);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 图片与导出
  // ═══════════════════════════════════════════════════════════════

  void addPendingImage(String base64Image) {
    pendingImages.value = [...pendingImages.value, base64Image];
  }

  void clearPendingImages() {
    pendingImages.value = [];
  }

  void removePendingImage(int index) {
    final images = List<String>.from(pendingImages.value);
    if (index >= 0 && index < images.length) {
      images.removeAt(index);
      pendingImages.value = images;
    }
  }

  Future<void> exportImage({
    required ChatEntity chat,
    required Uint8List bytes,
  }) async {
    try {
      await _supportService.saveImageFile(bytes, chat.id!);
    } catch (e) {
      error.value = e.toString();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 草稿
  // ═══════════════════════════════════════════════════════════════

  Future<void> prepareNewChatDraft() async {
    currentChat.value = null;
    messages.value = [];
    pendingImages.value = [];
    currentTokenUsage.value = null;
    cumulativeTokenTotal.value = 0;
    await _syncDraftDefaults();
  }

  Future<void> _syncDraftDefaults() async {
    currentModel.value = _settingViewModel.chatModel.value;
    currentProvider.value = _settingViewModel.chatModelProvider.value;

    if (currentModel.value == null) {
      await _modelViewModel.loadEnabledModels();
      currentModel.value = _modelViewModel.enabledModels.value.firstOrNull;
      if (currentModel.value != null) {
        currentProvider.value = await _supportService.getProviderForModel(
          currentModel.value!.providerId,
        );
      }
    }

    if (_sentinelViewModel.sentinels.value.isEmpty) {
      await _sentinelViewModel.getSentinels();
    }
    currentSentinel.value = _sentinelViewModel.defaultSentinel.value;
    currentRetention.value = defaultDraftRetention;
    currentTemperature.value = defaultDraftTemperature;
  }
}
