import 'dart:async';
import 'dart:convert';

import 'package:athena_core/entity/approval_mode.dart';
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
import 'package:athena_gui/view_model/chat_params_state.dart';
import 'package:athena_gui/view_model/chat_run_state.dart';
import 'package:athena_gui/view_model/pending_image.dart';
import 'package:athena_gui/view_model/pending_image_store.dart';
import 'package:athena_gui/view_model/message_window_store.dart';
import 'package:athena_gui/view_model/queued_input_queue.dart';
import 'package:athena_gui/view_model/turn_start_cache.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signals/signals.dart';

/// ChatViewModel 负责聊天会话的业务逻辑。
///
/// 持有全部 UI 状态（Signal），直接调用 Service/Repository 完成简单操作，
/// 将复杂的流式 Agent 交互委托给 [AgentStreamDelegate]（通过 Stream 事件通信）。
class ChatViewModel {
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

  /// 轮次指示器的全量轮次起点，按 chatId 缓存：一次整文件扫描的代价不低，
  /// 切回同一会话时直接用缓存。消息被删除（会连带删掉后面的轮次）时按 id 截断。

  /// 扫描期间新发出、还没并进扫描结果的 user 消息 id(按 chatId)。
  ///
  /// 整文件扫描是个快照,期间用户可能又发了一条;等扫描回来时把它并进去,
  /// 这样轮次数始终等于"整段会话的 user 消息数",不必为了追上发送而重扫。

  bool get hasOlderMessages => _window.hasOlder;

  // ─── Signals ───

  final chats = listSignal<ChatEntity>([]);
  final chatHistories = listSignal<ChatHistoryEntity>([]);
  final currentChat = signal<ChatEntity?>(null);

  /// 整段会话里每一轮的起点 id（含尚未加载的历史），轮次指示器用。
  ///
  /// 消息列表是窗口化分页的，只持有最近若干条，而指示器要按整段会话的
  /// 轮数来画，所以由仓储整文件扫一遍得到（见
  /// `MessageRepository.getTurnStartIds`）。**计数与窗口无关**：扫描是唯一
  /// 当前对话的轮次起点。整块逻辑在 TurnStartCache 里；这里转发它的信号，
  /// 指示器照旧读 `chatViewModel.turnStartIds.value`。
  ListSignal<String> get turnStartIds => _turns.turnStartIds;

  /// 待发输入的排队区（按会话 FIFO）。见 QueuedInputQueue。
  late final QueuedInputQueue _queue = QueuedInputQueue();

  /// Unsent messages for the selected chat, displayed above its composer.
  late final queuedMessages = computed(
    () => _queue.messagesFor(currentChat.value?.id),
  );
  final isLoading = signal(false);

  /// 当前选中对话的首屏历史正在读取。
  ///
  /// 与通用 CRUD loading、LLM 流式状态分离，仅用于切换对话时的消息区反馈。
  final isLoadingMessages = signal(false);

  /// 运行态（流式中的对话、实时进度、汇报记账）整块在 [ChatRunState] 里；
  /// 这里转发它的信号，页面代码一行未改。
  late final ChatRunState _runState = ChatRunState();

  /// 正在流式运行的对话 id 集合（多对话可同时运行）。
  ListSignal<String> get streamingChatIds => _runState.streamingChatIds;

  /// 当前显示的对话是否正在流式（用于输入框/消息列表的流式状态展示）。
  late final isCurrentChatStreaming = computed(() {
    final id = currentChat.value?.id;
    return id != null && _runState.isStreaming(id);
  });

  /// 挂起的权限审批请求（按对话渲染为会话内卡片）。
  final pendingApprovals = listSignal<ApprovalRequest>([]);

  /// 当前挂起的提问请求（会话内卡片，按 chatId 归属）。
  final pendingElicits = listSignal<ElicitRequest>([]);

  /// 最近一次失败的描述（同时以提示条告知用户，见 [_reportError]）。
  final error = signal<String?>(null);

  // 下面这组 `current*` 是"当前选中对话"的参数；没有选中对话时
  // （[currentChat] 为 null，即草稿态）它们就是草稿本身：composer 上改的
  // 每一项都只写在这里，直到首条消息发送时由 [createChat] 一次性落盘。
  /// 当前 composer 指向的那条对话（或草稿）的参数，整块在 [ChatParamsState] 里。
  late final ChatParamsState _params = ChatParamsState(
    settingViewModel: _settingViewModel,
    modelViewModel: _modelViewModel,
    sentinelViewModel: _sentinelViewModel,
    supportService: _supportService,
  );

  Signal<ModelEntity?> get currentModel => _params.currentModel;
  Signal<ProviderEntity?> get currentProvider => _params.currentProvider;
  Signal<SentinelEntity?> get currentSentinel => _params.currentSentinel;
  Signal<int> get currentRetention => _params.currentRetention;
  Signal<double> get currentTemperature => _params.currentTemperature;

  /// 当前对话（或草稿态）的推理强度。null = 不传参、使用模型默认。
  Signal<String> get currentReasoningEffort => _params.currentReasoningEffort;

  /// 当前对话（或草稿态）的工作文件夹，null = 不指定。
  Signal<String?> get currentWorkspacePath => _params.currentWorkspacePath;

  /// 当前对话（或草稿态）的工具审批档位。
  ///
  /// 草稿态的初值取 `AgentSettings.newChatApprovalMode`（启动时从旧的全局
  /// 设置播种），草稿改档只写这里，首条消息发送时随草稿一起落盘。
  Signal<ApprovalMode> get currentApprovalMode => _params.currentApprovalMode;
  Signal<int> get currentIteration => _runState.currentIteration;
  Signal<String?> get currentToolName => _runState.currentToolName;
  Signal<TokenUsage?> get currentTokenUsage => _runState.currentTokenUsage;

