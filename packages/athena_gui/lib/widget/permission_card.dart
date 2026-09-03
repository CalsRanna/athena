import 'package:athena_gui/component/tool_card.dart';
import 'package:athena_core/agent/permission/permission_prompt.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/delegate/agent_stream_delegate.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const permissionCardMaxHeightFraction = 0.5;

/// 会话内权限审批卡片（非模态）：渲染在所属对话的消息列表中。
///
/// 容器对齐 Agent 消息卡片（白色圆角 24）；内部结构复用 ToolCard 的
/// 标题行语言（工具图标 + 工具名 + 参数预览 + 运行状态），命令完整
/// 展示，按钮为浅色卡片上的胶囊体系（深色实心主按钮 + 描边次按钮）。
class PermissionApprovalCard extends StatelessWidget {
  final ApprovalRequest request;
  final double maxHeight;

  /// 决策回调（approved + persistExact）。
  final void Function(bool approved, bool persistExact) onDecision;

  const PermissionApprovalCard({
    super.key,
    required this.request,
    required this.maxHeight,
    required this.onDecision,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final platform = Theme.of(context).platform;
    final mobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    // 右侧留白对齐消息卡片的正文右缘:消息卡正文尾部有 CopyButton
    // 悬浮占位(移动 24 / 桌面 48),正文实际距卡片右为 16 + 该尾随位;
    // 审核卡片没有 CopyButton,右侧直接加大容器 padding 达到同等留白。
    final rightPadding = mobile ? 40.0 : 64.0;
    // 容器样式对齐 Agent 消息卡片（白色圆角 24、同款 padding），
    // 内部为 [头像] + [正文] 两列布局（与消息卡片一致）
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.surfaceRaised.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: EdgeInsets.fromLTRB(12, 12, rightPadding, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(context),
            const SizedBox(width: 12),
            Expanded(
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
          ],
        ),
      ),
    );
  }

  /// 头像：灰圆底 + 工具图标（对齐工具消息卡片的头像样式）。
  Widget _buildAvatar(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.avatarBackground,
      ),
      height: 36,
      width: 36,
      child: Icon(
        ToolCard.toolIcon(request.toolName),
        color: colors.textPrimary,
        size: 20,
      ),
    );
  }

  /// 标题行：工具名 + 参数预览（单行省略）。
  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Row(
      children: [
        Text(
          request.toolName,
          style: GoogleFonts.firaCode(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.textOnRaised,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            ToolCard.argPreview(request.toolName, request.arguments),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: colors.textOnRaised,
            ),
          ),
        ),
      ],
    );
  }

  /// 完整命令/参数展示：无背景的直接文字（与消息正文一致）。
  Widget _buildCommand(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Scrollbar(
      child: SingleChildScrollView(
        primary: false,
        child: Text(
          request.arguments,
          style: GoogleFonts.firaCode(
            fontSize: 12,
            color: colors.textOnRaised,
            height: 1.6,
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
          _CardPrimaryButton(
            label: 'Allow Once',
            onTap: () => onDecision(true, false),
          ),
          const SizedBox(height: 8),
          _CardSecondaryButton(
            label: 'Always Allow',
            onTap: () => onDecision(true, true),
          ),
          const SizedBox(height: 8),
          _CardSecondaryButton(
            label: 'Deny',
            onTap: () => onDecision(false, false),
          ),
        ],
      );
    }

    // 桌面：行内按钮，主操作（Allow Once）在最右
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _CardSecondaryButton(
          label: 'Deny',
          onTap: () => onDecision(false, false),
        ),
        const SizedBox(width: 12),
        _CardSecondaryButton(
          label: 'Always Allow',
          onTap: () => onDecision(true, true),
        ),
        const SizedBox(width: 12),
        _CardPrimaryButton(
          label: 'Allow Once',
          onTap: () => onDecision(true, false),
        ),
      ],
    );
  }
}

/// 浅色卡片上的主按钮：深色实心胶囊 + 白字。
class _CardPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CardPrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: ShapeDecoration(
            color: colors.cardPrimaryBackground,
            shape: StadiumBorder(),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: colors.cardPrimaryText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 浅色卡片上的次按钮：描边胶囊 + 深色文字。
class _CardSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CardSecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: ShapeDecoration(
            shape: StadiumBorder(side: BorderSide(color: colors.border)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: colors.textOnRaised,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// 把卡片决策转换为 core 的 [PermissionDecision]。
PermissionDecision permissionDecisionOf(bool approved, bool persistExact) =>
    PermissionDecision(approved: approved, persistExact: persistExact);
