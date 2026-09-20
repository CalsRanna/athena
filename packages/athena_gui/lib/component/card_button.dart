import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 会话内卡片（权限审批 / 提问）底部的按钮体系。
///
/// 卡片底色是浅色浮层，所以按钮不走 [AthenaColors.surfaceRaised] 的页面级
/// hover 体系，而是「深色实心主按钮 + 描边次按钮」这一对固定形态。
/// 之前这两个按钮在 `permission_card.dart` 与 `elicit_card.dart` 里各写了
/// 一份，能力已经漂移（提出版支持 `onTap == null` 置灰），此处合并为唯一实现。
class CardPrimaryButton extends StatelessWidget {
  final String label;

  /// 为 null 时置灰并禁用（提问卡片在未满足提交条件时使用）。
  final VoidCallback? onTap;

  const CardPrimaryButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          decoration: ShapeDecoration(
            color: colors.surfaceRaised.withValues(alpha: enabled ? 1 : 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AthenaRadius.control),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 浅色卡片上的次按钮：描边胶囊 + 深色文字，与主按钮同尺寸。
class CardSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const CardSecondaryButton({super.key, required this.label, this.onTap});

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AthenaRadius.control),
              side: BorderSide(color: colors.border),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
