import 'dart:async';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/entity/token_usage.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/service/chat_store_service.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_core/agent/permission/permission_prompt.dart';
import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena_gui/view_model/delegate/chat_rename_delegate.dart';
import 'package:athena_gui/view_model/delegate/chat_selection_delegate.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:athena_gui/extension/list_signal_extension.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signals/signals.dart';

class _QueuedChatInput {
  final MessageEntity message;
  final ChatEntity chat;
  final bool jsonMode;

  const _QueuedChatInput(this.message, this.chat, this.jsonMode);
}

/// ChatViewModel 负责聊天会话的业务逻辑。
///
/// 持有全部 UI 状态（Signal），直接调用 Service/Repository 完成简单操作，
/// 将复杂的流式 Agent 交互委托给 [AgentStreamDelegate]（通过 Stream 事件通信）。
class ChatViewModel {
  static const int defaultDraftRetention = -1;
  static const double defaultDraftTemperature = 1.0;

  /// 历史对话首次及每次向上翻页加载的原始消息数。
  static const int messagePageSize = 50;

  final ChatStoreService _manageService;
  final AgentStreamDelegate _stream;
  final ChatRenameDelegate _rename;
  final ChatSelectionDelegate _selection;
  final ChatUpdateService _supportService;
  final MessageRepository _messageRepo;
  final ModelResolver _modelResolver;
  final SettingViewModel _settingViewModel;
  final ModelViewModel _modelViewModel;
  final SentinelViewModel _sentinelViewModel;

  int? _oldestLoadedMessageId;
  bool _loadingOlderMessages = false;
  int _messageLoadGeneration = 0;
  int _olderLoadGeneration = 0;

  /// 轮次指示器的全量轮次起点，按 chatId 缓存：一次整文件扫描的代价不低，
  /// 切回同一会话时直接用缓存。消息被删除（会连带删掉后面的轮次）时按 id 截断。
  final Map<int, List<int>> _turnStartIdsByChat = {};

  /// 扫描期间新发出、还没并进扫描结果的 user 消息 id(按 chatId)。
  ///
  /// 整文件扫描是个快照,期间用户可能又发了一条;等扫描回来时把它并进去,
  /// 这样轮次数始终等于"整段会话的 user 消息数",不必为了追上发送而重扫。
  final Map<int, List<int>> _pendingTurnIds = {};

  bool get hasOlderMessages => _oldestLoadedMessageId != null;

  // ─── Signals ───

  final chats = listSignal<ChatEntity>([]);
  final chatHistories = listSignal<ChatHistoryEntity>([]);
  final currentChat = signal<ChatEntity?>(null);
  final messages = listSignal<MessageEntity>([]);

  /// 整段会话里每一轮的起点 id（含尚未加载的历史），轮次指示器用。
  ///
  /// 消息列表是窗口化分页的，只持有最近若干条，而指示器要按整段会话的
  /// 轮数来画，所以由仓储整文件扫一遍得到（见
  /// `MessageRepository.getTurnStartIds`）。**计数与窗口无关**：扫描是唯一
  /// 来源，此后新发出的 user 消息由 [_recordNewTurn] 就地补上、删消息按 id
  /// 截断。计数还没到手时本信号为空，指示器不画——不给错的数字。
  final turnStartIds = listSignal<int>([]);

  final _queuedInputs = listSignal<_QueuedChatInput>([]);

  /// Unsent messages for the selected chat, displayed above its composer.
  late final queuedMessages = computed(
    () => _queuedInputs.value
        .where((input) => input.chat.id == currentChat.value?.id)
        .map((input) => input.message)
        .toList(),
  );
  final isLoading = signal(false);

  /// 当前选中对话的首屏历史正在读取。
  ///
  /// 与通用 CRUD loading、LLM 流式状态分离，仅用于切换对话时的消息区反馈。
  final isLoadingMessages = signal(false);

  /// 正在流式运行的对话 id 集合（多对话可同时运行）。
  final streamingChatIds = listSignal<int>([]);

  /// 当前显示的对话是否正在流式（用于输入框/消息列表的流式状态展示）。
  late final isCurrentChatStreaming = computed(() {
    final id = currentChat.value?.id;
    return id != null && streamingChatIds.value.contains(id);
  });

  /// 挂起的权限审批请求（按对话渲染为会话内卡片）。
  final pendingApprovals = listSignal<ApprovalRequest>([]);

  /// 当前挂起的提问请求（会话内卡片，按 chatId 归属）。
  final pendingElicits = listSignal<ElicitRequest>([]);

  final error = signal<String?>(null);

