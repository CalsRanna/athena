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

  // ─── 状态 ────────────────────────────────────────────────

  /// 聊天列表(含最后一条消息内容),按 pinned + updated_at 排序。
  final chatList = signal<List<ChatHistoryEntity>>([]);
  final currentChat = signal<ChatEntity?>(null);
  final messages = signal<List<MessageEntity>>([]);

  final currentModel = signal<ModelEntity?>(null);
  final currentProvider = signal<ProviderEntity?>(null);
  final currentSentinel = signal<SentinelEntity?>(null);

  final isStreaming = signal(false);
  final currentIteration = signal(0);
  final currentToolName = signal<String?>(null);
  final currentTokenUsage = signal<TokenUsage?>(null);
  final error = signal<String?>(null);

  TuiAgentBridge get bridge => _bridge;

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
    final (_, histories) = await _manageService.getChats();
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
    final sentinels = await _sentinelRepo.getAllSentinels();
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
  Future<List<SentinelEntity>> get availableSentinels =>
      _sentinelRepo.getAllSentinels();

  /// 全部 provider(供 /providers 配置)。
  Future<List<ProviderEntity>> get availableProviders =>
      _providerRepo.getAllProviders();

  /// 保存 provider 的 API key(空 key 视为清除)。
  Future<void> updateProviderApiKey(
    ProviderEntity provider,
    String apiKey,
  ) async {
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
    messages.value = [...messages.value, message];
  }

  /// 选中聊天并加载其消息。
  Future<void> selectChat(ChatEntity chat) async {
    // 流式期间禁止切换:旧聊天的 RunEvent 增量会写进新聊天列表
    // (与 GUI ChatViewModel.selectChat 的保护一致)
    if (isStreaming.value) return;
    final result = await _manageService.selectChat(chat);
    currentChat.value = chat;
    messages.value = result.messages;
    currentModel.value = result.model;
    currentProvider.value = result.provider;
    currentSentinel.value = result.sentinel;
    currentIteration.value = 0;
    currentToolName.value = null;
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
    _flushTimer?.cancel();
    _flushTimer = null;

    try {
      final stream = _bridge.send(message: message, chat: chat, jsonMode: jsonMode);
      await for (final event in stream) {
        handleRunEvent(event);
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      _flushTimer?.cancel();
      _flushTimer = null;
      if (_pendingList != null) {
        messages.value = _pendingList!;
        _pendingList = null;
      }
      isStreaming.value = false;
      currentIteration.value = 0;
      currentToolName.value = null;
    }
  }

  void stopGenerating() {
    _bridge.stop();
  }

  /// 消费单个 [RunEvent](sendMessage 的事件分发;测试可注入事件验证
  /// 跨聊天过滤与列表更新,不依赖真实 Agent 流)。
  @visibleForTesting
  void handleRunEvent(RunEvent event) {
    switch (event) {
      case RunMessageStored(:final message):
        _pushMessage(message);
      case RunAssistantAppended(:final message):
        _pushMessage(message);
      case RunMessageUpdated(:final message):
        _applyMessageUpdate(message);
      case RunIterationChanged(:final iteration):
        currentIteration.value = iteration;
      case RunToolNameChanged(:final toolName):
        currentToolName.value = toolName;
      case RunUsageChanged(:final usage, :final chat):
        if (chat.id == currentChat.value?.id) {
          currentTokenUsage.value = usage;
          _reloadChats();
        }
      case RunAutoRename():
        final chat = currentChat.value;
        if (chat != null) unawaited(_autoRename(chat));
      case RunListReload():
        unawaited(_reloadChats());
      case RunError(:final message):
        LoggerUtil.e('sendMessage RunError: $message');
        error.value = message;
    }
  }

  /// 思考卡片展开/折叠切换,转发给核心协调层。
  Future<void> toggleExpanded(MessageEntity message) async {
    if (message.id != null) {
      _bridge.updateExpanded(message.id!, !message.expanded);
    }
    final updated = await _supportService.updateExpanded(message);
    _applyMessageUpdate(updated);
  }

  /// 自动重命名:取首个用户消息前 30 字符。
  /// (GUI 用 LLM 生成标题;TUI 第一版简化,避免额外网络请求)
  ///
  /// 契约:核心层在首条用户消息刚落库后立即 yield RunAutoRename
  /// (agent_run_coordinator.dart),此刻"首条 user 消息"与"最新消息"
  /// 等价;但该时序属隐式契约,这里做防御性查找:遍历该聊天的全部
  /// 消息取第一条非空 user 消息,不依赖消息写入顺序。
  Future<void> _autoRename(ChatEntity chat) async {
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
    // 同步本地 currentChat 的 title
    final current = currentChat.value;
    if (current?.id == chat.id) {
      currentChat.value = current?.copyWith(title: title);
    }
  }

  /// 从消息文本截取聊天标题:取前 30 字符,超长加省略号。
  static String _titleFromText(String text) {
    final trimmed = text.trim();
    return trimmed.length > 30 ? '${trimmed.substring(0, 30)}…' : trimmed;
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
    // 未 flush 时 value 还是旧列表,会把 pending 中未推送的消息丢掉
    final base = _pendingList ?? messages.value;
    _pendingList = [...base, message];
    _flushSoon();
  }

  void _applyMessageUpdate(MessageEntity message) {
    // 同上:跨聊天更新(如旧聊天 finalize 的落库回读)不得污染当前列表
    if (message.chatId != currentChat.value?.id) return;
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

  /// 流式高频更新合并:50ms 内多次更新只通知 UI 一次。
  void _flushSoon() {
    _flushTimer ??= Timer(const Duration(milliseconds: 50), () {
      _flushTimer = null;
      if (_pendingList != null) {
        messages.value = _pendingList!;
        _pendingList = null;
      }
    });
  }
}
