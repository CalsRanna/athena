import 'dart:async';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/permission/permission_service.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/coordinator/agent_run_coordinator.dart';
import 'package:athena_core/coordinator/run_event.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/repository/chat_repository.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/repository/model_repository.dart';
import 'package:athena_core/repository/sentinel_repository.dart';
import 'package:athena_core/service/chat_manage_service.dart';
import 'package:athena_core/service/chat_message_service.dart';
import 'package:athena_core/service/chat_service.dart';
import 'package:athena_core/service/chat_support_service.dart';
import 'package:athena_core/storage/agent_settings.dart';
import 'package:athena_core/util/tool_args_formatter.dart';
import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/widget/permission_dialog.dart';
import 'package:athena_gui/widget/skill_trust_dialog.dart';
import 'package:openai_dart/openai_dart.dart';

/// GUI 侧的 Agent 流桥：包装核心 [AgentRunCoordinator]，
/// 注入权限/Skill 信任对话框实现，事件原样转发。
class AgentStreamDelegate {
  final AgentRunCoordinator _coordinator;

  AgentStreamDelegate({required AgentServiceCoordinatorDeps deps})
    : _coordinator = AgentRunCoordinator(
        agentService: deps.agentService,
        manageService: deps.manageService,
        messageService: deps.messageService,
        chatService: deps.chatService,
        messageRepo: deps.messageRepo,
        modelRepo: deps.modelRepo,
        sentinelRepo: deps.sentinelRepo,
        chatRepo: deps.chatRepo,
        supportService: deps.supportService,
        agentSettings: deps.agentSettings,
        permissionService: deps.permissionService,
        skillRegistry: deps.skillRegistry,
        permissionPrompt: (toolName, arguments) =>
            _askPermission(deps, toolName, arguments),
        skillTrustPrompt: _askSkillTrust,
      );

  int? get streamingChatId => _coordinator.streamingChatId;
  Future<void>? get settled => _coordinator.settled;

  /// 用户点击思考卡片切换的展开状态，转发给核心协调层。
  void updateExpanded(int messageId, bool expanded) {
    _coordinator.updateExpanded(messageId, expanded);
  }

  Stream<RunEvent> send({
    required MessageEntity message,
    required ChatEntity chat,
  }) {
    return _coordinator.send(message: message, chat: chat);
  }

  void stop() {
    _coordinator.stop();
  }

  void steer(ChatMessage message) {
    _coordinator.steer(message);
  }

  void followUp(ChatMessage message) {
    _coordinator.followUp(message);
  }

  void clearQueues() {
    _coordinator.clearQueues();
  }

  // ─── GUI 侧实现：对话框 ─────────────────────────────────

  static Future<PermissionDecision> _askPermission(
    AgentServiceCoordinatorDeps deps,
    String toolName,
    String arguments,
  ) async {
    final description = formatToolArgsForApproval(toolName, arguments);

    final dialogFuture = showPermissionDialog(
      toolName: toolName,
      description: description,
    );

    final cancelToken = deps.agentService.currentCancelToken;
    final result = await Future.any<PermissionDialogResult>([
      dialogFuture,
      if (cancelToken != null)
        cancelToken.whenCancelled.then((_) {
          final nav = router.navigatorKey.currentState;
          if (nav?.canPop() ?? false) nav!.pop();
          return const PermissionDialogResult(approved: false);
        }),
    ]);

    return PermissionDecision(
      approved: result.approved,
      persistExact: result.persistExact,
    );
  }

  static Future<bool> _askSkillTrust(String dir, List<String> names) {
    return showSkillTrustDialog(projectDir: dir, skillNames: names);
  }
}

/// 组装 [AgentRunCoordinator] 所需依赖的载体（由 di.dart 构造）。
class AgentServiceCoordinatorDeps {
  final AgentService agentService;
  final ChatManageService manageService;
  final ChatMessageService messageService;
  final ChatService chatService;
  final MessageRepository messageRepo;
  final ModelRepository modelRepo;
  final SentinelRepository sentinelRepo;
  final ChatRepository chatRepo;
  final ChatSupportService supportService;
  final AgentSettings agentSettings;
  final PermissionService permissionService;
  final SkillRegistry skillRegistry;

  AgentServiceCoordinatorDeps({
    required this.agentService,
    required this.manageService,
    required this.messageService,
    required this.chatService,
    required this.messageRepo,
    required this.modelRepo,
    required this.sentinelRepo,
    required this.chatRepo,
    required this.supportService,
    required this.agentSettings,
    required this.permissionService,
    required this.skillRegistry,
  });
}
