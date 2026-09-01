import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
import 'package:meta/meta.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/runtime_context.dart';
import 'package:athena_core/coordinator/agent_run_coordinator.dart';
import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
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

/// 权限审批回调:由 TUI UI 层注册(终端内模态)。
typedef TuiPermissionHandler = Future<PermissionDecision> Function(
  String toolName,
  String arguments,
);

/// TUI 侧的 Agent 流桥:包装核心 [AgentRunCoordinator]。
///
/// 结构与 GUI 的 AgentStreamDelegate 对称:事件原样转发,
/// 权限审批由 [permissionHandler] 注入。
class TuiAgentBridge {
  late final AgentRunCoordinator _coordinator;

  /// UI 层在启动时注册(尚未注册时拒绝权限请求,保证 Agent 不卡死)。
  TuiPermissionHandler? permissionHandler;

  TuiAgentBridge({
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
    required ExperienceRepository experienceRepository,
  }) {
    _coordinator = AgentRunCoordinator(
      agentService: agentService,
      manageService: manageService,
      messageService: messageService,
      chatService: chatService,
      messageRepo: messageRepo,
      modelRepo: modelRepo,
      sentinelRepo: sentinelRepo,
      chatRepo: chatRepo,
      supportService: supportService,
      agentSettings: agentSettings,
      permissionService: permissionService,
      permissionPrompt: (chatId, toolName, arguments, cancelToken) =>
          _askPermission(toolName, arguments, cancelToken),
      experienceRepository: experienceRepository,
      runtimeEnvironment: RuntimeEnvironment.tui,
    );
  }

  /// 等待指定对话的 run 完成后 resolve 的 Future（TUI 单对话）。
  Future<void>? settledOf(int chatId) => _coordinator.settledOf(chatId);

  Stream<RunEvent> send({
    required MessageEntity message,
    required ChatEntity chat,
    bool jsonMode = false,
  }) {
    return _coordinator.send(
      message: message,
      chat: chat,
      jsonMode: jsonMode,
    );
  }

  void stop(int chatId) {
    _coordinator.stop(chatId);
  }

  // ─── TUI 侧实现:终端内模态 ─────────────────────────────

  /// 测试入口:直接请求一次权限(走与 Agent 相同的 handler 逻辑)。
  @visibleForTesting
  Future<PermissionDecision> requestPermissionForTest(
    String toolName,
    String arguments,
  ) {
    return _askPermission(toolName, arguments, CancelToken());
  }

  Future<PermissionDecision> _askPermission(
    String toolName,
    String arguments,
    CancelToken cancelToken,
  ) async {
    final handler = permissionHandler;
    if (handler == null) {
      // UI 未就绪时拒绝,避免 Agent 挂起等待
      return const PermissionDecision(approved: false);
    }
    // run 取消时自动拒绝,避免审批请求挂起导致 Agent 卡死
    return Future.any<PermissionDecision>([
      handler(toolName, arguments),
      cancelToken.whenCancelled.then(
        (_) => const PermissionDecision(approved: false),
      ),
    ]);
  }

}
