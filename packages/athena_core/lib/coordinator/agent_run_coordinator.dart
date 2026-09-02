import 'dart:async';
import 'dart:convert';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/evolution/evolution_prompt.dart';
import 'package:athena_core/agent/evolution/memory_digest.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/runtime_context.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/run_outcome.dart';
import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/service/chat_manage_service.dart';
import 'package:athena_core/service/chat_message_service.dart';
import 'package:athena_core/service/chat_service.dart';
import 'package:athena_core/service/chat_support_service.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_core/util/logger_util.dart';
import 'package:openai_dart/openai_dart.dart';

/// 用户对权限弹窗的决策（GUI 弹窗 / TUI 终端提示由 [PermissionPrompt] 提供）。
class PermissionDecision {
  final bool approved;
  final bool persistExact;
  const PermissionDecision({required this.approved, this.persistExact = false});
}

/// 权限审批回调：由各 App 注入（GUI=会话内审批卡片，TUI=终端提示）。
///
/// [chatId] 标识请求所属对话（GUI 据此把审批渲染到对应会话）；
/// [cancelToken] 供调用方在 run 取消时自动拒绝审批。
typedef PermissionPrompt =
    Future<PermissionDecision> Function(
      int chatId,
      String toolName,
      String arguments,
      CancelToken cancelToken,
    );

/// UI 无关的 Agent run 编排层。
///
/// 职责：用户消息落库 → 构建上下文（含压缩）→ 追加占位消息 →
/// 消费 [AgentService] 事件流 → 流式更新 [MessageEntity] → 用量落库 →
/// 收尾/取消/错误落库。产出 [RunEvent] 纯数据流，无任何 UI 类型。
class AgentRunCoordinator {
  static const _directChatSentinelKey = 'direct';

  final AgentService _agentService;
  final ChatManageService _manageService;
  final ChatMessageService _messageService;
  final ChatService _chatService;
  final MessageRepository _messageRepo;
  final ModelRepository _modelRepo;
  final SentinelRepository _sentinelRepo;
  final ChatRepository _chatRepo;
  final ChatSupportService _supportService;
  final AgentSettings _agentSettings;
  final PermissionService _permissionService;
  final PermissionPrompt _permissionPrompt;

  /// 经验仓库：每次 run 开始时注入相关经验的摘要（见 [MemoryDigest]）。
  final ExperienceRepository _experienceRepository;

  /// Agent 运行环境（GUI/TUI）；null = 不注入运行时上下文提示。
  final RuntimeEnvironment? _runtimeEnvironment;

  /// 下一个 run 的自增 id（多 run 并发的隔离标识）。
  int _nextRunId = 0;

  /// 正在流式运行的对话 id 集合（支持多对话同时运行）。
  final Set<int> _streamingChatIds = {};

  /// chatId → runId 映射（取消/等待 settle/注入消息时定位到对应 run）。
  final Map<int, int> _runIdByChat = {};

  /// Coordinator 从 run 建立的第一刻就持有取消令牌。此前令牌直到
  /// AgentService.run 才创建，用户在上下文构建/自动压缩期间点击停止会丢失。
  final Map<int, CancelToken> _cancelTokenByChat = {};

  /// 完整 run（含取消落库和时间戳收尾）结束后完成，而非仅 Agent 内循环结束。
  final Map<int, Completer<void>> _settledByChat = {};

  /// 流式运行中的消息快照（chatId → 当前正在生成的 assistant 消息）。
  ///
  /// 流式中间态只存在于内存（迭代边界才落库），UI 切换到正在运行的对话时
  /// 需要据此恢复实时进度；run 结束时移除（届时 DB 已是最终态）。
  final Map<int, MessageEntity> _liveMessages = {};

  /// 用户点击思考卡片切换的展开状态(messageId → expanded)。
  ///
  /// 流式更新期间由 UI 层调用 [updateExpanded] 同步通知;`_consumeStream`
  /// 的 copyWith 链基于本地缓存 `current`,若不应用 override,下一次推理增量
  /// 会把用户刚展开的卡片重新折叠(思考未结束时"闪一下又关闭")。
  final Map<int, bool> _expandedOverrides = {};

