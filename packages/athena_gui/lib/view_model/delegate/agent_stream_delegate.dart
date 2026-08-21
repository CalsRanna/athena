import 'dart:async';

import 'package:athena_core/agent/agent_service.dart';
import 'package:athena_core/agent/cancel_token.dart';
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
import 'package:athena_gui/widget/skill_trust_dialog.dart';
import 'package:openai_dart/openai_dart.dart';

/// 一个挂起的权限审批请求（按 [chatId] 隔离，渲染到对应会话）。
class ApprovalRequest {
  final int chatId;
  final String toolName;

  /// 审批内容（shell 为完整命令，其他为参数键值），已格式化。
  final String arguments;
  final Completer<PermissionDecision> completer;

  ApprovalRequest({
    required this.chatId,
    required this.toolName,
    required this.arguments,
    required this.completer,
  });
}

/// GUI 侧的 Agent 流桥：包装核心 [AgentRunCoordinator]，
/// 权限审批以会话内卡片（非模态）呈现，事件原样转发。
class AgentStreamDelegate {
  late final AgentRunCoordinator _coordinator;

  final _approvalController = StreamController<ApprovalRequest>.broadcast();

  /// 挂起的权限审批请求流（ChatViewModel 订阅后渲染为会话内卡片）。
  Stream<ApprovalRequest> get approvalRequests => _approvalController.stream;

  AgentStreamDelegate({required AgentServiceCoordinatorDeps deps}) {
    _coordinator = AgentRunCoordinator(
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
      permissionPrompt: (chatId, toolName, arguments, cancelToken) =>
          _askPermission(chatId, toolName, arguments, cancelToken),
      skillTrustPrompt: _askSkillTrust,
    );
  }

  /// 正在流式运行的对话 id 集合（多对话可同时运行）。
  Set<int> get streamingChatIds => _coordinator.streamingChatIds;

  /// 指定对话是否正在流式运行。
  bool isStreamingChat(int chatId) => _coordinator.isStreamingChat(chatId);

  /// 等待指定对话的 run 完成后 resolve 的 Future。
  Future<void>? settledOf(int chatId) => _coordinator.settledOf(chatId);

  /// 指定对话当前流式中的消息快照（用于切换到运行中的对话时恢复进度）。
  MessageEntity? liveMessage(int chatId) => _coordinator.liveMessage(chatId);

  /// 用户点击思考卡片切换的展开状态，转发给核心协调层。
  void updateExpanded(int messageId, bool expanded) {
    _coordinator.updateExpanded(messageId, expanded);
  }

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

  void steer(int chatId, ChatMessage message) {
    _coordinator.steer(chatId, message);
  }

  void followUp(int chatId, ChatMessage message) {
    _coordinator.followUp(chatId, message);
  }

  void clearQueues(int chatId) {
    _coordinator.clearQueues(chatId);
  }

  /// 用户对某个审批请求做出决策（由 UI 卡片调用）。
  void respondApproval(ApprovalRequest request, PermissionDecision decision) {
    if (!request.completer.isCompleted) {
      request.completer.complete(decision);
    }
  }

  // ─── GUI 侧实现：会话内审批卡片（非模态） ────────────────

  Future<PermissionDecision> _askPermission(
    int chatId,
    String toolName,
    String arguments,
    CancelToken cancelToken,
  ) async {
    final completer = Completer<PermissionDecision>();
    _approvalController.add(
      ApprovalRequest(
        chatId: chatId,
        toolName: toolName,
        arguments: formatToolArgsForApproval(toolName, arguments),
        completer: completer,
      ),
    );

    // run 取消时自动拒绝；同时完成 completer 让 UI 卡片自动移除
    final result = await Future.any<PermissionDecision>([
      completer.future,
      cancelToken.whenCancelled.then(
        (_) => const PermissionDecision(approved: false),
      ),
    ]);
    if (!completer.isCompleted) completer.complete(result);
    return result;
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
