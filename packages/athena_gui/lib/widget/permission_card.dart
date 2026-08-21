import 'package:athena_core/coordinator/agent_run_coordinator.dart';
import 'package:athena_gui/util/color_util.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena_gui/widget/permission_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// 会话内权限审批卡片（非模态）：渲染在所属对话的消息列表中。
///
/// 与模态弹窗的差异：多个对话的审批请求各自挂在自己的会话里，
/// 用户可自由切换对话处理，互不阻塞。
class PermissionApprovalCard extends StatelessWidget {
  final ApprovalRequest request;

  /// 决策回调（approved + persistExact）。
  final void Function(bool approved, bool persistExact) onDecision;

  const PermissionApprovalCard({
    super.key,
    required this.request,
    required this.onDecision,
  });

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final mobile = platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS;

    return Container(
      constraints: const BoxConstraints(minWidth: 400, maxWidth: 560),
      decoration: BoxDecoration(
        color: ColorUtil.FF282F32,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ColorUtil.FF6ABEB9.withValues(alpha: 0.4),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                HugeIcons.strokeRoundedAlert02,
                size: 16,
                color: ColorUtil.FF6ABEB9,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Waiting for approval',
                  style: TextStyle(
                    color: ColorUtil.FF9E9E9E,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PermissionDialogContent(
            toolName: request.toolName,
            description: request.arguments,
            mobile: mobile,
            onDecision: onDecision,
          ),
        ],
      ),
    );
  }
}

/// 把卡片决策转换为 core 的 [PermissionDecision]。
PermissionDecision permissionDecisionOf(bool approved, bool persistExact) =>
    PermissionDecision(
      approved: approved,
      persistExact: persistExact,
    );
