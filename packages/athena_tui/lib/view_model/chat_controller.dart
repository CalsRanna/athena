import 'dart:async';

import 'package:meta/meta.dart';
import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/chat_history_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/model/token_usage.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/provider_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/service/chat_manage_service.dart';
import 'package:athena_core/service/chat_support_service.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:athena_tui/bridge/tui_agent_bridge.dart';
import 'package:athena_tui/storage/jsonl_session_repository.dart';
import 'package:athena_tui/ui/text_util.dart';
import 'package:signals/signals.dart';

/// TUI 聊天控制器:持有全部 UI 状态(signals),消费 [RunEvent] 事件流。
///
/// 不依赖 nocterm,纯 Dart 可测试。事件处理与 GUI ChatViewModel 对齐。
class ChatController {
  ChatController({
    required ChatManageService manageService,
    required TuiAgentBridge bridge,
    required MessageRepository messageRepo,
    required ModelRepository modelRepo,
    required ProviderRepository providerRepo,
    required SentinelRepository sentinelRepo,
    required ChatSupportService supportService,
    Future<void> Function(String modelId)? onModelSwitched,
    String? defaultModelId,
  })  : _manageService = manageService,
        _bridge = bridge,
        _messageRepo = messageRepo,
        _modelRepo = modelRepo,
        _providerRepo = providerRepo,
        _sentinelRepo = sentinelRepo,
        _supportService = supportService,
        _onModelSwitched = onModelSwitched,
        _defaultModelId = defaultModelId;

  final ChatManageService _manageService;
  final TuiAgentBridge _bridge;
  final MessageRepository _messageRepo;
  final ModelRepository _modelRepo;
  final ProviderRepository _providerRepo;
  final SentinelRepository _sentinelRepo;
  final ChatSupportService _supportService;

  /// 模型切换后的持久化回调(写回 setting.yaml 的 model: modelId)。
  final Future<void> Function(String modelId)? _onModelSwitched;

  /// 默认模型 modelId(setting.yaml 的 model:),新建对话时使用。
  /// 启动时由 TuiDi 注入,之后每次 `newChat`(/new、启动、删除后自动新建)
  /// 都用它。可变:启动导入 yaml 后才赋值。
  String? _defaultModelId;

  /// 设置默认模型 modelId(启动时从 setting.yaml 导入后调用)。
  void setDefaultModelId(String? modelId) {
    _defaultModelId = modelId;
  }

  // ─── 消息窗口化 ─────────────────────────────────────────

  /// 内存中最多持有的消息条数(长对话分页加载的窗口大小)。
  ///
  /// 历史聊天可达几百 MB 消息,全量加载既占内存又拖慢每次 flush 的
  /// 全树 build。只持有最近 N 条,向上滚动到顶时按 id 边界加载更早
  /// 批次。500 条约几 MB,每次 flush 的 build 成本约 1-2ms。
  static const int messageWindowSize = 500;

  /// 窗口最旧消息的 id;null = 已加载到文件头,没有更早的消息了。
  int? _windowMinId;

  /// 是否还有更早的消息可加载(UI 滚动到顶时据此触发分页)。
  bool get hasOlder => _windowMinId != null;

  /// 分页加载进行中(UI 防重入)。
  bool _loadingOlder = false;

  /// 加载最近窗口大小的消息(JSONL 实现走尾部扫描,不读整个文件;
  /// 其他实现防御性全量后取末尾)。
  Future<List<MessageEntity>> _loadRecentMessages(int chatId) async {
    final repo = _messageRepo;
    if (repo is JsonlSessionRepository) {
      return repo.loadRecentMessages(chatId, count: messageWindowSize);
    }
    final all = await repo.getMessagesByChatId(chatId);
    return all.length <= messageWindowSize
        ? all
        : all.sublist(all.length - messageWindowSize);
  }

