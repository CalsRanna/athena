import 'dart:async';
import 'dart:convert';

import 'package:athena/agent/agent_service.dart';
import 'package:athena/agent/cancel_token.dart';
import 'package:athena/agent/evolution/evolution_prompt.dart';
import 'package:athena/agent/permission/permission_rule.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/agent/skill/skill_registry.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/model/token_usage.dart';
import 'package:athena/repository/chat_repository.dart';
import 'package:athena/repository/message_repository.dart';
import 'package:athena/repository/model_repository.dart';
import 'package:athena/repository/sentinel_repository.dart';
import 'package:athena/service/chat_manage_service.dart';
import 'package:athena/service/chat_message_service.dart';
import 'package:athena/service/chat_service.dart';
import 'package:athena/service/chat_support_service.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/router/router.dart';
import 'package:athena/util/logger_util.dart';
import 'package:athena/util/tool_args_formatter.dart';
import 'package:athena/widget/permission_dialog.dart';
import 'package:athena/widget/skill_trust_dialog.dart';
import 'package:openai_dart/openai_dart.dart';

// ─── Stream 事件 ───────────────────────────────────────────────

sealed class AgentStreamEvent {
  const AgentStreamEvent();
}

class StreamMessageStored extends AgentStreamEvent {
  final MessageEntity message;
  const StreamMessageStored(this.message);
}

class StreamAssistantAppended extends AgentStreamEvent {
  final MessageEntity message;
  const StreamAssistantAppended(this.message);
}

class StreamMessageUpdated extends AgentStreamEvent {
  final MessageEntity message;
  const StreamMessageUpdated(this.message);
}

class StreamIterationChanged extends AgentStreamEvent {
  final int iteration;
  const StreamIterationChanged(this.iteration);
}

class StreamToolNameChanged extends AgentStreamEvent {
  final String? toolName;
  const StreamToolNameChanged(this.toolName);
}

class StreamUsageChanged extends AgentStreamEvent {
  final TokenUsage usage;
  final ChatEntity chat;
  const StreamUsageChanged(this.usage, this.chat);
}

class StreamAutoRename extends AgentStreamEvent {
  const StreamAutoRename();
}

class StreamListReload extends AgentStreamEvent {
  const StreamListReload();
}

class StreamError extends AgentStreamEvent {
  final String message;
  const StreamError(this.message);
}

// ─── Delegate ───────────────────────────────────────────────────

class AgentStreamDelegate {
  final AgentService _agentService;
  final ChatManageService _manageService;
  final ChatMessageService _messageService;
  final ChatService _chatService;
  final MessageRepository _messageRepo;
  final ModelRepository _modelRepo;
  final SentinelRepository _sentinelRepo;
  final ChatRepository _chatRepo;
  final ChatSupportService _supportService;
  final SettingViewModel _settingViewModel;
  final PermissionService _permissionService;
  final SkillRegistry _skillRegistry;

  CancelToken? _cancelToken;
  int? _streamingChatId;
  Completer<void>? _settled;
  bool _skillTrustPrompted = false;

  AgentStreamDelegate({
    required AgentService agentService,
    required ChatManageService manageService,
    required ChatMessageService messageService,
    required ChatService chatService,
    required MessageRepository messageRepo,
    required ModelRepository modelRepo,
    required SentinelRepository sentinelRepo,
    required ChatRepository chatRepo,
    required ChatSupportService supportService,
    required SettingViewModel settingViewModel,
    required PermissionService permissionService,
    required SkillRegistry skillRegistry,
  })  : _agentService = agentService,
        _manageService = manageService,
        _messageService = messageService,
        _chatService = chatService,
        _messageRepo = messageRepo,
        _modelRepo = modelRepo,
        _sentinelRepo = sentinelRepo,
        _chatRepo = chatRepo,
        _supportService = supportService,
        _settingViewModel = settingViewModel,
        _permissionService = permissionService,
        _skillRegistry = skillRegistry;

  int? get streamingChatId => _streamingChatId;
  Future<void>? get settled => _settled?.future;

