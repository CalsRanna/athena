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

  /// 尾随控件（如「清除」按钮）。前景色由 chip 统一注入，调用方只需给字形
  /// 与尺寸；它自己的 onTap 在命中测试里先于 chip 的 onTap 生效。
  final Widget? trailing;

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
    this.trailing,
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
    // hover 的填充是**前景色 5% 的叠加层**，不是某个固定灰。上下文带的底色
    // 就是 surfaceButtonSecondary（浅色 #F0EFEC），而表面状态灰在浅色下几乎与
    // 它同值：surfaceHover 与它完全相同，surfaceSelected 只深 3/255
    // （#EDECE9）——chip 落在带上 hover 等于没反应。
    // Claude 的 hover 填充一律是中性色的 alpha 叠加（`--cds-alpha-1/2/3` =
    // neutral-900 的 5/10/20%，chip 静止 5%、hover 10%），所以任何底色的容器上
    // 都留得住对比度。本仓 chip 坐在已经是 5% 灰的带上，hover 再叠 5%，
    // 合成像素 #E5E4E1 正好等于 Claude「hover 中的 chip」（#E4E4E3）。
    final hoverFill = colors.textPrimary.withValues(alpha: 0.05);
    // 静止态不能写 `Colors.transparent`：它的 RGB 是黑，插值到浅色中途会渲染
    // 成"半透明深灰"，表现为 hover 先闪一下深色再变浅（同 menu.dart 的说明）。
    // 用目标色的 0 透明度版本，RGB 全程一致，只有 alpha 在动。
    final resting = widget.filled
        ? colors.surfaceButtonSecondary
        : hoverFill.withValues(alpha: 0);
    // hover 高亮只对可点的 chip 生效（放在上下文带上时 chip 不带底色，
    // 但可点却毫无反馈同样不对）。自带宽度的 chip 要让叠加层压在自己的底色上
    // （合成成不透明色，避免插值中途出现半透明深色）。
    final background = hover && widget.onTap != null
        ? (widget.filled
              ? Color.alphaBlend(hoverFill, colors.surfaceButtonSecondary)
              : hoverFill)
        : resting;
    var container = AnimatedContainer(
      decoration: BoxDecoration(
        color: background,
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
          if (widget.trailing != null) ...[
            const SizedBox(width: 4),
            IconTheme(
              data: IconThemeData(color: foreground),
              child: widget.trailing!,
            ),
          ],
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
