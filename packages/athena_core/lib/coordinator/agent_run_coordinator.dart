import 'dart:async';
import 'dart:convert';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/evolution/evolution_prompt.dart';
import 'package:athena_core/agent/permission/command_analyzer.dart';
import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
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

/// 权限审批回调：由各 App 注入（GUI=对话框，TUI=stdin 提示）。
typedef PermissionPrompt = Future<PermissionDecision> Function(
  String toolName,
  String arguments,
);

/// Skill 信任回调：由各 App 注入（GUI=对话框，TUI=stdin 提示）。
typedef SkillTrustPrompt = Future<bool> Function(
  String dir,
  List<String> names,
);

/// UI 无关的 Agent run 编排层。
///
/// 职责：用户消息落库 → 构建上下文（含压缩）→ 追加占位消息 →
/// 消费 [AgentService] 事件流 → 流式更新 [MessageEntity] → 用量落库 →
/// 收尾/取消/错误落库。产出 [RunEvent] 纯数据流，无任何 UI 类型。
class AgentRunCoordinator {
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
  final SkillRegistry _skillRegistry;
  final PermissionPrompt _permissionPrompt;
  final SkillTrustPrompt _skillTrustPrompt;

  int? _streamingChatId;
  bool _skillTrustPrompted = false;

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
    required SkillRegistry skillRegistry,
    required PermissionPrompt permissionPrompt,
    required SkillTrustPrompt skillTrustPrompt,
  })  : _agentService = agentService,
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
        _skillRegistry = skillRegistry,
        _permissionPrompt = permissionPrompt,
        _skillTrustPrompt = skillTrustPrompt;

  int? get streamingChatId => _streamingChatId;
  Future<void>? get settled => _agentService.settled;

  Stream<RunEvent> send({
    required MessageEntity message,
    required ChatEntity chat,
    bool jsonMode = false,
  }) async* {
    await _maybePromptSkillTrust();

    _streamingChatId = chat.id;
    yield const RunIterationChanged(0);
    yield const RunToolNameChanged(null);

    try {
      // 1. 保存用户消息
      final id = await _messageRepo.storeMessage(message);
      final userMessage = message.copyWith(id: id);
      yield RunMessageStored(userMessage);

      // 首条用户消息时触发自动命名
      final isDefaultTitle = chat.title.isEmpty || chat.title == 'New Chat';
      if (isDefaultTitle) {
        if (await _messageService.isFirstUserMessage(chat.id!)) {
          yield const RunAutoRename();
        }
      }

      // 2. 准备上下文
      final model = await _modelRepo.getModelById(chat.modelId);
      if (model == null) return;

      final provider = await _supportService.getProviderForModel(model.providerId);
      if (provider == null) return;

      final sentinel = await _sentinelRepo.getSentinelById(chat.sentinelId);
      final includeReasoning = model.reasoning;
      final wrappedMessages = await _messageService.buildMessages(
        chat: chat,
        sentinel: sentinel,
        includeReasoning: includeReasoning,
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
            )
          : wrappedMessages;

      // 3. 追加 assistant 占位消息
      final assistantMessage = await _manageService.appendAssistantPlaceholder(
        chat.id!,
      );
      yield RunAssistantAppended(assistantMessage);

      // 4. 启动 Agent 循环
      final agentStream = _agentService.run(
        chat: chat,
        provider: provider,
        model: model,
        baseMessages: compactedMessages,
        evolutionPrompt: EvolutionPrompt.hint,
        sentinelId: chat.sentinelId.toString(),
        maxIterations: _agentSettings.maxAgentIterations.value,
        permissionService: _permissionService,
        onPermission: (toolName, arguments) =>
            _askPermission(toolName, arguments),
        jsonMode: jsonMode,
      );

      // 5. 消费流（取消/错误均在 _consumeStream 内部处理并落库）
      yield* _consumeStream(chat, assistantMessage, agentStream);

      await _manageService.updateChatTimestamp(chat);
      yield const RunListReload();
    } finally {
      _streamingChatId = null;
      _expandedOverrides.clear();
    }
  }

  void stop() {
    _agentService.abort();
  }

  /// 注入一条 steering 消息：当前轮工具执行完后、下一轮 LLM 调用前插入。
  void steer(ChatMessage message) {
    _agentService.steer(message);
  }

  /// 注入一条 followUp 消息：Agent 停止后作为新用户输入继续运行。
  void followUp(ChatMessage message) {
    _agentService.followUp(message);
  }

  /// 清空所有待注入消息队列。
  void clearQueues() {
    _agentService.clearQueues();
  }

  // ─── 内部 ─────────────────────────────────────────────────

  Future<void> _maybePromptSkillTrust() async {
    if (_skillTrustPrompted) return;
    if (!_skillRegistry.hasPendingProjectSkills) return;
    _skillTrustPrompted = true;

    final dir = _skillRegistry.pendingProjectDir;
    if (dir == null) return;

    final names =
        _skillRegistry.pendingProjectSkills.map((s) => s.name).toList();
    final trusted = await _skillTrustPrompt(dir, names);
    if (trusted) {
      await _skillRegistry.trustCurrentProject();
    }
  }

  /// 消费 Agent 流，产出 [RunEvent]。
  ///
  /// CancelledException 在内部捕获并落库后，流正常结束（不向外抛）。
  Stream<RunEvent> _consumeStream(
    ChatEntity chat,
    MessageEntity assistantMessage,
    Stream<AgentEvent> agentStream,
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
        _agentService.currentCancelToken?.throwIfCancelled();

        if (event is AgentTurnStartEvent) {
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
          final index =
              toolCallsJson.indexWhere((c) => c['id'] == event.id);
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
          final updated =
              await _chatRepo.getChatById(chat.id!);
          if (updated != null) {
            yield RunUsageChanged(event.usage, updated);
          }
        }

        if (appendedNewMessage) {
          yield RunAssistantAppended(current);
          appendedNewMessage = false;
        }
        // 应用用户最近的展开选择:增量 copyWith 链基于本地缓存 current,
        // 若不在此覆盖,刚展开的卡片会被下一次增量重新折叠
        current = _withExpandedOverride(current);
        yield RunMessageUpdated(current);
      }

      if (current.reasoning) {
        current = current.copyWith(reasoning: false);
        yield RunMessageUpdated(current);
      }

      await _manageService.finalizeAssistantMessage(current);
    } on CancelledException {
      // 取消：保留已累积内容并落库
      yield RunMessageUpdated(
        await _manageService.recordCancelledOnMessage(current),
      );
    } catch (e) {
      // 错误已记录到消息内容中
      yield RunMessageUpdated(
        await _manageService.recordErrorOnMessage(current, e),
      );
      yield RunError(e.toString());
    }
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
  }) async {
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
      );
      if (summary.isEmpty) return wrappedMessages;

      final chatId = chat.id!;

      final activeMessages =
          await _messageRepo.getMessagesByChatId(chatId, includeCompacted: false);

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

      if (toCompactIds.isNotEmpty) {
        await _messageRepo.markAsCompacted(toCompactIds);
      }

      final summaryEntity = MessageEntity(
        chatId: chatId,
        role: 'system',
        content: 'Previous conversation summary:\n$summary',
      );
      final summaryId = await _messageRepo.storeMessage(summaryEntity);
      final persistedSummary = summaryEntity.copyWith(id: summaryId);

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
    String toolName,
    String arguments,
  ) async {
    final decision = await _permissionPrompt(toolName, arguments);

    if (decision.approved) {
      Map<String, dynamic> args;
      try {
        args = jsonDecode(arguments) as Map<String, dynamic>;
      } catch (_) {
        args = {};
      }

      // 任何批准模式都先写入会话级缓存:同一 run 内不再重复弹窗
      await _permissionService.approveForSession(toolName, args);

      if (decision.persistExact) {
        // "Always Allow" 对 shell 命令存动作级规则(如 git push → action git,
        // pattern push*),这样记住后同类调用真正放行;非 shell 存精确路径/URL。
        final keyArg = _permissionService.primaryArg(toolName, args);
        final isShell = toolName == 'bash' || toolName == 'powershell';
        if (isShell && keyArg != null) {
          final parsed = CommandAnalyzer.parseRulePattern('$keyArg *');
          await _permissionService.persistRule(PermissionRule(
            tool: toolName,
            action: parsed.action,
            pattern: parsed.pattern,
          ));
        } else {
          await _permissionService.persistRule(PermissionRule(
            tool: toolName,
            pattern: keyArg ?? '',
          ));
        }
      }
    }

    return decision.approved;
  }
}