  /// 待发图片的暂存、解码校验与按对话分槽，整块在 [PendingImageStore] 里。
  late final PendingImageStore _images = PendingImageStore(
    currentChatId: () => currentChat.value?.id,
  );

  /// 当前对话的待发图片。转发 [PendingImageStore.pendingImages]，页面照旧读
  /// `chatViewModel.pendingImages.value`。
  ListSignal<PendingImage> get pendingImages => _images.pendingImages;

  /// 轮次起点缓存（整块在 TurnStartCache 里）。它需要读当前对话与加载代次，
  /// 也需要仓储去扫整文件，所以三样都注入。
  late final TurnStartCache _turns = TurnStartCache(
    currentChatId: () => currentChat.value?.id,
    currentGeneration: () => _window.generation,
    scan: (chatId) => _messageRepo.getTurnStartIds(chatId),
  );

  /// composer 里没发出去的文字，按对话分开存（key 同待发图片的槽位）。
  /// 文字的真相同样在输入框（`TextEditingController`）里，这张表只放"当前不在
  /// 编辑的那几槽"——页面切走时存进来、切回来时取走。只活在内存里：草稿是
  /// 临时输入，进程退出即丢。
  final Map<String?, String> _composerDrafts = {};

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

  /// 窗口分页、流式合并与加载代次整块在 [MessageWindowStore] 里；这里只转发。
  Future<int> loadOlderMessages() => _window.loadOlder();

  // ─── 消息窗口 ───────────────────────────────────────────────────
  //
  // 窗口列表、分页、流式增量合并与加载代次整块在 [MessageWindowStore] 里：它自
  // 有一套状态（最旧一条的 seq、两个代次、合并缓冲）与完整的并发语义，与列表
  // CRUD、参数、run 交互都不相干。这里只保留与页面同名的入口。

  late final MessageWindowStore _window = MessageWindowStore(
    repository: _messageRepo,
    currentChatId: () => currentChat.value?.id,
    pageSize: messagePageSize,
    flushInterval: _flushInterval,
  );

  /// 当前显示的消息窗口。转发 [MessageWindowStore.messages]，页面照旧读
  /// `chatViewModel.messages.value`。
  ListSignal<MessageEntity> get messages => _window.messages;

  /// chatId → 当前 sendMessage 的完整收尾。用户点击停止后 UI 会立即退出
  /// streaming，但同一对话的新消息要在旧 run 落库完成后再启动，避免迟到
  /// 事件/工具结果覆盖新一轮。

  /// 合并窗口。窗口内到达的所有增量只触发一次信号写入。
  ///
  /// 100ms 的取舍与 token 速率无关，取决于一次 flush 的成本：全树 build +
  /// 流式长文本 layout + markdown 全量重解析，20KB 正文约几毫秒。10fps
  /// 的文本刷新在视觉上已是连续的，再快只是徒增 CPU。
  ///
  /// 速率越高这里越关键：600 tok/s 时不合并就是每秒 600 次全量重解析，
  /// 直接把 UI 线程打满；合并后恒定 10 次/秒，与 token 速率解耦。
  final Duration _flushInterval;

  /// 运行指示由自动汇报点亮的会话（汇报 run 收尾时据此熄灭）。

  /// 流式追加/替换（占位消息、用户消息、内容增量）。
  void _bufferAppendMessage(MessageEntity message, String chatId) =>
      _window.addBuffered(message, chatId);

  /// 立即把挂起增量写入信号。收尾、以及任何需要读到最新列表的用户
  /// 操作（删除、展开）之前必须调用，否则会读到过期的窗口。
  void _flushMessages() => _window.flush();

  /// 丢弃挂起增量。整表被替换（切换对话、新建草稿）时使用——此时
  /// 冲刷旧缓冲只会把上一个对话的消息写进新列表。
  void _discardPendingMessages() => _window.discardPending();

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

    // 后台任务完成后的自动汇报由协调层自己发起，没有对应的 sendMessage
    // 事件流；订阅内部事件流，让汇报的流式进度和最终结论照常出现在会话里。
    streamDelegate.internalEvents.listen(_handleInternalRunEvent);