  /// 向上加载更早的一批消息(插入列表头部),返回新增条数。
  ///
  /// 已到文件头(_windowMinId == null)或加载进行中时返回 0。
  Future<int> loadOlderMessages() async {
    final minId = _windowMinId;
    final chat = currentChat.value;
    if (!_active || _loadingOlder || minId == null || chat?.id == null) {
      return 0;
    }
    _loadingOlder = true;
    try {
      final repo = _messageRepo;
      final older = repo is JsonlSessionRepository
          ? await repo.loadRecentMessages(
              chat!.id!,
              count: messageWindowSize,
              beforeId: minId,
            )
          : <MessageEntity>[]; // 非 JSONL 实现不支持分页,不再加载
      if (older.isEmpty) {
        _windowMinId = null; // 没有更早的消息了
        return 0;
      }
      messages.value = [...older, ...messages.value];
      // 返回不足窗口 → 扫描已到文件头,没有更早的了;正好满窗口 → 还有
      _windowMinId =
          older.length >= messageWindowSize ? older.first.id : null;
      return older.length;
    } finally {
      _loadingOlder = false;
    }
  }

  /// 窗口超限时从头部裁掉多余消息(流式增量只加尾部,裁头部历史;
  /// 被裁消息可随时通过 loadOlderMessages 重新加载)。
  List<MessageEntity> _trimWindow(List<MessageEntity> list) {
    if (list.length <= messageWindowSize) return list;
    final dropped = list.length - messageWindowSize;
    final trimmed = list.sublist(dropped);
    _windowMinId = trimmed.first.id;
    return trimmed;
  }

  // ─── 状态 ────────────────────────────────────────────────

  /// 聊天列表(含最后一条消息内容),按 pinned + updated_at 排序。
  final chatList = signal<List<ChatHistoryEntity>>([]);
  final currentChat = signal<ChatEntity?>(null);
  final messages = signal<List<MessageEntity>>([]);

  final currentModel = signal<ModelEntity?>(null);
  final currentProvider = signal<ProviderEntity?>(null);
  final currentSentinel = signal<SentinelEntity?>(null);

  final isStreaming = signal(false);
  final currentTokenUsage = signal<TokenUsage?>(null);
  final error = signal<String?>(null);

  TuiAgentBridge get bridge => _bridge;

  // ─── 生命周期 ────────────────────────────────────────────

  /// 组件树已拆解:异步延续(流式收尾、后台 IO)不再写信号。
  ///
  /// 背景:sendMessage 的 finally / 50ms flush 可能在 UI 拆解之后才执行
  /// (测试 binding 拆解不卸载组件树,订阅仍挂接;生产退出路径同样存在
  /// 该窗口),写信号会触发已失效订阅的 setState 抛 SignalEffectException。
  /// 用户主动操作(newChat/switchModel 等)无需 guard——退出后不可能有
  /// 用户输入,仅异步延续需要。
  bool _disposed = false;

  /// dispose 后为 false:异步延续入口用它在写信号前早退。
  bool get _active => !_disposed;

  /// 当前 sendMessage 的 in-flight future(退出路径等待其收尾完成)。
  Future<void>? _sendFuture;

  /// run 触发的后台 IO(列表重载/自动重命名),收尾前等待其完成:
  /// 让 isStreaming=false 成为"全部副作用已落定"的信号,退出/测试
  /// 边界不再与未完成的文件 IO 竞态(如测试 tearDown 删除目录时
  /// 撞上 Windows 文件锁)。
  Future<void>? _backgroundWork;

  /// 登记一段后台工作,并入 sendMessage 的收尾等待链。
  void _trackBackground(Future<void> work) {
    final tracked = work.catchError((Object e) {
      LoggerUtil.e('Background work failed: $e');
    });
    final previous = _backgroundWork;
    _backgroundWork = previous == null ? tracked : previous.then((_) => tracked);
  }

