import 'package:athena_core/agent/permission/permission_prompt.dart';
import 'package:athena_core/util/tool_args_formatter.dart';
import 'package:athena_gui/component/step_card.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';

const permissionCardMaxHeightFraction = 0.5;

/// 会话内权限审批卡片（非模态）：渲染在所属对话的消息列表中。
///
/// 容器是白底描边卡片；内部结构复用工具步骤行的标题行语言（工具图标 + 工具名 +
/// 调用描述），命令完整展示，按钮直接用全站的 [AthenaPrimaryButton] /
/// [AthenaSecondaryButton]（DESIGN.md §7：主路径操作按钮一律从 Primary CTA 派生）。
/// 这是待处理的 UI 决策，文字用常规 UI 档，不跟随会话字号；只展示执行内容。
class PermissionApprovalCard extends StatelessWidget {
  final ApprovalRequest request;
  final double maxHeight;

  /// 决策只作用于本次调用。
  final void Function(bool approved) onDecision;

  const PermissionApprovalCard({
    super.key,
    required this.request,
    required this.maxHeight,
    required this.onDecision,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.surfaceMobile,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AthenaRadius.container),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            Flexible(child: _buildCommand(context)),
            const SizedBox(height: 12),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  /// 标题行：工具图标 + 工具名 + 调用描述（单行省略，不展示参数）。
  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Row(
      children: [
        Icon(
          StepCard.toolIcon(request.toolName),
          size: AthenaIcon.regularSize,
          color: colors.textPrimary,
        ),
        const SizedBox(width: 8),
        Text(
          request.toolName,
          style: AthenaTextStyle.section.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            StepCard.toolLabel(request.arguments),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AthenaTextStyle.body.copyWith(color: colors.textPrimary),
          ),
        ),
      ],
    );
  }

  /// 完整命令/参数展示：无背景的直接文字。
  Widget _buildCommand(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Scrollbar(
      child: SingleChildScrollView(
        primary: false,
        child: SizedBox(
          width: double.infinity,
          child: Text(
            formatToolArgsForApproval(request.toolName, request.arguments),
            style: AthenaTextStyle.body.copyWith(color: colors.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final platform = Theme.of(context).platform;
    final mobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;

    if (mobile) {
      // 移动：全宽按钮，主操作（Allow Once）在最上
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AthenaPrimaryButton(
            onTap: () => onDecision(true),
            child: const Center(child: Text('Allow Once')),
          ),
          const SizedBox(height: 8),
          AthenaSecondaryButton(
            onTap: () => onDecision(false),
            child: const Center(child: Text('Deny')),
          ),
        ],
      );
    }

    // 桌面：行内按钮，主操作（Allow Once）在最右
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AthenaSecondaryButton(
          onTap: () => onDecision(false),
          child: const Text('Deny'),
        ),
        const SizedBox(width: 12),
        AthenaPrimaryButton(
          onTap: () => onDecision(true),
          child: const Text('Allow Once'),
        ),
      ],
    );
  }
}

PermissionDecision permissionDecisionOf(bool approved) =>
    PermissionDecision(approved: approved);
