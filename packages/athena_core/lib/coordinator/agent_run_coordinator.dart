import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/evolution/evolution_prompt.dart';
import 'package:athena_core/agent/evolution/memory_digest.dart';
import 'package:athena_core/agent/elicit/elicit_prompt.dart' show ElicitPrompt;
import 'package:athena_core/agent/permission/permission_prompt.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/permission/ai_permission_reviewer.dart';
import 'package:athena_core/agent/runtime_context.dart';
import 'package:athena_core/agent/tool/run_workspace.dart';
import 'package:athena_core/agent/run_outcome.dart';
import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/experience_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/service/chat_store_service.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_core/service/conversation_compactor.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_core/util/logger_util.dart';

/// UI 无关的 Agent run 编排层。
///
/// 职责：用户消息落库 → 构建上下文（含压缩）→ 追加占位消息 →
/// 消费 [AgentService] 事件流 → 流式更新 [MessageEntity] → 用量落库 →
/// 收尾/取消/错误落库。产出 [RunEvent] 纯数据流，无任何 UI 类型。
class AgentRunCoordinator {
  static const _directChatSentinelKey = 'direct';

  final AgentService _agentService;
  final ChatStoreService _manageService;
  final ChatMessageConverter _messageService;
  final ChatCompletionsService _chatService;
  final MessageRepository _messageRepo;
  final ModelRepository _modelRepo;
  final SentinelRepository _sentinelRepo;
  final ChatRepository _chatRepo;
  final ChatUpdateService _supportService;
  final AgentSettings _agentSettings;
  final PermissionService _permissionService;
  final PermissionPrompt _permissionPrompt;
  final ElicitPrompt? _elicitPrompt;

  /// 经验仓库：每次 run 开始时注入稳定的全量 active 经验目录。
  final ExperienceRepository _experienceRepository;

  /// Agent 运行环境（GUI/TUI）；null = 不注入运行时上下文提示。
  final RuntimeEnvironment? _runtimeEnvironment;

  /// 下一个 run 的自增 id（多 run 并发的隔离标识）。
  int _nextRunId = 0;

  /// 正在流式运行的对话 id 集合（支持多对话同时运行）。
  final Set<int> _streamingChatIds = {};

  /// chatId → runId 映射（取消/等待 settle/注入消息时定位到对应 run）。
  final Map<int, int> _runIdByChat = {};

  /// chatId → 本次 run 的工作文件夹（审批落库时按同一口径解析路径）。
  ///
  /// 按会话而非进程持有：多对话可同时运行，各自的工作文件夹不能串台。
  final Map<int, String?> _workspaceByChat = {};

  /// Coordinator 从 run 建立的第一刻就持有取消令牌。此前令牌直到
  /// AgentService.run 才创建，用户在上下文构建/自动压缩期间点击停止会丢失。
  final Map<int, CancelToken> _cancelTokenByChat = {};

  /// 完整 run（含取消落库和时间戳收尾）结束后完成，而非仅 Agent 内循环结束。
  final Map<int, Completer<void>> _settledByChat = {};

  /// 运行中输入队列（chatId → 待接续的落库消息）。
  ///
  /// 当前 run 结束后按序取出，以 [persistUserMessage: false] 自动接续为
  /// 新 run——事件流连续，UI 方无需感知 run 边界。
  final Map<int, List<MessageEntity>> _pendingInputs = {};

  /// 流式运行中的消息快照（chatId → 当前正在生成的 assistant 消息）。
  ///
  /// 流式中间态只存在于内存（迭代边界才落库），UI 切换到正在运行的对话时
  /// 需要据此恢复实时进度；run 结束时移除（届时 DB 已是最终态）。
  final Map<int, MessageEntity> _liveMessages = {};