  /// 记录用户对该消息的最新展开选择,流式增量更新据此保留状态。
  void updateExpanded(int messageId, bool expanded) {
    _expandedOverrides[messageId] = expanded;
  }

  /// 把 override 中用户最近的展开选择应用到流式更新前的消息上。
  MessageEntity _withExpandedOverride(MessageEntity message) {
    final override = _expandedOverrides[message.id];
    if (override == null || message.expanded == override) return message;
    return message.copyWith(expanded: override);
  }

  AgentRunCoordinator({
    required AgentService agentService,
    required ChatManageService manageService,
    required ChatMessageService messageService,
    required ChatService chatService,
    required MessageRepository messageRepo,
    required ModelRepository modelRepo,
    required SentinelRepository sentinelRepo,
    required ChatRepository chatRepo,
    required ChatSupportService supportService,
    required AgentSettings agentSettings,
    required PermissionService permissionService,
    required PermissionPrompt permissionPrompt,
    required ExperienceRepository experienceRepository,

    /// Agent 运行环境（GUI/TUI），由前端装配层注入；null = 不注入
    /// 运行时上下文提示（测试与未支持的环境）。
    RuntimeEnvironment? runtimeEnvironment,
  }) : _runtimeEnvironment = runtimeEnvironment,
       _agentService = agentService,
       _manageService = manageService,
       _messageService = messageService,
       _chatService = chatService,
       _messageRepo = messageRepo,
       _modelRepo = modelRepo,
       _sentinelRepo = sentinelRepo,
       _chatRepo = chatRepo,
       _supportService = supportService,
       _agentSettings = agentSettings,
       _permissionService = permissionService,
       _permissionPrompt = permissionPrompt,
       _experienceRepository = experienceRepository;

  /// 正在流式运行的对话 id 集合（多对话可同时运行）。
  Set<int> get streamingChatIds => _streamingChatIds;

  /// 指定对话是否正在流式运行。
  bool isStreamingChat(int chatId) => _streamingChatIds.contains(chatId);

  /// 等待指定对话的 run 完成后 resolve 的 Future（无运行返回 null）。
  Future<void>? settledOf(int chatId) {
    return _settledByChat[chatId]?.future;
  }

  /// 指定对话当前正在流式生成的消息快照；未在流式中返回 null。
  ///
  /// 用于 UI 切换到运行中的对话时恢复实时进度（DB 里只有迭代边界前的旧态）。
  MessageEntity? liveMessage(int chatId) => _liveMessages[chatId];

