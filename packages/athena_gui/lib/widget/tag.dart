import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/hover.dart';
import 'package:athena_gui/widget/press_scale.dart';
import 'package:flutter/widgets.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

/// 筛选 chip：胶囊 + 1px 实线边框，没有渐变边框。
///
/// 选中态靠"提亮底色 + 加粗文字"表达，不做明暗反转的实心填充——
/// 反转填充会在安静的灰阶层次里跳出一块高对比色块。
class AthenaTag extends StatelessWidget {
  final TextStyle base;
  final EdgeInsets padding;
  final bool selected;
  final String text;

  const AthenaTag({
    super.key,
    this.base = AthenaTextStyle.label,
    this.selected = false,
    required this.text,
  }) : padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6);

  const AthenaTag.small({
    super.key,
    this.base = AthenaTextStyle.caption,
    this.selected = false,
    required this.text,
  }) : padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3);

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final textStyle = base.copyWith(
      color: selected ? colors.textPrimary : colors.textSecondary,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
    final boxDecoration = BoxDecoration(
      color: selected ? colors.surfaceSelected : colors.surfaceDeep,
      border: Border.all(color: selected ? colors.borderStrong : colors.border),
      borderRadius: BorderRadius.circular(AthenaRadius.pill),
    );
    return AnimatedContainer(
      decoration: boxDecoration,
      duration: AthenaMotion.hover,
      padding: padding,
      child: AnimatedDefaultTextStyle(
        duration: AthenaMotion.hover,
        // 同 button.dart：Animated 版本没有 merge 构造，手动并上环境样式。
        style: DefaultTextStyle.of(context).style.merge(textStyle),
        child: Text(text),
      ),
    );
  }
}

class AthenaTagButton extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final void Function()? onTap;
  final bool selected;

  const AthenaTagButton({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
  }) : padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 5);

  const AthenaTagButton.small({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
  }) : padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3);

  @override
  State<AthenaTagButton> createState() => _AthenaTagButtonState();
}

class _AthenaTagButtonState extends State<AthenaTagButton> {
  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final selected = widget.selected;
    final foregroundColor = selected
        ? colors.textPrimary
        : colors.textSecondary;
    final child = DefaultTextStyle.merge(
      style: AthenaTextStyle.label.copyWith(
        color: foregroundColor,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      child: IconTheme.merge(
        data: IconThemeData(
          color: foregroundColor,
          size: AthenaIcon.inlineSize,
        ),
        child: widget.child,
      ),
    );
    final disabled = widget.onTap == null;
    return AthenaHover(
      enabled: !disabled,
      onTap: widget.onTap,
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder: (context, hover) => AthenaPressScale(
        enabled: !disabled,
        child: AnimatedContainer(
          duration: AthenaMotion.hover,
          decoration: BoxDecoration(
            // 选中态靠"提亮底色 + 加粗文字"表达，不做明暗反转的实心填充。
            color: selected
                ? colors.surfaceSelected
                : hover
                ? colors.surfaceHover
                : colors.surfaceDeep,
            border: Border.all(
              color: selected || hover ? colors.borderStrong : colors.border,
            ),
            borderRadius: BorderRadius.circular(AthenaRadius.pill),
          ),
          padding: widget.padding,
          child: child,
        ),
      ),
    );
  }
}