  /// 释放资源并阻止后续信号写入。幂等;由 AthenaApp.dispose 调用。
  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  /// 等待当前 sendMessage 完全结束(含 finally 与 flush)。无 in-flight 时立即返回。
  Future<void> waitForSend() => _sendFuture ?? Future.value();

  // ─── 初始化与聊天管理 ────────────────────────────────────

  /// 启动加载:每次启动都打开一个**全新的对话**,不恢复上次会话。
  ///
  /// 幂等:已初始化(currentChat 非空)时直接返回,不再访问存储。
  /// 第二次调用(如 AthenaApp.initState 与测试预加载)零 IO——
  /// 避免异步 IO 跨组件生命周期悬挂(测试 tearDown 删除数据目录后
  /// 未完成的读文件会抛 PathNotFoundException)。
  Future<void> initialize() async {
    if (currentChat.value != null) return;
    await startNewSession();
  }

  /// 打开全新会话:新建一个聊天并选中。历史聊天仍保留在列表,
  /// 可通过 /switch 查看;仅"启动选中"行为是全新的。
  /// 打开全新会话:新建一个聊天并选中。历史聊天仍保留在列表,
  /// 可通过 /switch 查看;仅"启动选中"行为是全新的。
  Future<void> startNewSession() async {
    await newChat();
  }

  Future<void> _reloadChats() async {
    if (!_active) return;
    final (_, histories) = await _manageService.getChats();
    if (!_active) return; // 等待 IO 期间 UI 拆解
    chatList.value = histories;
  }

  /// 新建聊天:默认模型 + 默认角色。
  ///
  /// 默认模型取 setting.yaml 的 `model:`(每次新建对话都用它,包括
  /// /new、启动、删除后自动新建);未配置或解析不到时回退第一个模型。
  Future<void> newChat({ModelEntity? model}) async {
    if (isStreaming.value) return;
    error.value = null;
    final models = await _modelRepo.getAllModels();
    final resolvedModel = model ??
        _resolveDefaultModel(models) ??
        (models.isEmpty ? null : models.first);
    final sentinel = await _defaultSentinel();
    if (resolvedModel == null || sentinel == null) {
      error.value = '没有可用模型或角色。请先运行 /providers 配置 API key。';
      return;
    }
    // Provider 未就绪时给出可见指引(不阻塞建聊天;真正的失败在发送时
    // 由核心层报 RunError)。种子数据保证模型总是存在,这条是实际
    // 最常见的"发不出消息"原因。
    // 只检查 apiKey 非空,不检查 enabled:enabled 是种子默认 false,
    // 用户可能手工编辑 yaml 只填 key(不置 enabled),依赖它会误报。
    final provider = await _supportService
        .getProviderForModel(resolvedModel.providerId);
    if (provider == null || provider.apiKey.isEmpty) {
      error.value = '当前模型 ${resolvedModel.name} 的 Provider 未配置 API key。'
          '请运行 /providers 配置后重试。';
    }
    final chat = await _manageService.createChat(
      model: resolvedModel,
      sentinel: sentinel,
    );
    await _reloadChats();
    await selectChat(chat);
  }

  /// 按 setting.yaml 的默认模型 modelId 解析模型;未配置或找不到返回 null。
  ///
  /// 链路不变式:yaml 的 `model:` 存的是**发给提供商 API 的实际模型 id**
  /// (如 deepseek-v4-flash、anthropic/claude-sonnet-4)。目录中 modelId
  /// 全局唯一(不同提供商的同一模型是不同 modelId),因此按 modelId 匹配
  /// 即唯一确定"模型 + 其提供商";chat 落库引用该模型后,发送时
  /// (ChatService)用的就是同一个 modelId,保证发给提供商的是正确模型。
  ModelEntity? _resolveDefaultModel(List<ModelEntity> models) {
    final defaultId = _defaultModelId;
    if (defaultId == null) return null;
    for (final model in models) {
      if (model.modelId == defaultId) return model;
    }
    return null;
  }