  Stream<RunEvent> send({
    required MessageEntity message,
    required ChatEntity chat,
    bool jsonMode = false,
  }) async* {
    final chatId = chat.id!;
    if (_runIdByChat.containsKey(chatId)) {
      throw StateError('Chat $chatId already has an active Agent run.');
    }

    final runId = ++_nextRunId;
    final cancelToken = CancelToken();
    final settled = Completer<void>();
    _streamingChatIds.add(chatId);
    _runIdByChat[chatId] = runId;
    _cancelTokenByChat[chatId] = cancelToken;
    _settledByChat[chatId] = settled;

    var userMessageStored = false;
    MessageEntity? assistantMessage;
    try {
      yield const RunIterationChanged(0);
      yield const RunToolNameChanged(null);

      // 1. 保存用户消息
      final id = await _messageRepo.storeMessage(message);
      final userMessage = message.copyWith(id: id);
      userMessageStored = true;
      yield RunMessageStored(userMessage);
      cancelToken.throwIfCancelled();

      // 首条用户消息时触发自动命名
      final isDefaultTitle = chat.title.isEmpty || chat.title == 'New Chat';
      if (isDefaultTitle) {
        final isFirst = await _messageService.isFirstUserMessage(chatId);
        cancelToken.throwIfCancelled();
        if (isFirst) {
          yield const RunAutoRename();
        }
      }

      // 2. 准备上下文
      final model = await _modelRepo.getModelById(chat.modelId);
      cancelToken.throwIfCancelled();
      if (model == null) {
        // 用户消息已落库；必须发错误事件，否则 UI 侧静默无响应
        yield RunError(
          'Model not found (id: ${chat.modelId}). '
          'Please select a valid model and retry.',
        );
        yield const RunOutcomeChanged(
          AgentRunOutcome(
            termination: AgentRunTermination.error,
            iterations: 0,
            error: 'model_not_found',
          ),
        );
        return;
      }

      final provider = await _supportService.getProviderForModel(
        model.providerId,
      );
      cancelToken.throwIfCancelled();
      if (provider == null) {
        yield RunError(
          'Provider not found for model "${model.modelId}". '
          'Please check provider configuration and retry.',
        );
        yield const RunOutcomeChanged(
          AgentRunOutcome(
            termination: AgentRunTermination.error,
            iterations: 0,
            error: 'provider_not_found',
          ),
        );
        return;
      }

      // 无 Sentinel 的直接对话使用独立记忆作用域，既不污染 Athena 的
      // 私有经验，也不落入 experience 工具的隐式 "default" 作用域。
      final sentinelKey = chat.hasSentinel
          ? chat.sentinelId.toString()
          : _directChatSentinelKey;

      // 2.5 每次顶层 send 都按当前任务重新检索。摘要只进入本次请求上下文，
      // 不落库，避免会话长期携带首个任务的过期记忆。
      final digestMessages = await MemoryDigest.messagesFor(
        repository: _experienceRepository,
        query: message.content,
        sentinelId: sentinelKey,
      );
      cancelToken.throwIfCancelled();

      final sentinel = await _sentinelRepo.getSentinelById(chat.sentinelId);
      cancelToken.throwIfCancelled();
      final includeReasoning = model.reasoning;
      final persistedMessages = await _messageService.buildMessages(
        chat: chat,
        sentinel: sentinel,
        includeReasoning: includeReasoning,
      );
      cancelToken.throwIfCancelled();
      // 兼容旧版：过滤曾落库的 stale digest，再追加当前任务的临时摘要。
      final wrappedMessages = MemoryDigest.replaceInContext(
        persistedMessages,
        digestMessages,
      );

      final compactedMessages = chat.retention == -1
          ? await _prepareMessagesWithCompact(
              chat: chat,
              sentinel: sentinel,
              wrappedMessages: wrappedMessages,
              contextWindow: model.contextWindow,
              currentTokens: chat.contextTokens,
              provider: provider,
              model: model,
              cancelToken: cancelToken,
            )
          : wrappedMessages;
      cancelToken.throwIfCancelled();

      final baseMessages = compactedMessages;

      // 3. 追加 assistant 占位消息
      assistantMessage = await _manageService.appendAssistantPlaceholder(
        chatId,
      );
      yield RunAssistantAppended(assistantMessage);
      cancelToken.throwIfCancelled();

      // 4. 启动 Agent 循环（runId 隔离，多个对话可同时运行）
      final agentStream = _agentService.run(
        runId: runId,
        chat: chat,
        provider: provider,
        model: model,
        baseMessages: baseMessages,
        evolutionPrompt: EvolutionPrompt.hint,
        runtimePrompt: _runtimeEnvironment == null
            ? null
            : runtimeContextPrompt(_runtimeEnvironment),
        sentinelId: sentinelKey,
        hasSentinelPrompt: sentinel != null && sentinel.prompt.isNotEmpty,
        maxIterations: _agentSettings.maxAgentIterations.value,
        permissionService: _permissionService,
        onPermission: (toolName, arguments) =>
            _askPermission(runId, chatId, toolName, arguments, cancelToken),
        jsonMode: jsonMode,
        cancelToken: cancelToken,
      );

      // 5. 消费流（取消/错误均在 _consumeStream 内部处理并落库）
      yield* _consumeStream(chat, assistantMessage, agentStream, cancelToken);

      await _manageService.updateChatTimestamp(chat);
      yield const RunListReload();
    } on CancelledException {
      // Agent 尚未启动时也要正常结束：补一条取消消息，避免用户消息后没有
      // assistant 收尾；不把用户主动停止显示为错误。
      var cancelledTarget = assistantMessage;
      var appended = false;
      if (cancelledTarget == null && userMessageStored) {
        cancelledTarget = await _manageService.appendAssistantPlaceholder(
          chatId,
        );
        appended = true;
      }
      if (cancelledTarget != null) {
        final cancelled = await _manageService.recordCancelledOnMessage(
          cancelledTarget,
        );
        _liveMessages[chatId] = cancelled;
        if (appended) {
          yield RunAssistantAppended(cancelled);
        } else {
          yield RunMessageUpdated(cancelled);
        }
      }
      yield const RunOutcomeChanged(
        AgentRunOutcome(
          termination: AgentRunTermination.cancelled,
          iterations: 0,
        ),
      );
      if (userMessageStored) {
        await _manageService.updateChatTimestamp(chat);
        yield const RunListReload();
      }
    } finally {
      if (_runIdByChat[chatId] == runId) {
        _streamingChatIds.remove(chatId);
        _runIdByChat.remove(chatId);
        _cancelTokenByChat.remove(chatId);
        _settledByChat.remove(chatId);
        _liveMessages.remove(chatId);
      }
      if (!settled.isCompleted) settled.complete();
      // 注意：_expandedOverrides 不在全局清理——finalize 时已按消息逐个
      // 移除，多 run 并发时全局 clear 会误删其他 run 的展开状态。
    }
  }

