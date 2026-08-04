import 'dart:async';

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
  })  : _manageService = manageService,
        _bridge = bridge,
        _messageRepo = messageRepo,
        _modelRepo = modelRepo,
        _providerRepo = providerRepo,
        _sentinelRepo = sentinelRepo,
        _supportService = supportService;

  final ChatManageService _manageService;
  final TuiAgentBridge _bridge;
  final MessageRepository _messageRepo;
  final ModelRepository _modelRepo;
  final ProviderRepository _providerRepo;
  final SentinelRepository _sentinelRepo;
  final ChatSupportService _supportService;

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

  /// 启动加载:刷新聊天列表;无聊天时自动创建并选中。
  ///
  /// 幂等:已初始化(currentChat 非空)时直接返回,不再访问存储。
  /// 第二次调用(如 AthenaApp.initState 与测试预加载)零 IO——
  /// 避免异步 IO 跨组件生命周期悬挂(测试 tearDown 删除数据目录后
  /// 未完成的读文件会抛 PathNotFoundException)。
  Future<void> initialize() async {
    if (currentChat.value != null) return;
    await _reloadChats();
    final chats = chatList.value;
    if (chats.isEmpty) {
      await newChat();
    } else {
      await selectChat(chats.first.chat);
    }
  }

  Future<void> _reloadChats() async {
    final (_, histories) = await _manageService.getChats();
    chatList.value = histories;
  }

  /// 新建聊天:默认模型 + 默认角色。
  Future<void> newChat() async {
    final model = await _defaultModel();
    final sentinel = await _defaultSentinel();
    if (model == null || sentinel == null) {
      error.value = '没有可用模型或角色。请先运行 /providers 配置 API key。';
      return;
    }
    final chat = await _manageService.createChat(
      model: model,
      sentinel: sentinel,
    );
    await _reloadChats();
    await selectChat(chat);
  }

  Future<ModelEntity?> _defaultModel() async {
    final models = await _modelRepo.getAllModels();
    if (models.isEmpty) return null;
    return models.first;
  }

  Future<SentinelEntity?> _defaultSentinel() async {
    final sentinels = await _sentinelRepo.getAllSentinels();
    if (sentinels.isEmpty) return null;
    return sentinels.first;
  }

  /// 全部可用模型(供选择弹层使用)。
  Future<List<ModelEntity>> get availableModels => _modelRepo.getAllModels();

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
    final updated = provider.copyWith(apiKey: apiKey.trim());
    await _providerRepo.updateProvider(updated);
    // 若当前会话用的正是该 provider,同步状态栏
    if (currentProvider.value?.id == provider.id) {
      currentProvider.value = updated;
    }
  }

  /// 向消息区推入一条临时消息(不落库,如 /help 输出)。
  /// 切换聊天后消失,仅内存展示。
  void pushTransientMessage(MessageEntity message) {
    messages.value = [...messages.value, message];
  }

  /// 选中聊天并加载其消息。
  Future<void> selectChat(ChatEntity chat) async {
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
    final updated = await _supportService.updateModel(chat!, model.id!);
    currentChat.value = updated;
    currentModel.value = model;
    currentProvider.value = await _supportService.getProviderForModel(
      model.providerId,
    );
    await _reloadChats();
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

    final message = MessageEntity(chatId: chat!.id!, role: 'user', content: text);
    isStreaming.value = true;
    currentTokenUsage.value = null;
    _pendingList = null;
    _flushTimer?.cancel();
    _flushTimer = null;

    try {
      final stream = _bridge.send(message: message, chat: chat, jsonMode: jsonMode);
      await for (final event in stream) {
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
            unawaited(_autoRename(chat));
          case RunListReload():
            unawaited(_reloadChats());
          case RunError(:final message):
            LoggerUtil.e('sendMessage RunError: $message');
            error.value = message;
        }
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
  Future<void> _autoRename(ChatEntity chat) async {
    final first = await _messageRepo.getLatestMessageByChatId(chat.id!);
    final text = first?.content ?? '';
    if (text.isEmpty) return;
    final title = text.trim().length > 30
        ? '${text.trim().substring(0, 30)}…'
        : text.trim();
    await _supportService.renameChatManually(chat, title);
    await _reloadChats();
    // 同步本地 currentChat 的 title
    final current = currentChat.value;
    if (current?.id == chat.id) {
      currentChat.value = current?.copyWith(title: title);
    }
  }

  // ─── 消息列表更新(含流式节流) ────────────────────────────

  void _pushMessage(MessageEntity message) {
    // 基础是"待 flush 的 pending(若有)",不能直接用 messages.value:
    // 未 flush 时 value 还是旧列表,会把 pending 中未推送的消息丢掉
    final base = _pendingList ?? messages.value;
    _pendingList = [...base, message];
    _flushSoon();
  }

  void _applyMessageUpdate(MessageEntity message) {
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