  // 下面这组 `current*` 是"当前选中对话"的参数；没有选中对话时
  // （[currentChat] 为 null，即草稿态）它们就是草稿本身：composer 上改的
  // 每一项都只写在这里，直到首条消息发送时由 [createChat] 一次性落盘。
  final currentModel = signal<ModelEntity?>(null);
  final currentProvider = signal<ProviderEntity?>(null);
  final currentSentinel = signal<SentinelEntity?>(null);
  final currentRetention = signal(defaultDraftRetention);
  final currentTemperature = signal(defaultDraftTemperature);

  /// 当前对话（或草稿态）的推理强度。null = 不传参、使用模型默认。
  final currentReasoningEffort = signal<String>(
    ChatEntity.defaultReasoningEffort,
  );

  /// 当前对话（或草稿态）的工作文件夹，null = 不指定。
  final currentWorkspacePath = signal<String?>(null);
  final currentIteration = signal(0);
  final currentToolName = signal<String?>(null);
  final currentTokenUsage = signal<TokenUsage?>(null);
  final pendingImages = listSignal<String>([]);

  // ─── Computed ───

  late final recentChatHistories = computed(() {
    return chatHistories.value.take(10).toList();
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

  SentinelEntity? _displaySentinel(ChatEntity chat, SentinelEntity? sentinel) {
    return chat.hasSentinel ? sentinel : SentinelViewModel.directChatSentinel;
  }

  void _resetMessagePagination() {
    _oldestLoadedMessageId = null;
    _loadingOlderMessages = false;
    _olderLoadGeneration++;
  }

  Future<List<MessageEntity>> _loadRecentMessages(
    int chatId, {
    required int count,
    int? beforeId,
  }) async {
    final repository = _messageRepo;
    if (repository is RecentMessageRepository) {
      return (repository as RecentMessageRepository).loadRecentMessages(
        chatId,
        count: count,
        beforeId: beforeId,
      );
    }

    final all = await repository.getMessagesByChatId(chatId);
    final eligible = beforeId == null
        ? all
        : all.where((message) => (message.id ?? 0) < beforeId).toList();
    if (eligible.length <= count) return eligible;
    return eligible.sublist(eligible.length - count);
  }

  Future<MessageWindow> _loadMessagePage(int chatId, {int? beforeId}) async {
    final repository = _messageRepo;
    if (beforeId == null && repository is RecentMessageRepository) {
      // 首屏：够小的会话整段给（此后 hasOlder=false，不再翻页），超过阈值的
      // 仍只给尾部一页。轮次条 hover/点击、列表高度因此不再分两段。
      return (repository as RecentMessageRepository).loadInitialMessages(
        chatId,
        pageSize: messagePageSize,
      );
    }
    final loaded = await _loadRecentMessages(
      chatId,
      count: messagePageSize + 1,
      beforeId: beforeId,
    );
    final hasOlder = loaded.length > messagePageSize;
    final page = hasOlder
        ? loaded.sublist(loaded.length - messagePageSize)
        : loaded;
    return (hasOlder: hasOlder, messages: page);
  }

  void _applyMessagePage(MessageWindow page) {
    _discardPendingMessages();
    messages.value = page.messages;
    _oldestLoadedMessageId = page.hasOlder && page.messages.isNotEmpty
        ? page.messages.first.id
        : null;
  }

  /// 向列表顶部追加一页更早的消息，返回实际新增条数。
  Future<int> loadOlderMessages() async {
    final chatId = currentChat.value?.id;
    final beforeId = _oldestLoadedMessageId;
    if (_loadingOlderMessages || chatId == null || beforeId == null) return 0;

    _loadingOlderMessages = true;
    final selectionGeneration = _messageLoadGeneration;
    final loadGeneration = ++_olderLoadGeneration;
    try {
      final page = await _loadMessagePage(chatId, beforeId: beforeId);
      if (selectionGeneration != _messageLoadGeneration ||
          loadGeneration != _olderLoadGeneration ||
          currentChat.value?.id != chatId) {
        return 0;
      }

      // 分页 IO 期间可能收到了流式增量，合并旧消息前先把增量冲刷到当前列表。
      _flushMessages();
      if (page.messages.isEmpty) {
        _oldestLoadedMessageId = null;
        return 0;
      }

      messages.value = [...page.messages, ...messages.value];
      _oldestLoadedMessageId = page.hasOlder ? page.messages.first.id : null;
      return page.messages.length;
    } finally {
      if (loadGeneration == _olderLoadGeneration) {
        _loadingOlderMessages = false;
      }
    }
  }

  // ─── 流式增量合并 ───────────────────────────────────────────────
  //
  // LLM 每个 token 产生一个 RunMessageUpdated，直写 messages 信号会让
  // 每个 delta 触发「整表复制 + 整个 ListView 重建 + markdown 全量重解析」，
  // 消息数 M、输出 N token 时是 O(N·M) 复制加 O(N²) 解析。
  //
  // 这里把窗口内的增量合并成一次信号写入（athena_tui 的 ChatController
  // 已用同一方案，见其 _flushSoon 注释）：追加与更新共用同一个 pending
  // 列表，保证「先追加占位、再更新内容」的顺序不被打乱——顺序一旦反转，
  // replaceWhere 找不到目标就会静默丢弃增量。

  /// 待冲刷的消息列表；null 表示无挂起增量。
  List<MessageEntity>? _pendingMessages;

  /// [_pendingMessages] 所属对话；切换对话后残留的缓冲不得写入新列表。
  int? _pendingChatId;

  Timer? _flushTimer;

  /// chatId → 当前 sendMessage 的完整收尾。用户点击停止后 UI 会立即退出
  /// streaming，但同一对话的新消息要在旧 run 落库完成后再启动，避免迟到
  /// 事件/工具结果覆盖新一轮。
  final Map<int, Completer<void>> _runSettledByChat = {};

  /// 合并窗口。窗口内到达的所有增量只触发一次信号写入。
  ///
  /// 100ms 的取舍与 token 速率无关，取决于一次 flush 的成本：全树 build +
  /// 流式长文本 layout + markdown 全量重解析，20KB 正文约几毫秒。10fps
  /// 的文本刷新在视觉上已是连续的，再快只是徒增 CPU。
  ///
  /// 速率越高这里越关键：600 tok/s 时不合并就是每秒 600 次全量重解析，
  /// 直接把 UI 线程打满；合并后恒定 10 次/秒，与 token 速率解耦。
  final Duration _flushInterval;

  /// 取出可变的 pending 列表（首次从当前信号值复制一份，之后原地变异，
  /// 省掉每个事件一次的整表复制）。
  List<MessageEntity> _pendingFor(int chatId) {
    if (_pendingMessages == null || _pendingChatId != chatId) {
      _pendingMessages = List<MessageEntity>.of(messages.value);
      _pendingChatId = chatId;
    }
    return _pendingMessages!;
  }

  /// 流式追加/替换（占位消息、用户消息、内容增量）。
  ///
  /// 流式增量几乎总是命中最后一条消息，先按尾部快速判定，避免每个事件
  /// 都对整个列表做一次 indexWhere——高 token 速率下这是每秒上千次
  /// O(消息数) 扫描。
  void _bufferAppendMessage(MessageEntity message, int chatId) {
    final pending = _pendingFor(chatId);
    if (pending.isNotEmpty && pending.last.id == message.id) {
      pending[pending.length - 1] = message;
      _scheduleFlush();
      return;
    }
    final index = pending.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      pending[index] = message;
    } else {
      pending.add(message);
    }
    _scheduleFlush();
  }

  void _scheduleFlush() {
    _flushTimer ??= Timer(_flushInterval, () {
      _flushTimer = null;
      _flushMessages();
    });
  }

  /// 立即把挂起增量写入信号。收尾、以及任何需要读到最新列表的用户
  /// 操作（删除、展开）之前必须调用，否则会读到过期的 messages.value。
  void _flushMessages() {
    _flushTimer?.cancel();
    _flushTimer = null;
    final pending = _pendingMessages;
    if (pending == null) return;
    _pendingMessages = null;
    _pendingChatId = null;
    messages.value = pending;
  }

  /// 丢弃挂起增量。整表被替换（切换对话、新建草稿）时使用——此时
  /// 冲刷旧缓冲只会把上一个对话的消息写进新列表。
  void _discardPendingMessages() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingMessages = null;
    _pendingChatId = null;
  }