    // 草稿的「当前模型」要跟着可用模型走：草稿初值只在进入草稿态那一刻算一次
    // （见 ChatParamsState.resetToDraftDefaults），此后启用的 provider、目录
    // 同步补进来的模型都不会自己进来，composer 右下角就一直空着。
    //
    // 只订阅 enabledModels；草稿态与「要不要补」都在 untracked 里读——补选会把
    // currentModel 写掉，把它读成依赖就成了「在自己的效果里写自己的依赖」。
    // VM 与应用同生命周期，不需要 dispose。
    effect(() {
      if (_modelViewModel.enabledModels.value.isEmpty) return;
      untracked(() {
        if (currentChat.value != null) return;
        unawaited(_params.adoptFirstAvailableModel());
      });
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
      _reportError(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  /// 启动：读会话列表，然后落在一个空草稿页上，
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
  /// 不落盘，`sessions/` 目录与侧栏里只有真正聊过的
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
        _reportError('Failed to create chat');
        return null;
      }
      final model = resolved.model;
      final provider = resolved.provider;

      if (_sentinelViewModel.sentinels.value.isEmpty) {
        await _sentinelViewModel.getSentinels();
      }
      // 草稿没显式选过角色就是默认角色 Athena（见 _syncDraftDefaults）；
      // 清掉角色是 directChatSentinel（空 id），同样能落库。
      final sentinel =
          currentSentinel.value ?? _sentinelViewModel.defaultSentinel.value;
      if (sentinel.id == null &&
          !identical(sentinel, SentinelViewModel.directChatSentinel)) {
        _reportError('Failed to create chat');
        return null;
      }

      final chat = await _manageService.createChat(
        model: model,
        sentinel: sentinel,
        retention: currentRetention.value,
        temperature: currentTemperature.value,
        reasoningEffort: currentReasoningEffort.value,
        workspacePath: currentWorkspacePath.value,
        approvalMode: currentApprovalMode.value,
      );

      final pinned = chats.value.where((c) => c.pinned).toList();
      final unpinned = chats.value.where((c) => !c.pinned).toList();
      chats.value = [...pinned, chat, ...unpinned];

      _window.beginLoad();
      isLoadingMessages.value = false;
      currentChat.value = chat;
      // 草稿落盘成对话：待发图片的槽位跟着改名（列表内容原地不动——调用方
      // 发送首条消息时马上要读 [pendingImages]）；文字草稿的槽位由页面同步。
      _images.claimFor(chat.id!);
      _params.setFromChat(
        chat,
        model: model,
        provider: provider,
        sentinel: sentinel,
      );
      _runState.noteUsage(null);
      // 新对话的轮次数是已知的 0：直接建缓存，之后每落一条 user 消息由
      // _recordNewTurn 就地追加，指示器从第二轮起就能画，不必等重新选中。
      _turns.seedEmpty(chat.id!);
      _discardPendingMessages();
      _window.clear();

      clearSelection();
      _selection.lastSelectedIndex.value = pinned.length;

      return chat;
    } catch (e) {
      _reportError(e.toString());
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// 删一条对话。视图落点只看"删的是不是正在看的那条"：
  ///
  /// - 删的是别条 → 当前对话与消息原样不动（删除是一个列表操作，不该顺手
  ///   把用户正在读的内容换掉）；
  /// - 删的正是当前这条 → 回草稿态（[prepareNewChatDraft]，与删掉最后一条
  ///   对话同一条路径）。**不自动落到邻居**：用户删掉的就是他想离开的那条，
  ///   替他去上一条等于再做一次他没要求的切换，而草稿页的"下一步"是显式的
  ///   （点侧栏任意一条，或直接开新对话）。
  Future<void> deleteChat(ChatEntity chat) async {
    isLoading.value = true;
    error.value = null;
    try {
      _queue.discardChats({chat.id!});
      final done = _settledOf(chat.id!);
      if (done != null) {
        _stream.stop(chat.id!);
        await done;
      }
      _rename.cancel(chat.id!);

      await _manageService.deleteChat(chat.id!);
      _turns.drop(chat.id);

      final removedCurrentChat = currentChat.value?.id == chat.id;
      chats.value = chats.value.where((c) => c.id != chat.id).toList();
      chatHistories.value = chatHistories.value
          .where((h) => h.chat.id != chat.id)
          .toList();

      if (removedCurrentChat) {
        await _clearToDraft();
      }
      _dropChatDrafts({chat.id!});
    } catch (e) {
      _reportError(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteChats(List<ChatEntity> chatsToDelete) async {
    isLoading.value = true;
    error.value = null;
    try {
      final ids = chatsToDelete.map((c) => c.id!).toSet();
      _queue.discardChats(ids);

      final settling = <Future<void>>[];
      for (final id in ids) {
        final done = _settledOf(id);
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
      _turns.dropMany(ids);

      final removedCurrentChat =
          currentChat.value != null && ids.contains(currentChat.value!.id);
      chats.value = chats.value.where((c) => !ids.contains(c.id)).toList();
      chatHistories.value = chatHistories.value
          .where((h) => !ids.contains(h.chat.id))
          .toList();

      if (removedCurrentChat) {
        await _clearToDraft();
      }
      _dropChatDrafts(ids);
    } catch (e) {
      _reportError(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  /// 设置里的「重置」：用 [reset] 清空全部本地数据，前后收拾会话状态。
  ///
  /// 清空前先停掉所有运行中的对话（含协调层自己发起的汇报 run）并等它们
  /// 收尾：run 若在会话文件删掉之后继续写入，会重建出没有会话头的文件，
  /// 侧栏里也会留着已经不存在的对话。清空后回草稿态、重读角色与会话列表，
  /// 并清掉按会话 id 存的草稿槽——重置后 id 从头分配，旧槽会串到新对话上。
  Future<T> runDataReset<T>(Future<T> Function() reset) async {
    _queue.clear();
    final running = {..._runState.runningChatIds, ..._stream.streamingChatIds};
    final settling = <Future<void>>[];
    for (final id in running) {
      final done = _settledOf(id);
      _stream.stop(id);
      _rename.cancel(id);
      if (done != null) settling.add(done);
    }
    await Future.wait(settling);

    final result = await reset();

    _turns.clear();
    chats.value = [];
    chatHistories.value = [];
    await _sentinelViewModel.getSentinels();
    await _clearToDraft();
    _composerDrafts.clear();
    _images.discardAllSlots();
    clearPendingImages();
    await getChats();
    return result;
  }

  /// 删掉当前对话后的落点：回草稿态，列表里的选中项一并清空。
  ///
  /// 走不带继承来源的 [prepareNewChatDraft]：被删的那条对话已经不在了，没有
  /// "还在的邻居"可以继承角色/工作文件夹，参数回默认——与"删掉最后一条对话"
  /// 完全同一条路径。
  Future<void> _clearToDraft() async {
    await prepareNewChatDraft();
    _selection.lastSelectedIndex.value = null;
  }

  Future<void> selectChat(ChatEntity chat) async {
    final loadGeneration = _window.beginLoad();
    currentChat.value = chat;
    // 待发图片按对话分开，跟着对话一起换（文字草稿由页面同步，见
    // `DesktopHomePage._restoreComposerDraft`）
    _retargetPendingImages();
    isLoadingMessages.value = true;
    // 新会话的 IO 返回前先卸载旧消息，避免用新 chatId 将旧长列表重建并回底。
    _discardPendingMessages();
    _window.clear();
    // 轮次指示器：先给缓存值（没有就退回"已加载窗口"的口径），整文件扫描
    // 在后台补，扫完由信号驱动重画，不挡这条 await 链。
    _turns.selectChat(chat.id!);
    unawaited(_loadTurnStartIds(chat.id!, loadGeneration));

    try {
      final page = await _window.loadInitial(chat.id!);
      final result = await _manageService.selectChat(
        chat,
        preloadedMessages: page.messages,
      );
      if (loadGeneration != _window.generation ||
          currentChat.value?.id != chat.id) {
        return;
      }

      // 切走后旧对话的挂起增量不得写进新列表
      _window.applyPage((hasOlder: page.hasOlder, messages: result.messages));
      _params.setFromChat(
        chat,
        model: result.model,
        provider: result.provider,
        sentinel: result.sentinel,
      );
      _runState.noteUsage(null);

      // 该对话正在流式运行时,DB 里只有迭代边界前的旧态,用内存快照恢复实时进度
      _mergeLiveMessage(chat.id!);
    } finally {
      if (loadGeneration == _window.generation &&
          currentChat.value?.id == chat.id) {
        isLoadingMessages.value = false;
      }
    }
  }

  /// 删除操作已持有被删的消息集合，按身份移除轮次（不能比较 UUID 大小）。
  void _dropTurnStartIds(String chatId, Set<String> deletedIds) =>
      _turns.prune(chatId, deletedIds);

  /// 读一次整段会话的轮次起点并缓存（逻辑与失败日志都在缓存里）。
  Future<void> _loadTurnStartIds(String chatId, int generation) =>
      _turns.load(chatId, generation);

  /// 新落库一条 user 消息 = 会话多了一轮；扫描还没回来时先记进待并清单。
  void _recordNewTurn(String chatId, String? messageId) =>
      _turns.record(chatId, messageId);

  /// 若 [chatId] 正在流式,用 coordinator 的内存快照覆盖/追加最后一条消息。
  ///
  /// 幂等：快照消息已存在于列表（id 相同）则替换，否则追加
  /// （竞态：快照对应的占位消息可能尚未落库）。
  void _mergeLiveMessage(String chatId) {
    final live = _stream.liveMessage(chatId);
    if (live != null) _appendOrReplaceMessage(live);
  }

  Future<void> togglePin(ChatEntity chat) async {
    error.value = null;
    try {
      final updated = await _manageService.togglePin(chat);
      if (updated != null) _applyPinnedLocally(updated);
    } catch (e) {
      _reportError(e.toString());
    }
  }

  /// 就地应用置顶结果，不重读会话目录。
  ///
  /// 此前这里无论成败都 `await getChats()`——那是 `getAllChats` +
  /// `getAllChatsWithLastMessage` 两趟全目录扫描（每条会话至少一次文件读），
  /// 点一下置顶的代价与会话数成正比。置顶只动一条会话，按仓储同一条排序口径
  /// （置顶优先，再按 updatedAt 倒序）重排这两条平行列表即可。
  ///
  /// 两条列表必须同序：侧栏按索引把它们配对渲染。
  void _applyPinnedLocally(ChatEntity updated) {
    if (chats.value.isNotEmpty) {
      chats.value = [
        for (final chat in chats.value)
          if (chat.id == updated.id) updated else chat,
      ]..sort(_byPinnedThenUpdated);
    }
    if (chatHistories.value.isNotEmpty) {
      chatHistories.value = [
        for (final history in chatHistories.value)
          if (history.chat.id == updated.id)
            ChatHistoryEntity(
              chat: updated,
              lastMessageContent: history.lastMessageContent,
            )
          else
            history,
      ]..sort((a, b) => _byPinnedThenUpdated(a.chat, b.chat));
    }
  }

  /// 与仓储（`getAllChats` / `getAllChatsWithLastMessage`）同一条排序口径。
  static int _byPinnedThenUpdated(ChatEntity a, ChatEntity b) {
    final pinned = (b.pinned ? 1 : 0).compareTo(a.pinned ? 1 : 0);
    if (pinned != 0) return pinned;
    return b.updatedAt.compareTo(a.updatedAt);
  }

  void clearSelection() => _selection.clearSelection();
  void toggleChatSelection(String chatId, int index) =>
      _selection.toggleChatSelection(chatId, index);
  void rangeSelectChats(int endIndex) =>
      _selection.rangeSelectChats(endIndex, chats.value);
  void initLastSelectedIndex() =>
      _selection.initLastSelectedIndex(currentChat.value, chats.value);

  // ═══════════════════════════════════════════════════════════════
  // 会话参数操作
  // ═══════════════════════════════════════════════════════════════

  /// 会话参数更新的统一外壳：清错误 → 落库 → 就地更新列表 → 同步草稿态信号。
  ///
  /// 这段顺序此前在七处各抄了一遍，每处都带着自己那份 `error` 重置与 try/catch。
  /// 抄一遍的代价是漏掉任何一步都只能靠读七份代码发现，而「错误怎么记」也不能
  /// 只改一处。集中之后 [sync] 里再抛的异常同样落到这里。
  Future<void> _applyChatUpdate({
    required Future<ChatEntity> Function() persist,
    required FutureOr<void> Function(ChatEntity updated) sync,
  }) async {
    error.value = null;
    try {
      final updated = await persist();
      _updateChatInLists(updated);
      await sync(updated);
    } catch (e) {
      _reportError(e.toString());
    }
  }

  Future<void> updateModel(ModelEntity model, {required ChatEntity chat}) =>
      _applyChatUpdate(
        persist: () => _supportService.updateModel(chat, model.id!),
        // 用调用方传进来的实体而不是落库结果：provider 要按它的 id 去查
        sync: (updated) => _params.setModel(model),
      );

  Future<void> updateSentinel(
    SentinelEntity sentinel, {
    required ChatEntity chat,
  }) => _applyChatUpdate(
    persist: () => _supportService.updateSentinel(chat, sentinel.id),
    sync: (_) => _params.setSentinel(sentinel),
  );

  Future<void> updateRetention(int retention, {required ChatEntity chat}) =>
      _applyChatUpdate(
        persist: () => _supportService.updateRetention(chat, retention),
        sync: (updated) => _params.setRetention(updated.retention),
      );

  Future<void> updateTemperature(
    double temperature, {
    required ChatEntity chat,
  }) => _applyChatUpdate(
    persist: () => _supportService.updateTemperature(chat, temperature),
    sync: (updated) => _params.setTemperature(updated.temperature),
  );

  Future<void> updateReasoningEffort(
    String effort, {
    required ChatEntity chat,
  }) => _applyChatUpdate(
    persist: () => _supportService.updateReasoningEffort(chat, effort),
    sync: (updated) => _params.setReasoningEffort(updated.reasoningEffort),
  );

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
      _reportError(e.toString());
    }
  }

  /// 设置/清除本会话的工作文件夹（null = 不指定，回到默认行为）。
  Future<void> updateWorkspacePath(String? path, {required ChatEntity chat}) =>
      _applyChatUpdate(
        persist: () => _supportService.updateWorkspacePath(chat, path),
        sync: (updated) => _params.setWorkspacePath(updated.workspacePath),
      );

  /// 设置本会话的工具审批档位。
  ///
  /// 只影响后续 run：运行中的 run 已在开始时读过自己那份档位。
  Future<void> updateApprovalMode(
    ApprovalMode mode, {
    required ChatEntity chat,
  }) => _applyChatUpdate(
    persist: () => _supportService.updateApprovalMode(chat, mode),
    sync: (updated) => _params.setApprovalMode(updated.approvalMode),
  );

  Future<void> updateCurrentModel(ModelEntity model) async {
    await _params.setModel(model);
  }

  /// 草稿态的显式选择（含入口注入的绑定角色），落盘时随草稿一起写入。
  void updateCurrentSentinel(SentinelEntity sentinel) =>
      _params.setSentinel(sentinel);

  void updateCurrentRetention(int retention) => _params.setRetention(retention);

  void updateCurrentTemperature(double temperature) =>
      _params.setTemperature(temperature);

  void updateCurrentReasoningEffort(String effort) =>
      _params.setReasoningEffort(effort);

  void updateCurrentWorkspacePath(String? path) =>
      _params.setWorkspacePath(path);

  void updateCurrentApprovalMode(ApprovalMode mode) =>
      _params.setApprovalMode(mode);

  // ═══════════════════════════════════════════════════════════════
  // Agent 流式交互
  // ═══════════════════════════════════════════════════════════════

  /// 整理一次用户输入：校验、必要时落草稿、构造消息。
  ///
  /// 桌面与移动的发送流程此前各写一遍，已经漂移——移动端不 trim、不检查是否有
  /// 启用模型、也不重查竞态。这里只收「能不能发、发什么、发给哪条对话」；输入框
  /// 文本、清空、滚动、弹窗文案这些呈现留给各自页面，所以本方法**不发送**：
  /// 页面拿到 [SendUserInputOutcome.sent] 后自行调 [sendMessage]，从而保持
  /// 「校验 → 清空输入框 → 发送」这个顺序不变。
  ///
  /// [ensureModelsReady] 由页面提供（加载模型列表并回答「现在至少有一个可用
  /// 模型吗」），这样本类不必依赖 ModelViewModel。
  ///
  /// [stillValid] 同样由页面提供，用来表达「页面还在、对话没切、附件没换」。
  /// 它带两个参数，因为两处重查的口径本来就不同：草稿落盘**前**只能要求
  /// 「当前对话还是我进来时那条」（草稿态下当前对话仍是来源对话）；落盘**后**
  /// 才要求「当前对话就是我刚要发出的那条新对话」。把它们合成一个参数会让
  /// 草稿发送在第一处重查就被判为过期。
  Future<
    ({SendUserInputOutcome outcome, MessageEntity? message, ChatEntity? chat})
  >
  prepareUserInput({
    required String text,
    required List<PendingImage> images,
    ChatEntity? chat,
    required Future<bool> Function() ensureModelsReady,
    bool Function(ChatEntity? target, bool draftJustCreated)? stillValid,
  }) async {
    final trimmed = text.trim();
    if (images.any((image) => !image.isReady)) {
      return (
        outcome: SendUserInputOutcome.imagesNotReady,
        message: null,
        chat: null,
      );
    }
    if (trimmed.isEmpty && images.isEmpty) {
      return (
        outcome: SendUserInputOutcome.emptyInput,
        message: null,
        chat: null,
      );
    }

    // 先备模型再落草稿：没有可用模型就没必要留下一条发不出去的空白对话
    final modelsReady = await ensureModelsReady();
    if (stillValid != null && !stillValid(chat, false)) {
      return (
        outcome: SendUserInputOutcome.superseded,
        message: null,
        chat: null,
      );
    }
    if (!modelsReady) {
      return (
        outcome: SendUserInputOutcome.noEnabledModels,
        message: null,
        chat: null,
      );
    }

    var target = chat;
    var draftCreated = false;
    if (target == null) {
      target = await createChat();
      draftCreated = true;
      if (target == null) {
        return (
          outcome: SendUserInputOutcome.cancelled,
          message: null,
          chat: null,
        );
      }
    }
    // 模型列表与草稿落盘都可能耗时：期间又贴了图就不能发旧快照。
    // draftJustCreated 传真实值——传成恒 true 会把「页面开着 X、当前对话是 Y」
    // 这种本来发得出去的情况静默判成过期。
    if (stillValid != null && !stillValid(target, draftCreated)) {
      return (
        outcome: SendUserInputOutcome.superseded,
        message: null,
        chat: null,
      );
    }

    final model = currentModel.value;
    if (model == null || model.id == null) {
      return (
        outcome: SendUserInputOutcome.noModel,
        message: null,
        chat: target,
      );
    }

    final message = MessageEntity(
      chatId: target.id ?? '',
      role: 'user',
      content: trimmed,
      imageUrls: images.map((image) => base64Encode(image.bytes!)).join(','),
    );
    // 附件已被这条消息消费掉；await 期间再贴的图不该被这次发送清掉
    clearPendingImages();
    return (outcome: SendUserInputOutcome.sent, message: message, chat: target);
  }

  Future<void> sendMessage(
    MessageEntity message, {
    required ChatEntity chat,
    bool jsonMode = false,
  }) async {
    final chatId = chat.id!;
    var input = QueuedChatInput(message, chat, jsonMode);
    // The owner drains this chat's queue after each complete coordinator run.
    // Keep unsent input out of history and model context until its turn starts.
    while (true) {
      if (_runState.hasRun(chatId)) {
        _queue.enqueue(input);
        return;
      }
      final previous = _stream.settledOf(chatId);
      if (previous != null) {
        // 协调层自己发起的 run（后台任务自动汇报）正在跑：输入框已经清空，
        // 先挂进排队区让用户看得到这条消息，删除会话时也能一并丢弃
        _queue.enqueue(input);
        await previous;
        // 等待期间会话被删（排队项已丢弃），或另一条等待中的发送已经把它
        // 带走发出：不再重复发送
        if (!_queue.contains(input)) return;
        continue;
      }
      break;
    }

    final settled = _runState.registerRun(chatId);
    // If an earlier input could not be stored, preserve FIFO on the next send.
    final waiting = _queue.nextFor(chatId);
    if (waiting != null) {
      _queue.enqueue(input);
      input = waiting;
    }
    try {
      while (true) {
        _runState.beginStreaming(chatId);
        if (currentChat.value?.id == chatId) _runState.noteUsage(null);
        await _sendInput(input);
        _flushMessages();
        final next = _queue.nextFor(chatId);
        if (next == null) break;
        input = next;
      }
    } catch (e) {
      _reportError(e.toString());
    } finally {
      _flushMessages();
      _runState.endStreaming(chatId);
      _runState.clearLiveProgressFor(
        chatId,
        currentChatId: currentChat.value?.id,
      );
      _runState.unregisterRun(chatId, settled);
      if (!settled.isCompleted) settled.complete();
    }
  }

  Future<void> _sendInput(QueuedChatInput input) async {
    // 排队期间用户可能在 composer 上改了模型、角色、工作文件夹等：这些修改
    // 已写回会话列表，出队时按最新的会话参数执行，而不是入队那一刻的快照
    final chat = _chatForEvent(input.chat.id!) ?? input.chat;
    final eventStream = _stream.send(
      message: input.message,
      chat: chat,
      jsonMode: input.jsonMode,
    );
    await for (final event in eventStream) {
      _applyRunEvent(event, chat: chat, input: input);
    }
  }

  /// 单个 [RunEvent] 的分发（用户 send 与内部汇报 run 共用一份语义）。
  ///
  /// [input] 只用于把「用户消息已落库」的排队项从本地队列移除：内部发起的
  /// run（后台任务完成后的自动汇报）没有排队项。
  void _applyRunEvent(
    RunEvent event, {
    required ChatEntity chat,
    QueuedChatInput? input,
  }) {
    final chatId = chat.id!;
    // 运行期间用户可能已切到其他对话：消息列表信号只反映当前显示的对话，
    // 事件属于其他对话时仅落库（coordinator 内部），不污染当前列表。
    final belongsToCurrent = chatId == currentChat.value?.id;
    switch (event) {
      case RunCompactionChanged(:final step, :final runStatistics):
        if (belongsToCurrent) {
          _bufferAppendMessage(
            step.toMessage().copyWith(runStatistics: runStatistics),
            chatId,
          );
          _flushMessages();
        }
      case RunMessageStored(:final message):
        // 用户消息落库 = 会话多了一轮，轮次计数就地跟上（见 _recordNewTurn）
        if (message.role == 'user') _recordNewTurn(chatId, message.id);
        batch(() {
          if (input != null) _queue.remove(input);
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
          _runState.noteIteration(iteration);
        }
      case RunToolNameChanged(:final toolName):
        if (belongsToCurrent && isStreamingChat(chatId)) {
          _runState.noteTool(toolName);
        }
      case RunUsageChanged(:final usage, :final chat):
        if (chat.id == currentChat.value?.id) {
          _runState.noteUsage(usage);
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
        // 协调层会把错误作为 assistant 消息落进会话：当前对话里用户已经看得到，
        // 不再叠一个提示条；在别的对话上发生的错误则要告诉用户
        if (belongsToCurrent) {
          error.value = message;
        } else {
          _reportError('${chat.title}: $message');
        }
    }
  }

  /// 内部 run（后台任务完成后的自动汇报）的事件入口。
  ///
  /// 它没有 sendMessage 的收尾流程，因此流式状态在这里维护：其他对话的汇报
  /// 照常落库，只有当前对话的汇报会点亮运行指示。
  void _handleInternalRunEvent(InternalRunEvent internal) {
    final chatId = internal.chatId;
    // 指示按会话记账，不看当前显示的是哪条：汇报中途切走再切回，这条对话
    // 仍要显示运行中；汇报结束时不管当前在看哪条都要熄灭——否则它会一直
    // 卡在「运行中」，发送键变成停止键。收尾以协调层的 settled 为准，
    // 正常结束、取消、出错都会完成它，不依赖某个具体事件是否到达。
    if (internal.event is RunAssistantAppended &&
        !_runState.isReporting(chatId)) {
      final settled = _stream.settledOf(chatId);
      if (settled != null) {
        _runState.markReporting(chatId);
        if (!isStreamingChat(chatId)) {
          _runState.beginStreaming(chatId);
        }
        unawaited(settled.whenComplete(() => _finishReport(chatId)));
      }
    }
    final chat = _chatForEvent(chatId);
    if (chat != null) _applyRunEvent(internal.event, chat: chat);
  }

  void _finishReport(String chatId) {
    if (!_runState.takeReportFinished(chatId)) return;
    // 汇报刚结束、用户的消息已接着开跑：指示归那条 sendMessage 管
    if (_runState.hasRun(chatId)) return;
    _runState.endStreaming(chatId);
    _runState.clearLiveProgressFor(
      chatId,
      currentChatId: currentChat.value?.id,
    );
  }

  /// 事件所属会话的实体。
  ///
  /// 内部 run 的事件不带 ChatEntity（只有 chatId）：从已加载的会话列表里取，
  /// 列表尚未包含它（刚创建/已切换）时跳过——按会话 id 过滤的事件仍然生效，
  /// 这里只影响需要 ChatEntity 的那几种（自动重命名）。
  ChatEntity? _chatForEvent(String chatId) {
    final current = currentChat.value;
    if (current?.id == chatId) return current;
    for (final history in chatHistories.value) {
      if (history.chat.id == chatId) return history.chat;
    }
    return null;
  }

  /// 追加或替换消息：切换对话的竞态下占位消息可能已在列表中
  /// （快照合并或 DB 预读），避免重复追加。
  void _appendOrReplaceMessage(MessageEntity message) =>
      _window.appendOrReplaceNow(message);

  /// 指定对话当前的收尾 future：本对象登记的（用户发起）优先，否则问协调层
  /// （后台任务自动汇报由它自己发起）。
  Future<void>? _settledOf(String chatId) =>
      _runState.settledOf(chatId) ?? _stream.settledOf(chatId);

  /// 指定对话是否正在流式运行。
  bool isStreamingChat(String chatId) => _runState.isStreaming(chatId);

  /// 记录失败并把这次失败作为**事件**发出去。
  ///
  /// [error] 是状态（最后一次失败，供测试与诊断读），[errors] 是事件（每次失败
  /// 都发一次，供呈现层弹提示）。分成两条是因为「显示一次」不该由状态承担：同一个
  /// 字符串连着失败两次时，只要状态没变，状态型监听什么都看不到。
  ///
  /// ViewModel **不弹 UI**：此前这里是仓库里唯一一处 ViewModel 直接调
  /// `AthenaDialog`，于是任何会报错的路径都要求 Router 已挂载，测试也没法在无 UI
  /// 的情况下跑。呈现交给 `ChatErrorDialogListener`（页面各包一层），与 settings
  /// 下 skill / sentinel / provider / experience 页面「VM 只写状态、页面自己呈现」
  /// 的口径一致。
  void _reportError(String message) {
    error.value = message;
    _errors.add(message);
  }

  final _errors = StreamController<String>.broadcast();

  /// 每次失败发一次的事件流；见 [_reportError]。
  Stream<String> get errors => _errors.stream;

  /// 停止指定对话的 Agent 运行。
  void stopGenerating(String chatId) {
    _stream.stop(chatId);
    // 用户可见状态立即停止；进程终止、取消落库等由现有 send Future 在后台
    // 完成。新输入会加入队列，等待旧 run 收尾后再写入聊天记录。
    // 只冲刷属于这个对话的挂起增量：无条件冲刷会把别的对话的缓冲也提交掉
    _window.flushFor(chatId);
    _runState.endStreaming(chatId);
    _runState.clearLiveProgressFor(
      chatId,
      currentChatId: currentChat.value?.id,
    );
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
        await _manageService.deleteMessagesFromIndex(
          message.chatId,
          messages.value,
          index,
        );
        _dropTurnStartIds(message.chatId, {
          for (final deleted in messages.value.skip(index))
            if (deleted.id != null) deleted.id!,
        });
        await refreshMessages(message.chatId);
      }
    } catch (e) {
      _reportError(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshMessages(String chatId) => _window.refresh(chatId);

  // ═══════════════════════════════════════════════════════════════
  // 重命名
  // ═══════════════════════════════════════════════════════════════

  void startRenaming(String chatId) => _selection.startRenaming(chatId);
  void stopRenaming(String chatId) => _selection.stopRenaming(chatId);

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
      _reportError(e.toString());
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
      _reportError(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 图片
  // ═══════════════════════════════════════════════════════════════

  // 逻辑整块在 PendingImageStore 里；这里保留与页面同名的入口。
  Future<void> addPendingImage(String path) => _images.addPath(path);

  Future<void> addPendingImages(List<String> paths) => _images.addPaths(paths);

  Future<bool> pasteClipboardImages() => _images.pasteClipboardImages();

  void clearPendingImages() => _images.clear();

  void removePendingImage(int index) => _images.removeAt(index);

  void _retargetPendingImages() => _images.retargetToCurrentChat();

  // ═══════════════════════════════════════════════════════════════
  // 草稿
  // ═══════════════════════════════════════════════════════════════

  /// 存一段没发出去的输入，等这条对话再被选中时由 [takeComposerDraft] 取回。
  /// 空串等于不留：不给一个空输入框占条目。
  void saveComposerDraft(String? chatId, String text) {
    if (text.isEmpty) {
      _composerDrafts.remove(chatId);
    } else {
      _composerDrafts[chatId] = text;
    }
  }

  /// 取出 [chatId] 的输入草稿（取走即删，理由同 [_retargetPendingImages]）。
  String takeComposerDraft(String? chatId) =>
      _composerDrafts.remove(chatId) ?? '';

  /// 对话被删掉后清掉它的草稿槽（文字与待发图片）：留着只会在内存里越堆越多，
  /// 而 chat id 不复用，那个槽再也回不去了。
  ///
  /// 必须在 [_clearToDraft] 之后调用——切换会把当前槽先存回它自己的位置，
  /// 早一步清就会被那一步重新写回来。
  void _dropChatDrafts(Set<String> chatIds) {
    for (final id in chatIds) {
      _composerDrafts.remove(id);
      _images.dropSlot(id);
    }
  }

  /// 进入草稿态：卸掉当前对话，composer 回到新对话默认参数，不落盘。
  ///
  /// 桌面端点"New chat"、移动端进入无对话的聊天页、删掉最后一个对话都到
  /// 这里；真正的会话文件要等首条消息发送时由 [createChat] 创建。
  ///
  /// [inheritFrom] 非空时草稿的**角色与工作文件夹**从这条对话继承：点
  /// "新建对话"的意图通常是在同一条项目/角色线上开个新话题，每次重选一遍
  /// 是纯重复劳动。传 null（启动落草稿、删掉最后一个对话）仍回默认角色与
  /// "不指定文件夹"。调用方传的必须是**快照**——本方法一进来就把
  /// [currentChat] 置空。
  ///
  /// [inheritWorkspace] 只被移动端关掉：移动端不注册 shell / 文件工具，
  /// 工作文件夹在那里不起作用，静默落库一个用不到的路径只会污染数据。
  ///
  /// 其余参数（模型、上下文保留、温度、推理强度）不继承，仍取默认。
  Future<void> prepareNewChatDraft({
    ChatEntity? inheritFrom,
    bool inheritWorkspace = true,
  }) async {
    _window.beginLoad();
    isLoadingMessages.value = false;
    currentChat.value = null;
    _discardPendingMessages();
    _window.clear();
    // 上一个对话的轮次起点不能留着，否则空白草稿页会画出它的指示条
    _turns.clear();
    // 待发图片切回"新对话"槽（上一个对话的那份存回它自己的槽）
    _retargetPendingImages();
    _runState.noteUsage(null);
    await _syncDraftDefaults(inheritFrom, inheritWorkspace: inheritWorkspace);
  }

  /// 继承来源对话的角色。显式"不用角色"（sentinel_id = null）继承成同一个保留
  /// 值；其余按 id 回仓储解析，这样隐藏的预设角色也能带过来（它们在
  /// [SentinelViewModel.sentinels] 里根本不出现）。
  /// 进入草稿态时把八个参数重置成「下一条对话的起点」；逻辑在 [ChatParamsState] 里。
  Future<void> _syncDraftDefaults(
    ChatEntity? inheritFrom, {
    required bool inheritWorkspace,
  }) => _params.resetToDraftDefaults(
    inheritFrom,
    inheritWorkspace: inheritWorkspace,
  );
}

/// [ChatViewModel.prepareUserInput] 的结论。页面据此决定呈现什么
/// （弹哪句提示、要不要清输入框），所以每种「不发送」都有自己的取值。
enum SendUserInputOutcome {
  /// 已备好消息，页面可以调 [ChatViewModel.sendMessage] 了。
  sent,

  /// trim 之后文本为空、且没有附件。
  emptyInput,

  /// 附件还在读/解码，字节没就绪。
  imagesNotReady,

  /// 没有启用的 provider / 模型。
  noEnabledModels,

  /// 目标对话没有可用模型。
  noModel,

  /// 等待期间页面被拆掉、切了对话或换了附件。
  superseded,

  /// 建草稿失败。
  cancelled,
}