  Future<SentinelEntity?> _defaultSentinel() async {
    final sentinels = await availableSentinels;
    if (sentinels.isEmpty) return null;
    return sentinels.first;
  }

  /// 可用模型(供选择弹层使用):仅返回所属 provider 已配置 API key 的
  /// 模型——没有 key 的 provider 无法发起请求,其模型不展示。
  Future<List<ModelEntity>> get availableModels async {
    return [for (final (model, _) in await availableModelsWithProvider) model];
  }

  /// 可用模型及其所属提供商名(展示用:模型名 (提供商名))。
  ///
  /// 仅返回所属 provider **已配置 API key** 的模型——没有 key 的
  /// provider 无法发起请求,其模型不展示。
  Future<List<(ModelEntity, String)>> get availableModelsWithProvider async {
    final models = await _modelRepo.getAllModels();
    final providers = await _providerRepo.getAllProviders();
    final keyedNames = {
      for (final p in providers)
        if (p.apiKey.isNotEmpty) p.id: p.name,
    };
    return [
      for (final m in models)
        if (keyedNames.containsKey(m.providerId))
          (m, keyedNames[m.providerId]!),
    ];
  }

  /// 全部可用角色(供选择弹层使用)。
  ///
  /// 预设角色仅 Athena 展示([SentinelEntity.isListVisible]),
  /// 其余预设角色隐藏;数据仍在库中,已存聊天引用不受影响。
  Future<List<SentinelEntity>> get availableSentinels async {
    final all = await _sentinelRepo.getAllSentinels();
    return all.where((s) => s.isListVisible).toList();
  }

  /// 全部 provider(供 /providers 配置)。
  Future<List<ProviderEntity>> get availableProviders =>
      _providerRepo.getAllProviders();

  /// 保存 provider 的 API key(空 key 视为清除)。
  Future<void> updateProviderApiKey(
    ProviderEntity provider,
    String apiKey,
  ) async {
    if (!_active) return;
    final trimmed = apiKey.trim();
    // 配置了 key 即视为启用(enabled 为种子默认 false,若不置 true,
    // provider 检查会永远报"未配置 API key")
    final updated = provider.copyWith(
      apiKey: trimmed,
      enabled: trimmed.isNotEmpty ? true : provider.enabled,
    );
    await _providerRepo.updateProvider(updated);
    // enabled 不参与"可用性"判断(仅 apiKey 非空即可用),但保留置位
    // 供 getEnabledProviders 等消费方区分
    // 若当前会话用的正是该 provider,同步状态栏
    if (currentProvider.value?.id == provider.id) {
      currentProvider.value = updated;
    }
    // 配置了 key:清除"未配置 API key"引导错误(用户已解决)
    if (trimmed.isNotEmpty) {
      error.value = null;
    }
    // provider 由 YamlProviderRepository 直接持久化到 setting.yaml,
    // 无需额外写回
  }

  /// 向消息区推入一条临时消息(不落库,如 /help 输出)。
  /// 切换聊天后消失,仅内存展示。
  void pushTransientMessage(MessageEntity message) {
    if (!_active) return;
    final pending = _pendingList;
    if (pending == null) {
      // 无流式增量:同步写入,不留定时器(定时器会越过 UI 拆解边界,
      // 拆解后触发写信号)
      messages.value = _trimWindow([...messages.value, message]);
    } else {
      // 流式增量在 pending 中:并入同一批 flush(直接写 messages.value
      // 会被 pending 整体覆盖丢弃);flush 定时器已由流式事件创建。
      // pending 私有且与 messages.value 分离,可直接变异零复制
      pending.add(message);
    }
  }