  AgentRunCoordinator({
    required AgentService agentService,
    required ChatStoreService manageService,
    required ChatMessageConverter messageService,
    required ChatCompletionsService chatService,
    required MessageRepository messageRepo,
    required ModelRepository modelRepo,
    required SentinelRepository sentinelRepo,
    required ChatRepository chatRepo,
    required ChatUpdateService supportService,
    required AgentSettings agentSettings,
    required PermissionService permissionService,
    required PermissionPrompt permissionPrompt,

    /// 提问回调（「你要哪个」）。null = 本端没有提问 UI，
    /// ask_user_question 会降级为「按假定继续」。
    ElicitPrompt? elicitPrompt,
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
       _elicitPrompt = elicitPrompt,
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

    /// 接续 run 传入 false：消息已在 [queueInput] 落库，跳过存储、直接发事件。
    bool persistUserMessage = true,
  }) async* {
    final chatId = chat.id!;
    if (_runIdByChat.containsKey(chatId)) {
      throw StateError('Chat $chatId already has an active Agent run.');
    }

    final runId = ++_nextRunId;
    final cancelToken = CancelToken();
    final settled = Completer<void>();
    // 会话工作文件夹：本次 run 的路径解析基准。目录已失效（删除/改名）
    // 时降级为「不指定」并记日志，不让工具在每一条命令上报错。
    final workspace = _resolveWorkspace(chat);
    _streamingChatIds.add(chatId);
    _runIdByChat[chatId] = runId;
    _cancelTokenByChat[chatId] = cancelToken;
    _settledByChat[chatId] = settled;
    _workspaceByChat[chatId] = workspace;

    var userMessageStored = false;
    MessageEntity? assistantMessage;
    try {
      yield const RunIterationChanged(0);
      yield const RunToolNameChanged(null);

      // 1. 保存用户消息（接续 run 的消息已在 queueInput 落库，跳过存储）
      MessageEntity userMessage;
      if (persistUserMessage) {
        final id = await _messageRepo.storeMessage(message);
        userMessage = message.copyWith(id: id);
      } else {
        userMessage = message;
      }
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

      // 2.5 注入当前 Sentinel 的稳定全量 active Memory 目录。内容不依赖
      // 当前用户消息；只有经验新增、更新或归档时才变化，保护 prompt cache。
      // 目录只进入本次请求上下文，不落库为聊天历史。
      final digestMessages = await MemoryDigest.messagesForSentinel(
        repository: _experienceRepository,
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
      // 稳定目录只拼入本次请求，不参与消息持久化。
      final baseMessages = [...persistedMessages, ...?digestMessages];

      // Read original messages, including compacted user instructions. Generated
      // summaries, skills, memories and tool outputs cannot grant authorization.
      final approvalMode = _agentSettings.approvalMode.value;
      final reviewContext = approvalMode == ApprovalMode.aiReview
          ? PermissionReviewContext.fromMessages(
              await _messageRepo.getMessagesByChatId(chatId),
            )
          : null;
      cancelToken.throwIfCancelled();

      // 3. 追加 assistant 占位消息
      assistantMessage = await _manageService.appendAssistantPlaceholder(
        chatId,
      );
      yield RunAssistantAppended(assistantMessage);
      cancelToken.throwIfCancelled();

      // 4. 启动 Agent 循环（runId 隔离，多个对话可同时运行）
      final compactor = ConversationCompactor(
        repository: _messageRepo,
        converter: _messageService,
        chatService: _chatService,
      );
      final agentStream = _agentService.run(
        runId: runId,
        chat: chat,
        provider: provider,
        model: model,
        baseMessages: baseMessages,
        evolutionPrompt: EvolutionPrompt.hint,
        runtimePrompt: _runtimeEnvironment == null
            ? null
            : runtimeContextPrompt(_runtimeEnvironment, workspace: workspace),
        // turnStart has finalized the preceding iteration before this callback
        // runs. Exclude the new placeholder and queued, not-yet-sent inputs.
        onCompact: (request) => compactor.compact(
          request: request,
          chatId: chatId,
          runId: runId,
          // The placeholder bounds this snapshot, including inputs queued
          // while the repository read is still in flight.
          beforeMessageId: _liveMessages[chatId]!.id!,
          excludedMessageIds: {
            for (final pending in _pendingInputs[chatId] ?? <MessageEntity>[])
              pending.id!,
          },
          provider: provider,
          model: model,
        ),
        sentinelId: sentinelKey,
        hasSentinelPrompt: sentinel != null && sentinel.prompt.isNotEmpty,
        maxIterations: _agentSettings.maxAgentIterations.value,
        permissionService: _permissionService,
        permissionReviewContext: reviewContext,
        bypassPermissions: approvalMode == ApprovalMode.bypass,
        workspace: workspace,
        onPermission: (toolName, arguments) =>
            _askPermission(runId, chatId, toolName, arguments, cancelToken),
        onElicit: _elicitPrompt,
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
        _workspaceByChat.remove(chatId);
      }
      if (!settled.isCompleted) settled.complete();
    }

    // ─── 接续排队输入 ───
    // 本 run 状态已在 finally 清理，递归 send 不会触发 already-active 保护；
    // 事件流连续，UI 的一次 sendMessage await 覆盖整条 run 链。
    // stop（取消）后同样接续：打断只作用于当前轮，排队消息照常进入下一轮。
    final pending = _pendingInputs[chatId];
    if (pending != null && pending.isNotEmpty) {
      if (await _chatRepo.getChatById(chatId) != null) {
        final next = pending.removeAt(0);
        yield* send(
          message: next,
          chat: chat,
          jsonMode: jsonMode,
          persistUserMessage: false,
        );
      } else {
        // 删除竞态防护：chat 已删除则丢弃排队消息
        _pendingInputs.remove(chatId);
      }
    }
  }

  /// 停止指定对话的 Agent 循环。
  void stop(int chatId) {
    final runId = _runIdByChat[chatId];
    _cancelTokenByChat[chatId]?.cancel();
    if (runId != null) _agentService.abort(runId);
  }

  /// 运行中输入：落库并排队，当前 run 结束后自动接续为新 run。
  ///
  /// 返回落库后的消息（调用方据此立即显示）；无活跃 run 时返回 null，
  /// 调用方应走 [send] 正常发送。
  Future<MessageEntity?> queueInput(int chatId, MessageEntity message) async {
    if (!_runIdByChat.containsKey(chatId)) return null;
    final id = await _messageRepo.storeMessage(message);
    final stored = message.copyWith(id: id);
    final pending = _pendingInputs.putIfAbsent(chatId, () => []);
    pending.add(stored);
    // 竞态：storeMessage 落库期间 run 可能已结束（接续检查已执行过），
    // 队列里这条消息将无人消费——撤销落库并返回 null，交由调用方
    // 等待收尾后走 send 正常路径（该路径只落库一次）。
    if (!_runIdByChat.containsKey(chatId)) {
      pending.remove(stored);
      if (pending.isEmpty) _pendingInputs.remove(chatId);
      await _messageRepo.deleteMessages(stored.chatId, {stored.id!});
      return null;
    }
    return stored;
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
        // Terminal compaction events must reach the UI even after Stop. The
        // placeholder becomes the step; the following answer gets a new ID.
        if (event is AgentCompactionEvent) {
          current = event.step.toMessage();
          _liveMessages[chat.id!] = current;
          yield RunCompactionChanged(event.step);
          if (event.step.isTerminal) {
            current = await _manageService.appendAssistantPlaceholder(chat.id!);
            _liveMessages[chat.id!] = current;
            yield RunAssistantAppended(current);
          }
          continue;
        }
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
          current = current.copyWith(
            reasoningContent: reasoningBuffer.toString(),
            reasoning: true,
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
            'modelResult': event.modelResult ?? event.result,
            if (event.outputId != null) 'outputId': event.outputId,
            'status': event.status.name,
            if (event.approvalReview != null)
              'approvalReview': event.approvalReview,
          });
          current = current.copyWith(toolResults: jsonEncode(toolResultsJson));
          hasCompletedIteration = true;
        } else if (event is AgentDoneEvent) {
          current = current.copyWith(content: event.content);
        } else if (event is AgentUsageEvent) {
          await _chatRepo.recordUsage(
            chat.id!,
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
      // A failed append after compaction still leaves current pointing at the
      // completed step. Report the run error without changing its summary.
      if (current.role != 'compaction') {
        current = _closeOpenToolCalls(
          current,
          'run aborted by error: $e',
          toolCallsJson,
          toolResultsJson,
        );
        final failed = await _manageService.recordErrorOnMessage(current, e);
        _liveMessages[chat.id!] = failed;
        yield RunMessageUpdated(failed);
      }
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

  // ─── 权限 ──────────────────────────────────────────────────

  /// 解析本次 run 的工作文件夹（已校验存在的绝对路径）。
  ///
  /// 目录不存在或不可访问时降级为 null（= 不指定）并记日志：工作文件夹是
  /// 用户随时可能删除的外部状态，不能让它在每次工具调用上报错。
  String? _resolveWorkspace(ChatEntity chat) {
    final path = chat.workspacePath;
    if (path == null || path.isEmpty) return null;
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        LoggerUtil.w('Chat ${chat.id} workspace not found: $path');
        return null;
      }
      return dir.absolute.path;
    } on FileSystemException catch (e) {
      LoggerUtil.w('Chat ${chat.id} workspace unavailable: $path ($e)');
      return null;
    }
  }

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
    if (cancelToken.isCancelled) return false;