  /// 停止指定对话的 Agent 循环。
  void stop(int chatId) {
    final runId = _runIdByChat[chatId];
    _cancelTokenByChat[chatId]?.cancel();
    if (runId != null) _agentService.abort(runId);
  }

  /// 注入一条 steering 消息：当前轮工具执行完后、下一轮 LLM 调用前插入。
  void steer(int chatId, ChatMessage message) {
    final runId = _runIdByChat[chatId];
    if (runId != null) _agentService.steer(runId, message);
  }

  /// 注入一条 followUp 消息：Agent 停止后作为新用户输入继续运行。
  void followUp(int chatId, ChatMessage message) {
    final runId = _runIdByChat[chatId];
    if (runId != null) _agentService.followUp(runId, message);
  }

  /// 清空指定对话所有待注入消息队列。
  void clearQueues(int chatId) {
    final runId = _runIdByChat[chatId];
    if (runId != null) _agentService.clearQueues(runId);
  }

  // ─── 内部 ─────────────────────────────────────────────────

  /// 消费 Agent 流，产出 [RunEvent]。
  ///
  /// CancelledException 在内部捕获并落库后，流正常结束（不向外抛）。
  Stream<RunEvent> _consumeStream(
    ChatEntity chat,
    MessageEntity assistantMessage,
    Stream<AgentEvent> agentStream,
    CancelToken cancelToken,
  ) async* {
    var current = assistantMessage;
    var contentBuffer = StringBuffer();
    var reasoningBuffer = StringBuffer();
    var toolCallsJson = <Map<String, dynamic>>[];
    var toolResultsJson = <Map<String, dynamic>>[];
    var hasCompletedIteration = false;
    // beginNewIteration() 创建了新占位消息时置位，循环体底部据此先发出
    // RunAssistantAppended 把新卡片加入 UI 列表，否则仅有 id 不同的新
    // 消息走 RunMessageUpdated 时 replaceWhere 找不到匹配而被丢弃。
    var appendedNewMessage = false;
    var sawOutcome = false;
    var turns = 0;

    Stream<RunEvent> beginNewIteration() async* {
      // 迭代结束:清除 reasoning 标记(流式期间一直为 true),避免该卡片在
      // UI 上永久显示 Thinking;落库后通知 UI 刷新为已结束的思考状态。
      final hadReasoning = current.reasoning;
      if (hadReasoning) {
        current = current.copyWith(reasoning: false);
      }
      await _manageService.finalizeAssistantMessage(current);
      if (hadReasoning) yield RunMessageUpdated(current);
      // 该消息已 finalize,不再接收流式更新,清除其展开状态覆盖
      if (current.id != null) _expandedOverrides.remove(current.id);
      // 每条消息的思考折叠状态独立：新迭代的消息重置为默认折叠
      current = await _manageService.appendAssistantPlaceholder(chat.id!);
      contentBuffer = StringBuffer();
      reasoningBuffer = StringBuffer();
      toolCallsJson = [];
      toolResultsJson = [];
      hasCompletedIteration = false;
      appendedNewMessage = true;
    }

    try {
      await for (final event in agentStream) {
        cancelToken.throwIfCancelled();

        if (event is AgentTurnStartEvent) {
          turns++;
          // 迭代边界以 turnStart 为准：上一轮以工具结果结束（或截断保护
          // 置位）后，新一轮即使纯 tool_calls 开场（无文本/推理前缀）
          // 也必须切到新消息，否则会与上一轮合并进同一条消息。
          // beginNewIteration 内部会复位 hasCompletedIteration，
          // 与 reasoning/text 守卫不会重复触发。
          if (hasCompletedIteration) yield* beginNewIteration();
          yield RunIterationChanged(event.iteration);
        } else if (event is AgentToolExecutionStartEvent) {
          yield RunToolNameChanged(event.name);
        } else if (event is AgentReasoningEvent) {
          if (hasCompletedIteration) yield* beginNewIteration();
          reasoningBuffer.write(event.delta);
          // expanded 显式传当前值：流式更新不得覆盖用户已持久化的展开状态
          current = current.copyWith(
            reasoningContent: reasoningBuffer.toString(),
            reasoning: true,
            expanded: current.expanded,
            reasoningUpdatedAt: DateTime.now(),
          );
        } else if (event is AgentTextEvent) {
          if (hasCompletedIteration) yield* beginNewIteration();
          contentBuffer.write(event.delta);
          current = current.copyWith(content: contentBuffer.toString());
        } else if (event is AgentToolCallEvent) {
          yield RunToolNameChanged(event.name);
          toolCallsJson.add({
            'id': event.id,
            'name': event.name,
            'arguments': event.arguments,
          });
          current = current.copyWith(toolCalls: jsonEncode(toolCallsJson));
        } else if (event is AgentToolCallArgsEvent) {
          // 流式参数增量：按 id 找到已建卡的工具调用并追加 arguments
          final index = toolCallsJson.indexWhere((c) => c['id'] == event.id);
          if (index >= 0) {
            toolCallsJson[index] = {
              ...toolCallsJson[index],
              'arguments':
                  (toolCallsJson[index]['arguments'] as String) + event.delta,
            };
            current = current.copyWith(toolCalls: jsonEncode(toolCallsJson));
          }
        } else if (event is AgentToolResultEvent) {
          toolResultsJson.add({
            'id': event.id,
            'name': event.name,
            'result': event.result,
          });
          current = current.copyWith(toolResults: jsonEncode(toolResultsJson));
          hasCompletedIteration = true;
        } else if (event is AgentDoneEvent) {
          current = current.copyWith(content: event.content);
        } else if (event is AgentUsageEvent) {
          await _chatRepo.recordUsage(
            chat.id!,
            event.usage.totalTokens,
            event.usage.promptTokens,
            event.usage.cachedTokens ?? 0,
          );
          final updated = await _chatRepo.getChatById(chat.id!);
          if (updated != null) {
            yield RunUsageChanged(event.usage, updated);
          }
        } else if (event is AgentRunOutcomeEvent) {
          sawOutcome = true;
          yield RunOutcomeChanged(event.outcome);
        }

        if (appendedNewMessage) {
          _liveMessages[chat.id!] = current;
          yield RunAssistantAppended(current);
          appendedNewMessage = false;
        }
        // 应用用户最近的展开选择:增量 copyWith 链基于本地缓存 current,
        // 若不在此覆盖,刚展开的卡片会被下一次增量重新折叠
        current = _withExpandedOverride(current);
        _liveMessages[chat.id!] = current;
        yield RunMessageUpdated(current);
      }

      if (current.reasoning) {
        current = current.copyWith(reasoning: false);
        _liveMessages[chat.id!] = current;
        yield RunMessageUpdated(current);
      }

      // 防御：流正常结束但仍有已宣布未执行的工具调用（异常场景），
      // 合成结果保证 tool_calls 与 tool 消息闭合。
      current = _closeOpenToolCalls(
        current,
        'run ended before execution',
        toolCallsJson,
        toolResultsJson,
      );

      await _manageService.finalizeAssistantMessage(current);
      if (!sawOutcome) {
        yield RunOutcomeChanged(
          AgentRunOutcome(
            termination: AgentRunTermination.completed,
            iterations: turns,
          ),
        );
      }
    } on CancelledException {
      // 取消：保留已累积内容并落库。
      // 先为已宣布但未执行/未完成的工具调用合成结果——否则消息带有
      // tool_calls 却缺 tool 响应，下一轮 buildMessages 重建时
      // OpenAI 兼容端会 400 拒绝，该聊天将无法继续。
      current = _closeOpenToolCalls(
        current,
        'execution cancelled (run interrupted)',
        toolCallsJson,
        toolResultsJson,
      );
      final cancelled = await _manageService.recordCancelledOnMessage(current);
      _liveMessages[chat.id!] = cancelled;
      yield RunMessageUpdated(cancelled);
      if (!sawOutcome) {
        yield RunOutcomeChanged(
          AgentRunOutcome(
            termination: AgentRunTermination.cancelled,
            iterations: turns,
          ),
        );
      }
    } catch (e) {
      // 错误已记录到消息内容中；同样先闭合工具调用
      current = _closeOpenToolCalls(
        current,
        'run aborted by error: $e',
        toolCallsJson,
        toolResultsJson,
      );
      final failed = await _manageService.recordErrorOnMessage(current, e);
      _liveMessages[chat.id!] = failed;
      yield RunMessageUpdated(failed);
      if (!sawOutcome) {
        yield RunOutcomeChanged(
          AgentRunOutcome(
            termination: AgentRunTermination.error,
            iterations: turns,
            error: e.toString(),
          ),
        );
      }
      yield RunError(e.toString());
    }
  }