  Stream<AgentStreamEvent> send({
    required MessageEntity message,
    required ChatEntity chat,
  }) async* {
    await _maybePromptSkillTrust();

    _cancelToken = CancelToken();
    _streamingChatId = chat.id;
    _settled = Completer<void>();
    yield const StreamIterationChanged(0);
    yield const StreamToolNameChanged(null);

    try {
      // 1. 保存用户消息
      final id = await _messageRepo.storeMessage(message);
      final userMessage = message.copyWith(id: id);
      yield StreamMessageStored(userMessage);

      // 首条用户消息时触发自动命名
      final isDefaultTitle = chat.title.isEmpty || chat.title == 'New Chat';
      if (isDefaultTitle) {
        if (await _messageService.isFirstUserMessage(chat.id!)) {
          yield const StreamAutoRename();
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
      yield StreamAssistantAppended(assistantMessage);

      // 4. 启动 Agent 循环
      final agentStream = _agentService.run(
        chat: chat,
        provider: provider,
        model: model,
        baseMessages: compactedMessages,
        evolutionPrompt: EvolutionPrompt.hint,
        sentinelId: chat.sentinelId.toString(),
        maxIterations: _settingViewModel.maxAgentIterations.value,
        auxiliaryModel: _settingViewModel.auxiliaryModel.value,
        auxiliaryModelProvider:
            _settingViewModel.auxiliaryModelProvider.value,
        permissionService: _permissionService,
        cancelToken: _cancelToken,
        onPermission: (toolName, arguments) =>
            _askPermission(toolName, arguments),
      );

      // 5. 消费流（取消/错误均在 _consumeStream 内部处理并落库）
      yield* _consumeStream(chat, assistantMessage, agentStream);

      await _manageService.updateChatTimestamp(chat);
      yield const StreamListReload();
    } finally {
      if (_settled != null && !_settled!.isCompleted) {
        _settled!.complete();
      }
      _cancelToken = null;
      _streamingChatId = null;
      _settled = null;
    }
  }

  void stop() {
    _cancelToken?.cancel();
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
    final trusted = await showSkillTrustDialog(
      projectDir: dir,
      skillNames: names,
    );
    if (trusted) {
      await _skillRegistry.trustCurrentProject();
    }
  }

  /// 消费 Agent 流，产出 [AgentStreamEvent]。
  ///
  /// CancelledException 在内部捕获并落库后，流正常结束（不向外抛）。
  Stream<AgentStreamEvent> _consumeStream(
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

    Future<void> beginNewIteration() async {
      await _manageService.finalizeAssistantMessage(current);
      current = await _manageService.appendAssistantPlaceholder(chat.id!);
      contentBuffer = StringBuffer();
      reasoningBuffer = StringBuffer();
      toolCallsJson = [];
      toolResultsJson = [];
      hasCompletedIteration = false;
    }

    try {
      await for (final event in agentStream) {
        _cancelToken?.throwIfCancelled();

        if (event is AgentReasoningEvent) {
          if (hasCompletedIteration) await beginNewIteration();
          reasoningBuffer.write(event.delta);
          current = current.copyWith(
            reasoningContent: reasoningBuffer.toString(),
            reasoning: true,
            reasoningUpdatedAt: DateTime.now(),
          );
        } else if (event is AgentTextEvent) {
          if (hasCompletedIteration) await beginNewIteration();
          contentBuffer.write(event.delta);
          current = current.copyWith(content: contentBuffer.toString());
        } else if (event is AgentToolCallEvent) {
          yield StreamToolNameChanged(event.name);
          toolCallsJson.add({
            'id': event.id,
            'name': event.name,
            'arguments': event.arguments,
          });
          current = current.copyWith(toolCalls: jsonEncode(toolCallsJson));
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
            yield StreamUsageChanged(event.usage, updated);
          }
        }

        yield StreamMessageUpdated(current);
      }

      if (reasoningBuffer.isNotEmpty) {
        current = current.copyWith(reasoning: false);
        yield StreamMessageUpdated(current);
      }

      await _manageService.finalizeAssistantMessage(current);
    } on CancelledException {
      // 取消：保留已累积内容并落库
      yield StreamMessageUpdated(
        await _manageService.recordCancelledOnMessage(current),
      );
    } catch (e) {
      // 错误已记录到消息内容中
      yield StreamMessageUpdated(
        await _manageService.recordErrorOnMessage(current, e),
      );
      yield StreamError(e.toString());
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

    final auxModel = _settingViewModel.auxiliaryModel.value;
    final auxProvider = _settingViewModel.auxiliaryModelProvider.value;

    try {
      final summary = await _chatService.complete(
        messages: [
          ChatMessage.system(_compactSystemPrompt),
          ChatMessage.user(textToSummarize),
        ],
        provider: auxProvider ?? provider,
        model: auxModel ?? model,
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
    Map<String, dynamic> args;
    try {
      args = jsonDecode(arguments) as Map<String, dynamic>;
    } catch (_) {
      args = {};
    }

    final description = formatToolArgsForApproval(toolName, arguments);

    final keyArg = _permissionService.primaryArg(toolName, args);
    final dialogFuture = showPermissionDialog(
      toolName: toolName,
      description: description,
      keyArg: keyArg ?? '',
    );

    final result = await Future.any<PermissionDialogResult>([
      dialogFuture,
      _cancelToken!.whenCancelled.then((_) {
        final nav = router.navigatorKey.currentState;
        if (nav?.canPop() ?? false) nav!.pop();
        return const PermissionDialogResult(approved: false);
      }),
    ]);

    if (result.approved) {
      if (result.persistExact) {
        await _permissionService.persistRule(PermissionRule(
          tool: toolName,
          pattern: keyArg ?? '',
        ));
      } else if (result.persistPattern != null) {
        await _permissionService.persistRule(PermissionRule(
          tool: toolName,
          pattern: result.persistPattern!,
        ));
      }
    }

    return result.approved;
  }
}