  /// 选中聊天并加载其消息。
  ///
  /// 消息分页加载最近 [messageWindowSize] 条(不走 manageService.selectChat
  /// 的全量加载——历史聊天可达几百 MB,全量读既慢又占内存);model /
  /// provider / sentinel 单独查。向上滚动到顶时经 [loadOlderMessages]
  /// 按 id 边界加载更早批次。
  Future<void> selectChat(ChatEntity chat) async {
    // 流式期间禁止切换:旧聊天的 RunEvent 增量会写进新聊天列表
    // (与 GUI ChatViewModel.selectChat 的保护一致)
    if (isStreaming.value) return;
    if (!_active) return;
    // 清掉未 flush 的 pending(瞬态消息/流式增量):否则 100ms 后 flush
    // 会用旧聊天的 pending 整体覆盖新聊天列表
    _pendingList = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    final messages = await _loadRecentMessages(chat.id!);
    if (!_active) return; // 等待 IO 期间 UI 拆解
    // 返回满窗口 → 文件里可能还有更早的;不足 → 已到文件头
    _windowMinId =
        messages.length >= messageWindowSize ? messages.first.id : null;
    final model = await _modelRepo.getModelById(chat.modelId);
    final provider = model == null
        ? null
        : await _supportService.getProviderForModel(model.providerId);
    final sentinel = await _sentinelRepo.getSentinelById(chat.sentinelId);
    if (!_active) return;
    currentChat.value = chat;
    this.messages.value = messages;
    currentModel.value = model;
    currentProvider.value = provider;
    currentSentinel.value = sentinel;
  }

  Future<void> deleteCurrentChat() async {
    // 流式期间禁止删除:正在写入的 messages/{chatId}.jsonl 会被级联删除
    if (isStreaming.value) return;
    final chat = currentChat.value;
    if (chat?.id == null) return;
    await _manageService.deleteChat(chat!.id!);
    await _reloadChats();
    if (chatList.value.isEmpty) {
      await newChat();
    } else {
      await selectChat(chatList.value.first.chat);
    }
  }

  /// 切换模型(仅当前会话,调 LLM 前的最后确认由 Agent 流程负责)。
  Future<void> switchModel(ModelEntity model) async {
    final chat = currentChat.value;
    if (chat?.id == null) return;
    // 用户主动选择了模型:清除旧的"未配置 key"引导错误。
    // (newChat 的检查只在建聊天时评估一次,不随状态更新,残留会误导)
    error.value = null;
    final updated = await _supportService.updateModel(chat!, model.id!);
    currentChat.value = updated;
    currentModel.value = model;
    currentProvider.value = await _supportService.getProviderForModel(
      model.providerId,
    );
    await _reloadChats();
    // 持久化用户选择的模型(modelId,稳定标识)
    final onSwitched = _onModelSwitched;
    if (onSwitched != null) {
      await onSwitched(model.modelId);
    }
  }

  Future<void> switchSentinel(SentinelEntity sentinel) async {
    final chat = currentChat.value;
    if (chat?.id == null) return;
    final updated = await _supportService.updateSentinel(chat!, sentinel.id!);
    currentChat.value = updated;
    currentSentinel.value = sentinel;
    await _reloadChats();
  }

  // ─── Agent 交互 ─────────────────────────────────────────

  /// 发送用户消息并消费 [RunEvent] 事件流(镜像 GUI ChatViewModel.sendMessage)。
  Future<void> sendMessage(String text, {bool jsonMode = false}) async {
    final chat = currentChat.value;
    if (chat?.id == null || isStreaming.value) return;

    error.value = null;
    final message = MessageEntity(chatId: chat!.id!, role: 'user', content: text);
    isStreaming.value = true;
    currentTokenUsage.value = null;
    _pendingList = null;
    _backgroundWork = null;
    _flushTimer?.cancel();
    _flushTimer = null;

    // 记录 in-flight future:退出路径(waitForSend)等待收尾完全结束。
    // _doSend 在首个 await 处挂起,此处赋值无竞态;identical 兜底防
    // 极端情况下已完成才赋值导致悬挂旧引用。
    final future = _doSend(message, chat, jsonMode);
    _sendFuture = future;
    try {
      await future;
    } finally {
      if (identical(_sendFuture, future)) _sendFuture = null;
    }
  }

