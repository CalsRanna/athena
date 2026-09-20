import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Codex 风格 chip：小圆角矩形 + 1px 实线边框，没有渐变边框、没有胶囊。
///
/// 选中态靠"提亮底色 + 提亮文字"表达，不做明暗反转的实心填充——
/// 反转填充在纯黑画布上会跳出一块白，破坏 Codex 的安静层次。
class AthenaTag extends StatelessWidget {
  final double fontSize;
  final EdgeInsets padding;
  final bool selected;
  final String text;

  const AthenaTag({
    super.key,
    this.fontSize = AthenaFontSize.label,
    this.selected = false,
    required this.text,
  }) : padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6);

  const AthenaTag.small({
    super.key,
    this.fontSize = AthenaFontSize.caption,
    this.selected = false,
    required this.text,
  }) : padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = TextStyle(
      color: selected ? colors.textPrimary : colors.textSecondary,
      fontSize: fontSize,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      height: 1.4,
    );
    var boxDecoration = BoxDecoration(
      color: selected ? colors.surfaceSelected : colors.surfaceDeep,
      border: Border.all(color: selected ? colors.borderStrong : colors.border),
      borderRadius: BorderRadius.circular(AthenaRadius.pill),
    );
    return AnimatedContainer(
      decoration: boxDecoration,
      duration: const Duration(milliseconds: 150),
      padding: padding,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 150),
        style: textStyle,
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
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var selected = widget.selected;
    var foregroundColor = selected ? colors.textPrimary : colors.textSecondary;
    var background = selected
        ? colors.surfaceSelected
        : hover
        ? colors.surfaceHover
        : colors.surfaceDeep;
    var borderColor = selected || hover ? colors.borderStrong : colors.border;
    var child = DefaultTextStyle.merge(
      style: TextStyle(
        color: foregroundColor,
        fontSize: AthenaFontSize.label,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        height: 1.4,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: foregroundColor, size: 14),
        child: widget.child,
      ),
    );
    var container = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AthenaRadius.pill),
      ),
      padding: widget.padding,
      child: child,
    );
    var mouseRegion = MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: _handleEnter,
      onExit: _handleExit,
      child: container,
    );
    if (widget.onTap == null) return mouseRegion;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: mouseRegion,
    );
  }

  void _handleEnter(PointerEnterEvent event) {
    if (!mounted) return;
    setState(() => hover = true);
  }

  void _handleExit(PointerExitEvent event) {
    if (!mounted) return;
    setState(() => hover = false);
  }
}

/// Composer 内的上下文 chip。
///
/// 与 [AthenaTagButton] 的区别：没有描边，只有一层浅灰填充（Codex 的
/// `#F4F4F4`），因为 composer 本身已经是一个浮起容器，chip 不需要再画边。
/// 形状是胶囊，左侧常带一个 14px 图标。
class AthenaContextChip extends StatefulWidget {
  final Widget? leading;
  final String label;
  final void Function()? onTap;

  /// 是否绘制自己的底色。
  ///
  /// 放在 composer 的上下文带上时传 false：带本身已是浅灰填充，chip 再画一层
  /// 同色底会变成"看不见的胶囊"。Codex 的上下文项就是带上直接排的文字 + 图标。
  final bool filled;

  const AthenaContextChip({
    super.key,
    this.leading,
    required this.label,
    this.onTap,
    this.filled = true,
  });

  @override
  State<AthenaContextChip> createState() => _AthenaContextChipState();
}

class _AthenaContextChipState extends State<AthenaContextChip> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var foreground = widget.onTap == null
        ? colors.textWeak
        : colors.textSecondary;
    var container = AnimatedContainer(
      decoration: BoxDecoration(
        color: !widget.filled
            ? Colors.transparent
            : hover
            ? colors.surfaceSelected
            : colors.surfaceButtonSecondary,
        borderRadius: BorderRadius.circular(AthenaRadius.pill),
      ),
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.leading != null) ...[
            IconTheme(
              data: IconThemeData(color: foreground, size: 13),
              child: widget.leading!,
            ),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: AthenaFontSize.label,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: container,
      ),
    );
  }
}
