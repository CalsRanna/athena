import 'package:athena_core/agent/cancel_token.dart';

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