  Future<void> _doSend(
    MessageEntity message,
    ChatEntity chat,
    bool jsonMode,
  ) async {
    if (!_active) return;
    try {
      final stream = _bridge.send(message: message, chat: chat, jsonMode: jsonMode);
      await for (final event in stream) {
        handleRunEvent(event);
      }
      // 等待 run 触发的后台 IO(列表重载/自动重命名)完成(内部已
      // catchError,不会抛),收尾信号 isStreaming=false 前全部落定
      final background = _backgroundWork;
      _backgroundWork = null;
      if (background != null) {
        await background;
      }
    } catch (e) {
      if (_active) error.value = e.toString();
    } finally {
      _flushTimer?.cancel();
      _flushTimer = null;
      // UI 已拆解:不再写信号(订阅已失效,写了会抛 SignalEffectException)
      if (_active) {
        if (_pendingList != null) {
          messages.value = _pendingList!;
          _pendingList = null;
        }
        isStreaming.value = false;
      }
    }
  }

  void stopGenerating() {
    final chatId = currentChat.value?.id;
    if (chatId != null) _bridge.stop(chatId);
  }

  /// 消费单个 [RunEvent](sendMessage 的事件分发;测试可注入事件验证
  /// 跨聊天过滤与列表更新,不依赖真实 Agent 流)。
  @visibleForTesting
  void handleRunEvent(RunEvent event) {
    if (!_active) return; // UI 拆解后的流式收尾事件不再写信号
    switch (event) {
      case RunMessageStored(:final message):
        _pushMessage(message);
      case RunAssistantAppended(:final message):
        _pushMessage(message);
      case RunMessageUpdated(:final message):
        _applyMessageUpdate(message);
      // TUI 无迭代/工具状态显示(与 GUI 不同),事件有意忽略
      case RunIterationChanged() || RunToolNameChanged():
        break;
      case RunUsageChanged(:final usage, :final chat):
        if (chat.id == currentChat.value?.id) {
          currentTokenUsage.value = usage;
          // 事件已带最新 ChatEntity:原位更新,避免每次 usage 事件
          // 全量重读所有聊天的消息文件(lastMessageContent 不受影响;
          // 排序字段 pinned/updatedAt 不随 usage 变化)
          final list = chatList.value;
          final index = list.indexWhere((h) => h.chat.id == chat.id);
          if (index >= 0) {
            final updated = [...list];
            updated[index] = ChatHistoryEntity(
              chat: chat,
              lastMessageContent: list[index].lastMessageContent,
            );
            chatList.value = updated;
          }
        }
      case RunAutoRename():
        final chat = currentChat.value;
        if (chat != null) {
          _trackBackground(_autoRename(chat));
        }
      case RunListReload():
        _trackBackground(_reloadChats());
      case RunError(:final message):
        LoggerUtil.e('sendMessage RunError: $message');
        error.value = message;
    }
  }

  /// 自动重命名:取首个用户消息前 30 字符。
  /// (GUI 用 LLM 生成标题;TUI 第一版简化,避免额外网络请求)
  ///
  /// 契约:核心层在首条用户消息刚落库后立即 yield RunAutoRename
  /// (agent_run_coordinator.dart),此刻"首条 user 消息"与"最新消息"
  /// 等价;但该时序属隐式契约,这里做防御性查找:遍历该聊天的全部
  /// 消息取第一条非空 user 消息,不依赖消息写入顺序。
  Future<void> _autoRename(ChatEntity chat) async {
    if (!_active) return;
    final messages = await _messageRepo.getMessagesByChatId(chat.id!);
    String? text;
    for (final m in messages) {
      if (m.role == 'user' && m.content.trim().isNotEmpty) {
        text = m.content;
        break;
      }
    }
    if (text == null) return;
    final title = _titleFromText(text);
    await _supportService.renameChatManually(chat, title);
    await _reloadChats();
    if (!_active) return;
    // 同步本地 currentChat 的 title
    final current = currentChat.value;
    if (current?.id == chat.id) {
      currentChat.value = current?.copyWith(title: title);
    }
  }