    if (decision.approved) {
      Map<String, dynamic> args;
      try {
        args = jsonDecode(arguments) as Map<String, dynamic>;
      } catch (_) {
        args = {};
      }

      // 与执行侧（executeToolCallInternal）同一解析口径：这里的 args 来自模型
      // 原始 JSON（相对路径），若直接用来记授权与落规则，会话级授权键与
      // 持久规则的路径都会与执行时算出的绝对路径对不上——表现为「同一 run 内
      // 已批准仍重复弹窗」与「始终允许」失效。
      args = applyRunWorkspace(toolName, args, _workspaceByChat[chatId]);

      // 任何批准模式都先写入本 run 的会话级缓存（按 run 隔离）:
      // 同一 run 内不再重复弹窗，其他 run 不受影响
      await _permissionService.approveForSession(runId, toolName, args);

      if (decision.persistExact) {
        // "Always Allow" 落库:规则形态由 PermissionRule.forToolCall 决定
        // (shell 落整条命令的 exact;文件走路径;web_fetch 走 origin;
        // 其余整工具放行)。
        final keyArg = _permissionService.primaryArg(toolName, args);
        for (final rule in PermissionRule.forToolCall(toolName, keyArg)) {
          await _permissionService.persistRule(rule);
        }
      }
    }

    return decision.approved;
  }
}
