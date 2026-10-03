import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:meta/meta.dart';
import 'package:athena_core/agent/elicit/elicit_prompt.dart'
    show ElicitQuestion;
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/runtime_context.dart';
import 'package:athena_core/agent/permission/permission_prompt.dart';
import 'package:athena_core/coordinator/agent_run_coordinator.dart';
import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/rewind_result.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/storage/experience_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/storage/chat_store.dart';
import 'package:athena_core/service/chat_message_converter.dart';
import 'package:athena_core/service/chat_completions_service.dart';
import 'package:athena_core/service/chat_update_service.dart';
import 'package:athena_core/storage/agent_settings.dart';

/// 权限审批回调:由 TUI UI 层注册(终端内模态)。
///
/// [chatId] 是发起请求的会话:自动汇报 run 会在非当前会话上请求审批,
/// UI 要标出它属于哪个会话。[cancelled] 在该 run 取消时完成——此时桥已
/// 按拒绝返回,UI 据此撤下这张卡片,不留一张再也等不到结果的审批。
typedef TuiPermissionHandler =
    Future<PermissionDecision> Function(
      String chatId,
      String toolName,
      String arguments,
      Future<void> cancelled, {
      String? reviewReason,
    });

/// 提问回调:由 TUI UI 层注册(终端内模态)。参数含义同 [TuiPermissionHandler]。
///
/// 返回 null = 未作答(UI 未就绪或用户跳过),工具据此按标注过的假定继续。
typedef TuiElicitHandler =
    Future<Map<String, String>?> Function(
      String chatId,
      List<ElicitQuestion> questions,
      Future<void> cancelled,
    );

/// TUI 侧的 Agent 流桥:包装核心 [AgentRunCoordinator]。
///
/// 结构与 GUI 的 AgentStreamDelegate 对称:事件原样转发,
/// 权限审批由 [permissionHandler] 注入。
class TuiAgentBridge {
  late final AgentRunCoordinator _coordinator;

  /// UI 层在启动时注册(尚未注册时拒绝权限请求,保证 Agent 不卡死)。
  TuiPermissionHandler? permissionHandler;

  /// UI 层在启动时注册。尚未注册时以"未作答"返回——提问不是安全决策,
  /// 没必要拒绝,让模型按假定继续即可(与权限请求的处理不同)。
  TuiElicitHandler? elicitHandler;

  TuiAgentBridge({
    required AgentService agentService,
    required ChatStore chatStore,
    required ChatMessageConverter messageService,
    required ChatCompletionsService chatService,
    required MessageRepository messageRepo,
    required ModelRepository modelRepo,
    required SentinelRepository sentinelRepo,
    required ChatRepository chatRepo,
    required ChatUpdateService supportService,
    required AgentSettings agentSettings,
    required PermissionService permissionService,
    required ExperienceRepository experienceRepository,
  }) {
    _coordinator = AgentRunCoordinator(
      agentService: agentService,
      chatStore: chatStore,
      messageService: messageService,
      chatService: chatService,
      messageRepo: messageRepo,
      modelRepo: modelRepo,
      sentinelRepo: sentinelRepo,
      chatRepo: chatRepo,
      supportService: supportService,
      agentSettings: agentSettings,
      permissionService: permissionService,
      permissionPrompt:
          (chatId, toolName, arguments, cancelToken, {reviewReason}) =>
              _askPermission(
                chatId,
                toolName,
                arguments,
                cancelToken,
                reviewReason: reviewReason,
              ),
      elicitPrompt: (chatId, questions, cancelToken) =>
          _askElicit(chatId, questions, cancelToken),
      experienceRepository: experienceRepository,
      runtimeEnvironment: RuntimeEnvironment.tui,
    );
  }

  /// 等待指定对话的 run 完成后 resolve 的 Future（TUI 单对话）。
  Future<void>? settledOf(String chatId) => _coordinator.settledOf(chatId);

  /// 协调层自己发起的 run（后台任务完成后的自动汇报）的事件流。
  Stream<InternalRunEvent> get internalEvents => _coordinator.internalEvents;

  MessageEntity? liveMessage(String chatId) => _coordinator.liveMessage(chatId);

  Stream<RunEvent> send({
    required MessageEntity message,
    required ChatEntity chat,
    bool jsonMode = false,
  }) {
    return _coordinator.send(message: message, chat: chat, jsonMode: jsonMode);
  }

  Future<RewindResult> rewindToUserMessage(String chatId, String messageId) =>
      _coordinator.rewindToUserMessage(chatId, messageId);

  void stop(String chatId) {
    _coordinator.stop(chatId);
  }

  /// 运行中输入：落库排队，当前 run 结束后自动接续为新 run。
  Future<MessageEntity?> queueInput(String chatId, MessageEntity message) {
    return _coordinator.queueInput(chatId, message);
  }

  // ─── TUI 侧实现:终端内模态 ─────────────────────────────

  /// 测试入口:直接请求一次权限(走与 Agent 相同的 handler 逻辑)。
  @visibleForTesting
  Future<PermissionDecision> requestPermissionForTest(
    String toolName,
    String arguments, {
    String chatId = '',
    CancelToken? cancelToken,
    String? reviewReason,
  }) {
    return _askPermission(
      chatId,
      toolName,
      arguments,
      cancelToken ?? CancelToken(),
      reviewReason: reviewReason,
    );
  }

  /// 测试入口:直接请求一次提问(走与 Agent 相同的 handler 逻辑)。
  @visibleForTesting
  Future<Map<String, String>?> requestElicitForTest(
    List<ElicitQuestion> questions, {
    String chatId = '',
    CancelToken? cancelToken,
    String? reviewReason,
  }) {
    return _askElicit(chatId, questions, cancelToken ?? CancelToken());
  }

  Future<Map<String, String>?> _askElicit(
    String chatId,
    List<ElicitQuestion> questions,
    CancelToken cancelToken,
  ) {
    final handler = elicitHandler;
    // UI 未就绪(或测试未注册)时以"未作答"返回,避免 Agent 挂起等待
    if (handler == null) return Future<Map<String, String>?>.value(null);
    // run 取消时立即返回未作答,卡片/提示条随之中止
    return Future.any<Map<String, String>?>([
      handler(chatId, questions, cancelToken.whenCancelled),
      cancelToken.whenCancelled.then<Map<String, String>?>((_) => null),
    ]);
  }

  Future<PermissionDecision> _askPermission(
    String chatId,
    String toolName,
    String arguments,
    CancelToken cancelToken, {
    String? reviewReason,
  }) async {
    final handler = permissionHandler;
    if (handler == null) {
      // UI 未就绪时拒绝,避免 Agent 挂起等待
      return const PermissionDecision(approved: false);
    }
    // run 取消时自动拒绝,避免审批请求挂起导致 Agent 卡死
    return Future.any<PermissionDecision>([
      handler(
        chatId,
        toolName,
        arguments,
        cancelToken.whenCancelled,
        reviewReason: reviewReason,
      ),
      cancelToken.whenCancelled.then(
        (_) => const PermissionDecision(approved: false),
      ),
    ]);
  }
}