  /// 为已宣布但无对应结果的工具调用合成结果（追加到 [toolResultsJson]），
  /// 保证落库的 assistant 消息 tool_calls 永远被 tool 消息全覆盖。
  ///
  /// [toolCallsJson]/[toolResultsJson] 是 `_consumeStream` 的流式累积缓冲。
  MessageEntity _closeOpenToolCalls(
    MessageEntity msg,
    String reason,
    List<Map<String, dynamic>> toolCallsJson,
    List<Map<String, dynamic>> toolResultsJson,
  ) {
    final covered = toolResultsJson.map((t) => t['id']).toSet();
    var changed = false;
    for (final tc in toolCallsJson) {
      final id = tc['id'] as String;
      if (!covered.contains(id)) {
        toolResultsJson.add({
          'id': id,
          'name': tc['name'],
          'result': 'Error: $reason',
        });
        changed = true;
      }
    }
    if (!changed) return msg;
    return msg.copyWith(toolResults: jsonEncode(toolResultsJson));
  }

  // ─── Compact ───────────────────────────────────────────────

  Future<List<ChatMessage>> _prepareMessagesWithCompact({
    required ChatEntity chat,
    required SentinelEntity? sentinel,
    required List<ChatMessage> wrappedMessages,
    required int contextWindow,
    required int currentTokens,
    required ProviderEntity provider,
    required ModelEntity model,
    required CancelToken cancelToken,
  }) async {
    cancelToken.throwIfCancelled();
    if (contextWindow <= 0 ||
        currentTokens <= 0 ||
        currentTokens / contextWindow <= 0.8) {
      return wrappedMessages;
    }

    final systemMessages = <ChatMessage>[];
    final compressible = <ChatMessage>[];
    for (final m in wrappedMessages) {
      if (m is SystemMessage) {
        systemMessages.add(m);
      } else {
        compressible.add(m);
      }
    }

    final splitIndex = (compressible.length * 0.6).ceil();
    final toSummarize = compressible.sublist(0, splitIndex);
    final keep = compressible.sublist(splitIndex);

    final textToSummarize = _buildCompactText(toSummarize);

    try {
      final summary = await _chatService.complete(
        messages: [
          ChatMessage.system(_compactSystemPrompt),
          ChatMessage.user(textToSummarize),
        ],
        provider: provider,
        model: model,
        cancelSignal: cancelToken.whenCancelled,
      );
      cancelToken.throwIfCancelled();
      if (summary.isEmpty) return wrappedMessages;

      final chatId = chat.id!;

      final activeMessages = await _messageRepo.getMessagesByChatId(
        chatId,
        includeCompacted: false,
      );
      cancelToken.throwIfCancelled();

      final nonSystemEntities = <MessageEntity>[];
      for (final entity in activeMessages) {
        if (entity.role != 'system') {
          nonSystemEntities.add(entity);
        }
      }

      final compactSplit = (nonSystemEntities.length * 0.6).ceil();
      final toCompactIds = nonSystemEntities
          .sublist(0, compactSplit)
          .where((e) => e.id != null)
          .map((e) => e.id!)
          .toSet();

      final summaryEntity = MessageEntity(
        chatId: chatId,
        role: 'system',
        content: 'Previous conversation summary:\n$summary',
      );
      // 先落库摘要，再标记压缩：若 storeMessage 失败走 catch 降级全量，
      // 历史消息保持完整；若 markAsCompacted 失败（低概率），摘要已
      // 入库但消息未压缩——下次 run 会重复压缩一遍，数据不丢。
      final summaryId = await _messageRepo.storeMessage(summaryEntity);
      cancelToken.throwIfCancelled();
      final persistedSummary = summaryEntity.copyWith(id: summaryId);

      if (toCompactIds.isNotEmpty) {
        try {
          await _messageRepo.markAsCompacted(toCompactIds);
          cancelToken.throwIfCancelled();
        } catch (e) {
          cancelToken.throwIfCancelled();
          LoggerUtil.w(
            'Compact: markAsCompacted failed '
            '(${toCompactIds.length} ids), summary kept: $e',
          );
        }
      }

      LoggerUtil.i(
        'Compact: ${toCompactIds.length} messages compacted → '
        '${summary.length} char summary (msg #$summaryId), '
        'keeping ${keep.length} recent messages',
      );

      return [
        ...systemMessages,
        ChatMessage.system(persistedSummary.content),
        ...keep,
      ];
    } catch (e) {
      cancelToken.throwIfCancelled();
      LoggerUtil.w('Compact failed, falling back to full messages: $e');
      return wrappedMessages;
    }
  }

