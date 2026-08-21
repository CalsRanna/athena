import 'dart:async';
import 'dart:typed_data';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/model/token_usage.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/service/chat_manage_service.dart';
import 'package:athena_core/service/chat_support_service.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_core/coordinator/agent_run_coordinator.dart';
import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena_gui/view_model/delegate/chat_rename_delegate.dart';
import 'package:athena_gui/view_model/delegate/chat_selection_delegate.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:athena_core/extension/list_signal_extension.dart';
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
  final ModelResolver _modelResolver;
  final SettingViewModel _settingViewModel;
  final ModelViewModel _modelViewModel;
  final SentinelViewModel _sentinelViewModel;

  // ─── Signals ───

  final chats = listSignal<ChatEntity>([]);
  final chatHistories = listSignal<ChatHistoryEntity>([]);
  final currentChat = signal<ChatEntity?>(null);
  final messages = listSignal<MessageEntity>([]);
  final isLoading = signal(false);

  /// 正在流式运行的对话 id 集合（多对话可同时运行）。
  final streamingChatIds = listSignal<int>([]);

  /// 是否有任一对话正在流式。
  late final isStreaming = computed(
    () => streamingChatIds.value.isNotEmpty,
  );

  /// 当前显示的对话是否正在流式（用于输入框/消息列表的流式状态展示）。
  late final isCurrentChatStreaming = computed(() {
    final id = currentChat.value?.id;
    return id != null && streamingChatIds.value.contains(id);
  });

  /// 挂起的权限审批请求（按对话渲染为会话内卡片）。
  final pendingApprovals = listSignal<ApprovalRequest>([]);

  final error = signal<String?>(null);

  final currentModel = signal<ModelEntity?>(null);
  final currentProvider = signal<ProviderEntity?>(null);
  final currentSentinel = signal<SentinelEntity?>(null);

  /// 新建对话时使用的角色（仅草稿态有效）。
  ///
  /// 与 [currentSentinel]（当前选中对话的角色）解耦：Shortcut 入口注入
  /// 绑定角色或用户在无选中对话时显式选择角色才会设置它；为空时
  /// [createChat] 回退默认角色 Athena，不复用上一个对话的角色。
  final draftSentinel = signal<SentinelEntity?>(null);

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
    chats.replaceWhere((c) => c.id == updated.id, updated);

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
    messages.replaceWhere((m) => m.id == updated.id, updated);
  }

  ChatViewModel({
    required ChatManageService manageService,
    required AgentStreamDelegate streamDelegate,
    required ChatRenameDelegate renameDelegate,
    ChatSelectionDelegate? selectionDelegate,
    required ChatSupportService supportService,
    required MessageRepository messageRepo,
    required ModelResolver modelResolver,
    required SettingViewModel settingViewModel,
    required ModelViewModel modelViewModel,
    required SentinelViewModel sentinelViewModel,
  })  : _manageService = manageService,
        _stream = streamDelegate,
        _rename = renameDelegate,
        _selection = selectionDelegate ?? ChatSelectionDelegate(),
        _supportService = supportService,
        _messageRepo = messageRepo,
        _modelResolver = modelResolver,
        _settingViewModel = settingViewModel,
        _modelViewModel = modelViewModel,
        _sentinelViewModel = sentinelViewModel {
    // 审批请求 → 会话内卡片；决策完成（含 run 取消自动拒绝）后自动移除。
    // VM 与应用同生命周期，订阅无需取消。
    streamDelegate.approvalRequests.listen((request) {
      pendingApprovals.value = [...pendingApprovals.value, request];
      unawaited(request.completer.future.whenComplete(() {
        pendingApprovals.value = pendingApprovals.value
            .where((r) => !identical(r, request))
            .toList();
      }));
    });
  }

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
      final resolved = await _modelResolver.resolve(
        preferredModelId: _settingViewModel.chatModelId.value,
      );
      if (resolved == null) {
        error.value = 'Failed to create chat';
        return null;
      }

      final model = resolved.model;
      final provider = resolved.provider;

      if (_sentinelViewModel.sentinels.value.isEmpty) {
        await _sentinelViewModel.getSentinels();
      }
      // 默认角色 Athena；仅当草稿态显式选定了角色
      // （Shortcut 入口注入或用户在无选中对话时选择）时使用选定角色。
      final sentinel =
          draftSentinel.value ?? _sentinelViewModel.defaultSentinel.value;

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
      // 草稿角色是一次性设定，消费后清空，避免下次新建对话复用。
      draftSentinel.value = null;

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
      if (isStreamingChat(chat.id!)) {
        final done = _stream.settledOf(chat.id!);
        _stream.stop(chat.id!);
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

      for (final id in ids) {
        if (streamingChatIds.value.contains(id)) {
          final done = _stream.settledOf(id);
          _stream.stop(id);
          if (done != null) await done;
        }
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

    // 该对话正在流式运行时,DB 里只有迭代边界前的旧态,用内存快照恢复实时进度
    _mergeLiveMessage(chat.id!);
  }

  /// 若 [chatId] 正在流式,用 coordinator 的内存快照覆盖/追加最后一条消息。
  ///
  /// 幂等：快照消息已存在于列表（id 相同）则替换，否则追加
  /// （竞态：快照对应的占位消息可能尚未落库）。
  void _mergeLiveMessage(int chatId) {
    final live = _stream.liveMessage(chatId);
    if (live != null) _appendOrReplaceMessage(live);
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
      // 先同步通知流式代理:思考/生成期间流式增量基于 delegate 的本地缓存,
      // 若不告知用户最新的展开选择,刚展开的卡片会被下一次增量重新折叠
      if (message.id != null) {
        _stream.updateExpanded(message.id!, !message.expanded);
      }
      final updated = await _supportService.updateExpanded(message);
      messages.replaceWhere((m) => m.id == message.id, updated);
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
    // 无选中对话时的显式选择（含 Shortcut 入口注入的绑定角色），
    // 作为下一次新建对话的角色。
    draftSentinel.value = sentinel;
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
    bool jsonMode = false,
  }) async {
    // 仅阻止同一对话的重复运行；其他对话可并发
    if (isStreamingChat(chat.id!)) return;

    streamingChatIds.value = [...streamingChatIds.value, chat.id!];
    currentTokenUsage.value = null;

    try {
      final eventStream = _stream.send(
        message: message,
        chat: chat,
        jsonMode: jsonMode,
      );
      await for (final event in eventStream) {
        // 运行期间用户可能已切到其他对话：消息列表信号只反映当前显示的对话，
        // 事件属于其他对话时仅落库（coordinator 内部），不污染当前列表。
        final belongsToCurrent = chat.id == currentChat.value?.id;
        switch (event) {
          case RunMessageStored(:final message):
            if (belongsToCurrent) {
              messages.value = [...messages.value, message];
            }
          case RunAssistantAppended(:final message):
            if (belongsToCurrent) {
              _appendOrReplaceMessage(message);
            }
          case RunMessageUpdated(:final message):
            if (belongsToCurrent) {
              _updateMessageInList(message);
            }
          case RunIterationChanged(:final iteration):
            currentIteration.value = iteration;
          case RunToolNameChanged(:final toolName):
            currentToolName.value = toolName;
          case RunUsageChanged(:final usage, :final chat):
            if (chat.id == currentChat.value?.id) {
              currentTokenUsage.value = usage;
              cumulativeTokenTotal.value = chat.tokenTotal;
              _updateChatInLists(chat);
            }
          case RunAutoRename():
            unawaited(renameChat(chat));
          case RunListReload():
            unawaited(getChats());
          case RunError(:final message):
            LoggerUtil.e("sendMessage RunError: $message");
            error.value = message;
        }
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      streamingChatIds.value = streamingChatIds.value
          .where((id) => id != chat.id)
          .toList();
      currentIteration.value = 0;
      currentToolName.value = null;
    }
  }

  /// 追加或替换消息：切换对话的竞态下占位消息可能已在列表中
  /// （快照合并或 DB 预读），避免重复追加。
  void _appendOrReplaceMessage(MessageEntity message) {
    final index = messages.value.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      final copy = List<MessageEntity>.from(messages.value);
      copy[index] = message;
      messages.value = copy;
    } else {
      messages.value = [...messages.value, message];
    }
  }

  /// 指定对话是否正在流式运行。
  bool isStreamingChat(int chatId) => streamingChatIds.value.contains(chatId);

  /// 停止指定对话的 Agent 运行。
  void stopGenerating(int chatId) {
    _stream.stop(chatId);
  }

  /// 用户对审批请求做出决策（Allow Once / Always Allow / Deny）。
  void respondApproval(ApprovalRequest request, PermissionDecision decision) {
    _stream.respondApproval(request, decision);
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
    draftSentinel.value = null;
    currentRetention.value = defaultDraftRetention;
    currentTemperature.value = defaultDraftTemperature;
  }
}
