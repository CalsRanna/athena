import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 主操作实心按钮的填充色与前景色。
///
/// 深色主题下是白底黑字，浅色主题下是黑底白字——Codex 的主按钮在两种
/// 主题里都是"画布的反色块"，因此取值全部来自 [AthenaColors] 的
/// surfaceRaised / textOnRaised 这一对。
class AthenaIconButton extends StatelessWidget {
  final IconData icon;
  final void Function()? onTap;
  final EdgeInsets? padding;
  const AthenaIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final hugeIcon = Icon(icon, color: colors.iconOnRaised, size: 16);
    final boxDecoration = BoxDecoration(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(AthenaRadius.control),
    );
    final button = Container(
      decoration: boxDecoration,
      padding: padding ?? const EdgeInsets.all(12),
      child: hugeIcon,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: button),
    );
  }
}

class AthenaPrimaryButton extends StatefulWidget {
  final void Function()? onTap;
  final Widget child;
  const AthenaPrimaryButton({super.key, this.onTap, required this.child});

  @override
  State<AthenaPrimaryButton> createState() => _AthenaPrimaryButtonState();
}

class _AthenaPrimaryButtonState extends State<AthenaPrimaryButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // Codex 没有 CTA 光晕：主按钮就是一块干净的反色实心矩形，
    // 悬停只把填充微微压暗（深色主题）/ 提亮（浅色主题）。
    final background = widget.onTap == null
        ? colors.surfaceButtonSecondary
        : hover
        ? Color.alphaBlend(
            colors.surface.withValues(alpha: 0.12),
            colors.surfaceRaised,
          )
        : colors.surfaceRaised;
    final foreground = widget.onTap == null
        ? colors.textSecondary
        : colors.textOnRaised;
    var container = AnimatedContainer(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AthenaRadius.control),
      ),
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: DefaultTextStyle(
        style: TextStyle(
          color: foreground,
          fontSize: AthenaFontSize.label,
          fontWeight: FontWeight.w600,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: foreground, size: 14),
          child: widget.child,
        ),
      ),
    );
    var mouseRegion = MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: handleEnter,
      onExit: handleExit,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: mouseRegion,
    );
  }

  void handleEnter(PointerEnterEvent event) => setState(() => hover = true);

  void handleExit(PointerExitEvent event) => setState(() => hover = false);
}

class AthenaSecondaryButton extends StatefulWidget {
  final void Function()? onTap;
  final EdgeInsets padding;
  final Widget child;

  const AthenaSecondaryButton({super.key, this.onTap, required this.child})
    : padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10);

  const AthenaSecondaryButton.medium({
    super.key,
    this.onTap,
    required this.child,
  }) : padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10);

  const AthenaSecondaryButton.small({
    super.key,
    this.onTap,
    required this.child,
  }) : padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6);

  @override
  State<AthenaSecondaryButton> createState() => _AthenaSecondaryButtonState();
}

class _AthenaSecondaryButtonState extends State<AthenaSecondaryButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var container = AnimatedContainer(
      decoration: BoxDecoration(
        // 同样不能用 Colors.transparent（见 menu.dart 的说明）
        color: widget.onTap != null && hover
            ? colors.surfaceHover
            : colors.surfaceHover.withValues(alpha: 0),
        border: Border.all(
          color: hover && widget.onTap != null
              ? colors.borderStrong
              : colors.border,
        ),
        borderRadius: BorderRadius.circular(AthenaRadius.control),
      ),
      duration: const Duration(milliseconds: 120),
      padding: widget.padding,
      child: DefaultTextStyle(
        style: TextStyle(
          color: widget.onTap == null
              ? colors.textSecondary
              : colors.textPrimary,
          fontSize: AthenaFontSize.label,
          fontWeight: FontWeight.w500,
        ),
        child: IconTheme.merge(
          data: IconThemeData(
            color: widget.onTap == null
                ? colors.textSecondary
                : colors.textPrimary,
            size: 14,
          ),
          child: widget.child,
        ),
      ),
    );
    var mouseRegion = MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: handleEnter,
      onExit: handleExit,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: mouseRegion,
    );
  }

  void handleEnter(PointerEnterEvent event) => setState(() => hover = true);

  void handleExit(PointerExitEvent event) => setState(() => hover = false);
}

class AthenaTextButton extends StatefulWidget {
  final void Function()? onTap;
  final String text;
  const AthenaTextButton({super.key, this.onTap, required this.text});

  @override
  State<AthenaTextButton> createState() => _AthenaTextButtonState();
}

class _AthenaTextButtonState extends State<AthenaTextButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var container = Container(
      decoration: BoxDecoration(
        color: hover ? colors.surfaceHover : Colors.transparent,
        borderRadius: BorderRadius.circular(AthenaRadius.control),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        widget.text,
        style: TextStyle(
          color: hover ? colors.textPrimary : colors.textSecondary,
          fontSize: AthenaFontSize.label,
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: container,
      ),
    );
  }
}