  ChatViewModel({
    required ChatStoreService manageService,
    required AgentStreamDelegate streamDelegate,
    required ChatRenameDelegate renameDelegate,
    ChatSelectionDelegate? selectionDelegate,
    required ChatUpdateService supportService,
    required MessageRepository messageRepo,
    required ModelResolver modelResolver,
    required SettingViewModel settingViewModel,
    required ModelViewModel modelViewModel,
    required SentinelViewModel sentinelViewModel,
    Duration streamFlushInterval = const Duration(milliseconds: 100),
  }) : _manageService = manageService,
       _stream = streamDelegate,
       _rename = renameDelegate,
       _selection = selectionDelegate ?? ChatSelectionDelegate(),
       _supportService = supportService,
       _messageRepo = messageRepo,
       _modelResolver = modelResolver,
       _settingViewModel = settingViewModel,
       _modelViewModel = modelViewModel,
       _sentinelViewModel = sentinelViewModel,
       _flushInterval = streamFlushInterval {
    // 审批请求 → 会话内卡片；决策完成（含 run 取消自动拒绝）后自动移除。
    // VM 与应用同生命周期，订阅无需取消。
    streamDelegate.approvalRequests.listen((request) {
      pendingApprovals.value = [...pendingApprovals.value, request];
      unawaited(
        request.completer.future.whenComplete(() {
          pendingApprovals.value = pendingApprovals.value
              .where((r) => !identical(r, request))
              .toList();
        }),
      );
    });

    // 提问请求 → 会话内卡片；提交答案或 run 取消（completer 以 null 完成）
    // 后自动移除，与审批卡片同生命周期。
    streamDelegate.elicitRequests.listen((request) {
      pendingElicits.value = [...pendingElicits.value, request];
      unawaited(
        request.completer.future.whenComplete(() {
          pendingElicits.value = pendingElicits.value
              .where((r) => !identical(r, request))
              .toList();
        }),
      );
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

  /// 启动：读会话列表，然后落在一个空草稿页上（对齐 Claude 桌面端），
  /// 不自动打开最近的对话。历史对话从侧栏点进去。
  Future<void> initSignals() async {
    final (chatsList, histories) = await _manageService.getChats();
    chats.value = chatsList;
    chatHistories.value = histories;
    await prepareNewChatDraft();
  }

  /// 把草稿落盘成一个真正的对话。
  ///
  /// 只在草稿态（[currentChat] 为 null）由"首条消息发送"调用：新建对话本身
  /// 不落盘（对齐 Claude 桌面端），`sessions/` 目录与侧栏里只有真正聊过的
  /// 对话。会话参数全部取自草稿态的 `current*` 信号——用户在 composer 上改过
  /// 的模型/角色/温度/上下文保留/推理强度/工作文件夹都要带过去；草稿没定
  /// 模型时回退到设置里的默认对话模型。**不动 [pendingImages]**：调用方发送
  /// 首条消息时还要读它。
  Future<ChatEntity?> createChat() async {
    isLoading.value = true;
    error.value = null;
    try {
      // 按 id 重新解析：拿到最新的模型行与其 provider，provider 已被删掉时
      // 回退到第一个可用模型，而不是带着悬空引用落盘。
      final resolved = await _modelResolver.resolve(
        preferredModelId:
            currentModel.value?.id ?? _settingViewModel.chatModelId.value,
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
      // 草稿没显式选过角色就是默认角色 Athena（见 _syncDraftDefaults）；
      // 清掉角色是 directChatSentinel（保留 id 0），同样能落库。
      final sentinel =
          currentSentinel.value ?? _sentinelViewModel.defaultSentinel.value;
      if (sentinel.id == null) {
        error.value = 'Failed to create chat';
        return null;
      }

      final chat = await _manageService.createChat(
        model: model,
        sentinel: sentinel,
        retention: currentRetention.value,
        temperature: currentTemperature.value,
        reasoningEffort: currentReasoningEffort.value,
        workspacePath: currentWorkspacePath.value,
      );

      final pinned = chats.value.where((c) => c.pinned).toList();
      final unpinned = chats.value.where((c) => !c.pinned).toList();
      chats.value = [...pinned, chat, ...unpinned];

      _messageLoadGeneration++;
      _resetMessagePagination();
      isLoadingMessages.value = false;
      currentChat.value = chat;
      currentModel.value = model;
      currentProvider.value = provider;
      currentSentinel.value = sentinel;
      currentTokenUsage.value = null;
      // 新对话的轮次数是已知的 0：直接建缓存，之后每落一条 user 消息由
      // _recordNewTurn 就地追加，指示器从第二轮起就能画，不必等重新选中。
      _turnStartIdsByChat[chat.id!] = [];
      turnStartIds.value = const [];
      _discardPendingMessages();
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
      _discardQueuedInputs({chat.id!});
      final done =
          _runSettledByChat[chat.id!]?.future ?? _stream.settledOf(chat.id!);
      if (done != null) {
        _stream.stop(chat.id!);
        await done;
      }
      _rename.cancel(chat.id!);

      await _manageService.deleteChat(chat.id!);
      _turnStartIdsByChat.remove(chat.id);
      _pendingTurnIds.remove(chat.id);

      final shouldSelectReplacement = currentChat.value?.id == chat.id;
      final replacement = shouldSelectReplacement
          ? _replacementChatAfterDeleting({chat.id!})
          : null;
      chats.value = chats.value.where((c) => c.id != chat.id).toList();
      chatHistories.value = chatHistories.value
          .where((h) => h.chat.id != chat.id)
          .toList();

      if (shouldSelectReplacement) {
        await _selectChatOrClear(replacement);
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
      _discardQueuedInputs(ids);

      final settling = <Future<void>>[];
      for (final id in ids) {
        final done = _runSettledByChat[id]?.future ?? _stream.settledOf(id);
        if (done != null) {
          _stream.stop(id);
          settling.add(done);
        }
      }
      await Future.wait(settling);
      for (final id in ids) {
        _rename.cancel(id);
      }

      await _manageService.deleteChats(ids);
      ids.forEach(_turnStartIdsByChat.remove);
      ids.forEach(_pendingTurnIds.remove);

      final shouldSelectReplacement =
          currentChat.value != null && ids.contains(currentChat.value!.id);
      final replacement = shouldSelectReplacement
          ? _replacementChatAfterDeleting(ids)
          : null;
      chats.value = chats.value.where((c) => !ids.contains(c.id)).toList();
      chatHistories.value = chatHistories.value
          .where((h) => !ids.contains(h.chat.id))
          .toList();

      if (shouldSelectReplacement) {
        await _selectChatOrClear(replacement);
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  ChatEntity? _replacementChatAfterDeleting(Set<int> deletedIds) {
    final currentIndex = chats.value.indexWhere(
      (chat) => chat.id == currentChat.value?.id,
    );
    for (var index = currentIndex - 1; index >= 0; index--) {
      final candidate = chats.value[index];
      if (!deletedIds.contains(candidate.id)) return candidate;
    }
    return chats.value
        .where((chat) => !deletedIds.contains(chat.id))
        .firstOrNull;
  }

  Future<void> _selectChatOrClear(ChatEntity? chat) async {
    if (chat != null) {
      await selectChat(chat);
      if (currentChat.value?.id == chat.id) {
        _selection.lastSelectedIndex.value = chats.value.indexWhere(
          (candidate) => candidate.id == chat.id,
        );
      }
    } else {
      await prepareNewChatDraft();
      _selection.lastSelectedIndex.value = null;
    }
  }

  Future<void> selectChat(ChatEntity chat) async {
    final loadGeneration = ++_messageLoadGeneration;
    _resetMessagePagination();
    currentChat.value = chat;
    isLoadingMessages.value = true;
    // 新会话的 IO 返回前先卸载旧消息，避免用新 chatId 将旧长列表重建并回底。
    _discardPendingMessages();
    messages.value = [];
    // 轮次指示器：先给缓存值（没有就退回"已加载窗口"的口径），整文件扫描
    // 在后台补，扫完由信号驱动重画，不挡这条 await 链。
    turnStartIds.value = _turnStartIdsByChat[chat.id!] ?? const [];
    unawaited(_loadTurnStartIds(chat.id!, loadGeneration));

    try {
      final page = await _loadMessagePage(chat.id!);
      final result = await _manageService.selectChat(
        chat,
        preloadedMessages: page.messages,
      );
      if (loadGeneration != _messageLoadGeneration ||
          currentChat.value?.id != chat.id) {
        return;
      }

      // 切走后旧对话的挂起增量不得写进新列表
      _applyMessagePage((hasOlder: page.hasOlder, messages: result.messages));
      currentModel.value = result.model;
      currentProvider.value = result.provider;
      currentSentinel.value = _displaySentinel(chat, result.sentinel);
      currentRetention.value = chat.retention;
      currentTemperature.value = chat.temperature;
      currentReasoningEffort.value = chat.reasoningEffort;
      currentWorkspacePath.value = chat.workspacePath;
      pendingImages.value = [];
      currentTokenUsage.value = null;

      // 该对话正在流式运行时,DB 里只有迭代边界前的旧态,用内存快照恢复实时进度
      _mergeLiveMessage(chat.id!);
    } finally {
      if (loadGeneration == _messageLoadGeneration &&
          currentChat.value?.id == chat.id) {
        isLoadingMessages.value = false;
      }
    }
  }

  /// 从 [deletedId] 起截断轮次起点缓存：删消息连带删掉它之后的全部消息
  /// （见 [ChatStoreService.deleteMessagesFromIndex]），而 id 在文件里单调，
  /// 所以 `id < deletedId` 就是删完后仍存在的那些轮次，不必重扫整个文件。
  void _dropTurnStartIdsFrom(int chatId, int? deletedId) {
    final cached = _turnStartIdsByChat[chatId];
    if (deletedId == null || cached == null) return;
    final kept = [
      for (final id in cached)
        if (id < deletedId) id,
    ];
    _turnStartIdsByChat[chatId] = kept;
    if (currentChat.value?.id == chatId) turnStartIds.value = kept;
  }

  /// 读一次整段会话的轮次起点并缓存。
  ///
  /// 整文件扫描可能较慢（长会话的 JSONL 可达几百 MB），所以不阻塞会话切换。
  /// 扫描期间指示器不显示（计数未知时宁可空着，也不给一个错的数字）；扫完由
  /// 信号驱动画出来。失败记一条警告——装饰性的东西不该挡住会话。
  Future<void> _loadTurnStartIds(int chatId, int generation) async {
    try {
      final scanned = await _messageRepo.getTurnStartIds(chatId);
      final pending = _pendingTurnIds.remove(chatId) ?? const <int>[];
      final ids = [
        ...scanned,
        for (final id in pending)
          if (!scanned.contains(id)) id,
      ];
      _turnStartIdsByChat[chatId] = ids;
      if (generation != _messageLoadGeneration ||
          currentChat.value?.id != chatId) {
        return;
      }
      turnStartIds.value = ids;
    } catch (e) {
      LoggerUtil.w('轮次起点扫描失败,指示器本次不显示', error: e);
    }
  }

  /// 新落库一条 user 消息 = 会话多了一轮。
  ///
  /// 计数只认文件：扫描结果已到手就地追加，还没到手先记进待并清单（见
  /// [_pendingTurnIds]）。**不**从消息列表里推——列表是窗口，而轮次数是整段
  /// 会话的属性，跟加载到哪无关。
  void _recordNewTurn(int chatId, int? messageId) {
    if (messageId == null) return;
    final cached = _turnStartIdsByChat[chatId];
    if (cached == null) {
      final pending = _pendingTurnIds.putIfAbsent(chatId, () => []);
      if (!pending.contains(messageId)) pending.add(messageId);
      return;
    }
    if (cached.contains(messageId)) return;
    final updated = [...cached, messageId];
    _turnStartIdsByChat[chatId] = updated;
    if (currentChat.value?.id == chatId) turnStartIds.value = updated;
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

  Future<void> updateModel(
    ModelEntity model, {
    required ChatEntity chat,
  }) async {
    error.value = null;
    try {
      final updated = await _supportService.updateModel(chat, model.id!);
      _updateChatInLists(updated);
      currentModel.value = model;
      currentProvider.value = await _supportService.getProviderForModel(
        model.providerId,
      );
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> updateSentinel(
    SentinelEntity sentinel, {
    required ChatEntity chat,
  }) async {
    error.value = null;
    try {
      final updated = await _supportService.updateSentinel(chat, sentinel.id!);
      _updateChatInLists(updated);
      currentSentinel.value = sentinel;
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> updateRetention(
    int retention, {
    required ChatEntity chat,
  }) async {
    error.value = null;
    try {
      final updated = await _supportService.updateRetention(chat, retention);
      _updateChatInLists(updated);
      currentRetention.value = updated.retention;
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> updateTemperature(
    double temperature, {
    required ChatEntity chat,
  }) async {
    error.value = null;
    try {
      final updated = await _supportService.updateTemperature(
        chat,
        temperature,
      );
      _updateChatInLists(updated);
      currentTemperature.value = updated.temperature;
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> updateReasoningEffort(
    String effort, {
    required ChatEntity chat,
  }) async {
    error.value = null;
    try {
      final updated = await _supportService.updateReasoningEffort(chat, effort);
      _updateChatInLists(updated);
      currentReasoningEffort.value = updated.reasoningEffort;
    } catch (e) {
      error.value = e.toString();
    }
  }

  /// 弹出系统目录选择器设置本会话（或草稿）的工作文件夹。
  ///
  /// 取消（返回 null）不做任何改动：native 目录选择器选不出「不指定」，
  /// 清除走 [updateWorkspacePath] / [updateCurrentWorkspacePath]。
  Future<void> pickWorkspaceFolder() async {
    final chat = currentChat.value;
    error.value = null;
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose working folder',
      );
      if (path == null) return;
      if (chat == null) {
        updateCurrentWorkspacePath(path);
      } else {
        await updateWorkspacePath(path, chat: chat);
      }
    } catch (e) {
      error.value = e.toString();
    }
  }

  /// 设置/清除本会话的工作文件夹（null = 不指定，回到默认行为）。
  Future<void> updateWorkspacePath(
    String? path, {
    required ChatEntity chat,
  }) async {
    error.value = null;
    try {
      final updated = await _supportService.updateWorkspacePath(chat, path);
      _updateChatInLists(updated);
      currentWorkspacePath.value = updated.workspacePath;
    } catch (e) {
      error.value = e.toString();
    }
  }

  Future<void> updateCurrentModel(ModelEntity model) async {
    currentModel.value = model;
    currentProvider.value = await _supportService.getProviderForModel(
      model.providerId,
    );
  }

  void updateCurrentSentinel(SentinelEntity sentinel) {
    // 草稿态的显式选择（含入口注入的绑定角色），落盘时随草稿一起写入。
    currentSentinel.value = sentinel;
  }

  void updateCurrentRetention(int retention) {
    currentRetention.value = retention;
  }

  void updateCurrentTemperature(double temperature) {
    currentTemperature.value = temperature;
  }

  void updateCurrentReasoningEffort(String effort) {
    currentReasoningEffort.value = effort;
  }

  void updateCurrentWorkspacePath(String? path) {
    currentWorkspacePath.value = path;
  }

  // ═══════════════════════════════════════════════════════════════
  // Agent 流式交互
  // ═══════════════════════════════════════════════════════════════

  Future<void> sendMessage(
    MessageEntity message, {
    required ChatEntity chat,
    bool jsonMode = false,
  }) async {
    final chatId = chat.id!;
    var input = _QueuedChatInput(message, chat, jsonMode);
    // The owner drains this chat's queue after each complete coordinator run.
    // Keep unsent input out of history and model context until its turn starts.
    while (true) {
      if (_runSettledByChat.containsKey(chatId)) {
        _queuedInputs.value = [..._queuedInputs.value, input];
        return;
      }
      final previous = _stream.settledOf(chatId);
      if (previous != null) {
        await previous;
        continue;
      }
      break;
    }

    final settled = Completer<void>();
    _runSettledByChat[chatId] = settled;
    // If an earlier input could not be stored, preserve FIFO on the next send.
    final waiting = _nextQueuedInput(chatId);
    if (waiting != null) {
      _queuedInputs.value = [..._queuedInputs.value, input];
      input = waiting;
    }
    try {
      while (true) {
        if (!isStreamingChat(chatId)) {
          streamingChatIds.value = [...streamingChatIds.value, chatId];
        }
        if (currentChat.value?.id == chatId) currentTokenUsage.value = null;
        await _sendInput(input);
        _flushMessages();
        final next = _nextQueuedInput(chatId);
        if (next == null) break;
        input = next;
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      _flushMessages();
      streamingChatIds.value = streamingChatIds.value
          .where((id) => id != chatId)
          .toList();
      if (currentChat.value?.id == chatId) {
        currentIteration.value = 0;
        currentToolName.value = null;
      }
      if (identical(_runSettledByChat[chatId], settled)) {
        _runSettledByChat.remove(chatId);
      }
      if (!settled.isCompleted) settled.complete();
    }
  }

  Future<void> _sendInput(_QueuedChatInput input) async {
    final chat = input.chat;
    final chatId = chat.id!;
    final eventStream = _stream.send(
      message: input.message,
      chat: chat,
      jsonMode: input.jsonMode,
    );
    await for (final event in eventStream) {
      // 运行期间用户可能已切到其他对话：消息列表信号只反映当前显示的对话，
      // 事件属于其他对话时仅落库（coordinator 内部），不污染当前列表。
      final belongsToCurrent = chat.id == currentChat.value?.id;
      switch (event) {
        case RunCompactionChanged(:final step):
          if (belongsToCurrent) {
            _bufferAppendMessage(step.toMessage(), chatId);
            _flushMessages();
          }
        case RunMessageStored(:final message):
          // 用户消息落库 = 会话多了一轮，轮次计数就地跟上（见 _recordNewTurn）
          if (message.role == 'user') _recordNewTurn(chatId, message.id);
          batch(() {
            if (_queuedInputs.value.contains(input)) {
              _queuedInputs.value = _queuedInputs.value
                  .where((queued) => !identical(queued, input))
                  .toList();
            }
            if (belongsToCurrent) {
              _bufferAppendMessage(message, chatId);
              _flushMessages();
            }
          });
        case RunAssistantAppended(:final message):
          if (belongsToCurrent) {
            _bufferAppendMessage(message, chatId);
          }
        case RunMessageUpdated(:final message):
          if (belongsToCurrent) {
            _bufferAppendMessage(message, chatId);
          }
        case RunIterationChanged(:final iteration):
          if (belongsToCurrent && isStreamingChat(chatId)) {
            currentIteration.value = iteration;
          }
        case RunToolNameChanged(:final toolName):
          if (belongsToCurrent && isStreamingChat(chatId)) {
            currentToolName.value = toolName;
          }
        case RunUsageChanged(:final usage, :final chat):
          if (chat.id == currentChat.value?.id) {
            currentTokenUsage.value = usage;
            _updateChatInLists(chat);
          }
        case RunOutcomeChanged():
          // 结构化结果供进化/诊断链路消费，GUI 暂无额外展示。
          break;
        case RunAutoRename():
          unawaited(renameChat(chat));
        case RunListReload():
          unawaited(getChats());
        case RunError(:final message):
          LoggerUtil.e("sendMessage RunError: $message");
          error.value = message;
      }
    }
  }

  /// 追加或替换消息：切换对话的竞态下占位消息可能已在列表中
  /// （快照合并或 DB 预读），避免重复追加。
  void _appendOrReplaceMessage(MessageEntity message) {
    if (!messages.replaceWhere((m) => m.id == message.id, message)) {
      messages.value = [...messages.value, message];
    }
  }

  _QueuedChatInput? _nextQueuedInput(int chatId) =>
      _queuedInputs.value.where((input) => input.chat.id == chatId).firstOrNull;

  void _discardQueuedInputs(Set<int> chatIds) {
    _queuedInputs.value = _queuedInputs.value
        .where((input) => !chatIds.contains(input.chat.id))
        .toList();
  }

  /// 指定对话是否正在流式运行。
  bool isStreamingChat(int chatId) => streamingChatIds.value.contains(chatId);

  /// 停止指定对话的 Agent 运行。
  void stopGenerating(int chatId) {
    _stream.stop(chatId);
    // 用户可见状态立即停止；进程终止、取消落库等由现有 send Future 在后台
    // 完成。新输入会加入队列，等待旧 run 收尾后再写入聊天记录。
    if (_pendingChatId == chatId) _flushMessages();
    streamingChatIds.value = streamingChatIds.value
        .where((id) => id != chatId)
        .toList();
    if (currentChat.value?.id == chatId) {
      currentIteration.value = 0;
      currentToolName.value = null;
    }
  }

  /// 用户对审批请求做出决策（Allow Once / Always Allow / Deny）。
  void respondApproval(ApprovalRequest request, PermissionDecision decision) {
    _stream.respondApproval(request, decision);
  }

  /// 用户提交提问卡片上的答案（问题文本 → 所选 label / 自填文本）。
  void respondElicit(ElicitRequest request, Map<String, String> answers) {
    _stream.respondElicit(request, answers);
  }

  Future<void> deleteMessage(MessageEntity message) async {
    isLoading.value = true;
    error.value = null;
    try {
      // 定位 index 前先落地挂起增量，否则读到的是过期列表
      _flushMessages();
      final index = messages.value.indexWhere((item) => item.id == message.id);
      if (index >= 0) {
        await _manageService.deleteMessagesFromIndex(messages.value, index);
        _dropTurnStartIdsFrom(message.chatId, message.id);
        await refreshMessages(message.chatId);
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshMessages(int chatId) async {
    if (currentChat.value?.id != chatId) return;
    final loadGeneration = ++_messageLoadGeneration;
    _resetMessagePagination();
    final page = await _loadMessagePage(chatId);
    if (loadGeneration != _messageLoadGeneration ||
        currentChat.value?.id != chatId) {
      return;
    }
    _applyMessagePage(page);
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

  // ═══════════════════════════════════════════════════════════════
  // 草稿
  // ═══════════════════════════════════════════════════════════════

  /// 进入草稿态：卸掉当前对话，composer 回到新对话默认参数，不落盘。
  ///
  /// 桌面端点"New chat"、移动端进入无对话的聊天页、删掉最后一个对话都到
  /// 这里；真正的会话文件要等首条消息发送时由 [createChat] 创建。
  Future<void> prepareNewChatDraft() async {
    _messageLoadGeneration++;
    _resetMessagePagination();
    isLoadingMessages.value = false;
    currentChat.value = null;
    _discardPendingMessages();
    messages.value = [];
    // 上一个对话的轮次起点不能留着，否则空白草稿页会画出它的指示条
    turnStartIds.value = const [];
    pendingImages.value = [];
    currentTokenUsage.value = null;
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
    currentReasoningEffort.value = ChatEntity.defaultReasoningEffort;
    currentWorkspacePath.value = null;
  }
}