  /// 从消息文本截取聊天标题:取前 30 字符,超长加省略号。
  ///
  /// 标题取自不可信的用户消息,却会渲染在状态栏、/list、/switch 弹层,
  /// 出口统一清洗 ANSI(与消息内容渲染一致)。
  static String _titleFromText(String text) {
    final clean = sanitizeAnsi(text).trim();
    return clean.length > 30 ? '${clean.substring(0, 30)}…' : clean;
  }

  /// 测试入口:暴露 [_titleFromText] 的纯函数语义。
  @visibleForTesting
  static String titleFromText(String text) => _titleFromText(text);

  /// 测试入口:直接触发 [_autoRename] 路径。
  @visibleForTesting
  Future<void> autoRenameForTest(ChatEntity chat) => _autoRename(chat);

  // ─── 消息列表更新(含流式节流) ────────────────────────────

  void _pushMessage(MessageEntity message) {
    // 防御:非当前聊天的流式增量不进入列表(selectChat 已有流式守卫,
    // 此过滤兜底未来的新调用路径,与 RunUsageChanged 的 chat.id 检查一致)
    if (message.chatId != currentChat.value?.id) return;
    // 基础是"待 flush 的 pending(若有)",不能直接用 messages.value:
    // 未 flush 时 value 还是旧列表,会把 pending 中未推送的消息丢掉。
    // pending 首次创建时与 messages.value 分离(复制),之后直接变异
    // 零复制——消息数 N 时每事件 O(1) 而非 O(N)(LLM 每 token 一事件,
    // 长对话时每事件复制整个列表是显著开销)。
    final pending = _pendingList;
    if (pending == null) {
      _pendingList = [...messages.value, message];
    } else {
      pending.add(message);
    }
    _flushSoon();
  }

  void _applyMessageUpdate(MessageEntity message) {
    // 同上:跨聊天更新(如旧聊天 finalize 的落库回读)不得污染当前列表
    if (message.chatId != currentChat.value?.id) return;
    final minId = _windowMinId;
    // 已被窗口裁掉的旧消息(如长时间流式后 finalize 的早期占位消息):
    // 丢弃,不 add——否则会错位插到列表尾部
    if (minId != null && (message.id ?? 0) < minId) return;
    final pending = _pendingList ?? List<MessageEntity>.of(messages.value);
    final index = pending.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      pending[index] = message;
    } else {
      pending.add(message);
    }
    _pendingList = pending;
    _flushSoon();
  }

  List<MessageEntity>? _pendingList;
  Timer? _flushTimer;

  /// 流式高频更新合并:窗口内多次更新只通知 UI 一次。
  ///
  /// 100ms 而非 50ms:一次 flush 帧的成本 = 全树 build + 流式消息全量
  /// layout(TextLayoutEngine 超线性,10k+ 字符时 10-30ms)+ 全树 paint。
  /// 帧率减半直接减半 CPU 占用;LLM 输出 ~10-50 token/s,100ms 窗口
  /// 每次 flush 仍包含多个 token,视觉上无感。
  void _flushSoon() {
    _flushTimer ??= Timer(const Duration(milliseconds: 100), () {
      _flushTimer = null;
      // UI 拆解后(dispose 已 cancel timer,此处兜底)不再写信号
      if (!_active) return;
      if (_pendingList != null) {
        // 窗口截头:流式增量只加尾部,超窗时裁掉头部历史(可重新加载)
        messages.value = _trimWindow(_pendingList!);
        _pendingList = null;
      }
    });
  }
}
