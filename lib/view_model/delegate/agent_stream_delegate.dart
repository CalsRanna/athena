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

/// Agent 流式交互的委托。
///
/// 不持有任何 Signal。通过回调将流事件传回 ChatViewModel。
/// 每次调用 [send] 创建内部控制状态，结束后自动清理。
class AgentStreamDelegate {
  final AgentService _agentService;
  final ChatManageService _manageService;
  final ChatMessageService _messageService;
  final ChatService _chatService;
  final MessageRepository _messageRepo;
  final ModelRepository _modelRepo;
  final SentinelRepository _sentinelRepo;
  final ChatSupportService _supportService;
  final SettingViewModel _settingViewModel;
  final PermissionService _permissionService;
  final SkillRegistry _skillRegistry;

  CancelToken? _cancelToken;
  int? _streamingChatId;
  Completer<void>? _settled;
  MessageEntity? _latestMessage;
  bool _skillTrustPrompted = false;

  AgentStreamDelegate({
    required AgentService agentService,
    required ChatManageService manageService,
    required ChatMessageService messageService,
    required ChatService chatService,
    required MessageRepository messageRepo,
    required ModelRepository modelRepo,
    required SentinelRepository sentinelRepo,
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
        _supportService = supportService,
        _settingViewModel = settingViewModel,
        _permissionService = permissionService,
        _skillRegistry = skillRegistry;

  int? get streamingChatId => _streamingChatId;
  Future<void>? get settled => _settled?.future;

  /// 发送消息的完整 Agent 循环。
  ///
  /// 通过回调将事件传回 ChatViewModel：
  /// - [onUserMessageStored]：用户消息入库后
  /// - [onAssistantAppended]：assistant 占位消息追加后
  /// - [onMessageUpdated]：流式过程中消息内容更新
  /// - [onIterationChanged]：迭代轮数变化
  /// - [onToolNameChanged]：当前工具名变化
  /// - [onListReload]：完成后重新加载会话列表
  /// - [onAutoRename]：触发自动重命名（首条消息时）
  Future<void> send({
    required MessageEntity message,
    required ChatEntity chat,
    required void Function(MessageEntity) onUserMessageStored,
    required void Function(MessageEntity) onAssistantAppended,
    required void Function(MessageEntity) onMessageUpdated,
    required void Function(int) onIterationChanged,
    required void Function(String?) onToolNameChanged,
    required Future<void> Function() onListReload,
    required Future<void> Function() onAutoRename,
    required Future<void> Function(TokenUsage, ChatEntity) onUsageChanged,
  }) async {
    await _maybePromptSkillTrust();

    _cancelToken = CancelToken();
    _streamingChatId = chat.id;
    _settled = Completer<void>();
    _latestMessage = null;
    onIterationChanged(0);
    onToolNameChanged(null);

    MessageEntity? assistantMessage;

    try {
      // 1. 保存用户消息
      final id = await _messageRepo.storeMessage(message);
      final userMessage = message.copyWith(id: id);
      onUserMessageStored(userMessage);

      // 首条用户消息时触发自动命名
      final isDefaultTitle = chat.title.isEmpty || chat.title == 'New Chat';
      if (isDefaultTitle) {
        if (await _messageService.isFirstUserMessage(chat.id!)) {
          unawaited(onAutoRename());
        }
      }

      // 2. 准备上下文
      final model = await _modelRepo.getModelById(chat.modelId);
      if (model == null) return;

      final provider = await _supportService.getProviderForModel(
        model.providerId,
      );
      if (provider == null) return;

      final sentinel = await _sentinelRepo.getSentinelById(chat.sentinelId);
      final includeReasoning =
          model.modelId.toLowerCase().contains('deepseek');
      final wrappedMessages = await _messageService.buildMessages(
        chat: chat,
        sentinel: sentinel,
        includeReasoning: includeReasoning,
      );

      // 2.5. Auto 模式下，若上下文接近窗口上限则触发 compact
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
      assistantMessage = await _manageService.appendAssistantPlaceholder(
        chat.id!,
      );
      onAssistantAppended(assistantMessage);

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

      // 5. 消费流
      assistantMessage = await _consumeStream(
        chat: chat,
        assistantMessage: assistantMessage,
        agentStream: agentStream,
        onMessageUpdated: onMessageUpdated,
        onIterationChanged: onIterationChanged,
        onToolNameChanged: onToolNameChanged,
        onUsageChanged: onUsageChanged,
      );

      await _manageService.finalizeAssistantMessage(assistantMessage);
      await _manageService.updateChatTimestamp(chat);
      await onListReload();
    } on CancelledException {
      final target = _latestMessage ?? assistantMessage;
      if (target != null) {
        onMessageUpdated(
          await _manageService.recordCancelledOnMessage(target),
        );
      }
    } catch (e) {
      final target = _latestMessage ?? assistantMessage;
      if (target != null) {
        onMessageUpdated(
          await _manageService.recordErrorOnMessage(target, e),
        );
      }
      rethrow;
    } finally {
      if (_settled != null && !_settled!.isCompleted) {
        _settled!.complete();
      }
      _cancelToken = null;
      _latestMessage = null;
      _streamingChatId = null;
      _settled = null;
    }
  }

  void stop() {
    _cancelToken?.cancel();
  }

  Future<void> deleteMessage({
    required MessageEntity message,
    required List<MessageEntity> currentMessages,
    required void Function(List<MessageEntity>) onMessagesChanged,
  }) async {
    final index = currentMessages
        .indexWhere((item) => item.id == message.id);
    if (index >= 0) {
      await _manageService.deleteMessagesFromIndex(currentMessages, index);
      onMessagesChanged(
        await _messageRepo.getMessagesByChatId(message.chatId),
      );
    }
  }

  Future<void> refreshMessages({
    required int chatId,
    required void Function(List<MessageEntity>) onMessagesChanged,
  }) async {
    onMessagesChanged(await _messageRepo.getMessagesByChatId(chatId));
  }

  Future<void> _maybePromptSkillTrust() async {
    if (_skillTrustPrompted) return;
    if (!_skillRegistry.hasPendingProjectSkills) return;
    _skillTrustPrompted = true;

    final dir = _skillRegistry.pendingProjectDir;
    if (dir == null) return;

    final names = _skillRegistry.pendingProjectSkills
        .map((s) => s.name)
        .toList();
    final trusted = await showSkillTrustDialog(
      projectDir: dir,
      skillNames: names,
    );
    if (trusted) {
      await _skillRegistry.trustCurrentProject();
    }
  }

  Future<MessageEntity> _consumeStream({
    required ChatEntity chat,
    required MessageEntity assistantMessage,
    required Stream<AgentEvent> agentStream,
    required void Function(MessageEntity) onMessageUpdated,
    required void Function(int) onIterationChanged,
    required void Function(String?) onToolNameChanged,
    required Future<void> Function(TokenUsage, ChatEntity) onUsageChanged,
  }) async {
    var current = assistantMessage;
    _latestMessage = current;
    var contentBuffer = StringBuffer();
    var reasoningBuffer = StringBuffer();
    var toolCallsJson = <Map<String, dynamic>>[];
    var toolResultsJson = <Map<String, dynamic>>[];
    var hasCompletedIteration = false;

    await for (final event in agentStream) {
      _cancelToken?.throwIfCancelled();

      if (event is AgentReasoningEvent) {
        if (hasCompletedIteration) {
          current = await _advanceIteration(chat, current, onMessageUpdated);
          contentBuffer = StringBuffer();
          reasoningBuffer = StringBuffer();
          toolCallsJson = [];
          toolResultsJson = [];
          hasCompletedIteration = false;
        }
        reasoningBuffer.write(event.delta);
        current = current.copyWith(
          reasoningContent: reasoningBuffer.toString(),
          reasoning: true,
          reasoningUpdatedAt: DateTime.now(),
        );
        onMessageUpdated(current);
        _latestMessage = current;
      } else if (event is AgentTextEvent) {
        if (hasCompletedIteration) {
          current = await _advanceIteration(chat, current, onMessageUpdated);
          contentBuffer = StringBuffer();
          reasoningBuffer = StringBuffer();
          toolCallsJson = [];
          toolResultsJson = [];
          hasCompletedIteration = false;
        }
        contentBuffer.write(event.delta);
        current = current.copyWith(content: contentBuffer.toString());
        onMessageUpdated(current);
        _latestMessage = current;
      } else if (event is AgentToolCallEvent) {
        onToolNameChanged(event.name);
        toolCallsJson.add({
          'id': event.id,
          'name': event.name,
          'arguments': event.arguments,
        });
        current = current.copyWith(toolCalls: jsonEncode(toolCallsJson));
        onMessageUpdated(current);
        _latestMessage = current;
      } else if (event is AgentToolResultEvent) {
        toolResultsJson.add({
          'id': event.id,
          'name': event.name,
          'result': event.result,
        });
        current = current.copyWith(
            toolResults: jsonEncode(toolResultsJson));
        onMessageUpdated(current);
        _latestMessage = current;
        hasCompletedIteration = true;
      } else if (event is AgentDoneEvent) {
        current = current.copyWith(content: event.content);
        onMessageUpdated(current);
        _latestMessage = current;
      } else if (event is AgentUsageEvent) {
        // 一次性原子写入累计 token_total + 上下文/缓存快照。
        final updated = await _supportService.recordUsage(
          chat,
          tokenDelta: event.usage.totalTokens,
          contextTokens: event.usage.promptTokens,
          cachedTokens: event.usage.cachedTokens ?? 0,
        );
        if (updated != null) {
          await onUsageChanged(event.usage, updated);
        }
      }
    }

    if (reasoningBuffer.isNotEmpty) {
      current = current.copyWith(reasoning: false);
      onMessageUpdated(current);
      _latestMessage = current;
    }

    return current;
  }

  Future<MessageEntity> _advanceIteration(
    ChatEntity chat,
    MessageEntity current,
    void Function(MessageEntity) onMessageUpdated,
  ) async {
    await _manageService.finalizeAssistantMessage(current);
    final next = await _manageService.appendAssistantPlaceholder(chat.id!);
    onMessageUpdated(next);
    return next;
  }

  /// Auto 模式下准备消息：若 token 占用率超过 70% 则触发 compact。
  ///
  /// compact 成功后：
  /// - 在 DB 中将压缩范围内的消息标记为 compacted=1
  /// - 插入一条 system 摘要消息
  /// - 下次 buildMessages 时 compacted 消息自动被过滤
  Future<List<ChatMessage>> _prepareMessagesWithCompact({
    required ChatEntity chat,
    required SentinelEntity? sentinel,
    required List<ChatMessage> wrappedMessages,
    required int contextWindow,
    required int currentTokens,
    required ProviderEntity provider,
    required ModelEntity model,
  }) async {
    // 仅当上下文占用率 > 80% 时触发压缩
    if (contextWindow <= 0 ||
        currentTokens <= 0 ||
        currentTokens / contextWindow <= 0.8) {
      return wrappedMessages;
    }

    // 找出 system 消息（sentinel prompt），它们不参与压缩
    final systemMessages = <ChatMessage>[];
    final compressible = <ChatMessage>[];
    for (final m in wrappedMessages) {
      if (m is SystemMessage) {
        systemMessages.add(m);
      } else {
        compressible.add(m);
      }
    }

    // 前半段压缩，后半段保留
    final splitIndex = (compressible.length * 0.6).ceil();
    final toSummarize = compressible.sublist(0, splitIndex);
    final keep = compressible.sublist(splitIndex);

    // 构建压缩文本
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

      // 持久化 compact 结果
      final chatId = chat.id!;

      // 1. 获取当前非压缩消息实体，定位被压缩的消息 ID
      final activeMessages =
          await _messageRepo.getMessagesByChatId(chatId, includeCompacted: false);

      // 找到 splitIndex 对应的实体 ID 分界点（跳过 system 角色消息）
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

      // 2. 标记被压缩消息为 compacted
      if (toCompactIds.isNotEmpty) {
        await _messageRepo.markAsCompacted(toCompactIds);
      }

      // 3. 插入摘要消息
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

  /// 把消息列表压缩为适合摘要的纯文本。
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
