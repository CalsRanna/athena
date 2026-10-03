import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/reasoning_effort.dart';
import 'package:flutter/material.dart';

/// 推理强度选择对话框——移动端,行样式与 [AthenaBottomSheetTile]
/// 一致,当前档位文字加粗区分。
class MobileReasoningEffortSelectDialog extends StatelessWidget {
  final String current;
  final void Function(String)? onTap;

  const MobileReasoningEffortSelectDialog({
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
        for (final option in reasoningEffortOptions)
          _MobileReasoningEffortTile(
            label: option.$2,
            selected: option.$1 == current,
            onTap: () => onTap?.call(option.$1),
          ),
      ],
    );
  }
}

class _MobileReasoningEffortTile extends StatelessWidget {
  final String label;
  final bool selected;
  final void Function()? onTap;

  const _MobileReasoningEffortTile({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final textStyle = AthenaTextStyle.row.copyWith(
      color: colors.textPrimary,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: textStyle),
        ),
      ),
    );
  }
}