  String _buildCompactText(List<ChatMessage> messages) {
    final buf = StringBuffer();
    for (final m in messages) {
      if (m is SystemMessage) continue;
      final role = m is UserMessage
          ? 'User'
          : m is AssistantMessage
          ? 'Assistant'
          : m is ToolMessage
          ? 'Tool'
          : 'System';
      String content;
      if (m is ToolMessage) {
        content = 'tool_call_id=${m.toolCallId} result=${m.content}';
      } else if (m is AssistantMessage) {
        content = m.content ?? '';
      } else if (m is UserMessage) {
        content = '${m.content}';
      } else {
        continue;
      }
      if (content.isEmpty) continue;
      buf.writeln('$role: $content');
      buf.writeln();
    }
    return buf.toString();
  }

  static const _compactSystemPrompt =
      'Summarize the conversation below. Keep all key facts, decisions, '
      'code patterns, file paths, URLs, error messages, and data values. '
      'Be concise but do not omit anything that might be needed later. '
      'Output only the summary, no preamble.';

  // ─── 权限 ──────────────────────────────────────────────────

  Future<bool> _askPermission(
    int runId,
    int chatId,
    String toolName,
    String arguments,
    CancelToken cancelToken,
  ) async {
    final decision = await _permissionPrompt(
      chatId,
      toolName,
      arguments,
      cancelToken,
    );

    if (decision.approved) {
      Map<String, dynamic> args;
      try {
        args = jsonDecode(arguments) as Map<String, dynamic>;
      } catch (_) {
        args = {};
      }

      // 任何批准模式都先写入本 run 的会话级缓存（按 run 隔离）:
      // 同一 run 内不再重复弹窗，其他 run 不受影响
      await _permissionService.approveForSession(runId, toolName, args);

      if (decision.persistExact) {
        // "Always Allow" 落库:规则形态由 PermissionRule.forToolCall 决定
        // (shell 按动作+参数、复合命令拆子命令;文件走路径;web_fetch 走
        // origin;其余整工具放行)。
        final keyArg = _permissionService.primaryArg(toolName, args);
        for (final rule in PermissionRule.forToolCall(toolName, keyArg)) {
          await _permissionService.persistRule(rule);
        }
      }
    }

    return decision.approved;
  }
}
