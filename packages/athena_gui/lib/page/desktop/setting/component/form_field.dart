import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 设置表单对话框里的一项：标签在上、控件在下（表单是纵向的，
/// 不是「左标签右输入」的两列）。
class DesktopSettingFormField extends StatelessWidget {
  final String label;
  final String? hint;
  final String? error;
  final Widget child;
  const DesktopSettingFormField({
    super.key,
    required this.label,
    this.hint,
    this.error,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final labelStyle = AthenaTextStyle.section.copyWith(
      color: colors.textPrimary,
    );
    final hintStyle = AthenaTextStyle.caption.copyWith(color: colors.textWeak);
    final errorStyle = AthenaTextStyle.caption.copyWith(
      color: colors.dangerText,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 6),
        child,
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: errorStyle),
        ] else if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint!, style: hintStyle),
        ],
      ],
    );
  }
}
