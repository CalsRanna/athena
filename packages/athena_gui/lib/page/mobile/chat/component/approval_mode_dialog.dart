import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_gui/component/approval_mode_label.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 审批模式选择对话框——移动端：三行（名称 + 一句说明），当前档加粗。
///
/// 带说明是因为三档的差别不看解释看不出来（desktop 的 Mode 菜单同样带）；
/// 推理强度的档位是自明的，那边就只列名字。
class MobileApprovalModeDialog extends StatelessWidget {
  final ApprovalMode current;
  final void Function(ApprovalMode)? onTap;

  const MobileApprovalModeDialog({
    super.key,
    required this.current,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        const SizedBox(height: 8),
        for (final mode in ApprovalMode.values)
          _MobileApprovalModeTile(
            mode: mode,
            selected: mode == current,
            onTap: () => onTap?.call(mode),
          ),
      ],
    );
  }
}

class _MobileApprovalModeTile extends StatelessWidget {
  final ApprovalMode mode;
  final bool selected;
  final void Function()? onTap;

  const _MobileApprovalModeTile({
    required this.mode,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final labelStyle = AthenaTextStyle.row.copyWith(
      color: colors.textPrimary,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mode.label, style: labelStyle),
            const SizedBox(height: 2),
            Text(
              mode.description,
              style: AthenaTextStyle.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
